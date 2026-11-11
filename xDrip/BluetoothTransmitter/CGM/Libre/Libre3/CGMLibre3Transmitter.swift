//
//  CGMLibre3Transmitter.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreBluetooth
import Security
import os

/// Stable, untranslated status values shared by the transport, persistence and device UI.
enum Libre3SensorStatus: String {
    case waitingForSensor = "Waiting for sensor"
    case authenticating = "Authenticating sensor"
    case waitingForGlucose = "Waiting for glucose"
    case warmingUp = "Sensor warming up"
    case okay = "Sensor OK"
    case readingUnavailable = "Sensor reading unavailable"
    case checkSensor = "Check sensor"
    case expired = "Sensor expired"
    case replaceSensor = "Replace sensor"

    enum Severity {
        case okay, warmup, warning, error, waiting
    }

    var severity: Severity {
        switch self {
        case .okay: return .okay
        case .warmingUp: return .warmup
        case .readingUnavailable, .checkSensor: return .warning
        case .expired, .replaceSensor: return .error
        case .waitingForSensor, .authenticating, .waitingForGlucose: return .waiting
        }
    }

    init?(storedValue: String) {
        // Keep the healthy status from earlier test installations compatible.
        if storedValue == "Receiving glucose" {
            self = .okay
        } else {
            guard let status = Self(rawValue: storedValue) else { return nil }
            self = status
        }
    }
}

protocol CGMLibre3TransmitterDelegate: AnyObject {
    func libre3Transmitter(_ transmitter: CGMLibre3Transmitter, updated record: Libre3PairingRecord)
}

/// Native Libre 3 transport. The superclass owns scanning, the central queue,
/// restoration and reconnection, security state belongs to one connection only.
// Mutable connection state is confined to the parent's central queue, UI snapshots use snapshotLock.
final class CGMLibre3Transmitter: BluetoothTransmitter, CGMTransmitter, @unchecked Sendable {
    private static let traceCategory = "CGMLibre3Transmitter"
    private static let traceLog = OSLog(subsystem: ConstantsLog.subSystem, category: traceCategory)
    private typealias GATT = Libre3LibreSensorGATT
    let sensorSerial: String
    private let warmupMinutes: Int
    private let wearMinutes: Int
    private let nfcReady: Bool
    private let cryptoReady: Bool
    private let store = Libre3CredentialStore()
    private var record: Libre3PairingRecord
    private weak var cgmDelegate: CGMTransmitterDelegate?
    private weak var libreDelegate: CGMLibre3TransmitterDelegate?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var subscribed = Set<CBUUID>()
    private var securityDeliveryTask: Task<Void, Never>?
    private var transport: Libre3AuthTransport?
    private var authentication: Task<Void, Never>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var writeID: UUID?
    private var connectionID = UUID()
    private var isReleased = false
    private var decoder: Libre3DataPlaneDecoder?
    private let assembler = Libre3DataPlaneNotificationAssembler()
    private var delivered = Set<UInt16>()
    private var lastBackfillRequest: Date?
    private var historyAnchor: UInt16?
    private var backfillSummary = Libre3BackfillSummary()
    private var backfillSummaryGeneration = 0
    private var backfillGeneration = 0
    private var pendingClinicalMinute: UInt16?
    private var outboundSequence: UInt16 = 0
    private var invalidPacketCount = 0
    private var announcedSensor = false
    private var needsRecovery = false
    private var reconnectDelay: TimeInterval = 0
    private var identityAttempt = 0
    private var certificateDisconnects = 0
    private var pairingStage = ""
    private var authenticationFailures = 0
    private let snapshotLock = NSLock()
    private var authenticatedSnapshot = false
    private var statusSnapshot = "Waiting for sensor"

    var isAuthenticated: Bool {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return authenticatedSnapshot
    }
    var connectionDescription: String {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return TextsLibre3.localized(Libre3SensorStatus(storedValue: statusSnapshot)?.rawValue ?? statusSnapshot)
    }
    var sensorStatus: Libre3SensorStatus? {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return Libre3SensorStatus(storedValue: statusSnapshot)
    }

