import Foundation
import CoreBluetooth

/// Готовое показание глюкозы от сенсора.
public struct AidexGlucosePoint: Hashable, Identifiable {
    public let timestamp: Date
    public let glucoseMgDl: Float
    public let rawMgDl: Float?
    public let sensorGlucoseMgDl: Float?
    public let rawI1: Float?
    public let rawI2: Float?
    public let timeOffsetMinutes: Int?
    public let sensorSerial: String
    public var id: String { "\(Int(timestamp.timeIntervalSince1970 * 1000))_\(sensorSerial)" }
}

/// Информация об обнаруженном сенсоре (режим сканирования).
public struct DiscoveredAidexSensor {
    public let peripheral: CBPeripheral
    public let name: String
    public let rssi: Int
    public let advertisementData: [String: Any]

    public init(peripheral: CBPeripheral, name: String, rssi: Int, advertisementData: [String: Any]) {
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.advertisementData = advertisementData
    }
}

public struct AidexSensorConfig {
    public let deviceName: String
    public let peripheralIdentifier: UUID?
    /// Если true — сенсор собирает все найденные устройства и возвращает их через делегата,
    /// а не подключается к первому совпадению.
    public let scanOnly: Bool
    /// Таймаут сканирования в режиме scanOnly (секунды). По умолчанию 10.
    public let scanTimeout: TimeInterval

    public init(deviceName: String,
                peripheralIdentifier: UUID? = nil,
                scanOnly: Bool = false,
                scanTimeout: TimeInterval = 10) {
        self.deviceName = deviceName
        self.peripheralIdentifier = peripheralIdentifier
        self.scanOnly = scanOnly
        self.scanTimeout = scanTimeout
    }
}

public protocol AidexDriverDelegate: AnyObject {
    func aidexDidConnect(_ sensor: AidexSensor)
    func aidexDidDisconnect(_ sensor: AidexSensor, reason: String)
    func aidexNeedsPairing(_ sensor: AidexSensor)
    func aidex(_ sensor: AidexSensor, didReceive glucose: AidexGlucosePoint)
    func aidex(_ sensor: AidexSensor, didUpdateState state: SensorSnapshot)
    func aidex(_ sensor: AidexSensor, keyExchangeComplete: Bool)
    func aidex(_ sensor: AidexSensor, didReceiveCalibrationResult success: Bool, message: String)
    func aidex(_ sensor: AidexSensor, didReceiveHistory range: HistoryRange)
    func aidex(_ sensor: AidexSensor, didReceiveCalibratedHistory entries: [CalibratedHistoryEntry])
    func aidex(_ sensor: AidexSensor, didReceiveAdcHistory entries: [AdcHistoryEntry])
    func aidex(_ sensor: AidexSensor, didReceiveCalibrations records: [CalibrationRecord])
    func aidex(_ sensor: AidexSensor, didReceiveStartupInfo info: StartupDeviceInfo)
    func aidex(_ sensor: AidexSensor, batteryMillivolts: Int)
    /// Вызывается при завершении режима сканирования (scanOnly). Возвращает все найденные сенсоры.
    func aidex(_ sensor: AidexSensor, didFinishScanning devices: [DiscoveredAidexSensor])
    /// Вызывается при активации сенсора (SET_NEW_SENSOR 0x20) — передаёт timestamp активации в мс.
    func aidex(_ sensor: AidexSensor, didActivateSensorAtMs activationMs: Int64)
}

public extension AidexDriverDelegate {
    func aidexDidConnect(_ sensor: AidexSensor) {}
    func aidexDidDisconnect(_ sensor: AidexSensor, reason: String) {}
    func aidexNeedsPairing(_ sensor: AidexSensor) {}
    func aidex(_ sensor: AidexSensor, didReceive glucose: AidexGlucosePoint) {}
    func aidex(_ sensor: AidexSensor, didUpdateState state: SensorSnapshot) {}
    func aidex(_ sensor: AidexSensor, keyExchangeComplete: Bool) {}
    func aidex(_ sensor: AidexSensor, didReceiveCalibrationResult success: Bool, message: String) {}
    func aidex(_ sensor: AidexSensor, didReceiveHistory range: HistoryRange) {}
    func aidex(_ sensor: AidexSensor, didReceiveCalibratedHistory entries: [CalibratedHistoryEntry]) {}
    func aidex(_ sensor: AidexSensor, didReceiveAdcHistory entries: [AdcHistoryEntry]) {}
    func aidex(_ sensor: AidexSensor, didReceiveCalibrations records: [CalibrationRecord]) {}
    func aidex(_ sensor: AidexSensor, didReceiveStartupInfo info: StartupDeviceInfo) {}
    func aidex(_ sensor: AidexSensor, batteryMillivolts: Int) {}
    func aidex(_ sensor: AidexSensor, didFinishScanning devices: [DiscoveredAidexSensor]) {}
    func aidex(_ sensor: AidexSensor, didActivateSensorAtMs activationMs: Int64) {}
}

enum StartupControlStage {
    case idle
    case waitDynamicAdvAck
    case waitAutoUpdateAck
    case failed
    case complete
}

// MARK: - AidexSensor

public final class AidexSensor: NSObject, ObservableObject {

    public let serial: String
    public let config: AidexSensorConfig
    public weak var delegate: AidexDriverDelegate?

