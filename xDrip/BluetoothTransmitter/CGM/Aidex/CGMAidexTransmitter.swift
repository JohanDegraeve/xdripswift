import CoreBluetooth
import Foundation
import os

class CGMAidexTransmitter: BluetoothTransmitter, CGMTransmitter {

    // MARK: - properties

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?

    /// cached calibration value (mg/dL) to send after next glucose reading arrives.
    /// AidexSensor.sendCalibration requires a valid lastOffsetMinutes, which is only
    /// available after the first F003 glucose notification.
    private var pendingCalibrationMgDl: Int?

    /// CGMAidexTransmitterDelegate
    public weak var cGMAidexTransmitterDelegate: CGMAidexTransmitterDelegate?

    /// underlying AidexSensor driver
    private var aidexSensor: AidexSensor?

    /// devices discovered during scan-only mode (keyed by peripheral identifier)
    private(set) var discoveredDevices: [UUID: DiscoveredAidexSensor] = [:]

    /// scan timeout work item
    private var scanTimeoutWork: DispatchWorkItem?

    /// is nonFixed enabled (Aidex always sends calibrated data, so nonFixed is irrelevant but required by protocol)
    private var nonFixedSlopeEnabled: Bool

    /// for trace
    let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAidex)
    private static let staticLog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAidex)

    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []

    /// current sensor serial number
    private var sensorSerialNumber: String?

    /// stable peripheral identifier (UUID) from the first successful connection,
    /// used for direct retrieval on restart instead of scanning by name.
    private var storedPeripheralIdentifier: UUID? {
        get {
            guard let key = persistentKey else { return nil }
            if let uuidString = UserDefaults.standard.string(forKey: "aidex.storedIdentifier.\(key)"),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            return nil
        }
        set {
            guard let key = persistentKey else { return }
            if let uuid = newValue {
                UserDefaults.standard.set(uuid.uuidString, forKey: "aidex.storedIdentifier.\(key)")
            } else {
                UserDefaults.standard.removeObject(forKey: "aidex.storedIdentifier.\(key)")
            }
        }
    }

    /// stable key for UserDefaults persistence — uses device name (serial) as key
    private var persistentKey: String? {
        let key = deviceName ?? deviceAddress
        guard let k = key, !k.isEmpty else { return nil }
        let sanitized = k.replacingOccurrences(of: " ", with: "_")
                         .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? nil : sanitized
    }

    /// Timestamp (ms) of the last CLEAR_STORAGE / SET_NEW_SENSOR operation.
    /// Persisted in UserDefaults so it survives app restarts. When the sensor
    /// reports a factory (stale) start time after reset, this is used as the
    /// effective sensor start time instead.
    private var lastSensorActivationTimestampMs: Int64 {
        get {
            guard let key = persistentKey else { return 0 }
            let raw = UserDefaults.standard.integer(forKey: "aidex.lastActivationMs.\(key)")
            return raw > 0 ? Int64(raw) : 0
        }
        set {
            guard let key = persistentKey else { return }
            if newValue > 0 {
                UserDefaults.standard.set(Int(newValue), forKey: "aidex.lastActivationMs.\(key)")
            } else {
                UserDefaults.standard.removeObject(forKey: "aidex.lastActivationMs.\(key)")
            }
        }
    }

    /// current sensor start time in ms
    private var sensorStartTimeMs: Int64 = 0

    /// wear days reported by sensor
    private var wearDays: Int = 0

    /// battery millivolts
    private var batteryMillivoltsStorage: Int = 0

    /// sensor age (computed from the best available start time).
    /// If the sensor-reported startTimeMs is older than wearDays + 1 day
    /// (indicating a factory timestamp that survived CLEAR_STORAGE), the
    /// persisted last-activation timestamp is used as a fallback.
    private var sensorAge: TimeInterval {
        let effectiveStartMs: Int64
        if sensorStartTimeMs > 0, wearDays > 0 {
            let maxAllowedAgeMs = Int64(wearDays + 1) * 86_400_000
            let ageFromSensorMs = Int64(Date().timeIntervalSince1970 * 1000) - sensorStartTimeMs
            if ageFromSensorMs > maxAllowedAgeMs, lastSensorActivationTimestampMs > 0 {
                effectiveStartMs = lastSensorActivationTimestampMs
                trace("CGMAidex: sensorAge using lastActivation fallback — sensor reports %{public}lld ms old (max %{public}lld), using persisted activation", log: log, category: ConstantsLog.categoryAidex, type: .info, ageFromSensorMs, maxAllowedAgeMs)
            } else {
                effectiveStartMs = sensorStartTimeMs
            }
        } else if sensorStartTimeMs > 0 {
            effectiveStartMs = sensorStartTimeMs
        } else {
            return 0
        }
        return TimeInterval((Int64(Date().timeIntervalSince1970 * 1000) - effectiveStartMs) / 1000)
    }

    /// Public battery millivolts for UI display.
    var batteryMillivolts: Int { batteryMillivoltsStorage }

    /// Sensor age in hours (for UI display).
    var sensorAgeHours: Int { Int(sensorAge / 3600) }

    /// Remaining sensor life in hours (for UI display).
    var sensorRemainingHours: Int {
        guard wearDays > 0, sensorStartTimeMs > 0 else { return 0 }
        let expiryMs = sensorStartTimeMs + Int64(wearDays) * 86_400_000
        let remainingMs = expiryMs - Int64(Date().timeIntervalSince1970 * 1000)
        return max(0, Int(remainingMs / 3_600_000))
    }

    // MARK: - Initialization

    init(address: String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMAidexTransmitterDelegate: CGMAidexTransmitterDelegate, sensorSerialNumber: String?, cGMTransmitterDelegate: CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?, webOOPEnabled: Bool?) {
        var newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: name ?? "AiDex")

        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name ?? "AiDex")
        }

        self.sensorSerialNumber = sensorSerialNumber
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        self.cGMAidexTransmitterDelegate = cGMAidexTransmitterDelegate
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false

        // Aidex has no write characteristic used by the base class.
        // Pass a valid placeholder UUID to avoid CBUUID(string:"") crash on restore.
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: nil, CBUUID_ReceiveCharacteristic: "F003", CBUUID_WriteCharacteristic: AidexUUID.charF002, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    // MARK: - overridden BluetoothTransmitter functions

    /// Prevents the base class from calling retrievePeripherals() with a non-UUID
    /// deviceAddress (Aidex stores the sensor name there). Instead, when Bluetooth
    /// powers on, start the AidexSensor connection flow directly.
    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Propagate the state change to the delegate (UI layer).
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: central.state, bluetoothTransmitter: self)
        }

        if central.state == .poweredOn {
            // Aidex manages its own CBCentralManager inside AidexSensor — the base
            // class centralManager is unused. Suppress the base-class
            // retrievePeripherals() path and start our own connection flow.
            let name = deviceName ?? deviceAddress
            if let sensorName = name, !sensorName.isEmpty {
                trace("CGMAidex: centralManagerDidUpdateState poweredOn — starting connection for %{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, sensorName)
                startAidexSensor(deviceName: sensorName)
            } else {
                trace("CGMAidex: centralManagerDidUpdateState poweredOn — no deviceName/deviceAddress, starting scan", log: log, category: ConstantsLog.categoryAidex, type: .info)
                scanForDevices()
            }
        }
    }

    /// Prevents base class from auto-connecting via its own CBCentralManager.
    /// Aidex uses AidexSensor for connections; the base CBCentralManager is unused.
    override func connect() {
        let name = deviceName ?? deviceAddress
        guard let sensorName = name, !sensorName.isEmpty else {
            trace("CGMAidex: connect() suppressed — no deviceName/deviceAddress", log: log, category: ConstantsLog.categoryAidex, type: .info)
            return
        }
        trace("CGMAidex: connect() proceeding with name=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, sensorName)
        startAidexSensor(deviceName: sensorName)
    }

    /// Returns the AidexSensor peripheral connection state so the UI can show
    /// "Connected" instead of "Reconnecting". The base class peripheral is always
    /// nil for Aidex (connection is managed by AidexSensor's own CBCentralManager).
    override func getConnectionStatus() -> CBPeripheralState? {
        return aidexSensor?.peripheral?.state
    }

    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        trace("CGMAidex: startScanning called, deviceName=%{public}@ deviceAddress=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, deviceName ?? "nil", deviceAddress ?? "nil")
        let name = deviceName ?? deviceAddress
        if let sensorName = name, !sensorName.isEmpty {
            startAidexSensor(deviceName: sensorName)
        } else {
            trace("CGMAidex: no device name known — falling back to scanForDevices()", log: log, category: ConstantsLog.categoryAidex, type: .info)
            scanForDevices()
        }
        return .success
    }

    /// Scan-only mode: collects all nearby Aidex sensors without connecting.
    func scanForDevices() {
        // Prevent duplicate scanners — if one is already running, let it finish.
        if objc_getAssociatedObject(self, &AssociatedKeys.scanner) != nil {
            trace("CGMAidex: scanForDevices skipped — scanner already running", log: log, category: ConstantsLog.categoryAidex, type: .info)
            return
        }
        trace("CGMAidex: scanForDevices called", log: log, category: ConstantsLog.categoryAidex, type: .info)
        discoveredDevices.removeAll()
        scanTimeoutWork?.cancel()

        // Use a lightweight private scanner with its own CBCentralManager.
        // No restore ID, no AidexSensor, no bonding — pure advertisement collection.
        let queue = DispatchQueue(label: "aidex.scanonly.\(UUID().uuidString.prefix(8))", qos: .userInitiated)
        let scanner = AidexDeviceScanner(deviceName: deviceName ?? "AiDex") { [weak self] devices in
            os_log("Aidex: scanner completion called, devices=%{public}d, self=%{public}@", log: CGMAidexTransmitter.staticLog, type: .info, devices.count, self == nil ? "nil" : "alive")
            guard let self else {
                os_log("Aidex: scanner completion — self is nil, dropping results", log: CGMAidexTransmitter.staticLog, type: .error)
                return
            }
            // Clean up associated object so next scanForDevices() can start fresh
            objc_setAssociatedObject(self, &AssociatedKeys.scanner, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            self.scanTimeoutWork = nil
            self.discoveredDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.peripheral.identifier, $0) })
            os_log("Aidex: scanner discoveredDevices populated, count=%{public}d, dispatching to main", log: CGMAidexTransmitter.staticLog, type: .info, self.discoveredDevices.count)

            DispatchQueue.main.async {
                os_log("Aidex: calling aidexDidFinishScanning delegate, devices=%{public}d, delegate=%{public}@", log: CGMAidexTransmitter.staticLog, type: .info, devices.count, String(describing: self.cGMAidexTransmitterDelegate))
                self.cGMAidexTransmitterDelegate?.aidexDidFinishScanning(
                    devices: devices,
                    from: self
                )
            }
        }

        // Keep scanner alive via associated object
        objc_setAssociatedObject(self, &AssociatedKeys.scanner, scanner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        trace("Aidex: scanner retained via objc, self=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, String(describing: Unmanaged.passUnretained(self).toOpaque()))

        let timeout = DispatchWorkItem { [weak scanner] in
            scanner?.stop()
        }
        scanTimeoutWork = timeout
        scanner.start(timeout: timeout, queue: queue)
        trace("Aidex: scanner.start() called", log: log, category: ConstantsLog.categoryAidex, type: .info)
    }

    /// Connect to a specific device discovered during scan-only mode.
    func connectToDiscoveredDevice(_ discovered: DiscoveredAidexSensor) {
        trace("CGMAidex: connectToDiscoveredDevice name=%{public}@ addr=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, discovered.name, discovered.peripheral.identifier.uuidString)

        scanTimeoutWork?.cancel()
        scanTimeoutWork = nil
        objc_setAssociatedObject(self, &AssociatedKeys.scanner, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Save the peripheral identifier immediately so it survives even if
        // aidexDidConnect fires before sensor.peripheral is set (race condition).
        storedPeripheralIdentifier = discovered.peripheral.identifier

        if let oldSensor = aidexSensor {
            oldSensor.delegate = nil
            oldSensor.disconnect()
        }
        aidexSensor = nil

        let config = AidexSensorConfig(deviceName: discovered.name, peripheralIdentifier: discovered.peripheral.identifier, scanOnly: false)
        let sensor = AidexSensor(config: config)
        sensor.delegate = self
        self.aidexSensor = sensor
        sensor.connectToDiscovered(discovered)
    }

    /// Connect to a device selected by the user from scan results (by device address).
    func connectToDiscoveredDevice(withAddress address: String) {
        guard let device = discoveredDevices.values.first(where: { $0.peripheral.identifier.uuidString == address }) else {
            trace("CGMAidex: connectToDiscoveredDevice — address %{public}@ not found in discovered devices", log: log, category: ConstantsLog.categoryAidex, type: .error, address)
            return
        }
        connectToDiscoveredDevice(device)
    }

    override func stopScanning() {
        aidexSensor?.pause()
    }

    override func disconnect() {
        aidexSensor?.disconnect()
    }

    override func prepareForRelease() {
        super.prepareForRelease()
        aidexSensor?.disconnect()
        aidexSensor = nil
    }

    deinit {
        aidexSensor?.disconnect()
    }

    // MARK: - AidexSensor lifecycle

    private func startAidexSensor(deviceName: String) {
        if let existing = aidexSensor {
            trace("CGMAidex: startAidexSensor — existing sensor already present, skipping duplicate creation", log: log, category: ConstantsLog.categoryAidex, type: .info)
            return
        }

        trace("CGMAidex: startAidexSensor deviceName=%{public}@ storedIdentifier=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, deviceName, storedPeripheralIdentifier?.uuidString ?? "nil")
        let config: AidexSensorConfig
        if let identifier = storedPeripheralIdentifier {
            trace("CGMAidex: startAidexSensor using stored peripheral identifier for direct connect", log: log, category: ConstantsLog.categoryAidex, type: .info)
            config = AidexSensorConfig(deviceName: deviceName, peripheralIdentifier: identifier, scanOnly: false)
        } else {
            trace("CGMAidex: startAidexSensor no stored identifier — will scan by name=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, deviceName)
            config = AidexSensorConfig(deviceName: deviceName, scanOnly: false)
        }
        let sensor = AidexSensor(config: config)
        sensor.delegate = self
        self.aidexSensor = sensor
        sensor.connect()
    }

    // MARK: - Hardware Reset

    /// Sends CLEAR_STORAGE (0xF3) command to the sensor.
    func resetSensor() {
        // Persist current time as the effective sensor activation timestamp.
        // After CLEAR_STORAGE, the sensor may continue reporting a stale
        // factory start time via 0x21 — this persisted value acts as a fallback.
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        print("[Aidex-DEBUG] ═══ CGMAidexTransmitter.resetSensor() called — nowMs=\(nowMs) date=\(Date(timeIntervalSince1970: Double(nowMs)/1000))")
        lastSensorActivationTimestampMs = nowMs
        // Also push into the AidexSensor so post-reset reconnect logic works.
        aidexSensor?.postResetRequestedAtMs = nowMs
        aidexSensor?.needsPostResetActivation = true
        aidexSensor?.resetSensor()
    }

    /// Sends DELETE_BOND (0xF2) command — removes only the vendor-level bond
    func unpairSensor() {
        // Clear persisted activation timestamp on unpair.
        lastSensorActivationTimestampMs = 0
        aidexSensor?.unpairSensor()
    }

    // MARK: - CGMTransmitter protocol

    func setNonFixedSlopeEnabled(enabled: Bool) {
        // Aidex sends calibrated data — non-fixed slope is not applicable
    }

    func isNonFixedSlopeEnabled() -> Bool {
        return false
    }

    func setWebOOPEnabled(enabled: Bool) {
        // Aidex sends calibrated data — webOOP is irrelevant
    }

    func isWebOOPEnabled() -> Bool {
        return true // Aidex always sends calibrated data
    }

    func overruleIsWebOOPEnabled() -> Bool {
        return false
    }

    func nonWebOOPAllowed() -> Bool {
        return false
    }

    func isAnubisG6() -> Bool {
        return false
    }

    func cgmTransmitterType() -> CGMTransmitterType {
        return .Aidex
    }

    func requestNewReading() {
        // Aidex streams automatically, no manual trigger
    }

    func maxSensorAgeInDays() -> Double? {
        return wearDays > 0 ? Double(wearDays) : nil
    }

    func startSensor(sensorCode: String?, startDate: Date) {
        // Aidex handles sensor activation through its own protocol
    }

    func stopSensor(stopDate: Date) {
        // Aidex handles sensor stop through its own protocol
    }

    func calibrate(calibration: Calibration) {
        guard let aidexSensor = aidexSensor else {
            trace("CGMAidex: calibrate failed — no AidexSensor", log: log, category: ConstantsLog.categoryAidex, type: .error)
            return
        }

        let mgDl = Int(calibration.bg)
        trace("CGMAidex: calibrate mgDl=%{public}d isVendorPaired=%{public}@ offsetMinutes=%{public}d", log: log, category: ConstantsLog.categoryAidex, type: .info, mgDl, aidexSensor.isVendorPaired.description, aidexSensor.currentOffsetMinutes)

        if aidexSensor.isVendorPaired, aidexSensor.currentOffsetMinutes > 0 {
            aidexSensor.calibrateSensor(glucoseMgDl: mgDl)
        } else {
            // Queue calibration for after key exchange and first glucose reading
            pendingCalibrationMgDl = mgDl
            trace("CGMAidex: queued calibration for after key exchange", log: log, category: ConstantsLog.categoryAidex, type: .info)
        }
    }

    func needsSensorStartTime() -> Bool {
        return false
    }

    func needsSensorStartCode() -> Bool {
        return false
    }

    func shouldWarnOnLargeCalibrationStep() -> Bool {
        return false
    }

    func getCBUUID_Service() -> String {
        return AidexUUID.service
    }

    func getCBUUID_Receive() -> String {
        return AidexUUID.charF003
    }
}

// MARK: - Associated Keys for objc associated objects

private enum AssociatedKeys {
    static var scanner: UInt8 = 0
}

// MARK: - AidexDeviceScanner (lightweight scan-only, no bonding)

/// Lightweight BLE scanner for Aidex sensors. Uses its own CBCentralManager with no
/// restore identifier, never connects, never triggers pairing — only collects advertisements.
private final class AidexDeviceScanner: NSObject, CBCentralManagerDelegate {

    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAidex)

    private let deviceName: String
    private let completion: (([DiscoveredAidexSensor]) -> Void)
    private var centralManager: CBCentralManager?
    private var discovered: [UUID: DiscoveredAidexSensor] = [:]
    private var timeoutWork: DispatchWorkItem?
    private var queue: DispatchQueue?

    init(deviceName: String, completion: @escaping ([DiscoveredAidexSensor]) -> Void) {
        self.deviceName = deviceName
        self.completion = completion
        super.init()
    }

    func start(timeout: DispatchWorkItem, queue: DispatchQueue) {
        self.queue = queue
        self.timeoutWork = timeout
        os_log("AidexScanner: creating CBCentralManager on queue=%{public}@", log: Self.log, type: .info, queue.label)
        centralManager = CBCentralManager(delegate: self, queue: queue,
                                          options: [CBCentralManagerOptionShowPowerAlertKey: false])
        queue.asyncAfter(deadline: .now() + .seconds(10), execute: timeout)
    }

    func stop() {
        os_log("AidexScanner: stop — discovered %{public}d device(s)", log: Self.log, type: .info, self.discovered.count)
        centralManager?.stopScan()
        centralManager?.delegate = nil
        centralManager = nil
        timeoutWork?.cancel()
        timeoutWork = nil

        let devices = discovered.values.sorted { $0.rssi > $1.rssi }
        completion(devices)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        os_log("AidexScanner: centralManager state=%{public}ld", log: Self.log, type: .info, central.state.rawValue)
        if central.state == .poweredOn {
            // Scan without service filter — Aidex sensors may not advertise the service UUID.
            // We filter by device name prefix in didDiscover instead.
            os_log("AidexScanner: starting scan (no service filter)", log: Self.log, type: .info)
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        os_log("AidexScanner: didDiscover name='%{public}@' rssi=%{public}@", log: Self.log, type: .info, name, RSSI)

        // Match only against the peripheral's own name, not deviceName.
        // deviceName was being matched incorrectly — it's always "AiDex" so it
        // matched every single BLE device in range.
        let isAidexSensor = name.isEmpty ? false : AidexUUID.knownNamePrefixes.contains { prefix in
            name.range(of: prefix, options: .caseInsensitive) != nil
        }
        guard isAidexSensor else { return }
        guard discovered[peripheral.identifier] == nil else { return }

        os_log("AidexScanner: matched Aidex sensor: name='%{public}@' rssi=%{public}@", log: Self.log, type: .info, name, RSSI)
        let entry = DiscoveredAidexSensor(
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue,
            advertisementData: advertisementData
        )
        discovered[peripheral.identifier] = entry
    }
}

// MARK: - AidexDriverDelegate

extension CGMAidexTransmitter: AidexDriverDelegate {

    func aidexDidConnect(_ sensor: AidexSensor) {
        if let storedId = sensor.peripheral?.identifier {
            storedPeripheralIdentifier = storedId
        }

        // Notify the base-class delegate so connectedAt / UI status is updated.
        // Aidex uses its own CBCentralManager (inside AidexSensor), so the base
        // class didConnect callback never fires — we must forward it manually.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)
            self.cGMAidexTransmitterDelegate?.aidexDidConnect(sensor, from: self)
        }
    }

    func aidexDidDisconnect(_ sensor: AidexSensor, reason: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bluetoothTransmitterDelegate?.didDisconnectFrom(bluetoothTransmitter: self)
            self.cGMAidexTransmitterDelegate?.aidexDidDisconnect(sensor, from: self)
        }
    }

    func aidexNeedsPairing(_ sensor: AidexSensor) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMAidexTransmitterDelegate?.aidexNeedsPairing(from: self)
        }
    }

    func aidex(_ sensor: AidexSensor, didReceive glucose: AidexGlucosePoint) {
        trace("CGMAidex: didReceive glucose=%.1f mg/dL sensorAge=%.0fh startTimeMs=%{public}lld", log: log, category: ConstantsLog.categoryAidex, type: .info, glucose.glucoseMgDl, sensorAge / 3600, sensorStartTimeMs)

        // Flush any pending calibration now that we have a valid offset
        if let pendingMgDl = pendingCalibrationMgDl, sensor.isVendorPaired, sensor.currentOffsetMinutes > 0 {
            trace("CGMAidex: flushing pending calibration %{public}d mg/dL (offsetMinutes=%{public}d)", log: log, category: ConstantsLog.categoryAidex, type: .info, pendingMgDl, sensor.currentOffsetMinutes)
            sensor.calibrateSensor(glucoseMgDl: pendingMgDl)
            pendingCalibrationMgDl = nil
        }

        // Guard against timestamps more than 10 minutes in the future
        let now = Date()
        let futureCutoff = now.addingTimeInterval(10 * 60)
        let safeTimestamp = glucose.timestamp <= futureCutoff ? glucose.timestamp : now

        let glucoseData = GlucoseData(timeStamp: safeTimestamp, glucoseLevelRaw: Double(glucose.glucoseMgDl))
        var data = [glucoseData]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &data, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
        }
    }

    func aidex(_ sensor: AidexSensor, didUpdateState state: SensorSnapshot) {
        if state.startTimeMs > 0, state.startTimeMs != sensorStartTimeMs {
            sensorStartTimeMs = state.startTimeMs
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cGMAidexTransmitterDelegate?.received(sensorStartTimeMs: state.startTimeMs, from: self)
            }
        }

        if state.officialEndMs > state.startTimeMs, state.startTimeMs > 0 {
            let maxWearDays = Int((state.officialEndMs - state.startTimeMs) / 86_400_000)
            if maxWearDays > 0, maxWearDays != wearDays {
                wearDays = maxWearDays
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.cGMAidexTransmitterDelegate?.received(wearDays: maxWearDays, from: self)
                }
            }
        }
    }

    func aidex(_ sensor: AidexSensor, keyExchangeComplete: Bool) {
        trace("CGMAidex: keyExchangeComplete, vendorPaired=%{public}@ serial=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, sensor.isVendorPaired.description, sensor.serial)
        if sensorSerialNumber == nil {
            sensorSerialNumber = sensor.serial
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cGMAidexTransmitterDelegate?.received(serialNumber: sensor.serial, from: self)
            }
        }
    }

    func aidex(_ sensor: AidexSensor, batteryMillivolts: Int) {
        trace("CGMAidex: batteryMillivolts=%{public}d", log: log, category: ConstantsLog.categoryAidex, type: .info, batteryMillivolts)
        self.batteryMillivoltsStorage = batteryMillivolts
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMAidexTransmitterDelegate?.received(batteryMillivolts: batteryMillivolts, from: self)
        }
    }

    func aidex(_ sensor: AidexSensor, didFinishScanning devices: [DiscoveredAidexSensor]) {
        trace("CGMAidex: didFinishScanning count=%{public}d", log: log, category: ConstantsLog.categoryAidex, type: .info, devices.count)
        discoveredDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.peripheral.identifier, $0) })
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMAidexTransmitterDelegate?.aidexDidFinishScanning(devices: devices, from: self)
        }
    }

    func aidex(_ sensor: AidexSensor, didReceiveStartupInfo info: StartupDeviceInfo) {
        trace("CGMAidex: didReceiveStartupInfo wearDays=%{public}d fw=%{public}@ hw=%{public}@ model=%{public}@", log: log, category: ConstantsLog.categoryAidex, type: .info, info.wearDays, info.firmwareVersion, info.hardwareVersion, info.modelName)

        if info.wearDays > 0 {
            wearDays = info.wearDays
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMAidexTransmitterDelegate?.received(wearDays: info.wearDays, from: self)
            if !info.firmwareVersion.isEmpty {
                self.cGMAidexTransmitterDelegate?.received(firmwareVersion: info.firmwareVersion, from: self)
            }
            if !info.modelName.isEmpty {
                self.cGMAidexTransmitterDelegate?.received(modelName: info.modelName, from: self)
            }
        }
    }

    // Default (no-op) implementations for optional protocol methods
    func aidex(_ sensor: AidexSensor, didReceiveCalibrationResult success: Bool, message: String) {}
    func aidex(_ sensor: AidexSensor, didReceiveHistory range: HistoryRange) {}
    func aidex(_ sensor: AidexSensor, didReceiveCalibratedHistory entries: [CalibratedHistoryEntry]) {}
    func aidex(_ sensor: AidexSensor, didReceiveAdcHistory entries: [AdcHistoryEntry]) {}
    func aidex(_ sensor: AidexSensor, didReceiveCalibrations records: [CalibrationRecord]) {}

    func aidex(_ sensor: AidexSensor, didActivateSensorAtMs activationMs: Int64) {
        lastSensorActivationTimestampMs = activationMs
        trace("CGMAidex: didActivateSensorAtMs=%{public}lld", log: log, category: ConstantsLog.categoryAidex, type: .info, activationMs)
    }
}