    init(
        address: String?, name: String?, record: Libre3PairingRecord,
        bluetoothTransmitterDelegate: BluetoothTransmitterDelegate,
        libreDelegate: CGMLibre3TransmitterDelegate, cgmDelegate: CGMTransmitterDelegate
    ) {
        self.sensorSerial = record.serial
        self.warmupMinutes = record.warmupMinutes
        self.wearMinutes = record.wearMinutes
        self.nfcReady = record.nfcCompleted && record.blePIN?.count == 4
        self.cryptoReady = record.cryptoVersion == 1
        self.record = record
        self.historyAnchor = record.lastLifeCount
        self.statusSnapshot = record.nfcCompleted ? "Waiting for sensor" : Libre3ConnectionError.recovery.localizedDescription
        self.libreDelegate = libreDelegate
        self.cgmDelegate = cgmDelegate
        let identity: BluetoothTransmitter.DeviceAddressAndName =
            address.map {
                .alreadyConnectedBefore(address: $0, name: name)
            } ?? .notYetConnected(expectedName: nil)
        super.init(
            addressAndName: identity, CBUUID_Advertisement: GATT.serviceUUID.uuidString,
            servicesCBUUIDs: [GATT.serviceUUID, GATT.securityServiceUUID],
            CBUUID_ReceiveCharacteristic: GATT.Char.glucoseData.uuidString,
            CBUUID_WriteCharacteristic: GATT.Char.patchControl.uuidString,
            bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        snapshotLock.lock()
        let recoveryRequired = needsRecovery
        snapshotLock.unlock()
        guard nfcReady, !recoveryRequired, cryptoReady else { return .nfcScanNeeded }
        return super.startScanning()
    }

    override func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        // NFC gives the advertised BLE address, not the iOS peripheral UUID.
        // Match the advertisement name before handing connection ownership to the parent.
        guard let expected = record.bleAddress?.replacingOccurrences(of: ":", with: "").uppercased(),
            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name,
            name.uppercased() == expected
        else { return }
        super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !isReleased else { return }
        resetConnection()
        setStatus(.authenticating)
        handleDidConnectCommon(peripheral)
        peripheral.discoverServices([GATT.serviceUUID, GATT.securityServiceUUID])
        let cycle = connectionID
        runOnCentralQueue(after: 90) { [weak self] in
            guard let self, self.connectionID == cycle, self.decoder == nil else { return }
            self.fail(Libre3ConnectionError.timeout)
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            Libre3Log.failure("Characteristic discovery", error: error, channel: service.uuid.uuidString)
            fail(Libre3ConnectionError.disconnected)
            return
        }
        for characteristic in service.characteristics ?? [] {
            characteristics[characteristic.uuid] = characteristic
        }
        for uuid in GATT.Char.handshakeNotifying where !subscribed.contains(uuid) {
            guard let characteristic = characteristics[uuid] else { continue }
            subscribed.insert(uuid)
            setNotifyValue(true, for: characteristic)
        }
        beginAuthenticationIfReady()
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            Libre3Log.failure("Notification subscription", error: error, channel: characteristic.uuid.uuidString)
            fail(Libre3ConnectionError.disconnected)
            return
        }
        beginAuthenticationIfReady()
    }

    override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == GATT.Char.patchControl, let error = error as NSError? {
            Self.logStage("Control write failed, sequence=\(outboundSequence), errorDomain=\(error.domain), errorCode=\(error.code)")
        }
        guard securityChannel(characteristic.uuid) != nil, let continuation = writeContinuation else { return }
        writeContinuation = nil
        writeID = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            Libre3Log.failure("Characteristic update", error: error, channel: characteristic.uuid.uuidString)
            return
        }
        guard let data = characteristic.value else { return }
        if let channel = securityChannel(characteristic.uuid), let transport {
            let previous = securityDeliveryTask
            securityDeliveryTask = Task {
                await previous?.value
                await transport.receive(data, on: channel)
            }
            return
        }
        guard let decoder, let channel = Libre3DataPlaneChannel(uuidString: characteristic.uuid.uuidString),
            let wire = assembler.feed(fragment: data, channel: channel)
        else { return }
        let packet: Libre3DataPlaneDecodedPacket
        do {
            let frame = try Libre3DataFrame.parse(wire)
            packet = try decoder.decrypt(frame: frame, channel: channel)
        } catch {
            invalidPacketCount += 1
            if invalidPacketCount <= 3 || invalidPacketCount % 60 == 0 {
                // Keep the failure category, never the rejected payload or authentication material.
                let reason = error is Libre3DataFrameError ? "framing" : error is Libre3AESCCMError ? "decryption" : "decoding"
                Self.logStage("Rejected data packet, reason=\(reason), channel=\(channel), bytes=\(wire.count), count=\(invalidPacketCount)")
            }
            return
        }
        requestSignalStrengthForTraceIfNeeded(from: peripheral)
        switch packet.payload {
        case .patchStatus(let status):
            Self.logStage(
                "Patch status, age=\(status.lifeCount), currentAge=\(status.currentLifeCount), state=\(status.patchState), error=\(status.errorData), stackDisconnect=\(status.stackDisconnectReason), appDisconnect=\(status.appDisconnectReason)"
            )
            // The status event has its own older life count. Use the current sensor age for lifecycle.
            if status.currentLifeCount >= 0 { updateLifecycle(age: Int(status.currentLifeCount)) }
            if status.sensorAttention.isReplaceSensor {
                record.sensorEnded = true
                try? store.save(record)
                setStatus(.replaceSensor)
                DispatchQueue.main.async { [weak self] in
                    self?.cgmDelegate?.sensorHealthEventOccurred(.terminal(source: .libre, reason: .libreSensorFailure))
                }
            } else if status.sensorAttention == .sensorEnded {
                record.sensorEnded = true
                try? store.save(record)
                setStatus(.expired)
            } else if status.sensorAttention == .checkSensor {
                setStatus(.checkSensor)
            } else if case .unknown = status.sensorAttention {
                setStatus(.readingUnavailable)
            }
        case .realtimeGlucose(let reading): receive(reading)
        case .historicalReadingPage(let page):
            receive(page)
            scheduleClinicalBackfill()
        case .clinicalReadingRecord(let reading): receive(reading)
        default: break
        }
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard !isReleased else { return }
        Self.logStage(
            "Disconnected, authenticated=\(decoder != nil), peripheralState=\(peripheral.state.rawValue), errorDomain=\((error as NSError?)?.domain ?? "none"), errorCode=\((error as NSError?)?.code ?? 0)"
        )
        if decoder == nil, record.phase5Key == nil, pairingStage == "send SendCertificateLoadDone 0x03" {
            noteCertificateDisconnect()
        }
        resetConnection()
        if !needsRecovery { setStatus(.waitingForSensor) }
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    override func reconnectAfterDisconnect(_ central: CBCentralManager) {
        guard !isReleased, !needsRecovery else { return }
        let cycle = connectionID
        Self.logStage("Reconnect scheduled, delay=\(reconnectDelay)s")
        runOnCentralQueue(after: reconnectDelay) { [weak self, weak central] in
            guard let self, let central, !self.isReleased, self.connectionID == cycle, !self.needsRecovery else { return }
            Self.logStage("Reconnect requested from CoreBluetooth, centralState=\(central.state.rawValue)")
            self.resumeConnection(central)
        }
    }

    private func resumeConnection(_ central: CBCentralManager) {
        super.reconnectAfterDisconnect(central)
    }

    override func prepareForRelease() {
        runOnCentralQueue { [weak self] in
            guard let self else { return }
            // A queued disconnect callback must not schedule a fresh reconnect during teardown.
            self.isReleased = true
            self.resetConnection()
        }
        stopScanning()
        super.prepareForRelease()
    }

    private func resetConnection() {
        logBackfillSummary()
        // Keep the previous sensor minute before status or realtime packets advance it.
        historyAnchor = record.lastLifeCount
        connectionID = UUID()
        pairingStage = ""
        authentication?.cancel()
        authentication = nil
        if let transport { Task { await transport.finish() } }
        transport = nil
        securityDeliveryTask = nil
        writeContinuation?.resume(throwing: Libre3ConnectionError.disconnected)
        writeContinuation = nil
        writeID = nil
        decoder = nil
        characteristics.removeAll()
        subscribed.removeAll()
        assembler.reset()
        outboundSequence = 0
        invalidPacketCount = 0
        lastBackfillRequest = nil
        backfillGeneration += 1
        pendingClinicalMinute = nil
        snapshotLock.lock()
        authenticatedSnapshot = false
        snapshotLock.unlock()
    }

    private func securityChannel(_ uuid: CBUUID) -> Libre3AuthTransport.Channel? {
        switch uuid {
        case GATT.Char.secCertData: return .certificate
        case GATT.Char.secChallengeData: return .challenge
        case GATT.Char.secCommandResponse: return .command
        default: return nil
        }
    }

    private func beginAuthenticationIfReady() {
        guard authentication == nil, decoder == nil,
            characteristics[GATT.Char.glucoseData] != nil,
            characteristics[GATT.Char.patchControl] != nil,
            characteristics[GATT.Char.historicData] != nil,
            GATT.Char.handshakeNotifying.allSatisfy({ characteristics[$0]?.isNotifying == true }),
            let pin = record.blePIN, pin.count == 4
        else { return }
        guard record.cryptoVersion == 1 else {
            fail(Libre3ConnectionError.recovery)
            return
        }
        if let persisted = try? store.load(serial: record.serial), persisted.blePIN == pin {
            record = persisted
        }
        let cycle = connectionID
        let transport = Libre3AuthTransport { [weak self] data, channel in
            guard let self else { throw Libre3ConnectionError.disconnected }
            try await self.writeSecurity(data, channel: channel, cycle: cycle)
        }
        self.transport = transport
        let savedKey = record.phase5Key
        if savedKey == nil { Libre3Log.event(.authenticationStarted) }
        let serial = record.serial
        let pinnedVersion = record.identityVersion
        let preferredLabel = record.identityLabel
        let attempt = identityAttempt
        Self.logStage("Authentication starting, mode=\(savedKey == nil ? "fresh" : "cached"), attempt=\(attempt + 1)")
        // Recovery identifiers are useful during testing, but do not belong in normal traces.
        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
            Self.logStage(
                "Authentication details, sensor=\(serial), Receiver ID=\(Libre3ReceiverID(record.receiverID).littleEndianHex) (little-endian), mode=\(savedKey == nil ? "fresh" : "cached"), credentials=\(pinnedVersion ?? "none"), identity=\(preferredLabel ?? "unselected"), attempt=\(attempt + 1), region=\(record.region.map(String.init) ?? "unknown"), security=\(record.securityVersion.map(String.init) ?? "unknown")",
                type: .debug)
        }
        let eventLogger: @Sendable (String) -> Void = { [weak self] stage in
            self?.runOnCentralQueue { [weak self] in
                guard let self, self.connectionID == cycle else { return }
                self.pairingStage = stage
                Self.logStage(stage)
            }
        }
        authentication = Task { [weak self] in
            do {
                let material: Libre3Phase6SessionMaterial
                let key: Data
                if let savedKey {
                    let result = try await Libre3PairingFlow(transport: transport, eventLogger: eventLogger)
                        .runCachedReconnectHandshake(tail4: pin, phase5RawKey: savedKey)
                    material = result.sessionMaterial
                    key = savedKey
                } else {
                    guard let pinnedVersion else { throw Libre3IdentityError.unavailable }
                    var identities = try await Libre3IdentityStore.shared.identities(version: pinnedVersion)
                    if let preferredLabel, let index = identities.firstIndex(where: { $0.label == preferredLabel }) {
                        identities.insert(identities.remove(at: index), at: 0)
                    }
                    guard identities.indices.contains(attempt) else { throw Libre3ConnectionError.credentialsRejected }
                    let identity = identities[attempt]
                    let flow = Libre3PairingFlow(transport: transport, phoneCert: identity.certificate, eventLogger: eventLogger)
                    let result = try await flow.runCommandGatedFirstPairHandshake(
                        blePIN: pin,
                        phase5RawKeyProvider: { preamble in
                            let key = try identity.authenticationKey(for: preamble.phaseHandshake)
                            let store = Libre3CredentialStore()
                            guard var pending = try store.load(serial: serial), pending.blePIN == pin else {
                                throw Libre3ConnectionError.storage
                            }
                            pending.phase5Key = key
                            pending.cryptoVersion = 1
                            pending.identityLabel = identity.label
                            try store.save(pending)
                            return key
                        })
                    material = result.sessionMaterial
                    key = try identity.authenticationKey(for: result.preamble.phaseHandshake)
                }
                try Task.checkCancellation()
                let crypto = try Libre3DataPlaneCrypto(sessionMaterial: material)
                self?.runOnCentralQueue { [weak self] in
                    guard let self, self.connectionID == cycle else { return }
                    do {
                        // Reload identity selection saved before the Phase 5 write.
                        if let persisted = try self.store.load(serial: serial) {
                            self.record.identityLabel = persisted.identityLabel
                        }
                        self.certificateDisconnects = 0
                        self.authenticationFailures = 0
                        self.reconnectDelay = 0
                        self.record.phase5Key = key
                        self.record.authenticated = true
                        self.record.peripheralID = self.deviceAddress
                        try self.store.save(self.record)
                        self.decoder = Libre3DataPlaneDecoder(crypto: crypto)
                        self.snapshotLock.lock()
                        self.authenticatedSnapshot = true
                        self.snapshotLock.unlock()
                        Libre3Log.event(.authenticationSucceeded)
                        self.setStatus(.waitingForGlucose)
                        for uuid in GATT.Char.dataPlaneNotifying + [GATT.Char.historicData, GATT.Char.clinicalData] {
                            if let characteristic = self.characteristics[uuid],
                                characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
                            {
                                self.setNotifyValue(true, for: characteristic)
                            }
                        }
                        let snapshot = self.record
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.isAuthenticated else { return }
                            self.bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)
                            self.libreDelegate?.libre3Transmitter(self, updated: snapshot)
                        }
                    } catch { self.fail(Libre3ConnectionError.storage) }
                }
            } catch is CancellationError {
            } catch {
                self?.runOnCentralQueue { [weak self] in
                    guard let self, self.connectionID == cycle else { return }
                    // Link failures do not invalidate credentials or force a new NFC scan.
                    if let pairingError = error as? Libre3PairingFlowError,
                        case .unexpectedCommandResponse(let label, _, _) = pairingError,
                        label == "CertificateAccepted", savedKey == nil
                    {
                        self.identityAttempt += 1
                        self.fail(Libre3ConnectionError.disconnected)
                    } else if case .writeTimeout(let label, _) = error as? Libre3PairingFlowError,
                        label == "SendCertificateLoadDone", savedKey == nil
                    {
                        self.noteCertificateDisconnect()
                        self.fail(Libre3ConnectionError.disconnected)
                    } else if case .credentialsRejected = error as? Libre3ConnectionError {
                        self.markRecoveryRequired()
                        self.fail(Libre3ConnectionError.credentialsRejected)
                    } else if case .sensorCertificateVerificationFailed = error as? Libre3PairingFlowError {
                        self.markRecoveryRequired()
                        self.fail(Libre3ConnectionError.malformed)
                    } else if error is Libre3IdentityError {
                        self.markRecoveryRequired()
                        self.fail(Libre3ConnectionError.resources)
                    } else if (error as? Libre3ConnectionError).map({
                        if case .recovery = $0 { return true }
                        return false
                    }) == true {
                        self.fail(Libre3ConnectionError.recovery)
                    } else if error is Libre3AESCCMError
                        || {
                            if case .phase6VerificationFailed = error as? Libre3PairingFlowError { return true }
                            return false
                        }()
                    {
                        self.authenticationFailures += 1
                        self.fail(self.authenticationFailures >= 3 ? Libre3ConnectionError.recovery : Libre3ConnectionError.disconnected)
                    } else {
                        self.fail(Libre3ConnectionError.disconnected)
                    }
                }
            }
        }
    }

    private func writeSecurity(_ data: Data, channel: Libre3AuthTransport.Channel, cycle: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            runOnCentralQueue { [weak self] in
                guard let self, self.connectionID == cycle else {
                    continuation.resume(throwing: Libre3ConnectionError.disconnected)
                    return
                }
                let uuid: CBUUID
                switch channel {
                case .certificate: uuid = GATT.Char.secCertData
                case .challenge: uuid = GATT.Char.secChallengeData
                case .command: uuid = GATT.Char.secCommandResponse
                }
                guard self.writeContinuation == nil, let characteristic = self.characteristics[uuid] else {
                    continuation.resume(throwing: Libre3ConnectionError.malformed)
                    return
                }
                let id = UUID()
                self.writeID = id
                self.writeContinuation = continuation
                guard self.writeDataToPeripheral(data: data, characteristicToWriteTo: characteristic, type: .withResponse, logPayload: false) else {
                    self.fail(Libre3ConnectionError.disconnected)
                    return
                }
                self.runOnCentralQueue(after: 10) { [weak self] in
                    guard let self, self.writeID == id else { return }
                    self.fail(Libre3ConnectionError.timeout)
                }
            }
        }
    }

    private func updateLifecycle(age: Int) {
        guard age >= 0, age <= Int(UInt16.max), record.lastLifeCount.map({ age >= Int($0) }) ?? true else { return }
        record.lastLifeCount = UInt16(age)
        if record.startedAt == nil { record.startedAt = Date().addingTimeInterval(-Double(age) * 60) }
        do { try store.save(record) } catch {
            fail(Libre3ConnectionError.storage)
            return
        }
        if let start = record.startedAt, !announcedSensor {
            announcedSensor = true
            DispatchQueue.main.async { [weak self] in self?.cgmDelegate?.newSensorDetected(sensorStartDate: start) }
        }
        if age < record.warmupMinutes { setStatus(.warmingUp) }
        deliver([], age: age)
    }

    private func receive(_ reading: Libre3RealtimeGlucoseReading) {
        let age = Int(reading.lifeCount)
        guard record.lastLifeCount.map({ reading.lifeCount >= $0 }) ?? true else { return }
        updateLifecycle(age: age)
        guard decoder != nil else { return }
        let lifecycle = Libre3SensorLifecycle(
            currentLifeCountMinutes: age,
            warmupDurationMinutes: record.warmupMinutes, wearDurationMinutes: record.wearMinutes)
        let usable = !record.sensorEnded && reading.currentGlucoseQualityAssessment(lifecycle: lifecycle).isUsable
        Self.logStage("Realtime age=\(age), usable=\(usable), quality=\(reading.dqErrorRaw), condition=\(reading.sensorConditionRaw), actionability=\(reading.actionableStatus)")
        if !usable { record.rejectedMinutes.insert(reading.lifeCount) }
        if lifecycle.isActive, !record.sensorEnded {
            let event: CGMSensorHealthEvent = usable ? .recovered(source: .libre) : .temporary(source: .libre, reason: .libreTemporarySensorIssue)
            DispatchQueue.main.async { [weak self] in self?.cgmDelegate?.sensorHealthEventOccurred(event) }
        }
        setStatus(lifecycle.isExpired ? .expired : lifecycle.isWarmingUp ? .warmingUp : usable ? .okay : .readingUnavailable)
        do { try store.save(record) } catch {
            fail(Libre3ConnectionError.storage)
            return
        }
        var values: [GlucoseData] = []
        if usable, let glucose = reading.currentGlucoseMgDL, !record.rejectedMinutes.contains(reading.lifeCount), delivered.insert(reading.lifeCount).inserted,
            let start = record.startedAt
        {
            values.append(GlucoseData(timeStamp: start.addingTimeInterval(Double(age) * 60), glucoseLevelRaw: Double(glucose)))
        }
        deliver(values, age: age)
        requestHistory(currentAge: age)
    }

    private func receive(_ page: Libre3HistoricalReadingPage) {
        guard !record.sensorEnded, let start = record.startedAt, let current = record.lastLifeCount else { return }
        var values: [GlucoseData] = []
        var acceptedMinutes: [UInt16] = []
        for sample in page.samples where sample.lifeCount >= record.warmupMinutes && sample.lifeCount < record.wearMinutes && sample.lifeCount <= current {
            guard !record.rejectedMinutes.contains(sample.lifeCount), let glucose = sample.glucoseMgDL,
                delivered.insert(sample.lifeCount).inserted
            else { continue }
            values.append(GlucoseData(timeStamp: start.addingTimeInterval(Double(sample.lifeCount) * 60), glucoseLevelRaw: Double(glucose), backfilledAt: Date()))
            acceptedMinutes.append(sample.lifeCount)
        }
        recordBackfill(minutes: acceptedMinutes, stream: .historical)
        deliver(values.sorted { $0.timeStamp > $1.timeStamp }, age: Int(current))
    }

    private func receive(_ reading: Libre3ClinicalReadingRecord) {
        // Clinical records supply minute-resolution backfill, not realtime status.
        // Never replace a rejected minute or use one to declare sensor recovery.
        guard !record.sensorEnded, let start = record.startedAt, let current = record.lastLifeCount,
            reading.lifeCount >= record.warmupMinutes, reading.lifeCount < record.wearMinutes,
            reading.lifeCount < current, !record.rejectedMinutes.contains(reading.lifeCount),
            let glucose = reading.currentGlucoseMgDL, delivered.insert(reading.lifeCount).inserted
        else { return }
        recordBackfill(minutes: [reading.lifeCount], stream: .clinical)
        deliver(
            [
                GlucoseData(
                    timeStamp: start.addingTimeInterval(Double(reading.lifeCount) * 60),
                    glucoseLevelRaw: Double(glucose), backfilledAt: Date())
            ], age: Int(current))
    }

    private func recordBackfill(minutes: [UInt16], stream: Libre3BackfillStream) {
        guard !minutes.isEmpty else { return }
        backfillSummary.append(minutes: minutes, stream: stream)
        backfillSummaryGeneration += 1
        let generation = backfillSummaryGeneration
        let cycle = connectionID
        // Summarize a quiet stream once instead of tracing every recovered minute.
        runOnCentralQueue(after: 3) { [weak self] in
            guard let self, self.connectionID == cycle, self.backfillSummaryGeneration == generation else { return }
            self.logBackfillSummary()
        }
    }

    private func logBackfillSummary() {
        guard let first = backfillSummary.firstMinute, let last = backfillSummary.lastMinute else { return }
        Self.logStage("Backfill accepted, historic=\(backfillSummary.historicalCount), clinical=\(backfillSummary.clinicalCount), firstAge=\(first), lastAge=\(last)")
        backfillSummary = Libre3BackfillSummary()
    }

    private func scheduleClinicalBackfill() {
        guard pendingClinicalMinute != nil else { return }
        backfillGeneration += 1
        let generation = backfillGeneration
        let cycle = connectionID
        // Wait for the historical stream to become quiet before requesting another stream.
        runOnCentralQueue(after: 3) { [weak self] in
            guard let self, self.connectionID == cycle, self.backfillGeneration == generation,
                let minute = self.pendingClinicalMinute,
                self.characteristics[GATT.Char.clinicalData]?.isNotifying == true
            else { return }
            self.pendingClinicalMinute = nil
            self.sendBackfill(.clinicalBackfillGreaterEqual(lifeCount: minute))
        }
    }

    private func sendBackfill(_ command: Libre3PatchControlCommand) {
        guard let decoder, let characteristic = characteristics[GATT.Char.patchControl], outboundSequence < UInt16.max else { return }
        // The first control command in each authenticated session uses sequence 1.
        // Consume the sequence before encryption, never reuse a nonce after a failed write.
        outboundSequence += 1
        guard let frame = try? decoder.crypto.encrypt(plaintext: command.plaintext, sequence: outboundSequence, kind: .patchControlWrite) else { return }
        Self.logStage("Control command, \(command.label), sequence=\(outboundSequence)")
        _ = writeDataToPeripheral(data: frame.raw, characteristicToWriteTo: characteristic, type: .withResponse, logPayload: false)
    }

    private func requestHistory(currentAge: Int) {
        // During warm-up there is no eligible glucose history. Never request a future minute.
        guard currentAge > record.warmupMinutes, !record.sensorEnded,
            lastBackfillRequest.map({ Date().timeIntervalSince($0) >= 22 * 60 }) ?? true,
            let decoder, let characteristic = characteristics[GATT.Char.patchControl],
            characteristics[GATT.Char.historicData]?.isNotifying == true, outboundSequence < UInt16.max
        else { return }
        guard let minute = Libre3BackfillWindow.startMinute(
            currentAge: currentAge, lastKnownAge: historyAnchor, warmupMinutes: record.warmupMinutes)
        else { return }
        let command = Libre3PatchControlCommand.historicalBackfillGreaterEqual(lifeCount: minute)
        outboundSequence += 1
        guard let frame = try? decoder.crypto.encrypt(plaintext: command.plaintext, sequence: outboundSequence, kind: .patchControlWrite) else { return }
        Self.logStage("Control command, \(command.label), sequence=\(outboundSequence), currentAge=\(currentAge)")
        if writeDataToPeripheral(data: frame.raw, characteristicToWriteTo: characteristic, type: .withResponse, logPayload: false) {
            lastBackfillRequest = Date()
            historyAnchor = UInt16(currentAge)
            pendingClinicalMinute = minute
            scheduleClinicalBackfill()
        }
    }

    private func deliver(_ values: [GlucoseData], age: Int) {
        DispatchQueue.main.async { [weak self] in
            var glucose = values
            self?.cgmDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucose, transmitterBatteryInfo: nil, sensorAge: Double(age) * 60)
        }
    }

    private func setStatus(_ status: Libre3SensorStatus) {
        // A later packet or reconnect cannot clear a confirmed terminal sensor state.
        let resolvedStatus =
            record.sensorEnded && status != .replaceSensor && status != .expired
            ? (Libre3SensorStatus(storedValue: record.status) == .replaceSensor ? .replaceSensor : .expired)
            : status
        publishStatus(resolvedStatus.rawValue)
    }

    private func publishStatus(_ status: String) {
        if record.status != status {
            Self.logStage("Status: " + status)
            switch Libre3SensorStatus(storedValue: status) {
            case .checkSensor: Libre3Log.event(.sensorCheckRequired)
            case .expired: Libre3Log.event(.sensorExpired)
            case .okay: Libre3Log.event(.sensorOkay)
            default: break
            }
        }
        // The UI still receives fresh snapshots when the status text itself has not changed.
        record.status = status
        snapshotLock.lock()
        statusSnapshot = status
        snapshotLock.unlock()
        let snapshot = record
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.libreDelegate?.libre3Transmitter(self, updated: snapshot)
            NotificationCenter.default.post(name: .libre3StateChanged, object: self)
        }
    }

    private func noteCertificateDisconnect() {
        // Retry once with the same identity for a possible link fault, then advance.
        certificateDisconnects += 1
        reconnectDelay = min(max(5, reconnectDelay * 2), 60)
        if certificateDisconnects >= 2 {
            identityAttempt += 1
            certificateDisconnects = 0
        }
    }

    private func markRecoveryRequired() {
        snapshotLock.lock()
        needsRecovery = true
        snapshotLock.unlock()
    }

    private func fail(_ error: Libre3ConnectionError) {
        if case .recovery = error { markRecoveryRequired() }
        reconnectDelay = min(max(5, reconnectDelay * 2), 60)
        Self.logStage("Connection failure, error=\(error), pairingStage=\(pairingStage), reconnectDelay=\(reconnectDelay)s")
        if needsRecovery {
            Libre3Log.event(.recoveryRequired)
        } else if decoder == nil {
            Libre3Log.event(.authenticationFailed)
        }
        resetConnection()
        switch error {
        case .disconnected, .timeout:
            // Routine link failures retry automatically, like the other CGMs. Do not leave a
            // modal warning behind after reconnection or ask the user to retry it manually.
            setStatus(.waitingForSensor)
            disconnect()
        default:
            publishStatus(error.localizedDescription)
            disconnect()
            DispatchQueue.main.async { [weak self] in self?.bluetoothTransmitterDelegate?.error(message: error.localizedDescription) }
        }
    }

    private static func logStage(_ stage: String, type: OSLogType = .info) {
        trace("%{public}@", log: traceLog, category: traceCategory, type: type, stage)
    }

    func cgmTransmitterType() -> CGMTransmitterType { .Libre3 }
    var productName: String { Libre3ProductNameResolver.title(wearMinutes: wearMinutes) }
    func isWebOOPEnabled() -> Bool { true }
    func nonWebOOPAllowed() -> Bool { false }
    func maxSensorAgeInDays() -> Double? { Double(wearMinutes) / 1440 }
    func sensorWarmupDurationInMinutes() -> Double? { Double(warmupMinutes) }
    func getCBUUID_Service() -> String { GATT.serviceUUID.uuidString }
    func getCBUUID_Receive() -> String { GATT.Char.glucoseData.uuidString }
}