    @Published public internal(set) var connectionPhase: ConnectionPhase = .idle
    @Published public internal(set) var isStreaming = false
    @Published public internal(set) var lastGlucose: AidexGlucosePoint?
    @Published public internal(set) var batteryMV = 0
    @Published public internal(set) var sensorExpired = false
    @Published public internal(set) var rssi = 0
    @Published public internal(set) var sensorStartTimeMs: Int64 = 0
    @Published public internal(set) var firmwareVersion = ""
    @Published public internal(set) var hardwareVersion = ""
    @Published public internal(set) var modelName = ""
    @Published public internal(set) var wearDays = 0
    @Published public internal(set) var sensorReportedWearDays = false
    @Published public internal(set) var calibrations: [CalibrationRecord] = []
    @Published public internal(set) var statusMessage = ""

    public var isVendorPaired: Bool { keyExchange.isComplete }

    /// Sensor warmup status derived from sensorStartTimeMs (set via 0x21 / 0x2AAA).
    /// - .unknown: sensor not activated yet (all-zeros start time) or not yet read
    /// - .warmingUp: elapsed < 7 min since activation — sensor is conditioning
    /// - .ready: elapsed >= 7 min — sensor should be streaming glucose
    public enum WarmupState: Equatable, CustomStringConvertible {
        case unknown
        case warmingUp(elapsedSeconds: Int, remainingSeconds: Int)
        case ready(elapsedSeconds: Int)

