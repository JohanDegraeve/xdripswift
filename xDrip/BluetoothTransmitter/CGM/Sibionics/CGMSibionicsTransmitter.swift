import CoreBluetooth
import Foundation
import os

/// Synchronously invalidates queued deliveries when a driver is halted or replaced.
final class GS1DeliveryGate {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var stopped = false
    private var released = false
    func token() -> UInt64? { lock.lock(); defer { lock.unlock() }; return stopped ? nil : generation }
    func allows(_ token: UInt64) -> Bool { lock.lock(); defer { lock.unlock() }; return !stopped && token == generation }
    func invalidate() { lock.lock(); generation &+= 1; lock.unlock() }
    func stop() { lock.lock(); stopped = true; generation &+= 1; lock.unlock() }
    func release() { lock.lock(); released = true; stopped = true; generation &+= 1; lock.unlock() }
    var isReleased: Bool { lock.lock(); defer { lock.unlock() }; return released }
}

/// Factory 14-day GS1 CN / AA55. Protocol and native-core state stay on the inherited
/// central queue. AA55 writes require the UI's persisted explicit Connect authorization.
final class CGMSibionicsTransmitter: BluetoothTransmitter, CGMTransmitter {
    private weak var cgmDelegate: CGMTransmitterDelegate?
    private let configuredIdentity: GS1CNIdentity?
    private let selectedUUID: UUID?
    private let authorized: Bool
    private let delivery = GS1DeliveryGate()
    private var session: GS1Session?
    private weak var activePeripheral: CBPeripheral?
    private var assembler = GS1PacketAssembler(layout: .fixed10)
    private let statusLog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBlueToothTransmitter)
    private let deviceInformationService = CBUUID(string: "180A")
    private let deviceInformationFields = Set(["2A24", "2A25", "2A29"])
    private var deviceInformationValues: [String: Data] = [:]
    private var detectedMAC: GS1MAC?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyReady = false
    private var beganConnection = false
    private var awaitingResponse = false
    private var waitingForWriteCapacity = false
    private var watchdog: DispatchWorkItem?
    private var retries = 0
    private let statusLock = NSLock()
    private var statusValue = "Waiting for connection"
    var statusText: String { statusLock.lock(); defer { statusLock.unlock() }; return statusValue }
    var readOnlyDetectedMAC: GS1MAC? { statusLock.lock(); defer { statusLock.unlock() }; return detectedMAC }
    private var canOperate: Bool { authorized && configuredIdentity != nil && selectedUUID != nil && delivery.token() != nil }

    init(address: String?, name: String?, code: String?, mac: String?, authorized: Bool,
         bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMTransmitterDelegate: CGMTransmitterDelegate) {
        selectedUUID = address.flatMap(UUID.init(uuidString:))
        configuredIdentity = try? GS1CNIdentity(sensorCode: code ?? "", mac: GS1MAC(mac ?? ""))
        self.authorized = authorized
        cgmDelegate = cGMTransmitterDelegate
        let known: DeviceAddressAndName = address.map { .alreadyConnectedBefore(address: $0, name: name ?? "GS1 CN") } ?? .notYetConnected(expectedName: nil)
        super.init(addressAndName: known, CBUUID_Advertisement: GS1ChineseProtocol.serviceUUID,
                   servicesCBUUIDs: [CBUUID(string: GS1ChineseProtocol.serviceUUID), CBUUID(string: "180A")],
                   CBUUID_ReceiveCharacteristic: GS1ChineseProtocol.notifyUUID,
                   CBUUID_WriteCharacteristic: GS1ChineseProtocol.writeUUID,
                   bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }
    func cgmTransmitterType() -> CGMTransmitterType { .sibionicsCN }
    func sensorWarmupDurationInMinutes() -> Double? { GS1Policy.warmup / 60 }
    func getCBUUID_Service() -> String { GS1ChineseProtocol.serviceUUID }
    func getCBUUID_Receive() -> String { GS1ChineseProtocol.notifyUUID }
    func maxSensorAgeInDays() -> Double? { 14 }
    // Existing app contract for already calibrated values; this decoder runs locally.
    func isWebOOPEnabled() -> Bool { true }
    func nonWebOOPAllowed() -> Bool { false }
    func needsSensorStartTime() -> Bool { false }
    func needsSensorStartCode() -> Bool { false }
    func requestNewReading() { runOnCentralQueue { [weak self] in self?.requestHistory() } }
    override var shouldLogPeripheralIdentity: Bool { false }
    override func shouldTimeoutStalledConnectionSetup() -> Bool { true }
    override func shouldConnectToDiscoveredPeripheral(_ peripheral: CBPeripheral) -> Bool {
        canOperate && selectedUUID == peripheral.identifier
    }
    override func connect() { if canOperate { super.connect() } }
    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        guard canOperate else { return .other(reason: "GS1 Connect authorization and selected device are required") }
        return super.startScanning()
    }
    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard canOperate else { central.stopScan(); return }
        if central.state != .poweredOn { resetTransport(); setStatus("Waiting for Bluetooth") }
        super.centralManagerDidUpdateState(central)
    }
    override func reconnectAfterDisconnect(_ central: CBCentralManager) {
        if canOperate { super.reconnectAfterDisconnect(central) }
    }
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard canOperate, peripheral.identifier == selectedUUID else { central.cancelPeripheralConnection(peripheral); return }
        resetTransport(); activePeripheral = peripheral
        super.centralManager(central, didConnect: peripheral)
        armWatchdog(after: 12, responseTimeout: true)
    }
    override func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == selectedUUID else { return }
        resetTransport(); setStatus("GS1 connection failed; retrying")
        guard canOperate, let token = delivery.token() else { return }
        runOnCentralQueue(after: 5) { [weak self, weak central, weak peripheral] in
            guard let self, let central, let peripheral, self.delivery.allows(token), self.canOperate,
                  central.state == .poweredOn, peripheral.state == .disconnected else { return }
            central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true, CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
        }
    }
    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == selectedUUID else { return }
        resetTransport(); setStatus("GS1 disconnected; waiting to reconnect")
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    override func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        // The base class takes its first restored peripheral; filter before calling it.
        for peripheral in restored where !canOperate || peripheral.identifier != selectedUUID {
            central.cancelPeripheralConnection(peripheral)
        }
        guard canOperate, let peripheral = restored.first(where: { $0.identifier == selectedUUID }) else { return }
        resetTransport(); activePeripheral = peripheral
        var filtered = dict
        filtered[CBCentralManagerRestoredStatePeripheralsKey] = [peripheral]
        super.centralManager(central, willRestoreState: filtered)
        // A restored pending connection can legitimately wait while out of range.
        // Start the setup deadline only once connected; didConnect handles that later.
        if peripheral.state == .connected { armWatchdog(after: 12, responseTimeout: true) }
    }
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        trace("GS1 services callback current=%{public}@ error=%{public}@", log: statusLog, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, isCurrent(peripheral).description, (error != nil).description)
        guard isCurrent(peripheral) else { return }
        if error != nil { recoverConnection("GS1 service discovery failed"); return }
        guard peripheral.services?.contains(where: { $0.uuid == CBUUID(string: GS1ChineseProtocol.serviceUUID) }) == true else {
            halt("The selected device does not expose the GS1 CN service"); return
        }
        super.peripheral(peripheral, didDiscoverServices: error)
        armWatchdog(after: 12, responseTimeout: true)
    }
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard isCurrent(peripheral) else { return }
        if service.uuid == deviceInformationService {
            guard error == nil else { return }
            for value in service.characteristics ?? []
            where deviceInformationFields.contains(value.uuid.uuidString) && value.properties.contains(.read) {
                peripheral.readValue(for: value)
            }
            return
        }
        guard service.uuid == CBUUID(string: GS1ChineseProtocol.serviceUUID) else { return }
        guard error == nil, let characteristics = service.characteristics,
              let write = characteristics.first(where: { $0.uuid == CBUUID(string: GS1ChineseProtocol.writeUUID) }),
              let notify = characteristics.first(where: { $0.uuid == CBUUID(string: GS1ChineseProtocol.notifyUUID) }),
              write.properties.contains(.write) || write.properties.contains(.writeWithoutResponse),
              notify.properties.contains(.notify) || notify.properties.contains(.indicate) else {
            halt("The selected device does not expose supported GS1 CN characteristics"); return
        }
        writeCharacteristic = write
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        // A restored subscription may already be active without another state callback.
        notifyReady = notify.isNotifying
        if notifyReady { begin() } else { armWatchdog(after: 12, responseTimeout: true) }
    }
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard isCurrent(peripheral), characteristic.uuid == CBUUID(string: GS1ChineseProtocol.notifyUUID) else { return }
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        guard error == nil, characteristic.isNotifying else { recoverConnection("GS1 notification subscription failed"); return }
        notifyReady = true
        if writeCharacteristic != nil { begin() }
    }
    override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard isCurrent(peripheral), characteristic.uuid == CBUUID(string: GS1ChineseProtocol.writeUUID) else { return }
        if error != nil { retryResponse("GS1 request was not acknowledged") }
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard isCurrent(peripheral), waitingForWriteCapacity else { return }
        waitingForWriteCapacity = false
        requestHistory()
    }
    private func begin() {
        guard canOperate, notifyReady, !beganConnection, let identity = configuredIdentity, let selectedUUID else { return }
        do {
            if session == nil {
                let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("GS1Sessions", isDirectory: true)
                session = try GS1Session(identity: identity.checkpointIdentity(peripheralID: selectedUUID), sensitivity: identity.sensitivity, storage: base)
            }
            beganConnection = true; retries = 0
            requestHistory()
        } catch { halt("GS1 history or checkpoint could not be restored. No readings are being published.") }
    }
    private func requestHistory() {
        guard canOperate, beganConnection, !awaitingResponse, notifyReady, let peripheral = activePeripheral,
              isCurrent(peripheral), peripheral.state == .connected, let characteristic = writeCharacteristic,
              let identity = configuredIdentity, let session else { return }
        guard session.nextIndex <= 65535 else { halt("Sensor index exhausted"); return }
        do {
            let data = try GS1ChineseProtocol.request(index: session.nextIndex, mac: identity.mac)
            let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
            if type == .withoutResponse && !peripheral.canSendWriteWithoutResponse {
                waitingForWriteCapacity = true; armWatchdog(after: 12, responseTimeout: true); return
            }
            assembler.reset(); waitingForWriteCapacity = false; awaitingResponse = true
            // Immediate central-queue write: it cannot survive halt/release in a
            // separate async closure, and the generic logger never sees the MAC.
            peripheral.writeValue(data, for: characteristic, type: type)
            setStatus(session.lastStatus)
            armWatchdog(after: 12, responseTimeout: true)
        } catch { halt("Unsupported GS1 request") }
    }
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if isCurrent(peripheral), characteristic.service?.uuid == deviceInformationService,
           deviceInformationFields.contains(characteristic.uuid.uuidString) {
            let key = characteristic.uuid.uuidString
            deviceInformationValues[key] = error == nil ? characteristic.value : nil
            let resolved = GS1Setup.deviceInformationMAC(deviceInformationValues)
            statusLock.lock()
            detectedMAC = resolved
            statusLock.unlock()
            return
        }
        // Do not pass raw signal payloads to the generic public trace logger.
        guard isCurrent(peripheral), beganConnection, notifyReady,
              characteristic.uuid == CBUUID(string: GS1ChineseProtocol.notifyUUID) else { return }
        guard error == nil, let data = characteristic.value, !data.isEmpty else { retryResponse("GS1 notification failed"); return }
        requestSignalStrengthForTraceIfNeeded(from: peripheral)
        let received = Date()
        do {
            for packet in try assembler.append(data) {
                switch packet {
                case .echo: break
                case .encryptedProtocolRequired:
                    halt("This GS1 requires the V120 protocol. This build supports CN AA55 only; no glucose is published.")
                    return
                case .samples(let samples):
                    guard let session else { return }
                    awaitingResponse = false; watchdog?.cancel()
                    let oldIndex = session.nextIndex
                    let readings = try session.ingest(samples, received: received, now: Date())
                    trace("GS1 accepted samples=%{public}d nextIndex=%{public}d historyReady=%{public}@ published=%{public}d", log: statusLog, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, samples.count, session.nextIndex, session.historyReady.description, readings.count)
                    let advanced = session.nextIndex > oldIndex
                    if advanced { retries = 0 }
                    setStatus(session.lastStatus)
                    publish(readings, start: session.startConfirmed ? session.start : nil)
                    if !advanced && !samples.isEmpty && !session.historyReady {
                        retryResponse("GS1 is not returning the missing history")
                    } else {
                        // Timers are best effort under iOS suspension. Restored BLE
                        // subscriptions resume from the persisted next sensor index.
                        armWatchdog(after: session.historyReady || samples.isEmpty ? 65 : 0.25, responseTimeout: false)
                    }
                }
            }
        } catch GS1SessionError.timeline {
            if let issue = session?.timelineIssue, issue.canRetry {
                // A queued BLE notification can arrive late after iOS suspension.
                // Reject its time and request the same missing minute again. Never
                // move the session anchor or publish from the rejected response.
                trace("GS1 timing rejected: %{public}@", log: statusLog, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, issue.diagnostic)
                retryResponse("GS1 timing delayed; re-reading saved history")
            } else {
                halt("GS1 session time changed. The saved session was kept; no readings are being published.")
            }
        } catch GS1SessionError.conflictingSample {
            halt("GS1 history conflicts with the saved sensor session; no readings are being published.")
        } catch is GS1ProtocolError {
            retryResponse("Invalid GS1 frame; requesting missing history")
        } catch { halt("GS1 history could not be saved or decoded; no readings are being published.") }
    }
    private func publish(_ readings: [GS1Session.Reading], start: Date?) {
        guard !readings.isEmpty, let token = delivery.token() else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.delivery.allows(token) else { return }
            let now = Date()
            let current = readings.filter { now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) <= 120 }
            guard let latestDate = current.map(\.date).max() else { return }
            var glucose = current.sorted { $0.date > $1.date }.map { GlucoseData(timeStamp: $0.date, glucoseLevelRaw: $0.mgdl) }
            // The coordinator reconstructs start as latest reading date minus age.
            // Use that same event time so BLE/dispatch latency cannot shift the start.
            self.cgmDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucose, transmitterBatteryInfo: nil, sensorAge: start.map { latestDate.timeIntervalSince($0) })
            self.bluetoothTransmitterDelegate?.heartBeat()
        }
    }
    private func isCurrent(_ peripheral: CBPeripheral) -> Bool {
        canOperate && peripheral.identifier == selectedUUID && activePeripheral === peripheral
    }
    private func resetTransport() {
        watchdog?.cancel(); watchdog = nil; delivery.invalidate()
        deviceInformationValues.removeAll()
        statusLock.lock(); detectedMAC = nil; statusLock.unlock()
        assembler.reset(); writeCharacteristic = nil; notifyReady = false; beganConnection = false
        awaitingResponse = false; waitingForWriteCapacity = false; activePeripheral = nil
    }
    private func retryResponse(_ message: String) {
        guard canOperate else { return }
        assembler.reset(); awaitingResponse = false; waitingForWriteCapacity = false
        retries += 1; setStatus(message)
        if retries > 3 { recoverConnection("GS1 response timed out; reconnecting") }
        else { armWatchdog(after: 1, responseTimeout: false) }
    }
    private func recoverConnection(_ message: String) {
        guard canOperate else { return }
        resetTransport(); retries = 0; setStatus(message)
        stopConnectAndRestartScanning(forgetDeviceOnTimeout: false)
    }
    private func armWatchdog(after interval: TimeInterval, responseTimeout: Bool) {
        watchdog?.cancel()
        guard let token = delivery.token() else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.canOperate, self.delivery.allows(token) else { return }
            if responseTimeout {
                if !self.beganConnection { self.recoverConnection("GS1 connection setup timed out") }
                else { self.retryResponse("GS1 response timed out; retrying") }
            } else { self.requestHistory() }
        }
        watchdog = work
        runOnCentralQueue(after: interval) { if !work.isCancelled { work.perform() } }
    }
    private func setStatus(_ value: String) {
        statusLock.lock(); let changed = statusValue != value; statusValue = value; statusLock.unlock()
        if changed { trace("GS1 status: %{public}@", log: statusLog, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, value) }
    }
    private func halt(_ message: String) {
        delivery.stop(); watchdog?.cancel(); assembler.reset(); awaitingResponse = false
        setStatus(message); stopScanning(); disconnect()
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.delivery.isReleased else { return }
            self.bluetoothTransmitterDelegate?.error(message: message)
        }
    }
    override func prepareForRelease() {
        delivery.release()
        runOnCentralQueue { [weak self] in self?.resetTransport() }
        super.prepareForRelease()
    }
}