/// Keep routine overlap, but include a longer interruption when a previous sensor minute is known.
/// The sensor supplies the history it still retains, which may have a lower sampling frequency.
enum Libre3BackfillWindow {
    static func startMinute(currentAge: Int, lastKnownAge: UInt16?, warmupMinutes: Int) -> UInt16? {
        guard warmupMinutes >= 0, currentAge > warmupMinutes, currentAge <= Int(UInt16.max) else { return nil }
        let overlapStart = max(warmupMinutes, currentAge - 180)
        return UInt16(max(warmupMinutes, min(lastKnownAge.map(Int.init) ?? overlapStart, overlapStart)))
    }
}

/// Counts readings accepted by the transmitter, not necessarily new database rows or contiguous history.
struct Libre3BackfillSummary {
    private(set) var historicalCount = 0
    private(set) var clinicalCount = 0
    private(set) var firstMinute: UInt16?
    private(set) var lastMinute: UInt16?

    mutating func append(minutes: [UInt16], stream: Libre3BackfillStream) {
        guard let first = minutes.min(), let last = minutes.max() else { return }
        switch stream {
        case .historical: historicalCount += minutes.count
        case .clinical: clinicalCount += minutes.count
        }
        firstMinute = min(firstMinute ?? first, first)
        lastMinute = max(lastMinute ?? last, last)
    }
}