        public var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .warmingUp(_, let remaining):
                if remaining > 60 { return "Warming up — \(remaining / 60)m \(remaining % 60)s left" }
                return "Warming up — \(remaining)s left"
            case .ready(let elapsed): return "Ready (\(elapsed / 60)m since start)"
            }
        }

        public var isWarmingUp: Bool { if case .warmingUp = self { return true }; return false }
        public var isReady: Bool { if case .ready = self { return true }; return false }
    }

    /// Minimum warmup duration before the sensor can produce glucose readings.
    static let warmupDurationSeconds: Int = 7 * 60

    public var warmupState: WarmupState {
        guard sensorStartTimeMs > 0 else { return .unknown }
        let startSec = Int(sensorStartTimeMs / 1000)
        let nowSec = Int(Date().timeIntervalSince1970)
        let elapsed = nowSec - startSec
        guard elapsed >= 0 else { return .unknown }
        if elapsed < Self.warmupDurationSeconds {
            return .warmingUp(elapsedSeconds: elapsed, remainingSeconds: Self.warmupDurationSeconds - elapsed)
        }
        return .ready(elapsedSeconds: elapsed)
    }

    /// Exposed for external calibration: the offset (in minutes) of the most recent
    /// glucose reading relative to sensor start. Required by sendCalibration to build
    /// the SET_CALIBRATION command. Returns 0 if no glucose has been received yet.
    public var currentOffsetMinutes: Int { lastOffsetMinutes }

    /// Send a calibration value (mg/dL) to the sensor.
    /// Requires key exchange to be complete and a valid offset from a prior glucose reading.
    public func calibrateSensor(glucoseMgDl: Int) {
        sendCalibration(glucoseMgDl: glucoseMgDl)
    }

    // Internal state
    var centralManager: CBCentralManager!
    public internal(set) var peripheral: CBPeripheral?
    let keyExchange: AidexKeyExchange
    lazy var commandBuilder = AidexCommandBuilder(keyExchange: keyExchange)
    var bareSerial: String { keyExchange.bareSerial }

    var f001: CBCharacteristic?
    var f002: CBCharacteristic?
    var f003: CBCharacteristic?
    var cgmSessionStartChar: CBCharacteristic?
    var modelNumberChar: CBCharacteristic?
    var softwareRevChar: CBCharacteristic?
    var manufacturerChar: CBCharacteristic?

    var challengeWritten = false
    var bondDataRead = false
    /// True when F001 (auth char) hit an insufficient-authentication wall before SMP
    /// bonding completed. Key exchange must wait until the link is encrypted.
    var keyExchangePendingBond = false
    var pendingCCCD: [CBCharacteristic] = []
    var cccdIndex = 0
    var cccdChainComplete = false
    /// Number of setNotifyValue retries for the current CCCD characteristic.
    /// Resets on each successful advance. After N failures the chain gives up and reconnects.
    var cccdRetryCount = 0
    static let cccdMaxRetries = 4
    var postKeyCCCDRefreshed = false
    /// True when a post-bond CCCD chain is in progress. When the chain completes
    /// (onCCCDChainComplete), deferred commands (startup info, history) are sent.
    var postKeySetupPending = false

    var historyDownloading = false
    var historyDownloadedOnce = false
    var historyRawNextIndex = 0
    var historyBriefNextIndex = 0
    var historyNewestOffset = 0
    var calibratedGlucoseCache: [Int: CalibratedHistoryEntry] = [:]

    var keyExchangeWatchdog: DispatchWorkItem?
    var historyPageWatchdog: DispatchWorkItem?
    var initialHistoryRequestWork: DispatchWorkItem?

    var reconnectAttempts = 0
    var consecutiveConnectFailures = 0
    var shouldReconnect = true

    var pendingResetReconnect = false
    var clearStorageQuietWindowActive = false
    var postResetRescanActive = false
    var postResetFailCount = 0
    static let maxPostResetFailures = 3
    var resetCompensationEnabled = false
    var needsPostResetActivation = false
    var autoActivationAttempted = false
    var postResetRequestedAtMs: Int64 = 0
    var clearStorageAckReceived = false
    var pendingUnpairDisconnect = false
    var isUnpaired = false
    var stop = false

    var lastOffsetMinutes = 0
    var liveOffsetCutoff = 0
    var lastF003Time: Date?
    var lastGlucoseTime: Date?
    var hasAuthoritativeSessionStart = false
    var streamingStartedAt: Date?
    var startupControlStage = StartupControlStage.idle

    // Scan-only mode state
    var discoveredSensors: [UUID: DiscoveredAidexSensor] = [:]
    var scanTimeoutWork: DispatchWorkItem?

    let bleQueue = DispatchQueue(label: "aidex.ble.\(UUID().uuidString.prefix(8))", qos: .userInitiated)

    // MARK: - Init

    public init(config: AidexSensorConfig) {
        self.config = config
        self.serial = config.deviceName
        let bare = SerialCrypto.stripPrefix(config.deviceName)
        self.keyExchange = AidexKeyExchange(bareSerial: bare)
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }

    // MARK: - Public API

    public func connect() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = true

            // If we have a known peripheral identifier, try direct retrieval first.
            // This avoids scanning and works even when the device isn't advertising
            // (e.g. already bonded at iOS level).
            if let identifier = self.config.peripheralIdentifier {
                // Wait for .poweredOn, then retrieve and connect
                self.connectionPhase = .connecting(identifier.uuidString)
                self.bleQueue.async { [weak self] in
                    self?.doConnectToIdentifier(identifier, attempt: 0)
                }
            } else {
                self.connectionPhase = .scanning
                self.startScan()
            }
        }
    }

    /// Запускает сканирование без автоматического подключения.
    /// Все найденные устройства будут возвращены через aidex(_:didFinishScanning:).
    public func scanOnlyConnect() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = true
            self.discoveredSensors.removeAll()
            self.connectionPhase = .scanning
            self.startScan()

            // Таймаут сканирования
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.config.scanOnly else { return }
                self.centralManager.stopScan()
                self.connectionPhase = .disconnected
                let devices = Array(self.discoveredSensors.values).sorted { $0.rssi > $1.rssi }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.aidex(self, didFinishScanning: devices)
                }
            }
            self.scanTimeoutWork = work
            self.bleQueue.asyncAfter(deadline: .now() + self.config.scanTimeout, execute: work)
        }
    }

    /// Подключается к конкретному устройству, найденному в режиме scanOnly.
    /// Uses retrievePeripherals to get a valid CBPeripheral for this CBCentralManager instance,
    /// since CBPeripheral objects from other CBCentralManagers are not valid for connect().
    public func connectToDiscovered(_ discovered: DiscoveredAidexSensor) {
        print("[AidexSensor] connectToDiscovered ENTER name=\(discovered.name) identifier=\(discovered.peripheral.identifier)")
        bleQueue.async { [weak self] in
            guard let self else { return }
            print("[AidexSensor] connectToDiscovered ON QUEUE state=\(self.centralManager.state.rawValue)")

            self.scanTimeoutWork?.cancel()
            self.scanTimeoutWork = nil
            self.centralManager.stopScan()
            self.discoveredSensors.removeAll()

            self.rssi = discovered.rssi
            self.shouldReconnect = true
            self.connectionPhase = .connecting(discovered.peripheral.identifier.uuidString)

            // Exit this async so centralManagerDidUpdateState can fire.
            // Use a follow-up async that polls for .poweredOn, then retrieves
            // a valid CBPeripheral (from this CM) and connects.
            self.bleQueue.async { [weak self] in
                guard let self else { return }
                print("[AidexSensor] connectToDiscovered follow-up, state=\(self.centralManager.state.rawValue)")
                self.doConnectToIdentifier(discovered.peripheral.identifier, attempt: 0)
            }
        }
    }

    private func doConnectToIdentifier(_ identifier: UUID, attempt: Int) {
        guard centralManager.state == .poweredOn else {
            if attempt % 3 == 0 {
                // Log every ~600ms to avoid spam
                print("[AidexSensor] doConnectToIdentifier waiting for poweredOn attempt=\(attempt) state=\(centralManager.state.rawValue)")
            }
            if attempt < 10 {
                bleQueue.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                    self?.doConnectToIdentifier(identifier, attempt: attempt + 1)
                }
            } else {
                print("[AidexSensor] doConnectToIdentifier FAILED after \(attempt) attempts: state still \(centralManager.state.rawValue)")
            }
            return
        }

        // Retrieve a valid CBPeripheral for THIS central manager
        let retrieved = centralManager.retrievePeripherals(withIdentifiers: [identifier])
        guard let p = retrieved.first else {
            print("[AidexSensor] doConnectToIdentifier: retrievePeripherals returned empty, scanning instead")
            // Fall back to scanning by name when direct retrieval fails.
            // The sensor may no longer be cached in CoreBluetooth's internal state.
            startScan()
            return
        }

        print("[AidexSensor] doConnectToIdentifier: retrieved peripheral name=\(p.name ?? "nil") state=\(p.state.rawValue)")
        self.peripheral = p
        p.delegate = self
        centralManager.connect(p, options: nil)
    }

    public func disconnect() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = false
            self.cancelAllTimers()
            if let p = self.peripheral {
                self.centralManager.cancelPeripheralConnection(p)
            }
            self.connectionPhase = .disconnected
        }
    }

    public func pause() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            // CRITICAL: Do NOT set shouldReconnect = false here.
            // pause() is called from CGMAidexTransmitter.stopScanning() after a successful
            // connect, solely to stop the BLE scan. Setting shouldReconnect = false would
            // prevent automatic reconnection when the connection drops later (timeout, range,
            // etc.). The sensor must be able to auto-reconnect on disconnect.
            self.cancelAllTimers()
            self.centralManager.stopScan()
        }
    }

    public func resume() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.centralManager = CBCentralManager(delegate: self, queue: self.bleQueue)
            self.connect()
        }
    }

    public func requestHistory() {
        bleQueue.async { [weak self] in self?.requestHistoryRange() }
    }

    public func calibrate(_ glucoseMgDl: Int) {
        bleQueue.async { [weak self] in self?.sendCalibration(glucoseMgDl: glucoseMgDl) }
    }

    public func resetSensor() {
        bleQueue.async { [weak self] in self?.triggerReset() }
    }

    public func startNewSensor() {
        bleQueue.async { [weak self] in self?.activateSensorNow() }
    }

    public func unpairSensor() {
        bleQueue.async { [weak self] in self?.triggerUnpair() }
    }

    // MARK: - Scanning

    func startScan() {
        startScan(retry: 0)
    }

    private func startScan(retry: Int) {
        print("[AidexSensor] startScan state=\(centralManager.state.rawValue) shouldReconnect=\(shouldReconnect) retry=\(retry)")
        guard centralManager.state == .poweredOn else {
            if retry < 25 {
                // Wait up to 5 seconds for Bluetooth to power on (25 * 200ms).
                bleQueue.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                    self?.startScan(retry: retry + 1)
                }
            } else {
                print("[AidexSensor] startScan FAILED after \(retry) retries: state still \(centralManager.state.rawValue)")
            }
            return
        }
        let services = [CBUUID(string: AidexUUID.service)]
        print("[AidexSensor] startScan: calling scanForPeripherals for service=181F")
        centralManager.scanForPeripherals(withServices: services, options: nil)
        connectionPhase = .scanning
    }

    // MARK: - Connect (replaces existing `connect`)

    /// Переподключение сенсора с заменой `centralManager` если необходимо
    func connectForce() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = true
            self.bleQueue.async { [weak self] in
                guard let self else { return }
                self.doConnectToStoredIdentifier()
            }
        }
    }

    private func doConnectToStoredIdentifier() {
        guard let identifier = config.peripheralIdentifier else {
            print("[AidexSensor] connectForce: no stored identifier — scanning")
            startScan()
            return
        }

        guard centralManager.state == .poweredOn else {
            print("[AidexSensor] connectForce: state=\(centralManager.state.rawValue) is not .poweredOn, retrying centralManager init")
            self.centralManager = CBCentralManager(delegate: self, queue: self.bleQueue)
            // centralManagerDidUpdateState подхватит при .poweredOn
            return
        }

        print("[AidexSensor] connectForce: doConnectToIdentifier \(identifier)")
        doConnectToIdentifier(identifier, attempt: 0)
    }

    // MARK: - Connection

    func onConnected() {
        print("[AidexSensor] onConnected peripheral=\(peripheral != nil ? (peripheral?.name ?? "unnamed") : "NIL") state=\(peripheral?.state.rawValue ?? -1)")
        connectionPhase = .discoveringServices
        reconnectAttempts = 0
        consecutiveConnectFailures = 0
        resetPerConnectionState()
        let services = [CBUUID(string: AidexUUID.service), CBUUID(string: AidexUUID.serviceDIS)]
        print("[AidexSensor] onConnected calling discoverServices: \(services.map { $0.uuidString })")
        peripheral?.discoverServices(services)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            print("[AidexSensor] onConnected calling delegate.aidexDidConnect")
            self.delegate?.aidexDidConnect(self)
        }
    }

    func resetPerConnectionState() {
        // Reset cryptographic state so that a fresh key exchange can run on
        // the new connection. Without this, the PAIR key from a previous
        // (failed) key-exchange attempt survives and the F001 notify guard
        // rejects the new 16-byte PAIR notification, blocking reconnection.
        keyExchange.reset()
        challengeWritten = false
        bondDataRead = false
        cccdChainComplete = false
        postKeyCCCDRefreshed = false
        postKeySetupPending = false
        pendingCCCD = []
        cccdIndex = 0
        cccdRetryCount = 0
        autoActivationAttempted = false
        startupControlStage = .idle
        historyDownloading = false
        historyDownloadedOnce = false
        historyRawNextIndex = 0
        historyBriefNextIndex = 0
        calibratedGlucoseCache.removeAll()
        liveOffsetCutoff = 0
        streamingStartedAt = nil
        lastF003Time = nil
        keyExchangeWatchdog?.cancel()
        historyPageWatchdog?.cancel()
        initialHistoryRequestWork?.cancel()
    }

    // MARK: - Service Discovery

    func discoverCharacteristicsForServices() {
        guard let p = peripheral else {
            print("[AidexSensor] discoverCharacteristicsForServices: peripheral NIL")
            return
        }
        print("[AidexSensor] discoverCharacteristicsForServices: services=\(p.services?.count ?? 0)")

        if let cgmService = p.services?.first(where: { $0.uuid == CBUUID(string: AidexUUID.service) }) {
            print("[AidexSensor] discoverCharacteristicsForServices: calling discoverCharacteristics for CGM service")
            p.discoverCharacteristics([
                CBUUID(string: AidexUUID.charF003),
                CBUUID(string: AidexUUID.charF002),
                CBUUID(string: AidexUUID.charF001),
            ], for: cgmService)
        } else {
            print("[AidexSensor] discoverCharacteristicsForServices: CGM service NOT FOUND")
        }

        if let disService = p.services?.first(where: { $0.uuid == CBUUID(string: AidexUUID.serviceDIS) }) {
            print("[AidexSensor] discoverCharacteristicsForServices: calling discoverCharacteristics for DIS service")
            p.discoverCharacteristics([
                CBUUID(string: AidexUUID.charModelNumber),
                CBUUID(string: AidexUUID.charSoftwareRev),
                CBUUID(string: AidexUUID.charManufacturer),
                CBUUID(string: AidexUUID.charSessionStart),
                CBUUID(string: AidexUUID.charSessionRun),
            ], for: disService)
        } else {
            print("[AidexSensor] discoverCharacteristicsForServices: DIS service NOT FOUND")
        }
    }

    // MARK: - CCCD Chain

    func onCharacteristicsDiscovered() {
        guard let p = peripheral,
              let cgmService = p.services?.first(where: { $0.uuid == CBUUID(string: AidexUUID.service) })
        else { return }

        f003 = cgmService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charF003) }
        f002 = cgmService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charF002) }
        f001 = cgmService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charF001) }

        if let disService = p.services?.first(where: { $0.uuid == CBUUID(string: AidexUUID.serviceDIS) }) {
            modelNumberChar  = disService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charModelNumber) }
            softwareRevChar  = disService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charSoftwareRev) }
            manufacturerChar = disService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charManufacturer) }
        }

        // CGM Session Start Time (0x2AAA) lives under the CGM service (0x181F),
        // not under DIS (0x180A). This is the authoritative session timestamp
        // the sensor uses to gate F003 streaming.
        cgmSessionStartChar = cgmService.characteristics?.first { $0.uuid == CBUUID(string: AidexUUID.charSessionStart) }

        readDISChars()

        connectionPhase = .enablingNotifications
        pendingCCCD = [f003, f002, f001].compactMap { $0 }
        cccdIndex = 0
        startCCCDChain()
    }

    func readDISChars() {
        guard let p = peripheral else { return }
        [modelNumberChar, softwareRevChar, manufacturerChar]
            .compactMap { $0 }
            .forEach { p.readValue(for: $0) }

        // Read CGM Session Start Time (0x2AAA) from the CGM service separately.
        // This is the sensor's activation timestamp — if it returns all-zeros or
        // a time older than the sensor's wearDays, auto-activation (SET_NEW_SENSOR
        // 0x20) is triggered to enable F003 streaming.
        if let c = cgmSessionStartChar {
            p.readValue(for: c)
        }
    }

    func startCCCDChain() {
        guard cccdIndex < pendingCCCD.count else {
            cccdChainComplete = true
            onCCCDChainComplete()
            return
        }
        let char = pendingCCCD[cccdIndex]
        print("[AidexSensor] startCCCDChain: setNotifyValue for \(char.uuid.uuidString) index=\(cccdIndex)/\(pendingCCCD.count) retry=\(cccdRetryCount)")
        peripheral?.setNotifyValue(true, for: char)
        scheduleCCCDTimeout(for: char)
    }

    /// Schedules a single retry-or-advance timer for the current CCCD characteristic.
    /// Each call represents one timeout window. If the CCCD has not been confirmed
    /// (cccdIndex still points to this char), the function decrements the remaining
    /// retry budget and either re-issues setNotifyValue or reconnects.
    private func scheduleCCCDTimeout(for char: CBCharacteristic) {
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.cccdWriteCallback))) { [weak self] in
            guard let self,
                  self.cccdIndex < self.pendingCCCD.count,
                  self.pendingCCCD[self.cccdIndex] == char
            else { return }

            self.cccdRetryCount += 1
            if self.cccdRetryCount <= Self.cccdMaxRetries {
                print("[AidexSensor] startCCCDChain: RETRY \(self.cccdRetryCount)/\(Self.cccdMaxRetries) for \(char.uuid.uuidString)")
                self.peripheral?.setNotifyValue(true, for: char)
                self.scheduleCCCDTimeout(for: char)
            } else {
                print("[AidexSensor] startCCCDChain: FAILED \(char.uuid.uuidString) after \(Self.cccdMaxRetries) retries — reconnecting")
                self.reconnect()
            }
        }
    }

    func onCCCDChainComplete() {
        print("[AidexSensor] onCCCDChainComplete postKeySetupPending=\(postKeySetupPending)")

        // Post-key-exchange CCCD chain: F003+F002 re-registered after bonding.
        // Now safe to send F002 commands (startup info, history request).
        if postKeySetupPending {
            postKeySetupPending = false
            executePostKeyCommands()
            return
        }

        // Pre-key-exchange CCCD chain: F003+F002+F001 now ready.
        // Read session start time, then kick off key exchange after settle.
        if let c = cgmSessionStartChar { peripheral?.readValue(for: c) }

        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.bondingSettle))) { [weak self] in
            print("[AidexSensor] onCCCDChainComplete: starting key exchange")
            self?.startKeyExchange()
        }
    }

    /// Sends deferred commands that require post-bond CCCDs (startup info, history
    /// request). Called from onCCCDChainComplete after the post-key CCCD chain finishes.
    private func executePostKeyCommands() {
        // Startup device info (0x10) — carries format rev and wearDays.
        if let cmd = commandBuilder.getStartupDeviceInfo(), let f002 {
            print("[Aidex-DEBUG] executePostKeyCommands: sending 0x10 getStartupDeviceInfo")
            peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        }

        // Startup control sequence: 0x35 (setDynamicAdvMode) → 0x34 (setAutoUpdateStatus).
        // GX-01S hardware requires this sequence to begin F003 live streaming after
        // key exchange. Without it, the sensor stays silent even when warmup is complete.
        // 0x35 ack triggers handleDynamicAdvModeAck → 0x34 → handleAutoUpdateStatusAck.
        if let cmd = commandBuilder.setDynamicAdvMode(1), let f002 {
            print("[Aidex-DEBUG] executePostKeyCommands: sending 0x35 setDynamicAdvMode")
            startupControlStage = .waitDynamicAdvAck
            peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        } else {
            print("[Aidex-DEBUG] executePostKeyCommands: WARNING setDynamicAdvMode command is nil")
        }
    }

    /// Kick off history download once the first live F003 reading arrives.
    private func startHistoryAfterFirstLiveReading() {
        guard !historyDownloading else { return }
        requestHistoryRange()
    }

    func startKeyExchange() {
        print("[AidexSensor] startKeyExchange f001=\(f001 != nil) challengeWritten=\(challengeWritten)")
        guard let f001 else {
            print("[AidexSensor] startKeyExchange: f001 is NIL, aborting")
            return
        }
        connectionPhase = .keyExchange

        let challenge = keyExchange.challenge
        print("[AidexSensor] startKeyExchange: writing challenge \(challenge.count) bytes")
        peripheral?.writeValue(challenge, for: f001, type: .withResponse)
        challengeWritten = true

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self, case .keyExchange = self.connectionPhase else { return }
            self.reconnect()
        }
        keyExchangeWatchdog = watchdog
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.keyExchange)), execute: watchdog)
    }

    func onKeyExchangeComplete() {
        keyExchangeWatchdog?.cancel()
        connectionPhase = .streaming
        isStreaming = true
        streamingStartedAt = Date()

        // Update statusMessage based on current warmup state.
        // If sensorStartTimeMs is not yet known (pre-0x21), show generic connecting.
        // After 0x21, statusMessage will be set in applySessionStartTime.
        if sensorStartTimeMs == 0 { statusMessage = "Connecting..." }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, keyExchangeComplete: true)
        }

        // Step 1: Send post-BOND config to F001 (unlocks the sensor for streaming).
        if let config = keyExchange.postBondConfig, let f001 {
            peripheral?.writeValue(config, for: f001, type: .withResponse)
        }

        // Step 2: Re-register F003 and F002 CCCDs now that bonding is complete.
        // Pre-bond CCCDs were set up before the link was encrypted — iOS may
        // silently preserve them as no-ops when the same characteristic is
        // re-subscribed after bonding. Explicitly unsubscribe first to force a
        // fresh CCCD handshake with the now-encrypted link.
        if !postKeyCCCDRefreshed {
            postKeyCCCDRefreshed = true
            postKeySetupPending = true
            print("[AidexSensor] onKeyExchangeComplete: unsubscribing pre-bond CCCDs before post-bond re-subscription")
            for char in [f003, f002].compactMap({ $0 }) {
                peripheral?.setNotifyValue(false, for: char)
            }
            // Allow the unsubscribe writes to flush, then start the fresh CCCD chain.
            bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.bondingSettle))) { [weak self] in
                guard let self else { return }
                print("[AidexSensor] onKeyExchangeComplete: starting post-bond CCCD chain for F003+F002")
                self.pendingCCCD = [self.f003, self.f002].compactMap { $0 }
                self.cccdIndex = 0
                self.cccdChainComplete = false
                self.startCCCDChain()
            }
        } else {
            // Already refreshed — go ahead immediately (reconnect path).
            executePostKeyCommands()
        }
    }

    // MARK: - F003 Handling

    func handleF003(data encrypted: Data) {
        guard let decrypted = keyExchange.decrypt(encrypted) else { return }

        switch AidexParser.classifyFrame(decrypted) {
        case .data:
            handleDataFrame(decrypted)
        case .status:
            handleStatusFrame(decrypted)
        case .calibration:
            if decrypted.first == 0x0A {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.aidex(self, didReceiveCalibrationResult: true, message: "Calibration accepted")
                }
            }
        case .unknown:
            break
        }
    }

    func handleDataFrame(_ decrypted: Data) {
        guard AidexParser.validateFrameCRC(decrypted),
              let frame = AidexParser.parseDataFrame(decrypted) else { return }

        let now = Date()
        lastF003Time = now

        guard frame.isValid else { return }

        let offset = frame.timeOffsetMinutes
        lastOffsetMinutes = offset
        if offset > liveOffsetCutoff { liveOffsetCutoff = offset }

        if sensorReportedWearDays, wearDays > 0, offset > wearDays * 24 * 60 {
            sensorExpired = true
        }

        let sampleTime = resolveTimestamp(now: now, offsetMinutes: offset)
        lastGlucoseTime = sampleTime

        let point = AidexGlucosePoint(
            timestamp: sampleTime,
            glucoseMgDl: frame.glucoseMgDl,
            rawMgDl: frame.i1 * 10.0,
            sensorGlucoseMgDl: frame.i1 * 18.0182,
            rawI1: frame.i1,
            rawI2: frame.i2,
            timeOffsetMinutes: offset,
            sensorSerial: bareSerial
        )

        lastGlucose = point
        statusMessage = ""

        // First validated live reading is the authoritative signal that the sensor
        // is fully activated — kick off history download now.
        if !historyDownloadedOnce {
            historyDownloadedOnce = true
            startHistoryAfterFirstLiveReading()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceive: point)
        }
    }

    func handleStatusFrame(_ decrypted: Data) {
        guard decrypted.count >= 3 else { return }
        let mv = Int(decrypted[1]) | (Int(decrypted[2]) << 8)
        guard mv >= 500, mv <= 3500 else { return }
        batteryMV = mv
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, batteryMillivolts: mv)
        }
    }

    // MARK: - F002 Response Handling

    func handleF002(response: Data) {
        let plaintext: Data
        if keyExchange.isComplete, let dec = keyExchange.decrypt(response) {
            plaintext = dec
        } else {
            plaintext = response
        }

        guard !plaintext.isEmpty else { return }
        let opcode = plaintext[0]

        let crcValid = plaintext.count < 3 || CRC16.validateResponse(plaintext)
        let dataOpcodes: Set<UInt8> = [0x21, 0x22, 0x23, 0x24, 0x26, 0x27]
        if !crcValid && dataOpcodes.contains(opcode) { return }

        switch opcode {
        case 0x10: handleStartupInfo(plaintext)
        case 0x11: handleBroadcastData(plaintext)
        case 0x21: handleLegacyStartTime(plaintext)
        case 0x22: handleHistoryRangeResponse(plaintext)
        case 0x23: handleHistoryRawResponse(plaintext)
        case 0x24: handleHistoryBriefResponse(plaintext)
        case 0x26: handleCalibrationRangeResponse(plaintext)
        case 0x27: handleCalibrationResponse(plaintext)
        case 0x20: handleNewSensorAck()
        case 0x34: handleAutoUpdateStatusAck()
        case 0x35: handleDynamicAdvModeAck()
        case 0xF2: handleDeleteBondAck()
        case 0xF3: handleClearStorageAck()
        default: break
        }
    }

    func handleStartupInfo(_ data: Data) {
        guard let info = AidexParser.parseStartupDeviceInfoFrame(data) else { return }
        firmwareVersion = info.firmwareVersion
        hardwareVersion = info.hardwareVersion
        modelName = info.modelName
        if info.wearDays > 0 {
            wearDays = info.wearDays
            sensorReportedWearDays = true
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceiveStartupInfo: info)
        }

        // The GX-01S hardware exposes no 0x2AAA characteristic under the CGM
        // service (only F001/F002/F003). Its authoritative session timestamp is
        // delivered via the legacy local-start-time command (0x21). Android
        // (AiDexBleManager.handleStartupDeviceInfoResponse) requests this right
        // after 0x10 — without it, the sensor never begins F003 streaming.
        if !hasAuthoritativeSessionStart {
            requestLegacyStartTime("post-0x10")
        }
    }

    /// Requests the legacy local start time (0x21). Completes the post-key bootstrap
    /// that unlocks F003 live streaming on sensors lacking a 0x2AAA characteristic.
    func requestLegacyStartTime(_ reason: String) {
        guard let cmd = commandBuilder.getLegacyStartTime(), let f002 else { return }
        print("[AidexSensor] requestLegacyStartTime(\(reason)): writing 0x21 to F002")
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
    }

    func handleBroadcastData(_ data: Data) {
        // Connected 0x11 broadcast sample carries a live glucose point identical in
        // shape to a direct F003 data frame. Route it through the same parser so the
        // first-live-reading history trigger and delegate delivery stay single-sourced.
        let payloadEnd = data.count >= 4 && CRC16.validateResponse(data) ? data.count - 2 : data.count
        guard payloadEnd > 2 else { return }
        let payload = data.subdata(in: 2..<payloadEnd)
        handleBroadcastPayload(payload, source: "connected-broadcast")
    }

    func handleBroadcastPayload(_ payload: Data, source: String) {
        // Connected 0x11 broadcast sample. Layout (unencrypted):
        //   [0..3] offsetMinutes (u32 LE, fallback u16 LE at [0..1])
        //   [4]    trend (signed byte, tenths of mg/dL/min)
        //   [5]    glucose mg/dL (u8) — or packed glucose
        // This is a best-effort FALLBACK for recovering display data when direct
        // F003 streaming is not yet producing readings; it is NOT the primary path.
        guard payload.count >= 7 else { return }

        let offsetCandidate = payload.count >= 4 ? Int(payload.subdata(in: 0..<4).toU32LE()) : -1
        let offsetMinutes: Int
        if offsetCandidate > 0 && offsetCandidate <= 30 * 24 * 60 {
            offsetMinutes = offsetCandidate
        } else {
            offsetMinutes = Int(payload.subdata(in: 0..<2).toU16LE())
        }
        guard offsetMinutes > 0, offsetMinutes <= 30 * 24 * 60 else { return }

        let fallbackGlucose = Int(payload[5])
        guard fallbackGlucose >= AidexFrame.minValidGlucose,
              fallbackGlucose <= AidexFrame.maxValidGlucose else { return }

        lastOffsetMinutes = offsetMinutes
        if offsetMinutes > liveOffsetCutoff { liveOffsetCutoff = offsetMinutes }

        let now = Date()
        let sampleTime = resolveTimestamp(now: now, offsetMinutes: offsetMinutes)
        let point = AidexGlucosePoint(
            timestamp: sampleTime,
            glucoseMgDl: Float(fallbackGlucose),
            rawMgDl: nil,
            sensorGlucoseMgDl: nil,
            rawI1: nil,
            rawI2: nil,
            timeOffsetMinutes: offsetMinutes,
            sensorSerial: bareSerial
        )
        lastGlucose = point

        statusMessage = ""

        if !historyDownloadedOnce {
            historyDownloadedOnce = true
            startHistoryAfterFirstLiveReading()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceive: point)
        }
    }

    func handleLegacyStartTime(_ data: Data) {
        let payloadEnd = data.count >= 4 && CRC16.validateResponse(data) ? data.count - 2 : data.count
        guard payloadEnd > 2 else { return }
        let payload = data.subdata(in: 2..<payloadEnd)
        let hex0x21 = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        guard let st = AidexParser.parseLocalStartTimePayload(payload) else { return }
        applySessionStartTime(st, source: "0x21")
        // After receiving 0x21 (session start time), the sensor is ready to stream
        // F003 and serve history. Delay the history range request to give the sensor
        // time to finish processing 0x21 — sending 0x22 too soon causes it to be ignored.
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(1000)) { [weak self] in
            self?.requestHistoryRange()
        }
    }

    func handleHistoryRangeResponse(_ data: Data) {
        guard let range = AidexParser.parseHistoryRange(data) else { return }
        historyNewestOffset = range.newestOffset
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceiveHistory: range)
        }
        if range.rawStart < historyNewestOffset {
            historyDownloading = true
            historyRawNextIndex = range.rawStart
            requestNextHistoryRawPage()
        }
    }

    func handleHistoryRawResponse(_ data: Data) {
        let entries = AidexParser.parseHistoryResponse(data)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceiveCalibratedHistory: entries)
        }
        for e in entries where !e.isSentinel {
            calibratedGlucoseCache[e.timeOffsetMinutes] = e
        }
        historyRawNextIndex = (entries.last?.timeOffsetMinutes ?? historyRawNextIndex) + 1
        if historyRawNextIndex < historyNewestOffset {
            scheduleNextHistoryPage(type: "raw")
        } else {
            historyRawNextIndex = historyNewestOffset
            finishHistoryRawAndStartBrief()
        }
    }

    func handleHistoryBriefResponse(_ data: Data) {
        let entries = AidexParser.parseBriefHistoryResponse(data)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceiveAdcHistory: entries)
        }
        historyBriefNextIndex = (entries.last?.timeOffsetMinutes ?? historyBriefNextIndex) + 1
        if historyBriefNextIndex < historyNewestOffset {
            scheduleNextBriefPage()
        } else {
            historyDownloading = false
        }
    }

    func handleCalibrationRangeResponse(_ data: Data) {
        guard let range = AidexParser.parseCalibrationRange(data),
              range.endIndex > range.startIndex else { return }
        requestCalibrationPage(index: range.endIndex)
    }

    func handleCalibrationResponse(_ data: Data) {
        let records = AidexParser.parseCalibrationResponse(data)
        calibrations = records
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.aidex(self, didReceiveCalibrations: records)
        }
    }

    // MARK: - History Requests

    func requestHistoryRange() {
        guard let f002, let cmd = commandBuilder.getHistoryRange() else { return }
        print("[AidexSensor] requestHistoryRange: writing 0x22 to F002, \(cmd.count) bytes")
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        scheduleHistoryPageWatchdog()
    }

    func requestNextHistoryRawPage() {
        guard let f002, let cmd = commandBuilder.getHistoriesRaw(offset: historyRawNextIndex) else { return }
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        scheduleHistoryPageWatchdog()
    }

    func requestNextBriefPage() {
        guard let f002, let cmd = commandBuilder.getHistories(offset: historyBriefNextIndex) else { return }
        peripheral?.writeValue(cmd, for: f002, type: .withoutResponse)
        scheduleHistoryPageWatchdog()
    }

    func finishHistoryRawAndStartBrief() {
        historyBriefNextIndex = 0
        requestNextBriefPage()
    }

    func scheduleNextHistoryPage(type: String = "raw") {
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.historyRequestDelay))) { [weak self] in
            guard let self, self.historyDownloading else { return }
            if type == "raw" {
                self.requestNextHistoryRawPage()
            }
        }
    }

    func scheduleNextBriefPage() {
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.historyRequestDelay))) { [weak self] in
            guard let self, self.historyDownloading else { return }
            self.requestNextBriefPage()
        }
    }

    func scheduleHistoryPageWatchdog() {
        historyPageWatchdog?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            self?.historyDownloading = false
        }
        historyPageWatchdog = watchdog
        bleQueue.asyncAfter(deadline: .now() + .milliseconds(Int(AidexTimeout.historyPage)), execute: watchdog)
    }

    // MARK: - Calibration

    func sendCalibration(glucoseMgDl: Int) {
        guard keyExchange.isComplete, lastOffsetMinutes > 0,
              glucoseMgDl >= 30, glucoseMgDl <= 500,
              let cmd = commandBuilder.setCalibration(offsetMinutes: lastOffsetMinutes, glucoseMgDl: glucoseMgDl),
              let f002
        else {
            print("[AidexSensor] sendCalibration FAILED: keComplete=\(keyExchange.isComplete) offset=\(lastOffsetMinutes) mgDl=\(glucoseMgDl)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.aidex(self, didReceiveCalibrationResult: false, message: "Cannot calibrate")
            }
            return
        }

        print("[AidexSensor] sendCalibration: writing SET_CALIBRATION offset=\(lastOffsetMinutes) mgDl=\(glucoseMgDl) cmd=\(cmd.count) bytes withoutResponse")
        statusMessage = "Calibrating..."
        bleQueue.async { [weak self] in
            guard let self else { return }
            // SET_CALIBRATION must be written without response — the sensor
            // does not ACK command writes to F002. With .withResponse, iOS
            // returns "Writing is not permitted" because the peripheral
            // doesn't send a Write Response for this characteristic.
            self.peripheral?.writeValue(cmd, for: self.f002!, type: .withoutResponse)
        }
    }
}