/// Only closed outcomes enter the Activity Log. Error details stay in the developer trace.
enum Libre3Log {
    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: "Libre3")

    static func event(_ activity: TroubleshootingCGMActivity, error: Error? = nil) {
        let type: OSLogType
        switch activity {
        case .authenticationFailed, .recoveryRequired, .credentialsUnavailable, .accountLookupFailed,
             .nfcScanFailed, .nfcScanTimedOut, .nfcUnavailable:
            type = .error
        default: type = .info
        }
        trace("Libre 3 %{public}@", log: log, category: "Libre3", type: type,
              troubleshooting: .standard(.cgm(source: .libre3, activity: activity)), activity.rawValue)
        if error != nil { failure(activity.rawValue, error: error, type: type) }
    }

    static func failure(_ operation: String, error: Error?, channel: String = "none", type: OSLogType = .error) {
        guard let error else { return }
        let category: String
        if let lookupError = error as? Libre3AccountLookup.LookupError {
            switch lookupError {
            case .credentials: category = "loginRejected"
            case .consent: category = "accountConsentRequired"
            case .unsupported: category = "accountLookupUnavailable"
            }
        } else if let identityError = error as? Libre3IdentityError {
            category = identityError == .invalidFile ? "credentialValidation" : "credentialsUnavailable"
        } else {
            category = "system"
        }
        let underlying = error as NSError
        trace("%{public}@, category=%{public}@, channel=%{public}@, errorDomain=%{public}@, errorCode=%{public}@",
              log: log, category: "Libre3", type: type,
              operation, category, channel, underlying.domain, String(underlying.code))
    }

    static func detail(_ message: String) {
        trace("%{public}@", log: log, category: "Libre3", type: .info, message)
    }
}
