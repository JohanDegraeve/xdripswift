//
//  CGMOttaiTransmitter.swift
//  xdrip
//
//  Ottai / Syai CGM Bluetooth transmitter.
//
//  This is a Swift copy of OttaiBleManager.kt from JugglucoNG (the working
//  Android driver), built on xDrip's BluetoothTransmitter class. The
//  encryption, login math, packet parsing and the glucose formula live in the
//  Core/ files. This class talks to the sensor step by step, checks every
//  reading the same way the Android code does, and gives the good readings to
//  xDrip.
//
//  Same as the Kotlin where iOS allows it:
//    - connect -> reset -> find services -> turn on notifications (history,
//      live, cgm-info) -> login (Auth V2) -> read the command byte:
//      3 = streaming, 0..2 = needs activation, 4 or more = sensor ended
//      (read the live buffer only to learn the last dataNo, fetch history, no live)
//    - the live poll time comes from the 0x0777 cgm-info packet (4 or more
//      bytes, 5..3600 s, at most 60 s); the poll waits while live
//      notifications keep coming
//    - sample times come from a "stream anchor" (start = sample - dataNo * 60 s);
//      the start is saved as the activation time only after two anchors agree
//    - a dataNo limit against broken packets, with a "stop trusting the limit" rule
//    - all the checks, in this order: hard reject -> recently rejected -> warmup
//      -> continuity (one-minute jump, lonely spike in history) -> freshness
//    - history comes in blocks of 270 records, 750 ms apart, with a 12 s watchdog
//  Different on purpose (xDrip has no Room database):
//    - the first readings after connect are collected and given to xDrip ONCE,
//      newest first, so its 5-minute filter can fill the chart from empty
//    - the first backfill is a fixed 24 h window (not a database diff), and
//      there is no list of missing windows saved between sessions
//    - NFC wake, connection priority and the outage probe do not exist on iOS
//
//  Threads: everything in this class runs on `workQueue` (one at a time).
//  CoreBluetooth callbacks are sent there in order. The base class helpers
//  (read, write, notify, disconnect) switch to their own queue, so we can call
//  them from `workQueue`. Readings go to xDrip on the main queue (Core Data).
//

import CoreBluetooth
import Foundation
import os

final class CGMOttaiTransmitter: BluetoothTransmitter, CGMTransmitter {

    // MARK: - constants (same values as OttaiBleManager.kt)

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMOttai)

    private static let mgdlPerMmoll: Double = 18.0
    private static let recordIntervalMs: Int64 = 60_000
    private static let maxLivePollIntervalMs: Int64 = 60_000
    private static let historyRequestChunkRecords = 270
    private static let historyChunkDelay: TimeInterval = 0.75
    private static let historyPageTimeout: TimeInterval = 12.0
    private static let historyMaxRetries = 3
    private static let historyRequestCooldownMs: Int64 = 60_000
    private static let recentHistoryRecords = 60
    /// xDrip only: how far back the first backfill goes (the Kotlin uses a database diff instead).
    private static let initialBackfillRecords = 24 * 60
    private static let initialHistoryDelay: TimeInterval = 4.0
    private static let initialHistoryMinSensorAgeMs: Int64 = 3 * 60_000
    private static let maxReasonableDataNoAhead = 120
    private static let maxConsecutiveCeilingFullDrops = 3
    private static let currentSampleFreshMs: Int64 = 120_000
    private static let currentSampleFloorGraceMs: Int64 = recordIntervalMs
    private static let confirmedStartAgreementMs: Int64 = 2 * recordIntervalMs
    private static let maxConsecutiveContinuityRejects = 3
    private static let postActivationConfirmDelay: TimeInterval = 1.0
    private static let postActivationConfirmRetry: TimeInterval = 1.5
    private static let postActivationConfirmMaxAttempts = 4
    private static let reauthDelay: TimeInterval = 3.0

    // MARK: - identity / materials

    private let sensorId: String
    private var materials: OttaiRegistry.DeviceMaterials
    private var authKeys: [[UInt8]]?
    private var macBytes: [UInt8] { OttaiCrypto.hexToBytes(sensorId) }

    private weak var cgmTransmitterDelegate: CGMTransmitterDelegate?

    /// xDrip only: sends the accepted readings to the Syai cloud when the user turned that on.
    private let cloudUploader: OttaiCloudUploader

    // MARK: - state for one connection (reset on every connect)

    private enum Phase { case idle, enablingNotify, auth, streaming }
    private enum AuthStep { case none, readDeviceTime, readDeviceParam, readDeviceSign, writeAppParam, writeAppSign, done }
    private enum ActStep { case none, rtc, maxActive, destruction, command, done }

    private var phase: Phase = .idle
    private var authStep: AuthStep = .none
    private var actStep: ActStep = .none
    private var commandStatus = -1
    private var connectionGeneration = 0

    private var characteristics: [String: CBCharacteristic] = [:]
    private var discoveredServices = Set<CBUUID>()
    private weak var connectedPeripheral: CBPeripheral?

    private var deviceTimeBytes: [UInt8] = []
    private var deviceParamIndex = 0
    private var deviceParamTime: [UInt8] = []
    private var devicePubX: [UInt8] = []
    private var devicePubY: [UInt8] = []
    private var appKeyPair: OttaiBleAuth.KeyPair?
    private var appIndex = 0
    private var appTime3: [UInt8] = []
    private var sessionKeyHex = ""
    private var lastAuthDevHex = ""
    private var serverAuthHostBytes: [UInt8]?
    private var serverAuthFlagBytes: [UInt8]?

    private var pendingActivation = false
    private var rediscoveredServices = Set<CBUUID>()
    /// How many services the sensor reported in the re-discovery before activation.
    private var expectedRediscoveryCount = 0
    private var activationConfirmAttempt = 0

    /// The three services the normal (streaming) connection needs.
    private static let requiredServices: Set<CBUUID> = [
        CBUUID(string: OttaiConstants.serviceAuth),
        CBUUID(string: OttaiConstants.serviceCgm),
        CBUUID(string: OttaiConstants.serviceDeviceInfo),
    ]

    private var livePollTimer: DispatchSourceTimer?
    private var liveReadInFlight = false

    // history block chain (for one connection)
    private var activeHistoryStart = -1
    private var activeHistoryEndExclusive = -1
    private var pendingHistoryReason: String?
    private var pendingHistoryNextStart = 0
    private var pendingHistoryEndExclusive = 0
    private var historyRetryCount = 0
    private var historyChunkBestDataNo = -1
    private var historyWatchdog: DispatchWorkItem?
    private var historyChunkWork: DispatchWorkItem?
    private var lastHistoryRequestAtMs: Int64 = 0

    // MARK: - state that stays across reconnects

    private var lastDataNo = 0
    private var lastGlucoseAtMs: Int64 = 0
    private var lastLiveFrameAtMs: Int64 = 0
    private var lastLiveNotifyAtMs: Int64 = 0
    private var livePollIntervalMs: Int64 = recordIntervalMs
    private var activatedMaxActiveMs: Int64 = 0
    private var activationRequested = false
    private var activationCommandSentAtMs: Int64 = 0
    private var maxActiveCandidatesMs: [Int64] = []
    private var maxActiveCandidateIndex = 0
    private var maxActiveAttemptMs: Int64 = 0

    // stream time anchor (see seedStreamTimeAnchor / offerConfirmedActiveTime)
    private var provisionalActiveTimeMs: Int64 = 0
    private var streamStartTimeMs: Int64 = 0
    private var streamStartReliable = false
    private var pendingConfirmedStartMs: Int64 = 0

    // dataNo limit
    private var consecutiveCeilingFullDrops = 0
    private var ceilingDistrusted = false

    // wrong-sensor guard. On iOS the stored BLE address is not the sensor id, so it
    // can point to an old sensor while the keys are for a new one. When the login
    // fails twice with a bad device signature, we forget that peripheral and scan
    // again, skipping the rejected one for the rest of this app run.
    private var lastVerifyFailed = false
    private var wrongSensorStrikes = 0
    private var rejectedPeripheralIdentifiers = Set<String>()
    private let rejectedIdentifiersLock = NSLock()

    // continuity check
    private struct RejectedSample { let rawCurrent: Int; let mmol: Float }
    private var recentlyRejectedSamples: [Int: RejectedSample] = [:]
    private var recentlyRejectedOrder: [Int] = []
    private var lastAcceptedDataNo = -1
    private var lastAcceptedSampleMs: Int64 = 0
    private var lastAcceptedMmol: Float = 0
    private var lastAcceptedRawCurrent = 0
    private var lastEvaluatedDataNo = -1
    private var lastEvaluatedSampleMs: Int64 = 0
    private var consecutiveContinuityRejects = 0

    // xDrip only: the last sensor session start reported to xDrip (see reportSensorSessionIfNeeded)
    private var lastReportedSensorStartMs: Int64 = 0

    // xDrip only: the first readings are collected here (see the file header)
    private var initialFlushDone = false
    private var initialHistoryRequested = false
    private var initialBuffer: [Int: GlucoseData] = [:]
    private var flushGeneration = 0

    private let workQueue = DispatchQueue(label: "CGMOttaiTransmitter.work")

    // MARK: - init

    init(address: String?, name: String?, sensorId: String,
         bluetoothTransmitterDelegate: BluetoothTransmitterDelegate,
         cGMTransmitterDelegate: CGMTransmitterDelegate) {

        let canonical = OttaiConstants.canonicalSensorId(sensorId).isEmpty ? sensorId : OttaiConstants.canonicalSensorId(sensorId)
        self.sensorId = canonical
        self.materials = OttaiRegistry.loadMaterials(sensorId: canonical)
        self.authKeys = materials.authKeys
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        self.cloudUploader = OttaiCloudUploader(sensorId: canonical)

        // load the saved state (restoreFromPersistence in the Kotlin)
        self.lastDataNo = OttaiRegistry.loadLastDataNo(canonical)
        self.activatedMaxActiveMs = OttaiRegistry.loadAcceptedMaxActive(canonical)
        if materials.activeTimeMs > 0 {
            OttaiRegistry.saveProvisionalActiveTime(canonical, 0)
            self.provisionalActiveTimeMs = 0
        } else {
            self.provisionalActiveTimeMs = OttaiRegistry.loadProvisionalActiveTime(canonical)
        }
        if let b = OttaiRegistry.loadContinuityBaseline(canonical) {
            lastAcceptedDataNo = b.dataNo
            lastAcceptedSampleMs = b.sampleMs
            lastAcceptedMmol = b.mmol
            lastAcceptedRawCurrent = b.rawCurrent
            lastEvaluatedDataNo = b.dataNo
            lastEvaluatedSampleMs = b.sampleMs
        }

        // On iOS the "address" is a CoreBluetooth id, not the sensor MAC. If we have
        // one (reconnect), use it. If not, scan for a new device.
        let storedAddress = address ?? OttaiRegistry.findRecord(canonical)?.address
        let newAddressAndName: BluetoothTransmitter.DeviceAddressAndName
        if let a = storedAddress, !a.isEmpty {
            newAddressAndName = .alreadyConnectedBefore(address: a, name: name)
        } else {
            newAddressAndName = .notYetConnected(expectedName: nil)
        }

        super.init(addressAndName: newAddressAndName,
                   CBUUID_Advertisement: "181F",
                   servicesCBUUIDs: [CBUUID(string: OttaiConstants.serviceAuth),
                                     CBUUID(string: OttaiConstants.serviceCgm),
                                     CBUUID(string: OttaiConstants.serviceDeviceInfo)],
                   CBUUID_ReceiveCharacteristic: OttaiConstants.charGlucoseLive,
                   CBUUID_WriteCharacteristic: OttaiConstants.charCommand,
                   bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    // MARK: - CGMTransmitter

    func cgmTransmitterType() -> CGMTransmitterType { .ottai }
    func getCBUUID_Service() -> String { OttaiConstants.serviceCgm }
    func getCBUUID_Receive() -> String { OttaiConstants.charGlucoseLive }
    func maxSensorAgeInDays() -> Double? {
        let ms = OttaiConstants.expectedLifetimeMs(cloudActiveExpireMs: materials.activeExpireTimeMs, acceptedMaxActiveMs: activatedMaxActiveMs)
        return Double(ms) / Double(24 * 3600 * 1000)
    }
    func needsSensorStartTime() -> Bool { false }
    func needsSensorStartCode() -> Bool { false }
    /// The sensor sends glucose that is already calibrated (the cloud formula does it).
    /// Without this, xDrip keeps asking the user for a calibration value.
    func isWebOOPEnabled() -> Bool { true }
    /// The user cannot switch the calibrated mode off.
    func nonWebOOPAllowed() -> Bool { false }

    /// xDrip "start sensor" = the Ottai activation. It cannot be undone.
    /// The sensor's last command byte (3 = active, 4+ = ended, 0..2 = not started).
    /// The settings screen uses it to warn before a repeated activation.
    var sensorCommandStatus: Int { commandStatus }

    /// Same as `requestForceActivation()` in JugglucoNG: the user's Activate button is
    /// always a "force" request. It also runs on a sensor that is already active or has
    /// ended, so the user can try to start it again (for example to extend the lifetime).
    /// The warning is shown by the settings screen before this is called.
    func startSensor(sensorCode: String?, startDate: Date) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if self.effectiveActiveTimeMs() > 0 || self.activationCommandSentAtMs > 0 {
                trace("FORCE activation (bypassing already-started guard)", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .info)
            }
            self.activationRequested = true
            OttaiRegistry.setActivationAttempted(self.sensorId, true)
            if self.phase == .streaming, !self.sessionKeyHex.isEmpty {
                self.requestActivationWithRediscovery()
            } else {
                trace("activation refused for now — not authenticated (phase=%{public}@); will run after the next login", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .info, "\(self.phase)")
            }
        }
    }

    // MARK: - connect / disconnect

    /// Every connection starts from zero. The sensor gives a new login challenge
    /// each time, and the characteristic objects from the old connection are no
    /// longer valid. Without this reset, a reconnect after a Bluetooth drop kept
    /// the old session key and old handles: no new login, every write failed with
    /// "The handle is invalid", the sensor dropped the link again, and so on until
    /// the user switched the connection off and on by hand.
    private func resetConnectionState() {
        connectionGeneration += 1
        phase = .idle
        authStep = .none
        actStep = .none
        commandStatus = -1
        discoveredServices.removeAll()
        rediscoveredServices.removeAll()
        characteristics.removeAll()
        connectedPeripheral = nil
        deviceTimeBytes = []
        appKeyPair = nil
        sessionKeyHex = ""
        serverAuthHostBytes = nil
        serverAuthFlagBytes = nil
        pendingActivation = false
        expectedRediscoveryCount = 0
        liveReadInFlight = false
        lastVerifyFailed = false
        livePollTimer?.cancel()
        livePollTimer = nil
        clearPendingHistoryRange()
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // This is queued BEFORE super starts service discovery. The discovery
        // callbacks go to the same queue, so the reset always runs first.
        workQueue.async { [weak self] in self?.resetConnectionState() }
        super.centralManager(central, didConnect: peripheral)
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            self.livePollTimer?.cancel()
            self.livePollTimer = nil
            self.phase = .idle
            self.sessionKeyHex = ""
            self.clearPendingHistoryRange()
        }
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    /// Drop the link, so the base class reconnects and the login starts again.
    /// Does nothing if a newer connection came in the meantime.
    private func recoverAndReconnect(_ reason: String) {
        let gen = connectionGeneration
        trace("%{public}@ — reconnecting", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, reason)
        workQueue.asyncAfter(deadline: .now() + Self.reauthDelay) { [weak self] in
            guard let self = self, self.connectionGeneration == gen else { return }
            self.disconnect()
        }
    }

    /// The sensor refused the auth write. When the device signature also failed, we
    /// are most likely talking to the wrong physical sensor (an old one with the same
    /// name). After two such logins, forget it and scan for another sensor.
    private func handleAuthWriteFailure() {
        if lastVerifyFailed { wrongSensorStrikes += 1 }
        if lastVerifyFailed && wrongSensorStrikes >= 2 {
            rotateAwayFromWrongSensor()
        } else {
            recoverAndReconnect("auth write failed")
        }
    }

    private func rotateAwayFromWrongSensor() {
        wrongSensorStrikes = 0
        if let address = deviceAddress {
            rejectedIdentifiersLock.lock()
            rejectedPeripheralIdentifiers.insert(address)
            rejectedIdentifiersLock.unlock()
        }
        trace("login keeps failing with a bad device signature — this looks like the wrong sensor; forgetting it and scanning for another one", log: log, category: ConstantsLog.categoryCGMOttai, type: .error)
        disconnectAndForget()
        workQueue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            _ = self?.startScanning()
        }
    }

    override func shouldConnectToDiscoveredPeripheral(_ peripheral: CBPeripheral) -> Bool {
        rejectedIdentifiersLock.lock()
        let rejected = rejectedPeripheralIdentifiers.contains(peripheral.identifier.uuidString)
        rejectedIdentifiersLock.unlock()
        return !rejected
    }

    private func afterDelay(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        let gen = connectionGeneration
        workQueue.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, self.connectionGeneration == gen else { return }
            block()
        }
    }

    // MARK: - service discovery

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Remember how many services the sensor has, so the re-discovery before an
        // activation waits for ALL of them (like Android's all-or-nothing discovery).
        let count = peripheral.services?.count ?? 0
        workQueue.async { [weak self] in
            guard let self = self, self.pendingActivation else { return }
            self.expectedRediscoveryCount = count
        }
        super.peripheral(peripheral, didDiscoverServices: error)
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let chars = service.characteristics ?? []
        let serviceUUID = service.uuid
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if let error = error {
                trace("in didDiscoverCharacteristicsFor, error %{public}@", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .error, error.localizedDescription)
            }
            self.connectedPeripheral = peripheral
            for ch in chars { self.characteristics[ch.uuid.full128] = ch }
            if self.phase == .idle {
                self.discoveredServices.insert(serviceUUID)
                if Self.requiredServices.isSubset(of: self.discoveredServices) { self.onServicesDiscovered() }
            } else if self.pendingActivation {
                self.rediscoveredServices.insert(serviceUUID)
                if self.expectedRediscoveryCount > 0, self.rediscoveredServices.count >= self.expectedRediscoveryCount {
                    self.pendingActivation = false
                    trace("post-auth re-discovery complete — starting activation", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .info)
                    self.startActivationWrites()
                }
            }
        }
    }

    private func char(_ uuidString: String) -> CBCharacteristic? {
        characteristics[CBUUID(string: uuidString).full128]
    }

    private func onServicesDiscovered() {
        authKeys = materials.authKeys
        switch ottaiAuthEntryMode(
            hasAuthKeys: authKeys != nil,
            bootstrapPending: OttaiRegistry.isV3CredentialBootstrapPending(sensorId),
            cnSessionAvailable: OttaiRegistry.loadSessionProfile() == .cnPhone && !OttaiRegistry.loadAccessToken().isEmpty,
            validatedDeviceVersion: OttaiRegistry.loadLastValidatedDeviceVersion(sensorId: sensorId)
        ) {
        case .storedMaterialAuth:
            phase = .enablingNotify
            // order: history, live, cgm-info
            for uuid in [OttaiConstants.charGlucoseHistory, OttaiConstants.charGlucoseLive, OttaiConstants.charCgmInfoNotify] {
                if let ch = char(uuid) { setNotifyValue(true, for: ch) }
            }
            afterDelay(0.6) { [weak self] in self?.startAuth() }
        case .v3CredentialBootstrap:
            trace("starting V3 credential bootstrap", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
            startAuth()
        case .blocked:
            // No keys yet (first Scan, before the cloud id and fetch). Stay connected
            // and do nothing: the connection creates the device entry and shows the
            // setup screen.
            trace("no auth keys and no authorized V3 bootstrap — idle until credentials are set", log: log, category: ConstantsLog.categoryCGMOttai, type: .error)
        }
    }

    // MARK: - login (Auth V2 / V3)

    private func startAuth() {
        phase = .auth
        serverAuthHostBytes = nil
        serverAuthFlagBytes = nil
        authStep = .readDeviceTime
        readChar(OttaiConstants.charCurrentTime)
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid.full128
        let value = [UInt8](characteristic.value ?? Data())
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if let error = error {
                trace("read err %{public}@ %{public}@ phase=%{public}@", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .error, characteristic.uuid.uuidString, error.localizedDescription, "\(self.phase)")
                // The maxActive read is only for display. Never let it break a stream.
                if uuid == OttaiConstants.charMaxActiveTime { return }
                if self.phase == .auth { self.recoverAndReconnect("auth read failed") }
                return
            }
            self.handleValue(uuid: uuid, value: value)
        }
    }

    private func handleValue(uuid: String, value: [UInt8]) {
        switch uuid {
        case OttaiConstants.charCurrentTime:
            deviceTimeBytes = value
            authStep = .readDeviceParam
            readChar(OttaiConstants.charAuthDeviceParam)
        case OttaiConstants.charAuthDeviceParam:
            lastAuthDevHex = OttaiCrypto.bytesToHex(value)
            parseDeviceAuthParam(value)
            authStep = .readDeviceSign
            readChar(OttaiConstants.charAuthSign)
        case OttaiConstants.charAuthSign:
            handleAuthSign(value)
        case OttaiConstants.charCgmInfoNotify:
            handleCgmInfo(value)
        case OttaiConstants.charGlucoseLive:
            // CoreBluetooth gives notifications and read answers the same way. A live
            // value that comes while no read is running must be a notification.
            if liveReadInFlight { liveReadInFlight = false } else { lastLiveNotifyAtMs = nowMs() }
            handleGlucosePayload(value, live: true)
        case OttaiConstants.charGlucoseHistory:
            handleGlucosePayload(value, live: false)
        case OttaiConstants.charCommand:
            handleCommandStatus(value.first.map { Int($0) } ?? -1)
        case OttaiConstants.charMaxActiveTime:
            handleMaxActiveRead(value)
        default:
            break
        }
    }

    private func parseDeviceAuthParam(_ v: [UInt8]) {
        guard v.count >= 68 else { return }
        deviceParamIndex = Int(v[0])
        deviceParamTime = Array(v[1 ..< 4])
        devicePubX = Array(v[4 ..< 36])
        devicePubY = Array(v[36 ..< 68])
    }

    private func handleAuthSign(_ value: [UInt8]) {
        let authFlagHex = OttaiCrypto.bytesToHex(value)
        if OttaiRegistry.isV3CredentialBootstrapPending(sensorId) && authKeys == nil {
            requestCgmAuthVerify(authDevHex: lastAuthDevHex, authFlagHex: authFlagHex)
            return
        }
        _ = verifyDeviceSign(value)
        writeAppParam()
    }

    @discardableResult
    private func verifyDeviceSign(_ deviceSign: [UInt8]) -> Bool {
        guard let keys = authKeys, deviceParamIndex >= 0, deviceParamIndex < keys.count else { return false }
        let ok = OttaiBleAuth.verifyDeviceSign(
            deviceSign: deviceSign,
            authKeyHex: OttaiCrypto.bytesToHex(keys[deviceParamIndex]),
            macHex: OttaiCrypto.bytesToHex(macBytes),
            devPubX: devicePubX, devPubY: devicePubY, devTime: deviceParamTime)
        // The result is not reliable in the original app, so we only log it. But when
        // the login then also fails, a failed verify points to a wrong physical sensor.
        lastVerifyFailed = !ok
        trace("device sign verify=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, ok.description)
        return ok
    }

    private func writeAppParam() {
        if let host = serverAuthHostBytes, !host.isEmpty {
            authStep = .writeAppParam
            writeChar(OttaiConstants.charAuthAppParam, host)
            return
        }
        guard let keys = authKeys, !keys.isEmpty else {
            trace("cannot write auth parameter without stored auth keys", log: log, category: ConstantsLog.categoryCGMOttai, type: .error)
            return
        }
        let kp = OttaiBleAuth.generateKeyPair()
        appKeyPair = kp
        appTime3 = OttaiBleAuth.appTime3(deviceTimeBytes)
        appIndex = Int.random(in: 0 ..< keys.count)
        let param = OttaiBleAuth.appAuthParameter(selectedIndex: appIndex, time3: appTime3, pubX: kp.pubX, pubY: kp.pubY)
        authStep = .writeAppParam
        writeChar(OttaiConstants.charAuthAppParam, param)
    }

    override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid.full128
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if let error = error {
                trace("write err %{public}@ %{public}@ authStep=%{public}@ actStep=%{public}@", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .error, characteristic.uuid.uuidString, error.localizedDescription, "\(self.authStep)", "\(self.actStep)")
                if self.actStep == .maxActive, uuid == OttaiConstants.charMaxActiveTime, self.retryMaxActiveTime() { return }
                if self.actStep != .none {
                    self.failActivation("aborted after \(self.actStep) write error")
                } else if self.authStep == .writeAppParam || self.authStep == .writeAppSign {
                    self.handleAuthWriteFailure()
                } else if uuid == OttaiConstants.charHistoryRequest, self.activeHistoryEndExclusive > 0 {
                    // The sensor said no to this window (for example the start is past its
                    // last record). Treat it as an empty answer, so the chain goes on.
                    self.cancelHistoryWatchdog()
                    self.historyRetryCount = 0
                    self.advanceHistoryChunkChain()
                }
                return
            }
            self.handleWriteAck(uuid: uuid)
        }
    }

    private func handleWriteAck(uuid: String) {
        if uuid == OttaiConstants.charHistoryRequest { return }
        if authStep == .writeAppParam, uuid == OttaiConstants.charAuthAppParam {
            if let serverFlag = serverAuthFlagBytes, !serverFlag.isEmpty {
                authStep = .writeAppSign
                writeChar(OttaiConstants.charAuthSign, serverFlag)
                return
            }
            guard let keys = authKeys, let kp = appKeyPair else { return }
            let sign = OttaiBleAuth.authSignHex(authKeyHex: OttaiCrypto.bytesToHex(keys[appIndex]),
                                                macHex: OttaiCrypto.bytesToHex(macBytes),
                                                pubX: kp.pubX, pubY: kp.pubY, time3: appTime3)
            authStep = .writeAppSign
            writeChar(OttaiConstants.charAuthSign, sign)
            return
        }
        if authStep == .writeAppSign, uuid == OttaiConstants.charAuthSign {
            if serverAuthFlagBytes != nil {
                serverAuthHostBytes = nil
                serverAuthFlagBytes = nil
                authStep = .done
                phase = .streaming
                sessionKeyHex = ""
                trace("server active-auth write-back complete; fetching credentials", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
                scheduleV3BindAfterActiveAuth()
                return
            }
            deriveSession()
            authStep = .done
            if sessionKeyHex.isEmpty {
                recoverAndReconnect("auth complete; session=FAILED — no session key derived")
                return
            }
            phase = .streaming
            reportSensorSessionIfNeeded()
            lastVerifyFailed = false
            wrongSensorStrikes = 0
            rejectedIdentifiersLock.lock()
            rejectedPeripheralIdentifiers.removeAll()
            rejectedIdentifiersLock.unlock()
            trace("auth complete; session ok", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
            OttaiRegistry.ensureSensorRecord(sensorId: sensorId, address: deviceAddress ?? "", displayName: OttaiConstants.defaultDisplayName)
            // The command byte tells the true state: 0..2 = activate, 3 = stream,
            // 4 or more = the sensor has ended.
            readChar(OttaiConstants.charCommand)
            return
        }
        if actStep != .none {
            if actStep == .maxActive, uuid == OttaiConstants.charMaxActiveTime { markMaxActiveAccepted() }
            advanceActivation()
        }
    }

    private func deriveSession() {
        guard let kp = appKeyPair else { return }
        sessionKeyHex = OttaiBleAuth.deriveSessionKey(devPubX: devicePubX, devPubY: devicePubY, ourPrivate: kp.privateKey) ?? ""
        trace("session key derived len=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, "\(sessionKeyHex.count)")
    }

    // MARK: - V3 cgmAuth/verify + bindV3

    private func requestCgmAuthVerify(authDevHex: String, authFlagHex: String) {
        if authFlagHex.allSatisfy({ $0 == "0" }) { return }
        let mac = OttaiCrypto.bytesToHex(macBytes)
        let gen = connectionGeneration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let material = OttaiCloudClient.cgmAuthVerify(mac: mac, authDevHex: authDevHex, authFlagHex: authFlagHex)
            self?.workQueue.async { [weak self] in
                guard let self = self, self.connectionGeneration == gen, self.phase == .auth else { return }
                if let m = material,
                   let host = try? OttaiCrypto.hexToBytesStrict(m.authHost),
                   let flag = try? OttaiCrypto.hexToBytesStrict(m.authFlag),
                   !host.isEmpty, !flag.isEmpty {
                    self.serverAuthHostBytes = host
                    self.serverAuthFlagBytes = flag
                    self.writeAppParam()
                } else {
                    self.recoverAndReconnect("V3 credential bootstrap failed: no server material")
                }
            }
        }
    }

    private func scheduleV3BindAfterActiveAuth() {
        let id = sensorId
        let fallbackVersion = materials.deviceVersion
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5) { [weak self] in
            let version = OttaiRegistry.loadLastValidatedDeviceVersion(sensorId: id) ?? fallbackVersion
            if version.isEmpty { return }
            guard let resp = OttaiCloudClient.bindV3(mac: id, deviceVersion: version), !resp.keyA.isEmpty,
                  let mats = OttaiCloudClient.toMaterials(mac: id, resp: resp), mats.authKeys != nil,
                  OttaiRegistry.saveMaterials(sensorId: id, mats) else {
                if let self = self {
                    trace("bindV3 not accepted: %{public}@", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .error, OttaiCloudClient.lastError)
                }
                return
            }
            self?.workQueue.async { [weak self] in
                guard let self = self else { return }
                self.materials = mats
                self.authKeys = mats.authKeys
                OttaiRegistry.setV3CredentialBootstrapPending(id, false)
                self.disconnect() // the next connection will use the normal login with keyA
            }
        }
    }

    // MARK: - command byte

    private func handleCommandStatus(_ status: Int) {
        let previous = commandStatus
        commandStatus = status
        trace("cmd/activation status=%{public}d (official: 3=activated, <3=needs activation)", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, status)
        if status < 0 { return }
        if OttaiConstants.commandNeedsActivation(status) {
            livePollTimer?.cancel(); livePollTimer = nil
            if OttaiConstants.shouldStartActivation(commandStatus: status, explicitlyRequested: activationRequested),
               actStep == .none, !pendingActivation {
                activationRequested = false
                trace("sensor command status=%{public}d and user requested activation; starting activation sequence", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, status)
                afterDelay(0.25) { [weak self] in self?.requestActivationWithRediscovery() }
            } else {
                trace("sensor needs activation status=%{public}d; awaiting explicit user action", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, status)
            }
            return
        }
        if status == 3 {
            // activationCommandSentAtMs is kept on purpose (same as the Kotlin): it is the
            // warmup anchor for a sensor we just started, until the real start is confirmed.
            if previous >= 4 { trace("ended-sensor recovery accepted; normal streaming restored", log: log, category: ConstantsLog.categoryCGMOttai, type: .info) }
            if previous != 3 { startStreamingAfterCommandStatus() }
            return
        }
        // 4 or more = the sensor has ended. We do not try to restart it. We read the
        // live buffer once, only to learn the last dataNo, and then fetch the history
        // up to it. No glucose is published from this read.
        livePollTimer?.cancel(); livePollTimer = nil
        trace("sensor ended cmd=%{public}d; no lifetime write will be attempted automatically", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, status)
        afterDelay(0.5) { [weak self] in
            guard let self = self, self.commandStatus >= 4 else { return }
            self.readLiveGlucose("ended-history-index")
        }
    }

    private func startStreamingAfterCommandStatus() {
        afterDelay(0.25) { [weak self] in self?.readChar(OttaiConstants.charCgmInfoNotify) }
        afterDelay(0.7) { [weak self] in
            self?.readLiveGlucose("command-status-3")
            self?.scheduleLivePoll()
        }
        // Read the real lifetime of a sensor we did not activate ourselves. Only once.
        if activatedMaxActiveMs <= 0 {
            afterDelay(1.2) { [weak self] in self?.readChar(OttaiConstants.charMaxActiveTime) }
        }
        // History backfill that does not wait for the first live reading.
        afterDelay(Self.initialHistoryDelay) { [weak self] in self?.runInitialHistoryBackfill() }
    }

    /// The first history backfill. Only runs if the live path did not do it already.
    private func runInitialHistoryBackfill() {
        guard phase == .streaming, !sessionKeyHex.isEmpty, commandStatus == 3 else { return }
        guard !initialHistoryRequested, !initialFlushDone else { return }
        let sensorAgeMs = warmupAnchorMs() > 0 ? nowMs() - warmupAnchorMs() : -1
        if sensorAgeMs >= 0 && sensorAgeMs < Self.initialHistoryMinSensorAgeMs {
            let wait = Double(Self.initialHistoryMinSensorAgeMs - sensorAgeMs) / 1000.0
            trace("initial history backfill deferred %{public}ds — sensor is %{public}ds old", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, Int(wait), Int(sensorAgeMs / 1000))
            afterDelay(wait) { [weak self] in self?.runInitialHistoryBackfill() }
            return
        }
        guard lastDataNo > 0 else {
            readLiveGlucose("initial-history-probe")
            return
        }
        initialHistoryRequested = true
        let start = max(0, lastDataNo - Self.initialBackfillRecords)
        _ = requestHistoryRange("initial", start: start, count: lastDataNo - start)
    }

    // MARK: - live and history packets

    private func handleGlucosePayload(_ cipher: [UInt8], live: Bool) {
        if sessionKeyHex.isEmpty { return }
        if live && commandStatus >= 4 {
            handleEndedLiveBuffer(cipher)
            return
        }
        let receivedAtMs = nowMs()
        let kind = live ? "live" : "history"
        guard let payload = OttaiCrypto.decryptPayload(cipher, sessionKeyHex: sessionKeyHex) else {
            trace("%{public}@ decrypt failed len=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, kind, cipher.count)
            return
        }
        let records = OttaiParser.frameRecords(payload, deviceVersion: materials.deviceVersion)
        if records.isEmpty {
            trace("%{public}@ no records payloadLen=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, kind, payload.count)
            if live {
                afterDelay(1.8) { [weak self] in _ = self?.requestRecentHistory("empty-live") }
            } else if activeHistoryEndExclusive > 0 {
                // An empty answer is still an answer. Do not let it stop the chain.
                cancelHistoryWatchdog()
                historyRetryCount = 0
                advanceHistoryChunkChain()
            }
            return
        }
        let activeMs = effectiveActiveTimeMs()
        let readings: [OttaiReading]
        if live {
            readings = [OttaiParser.toReading(records.last!, method: materials.method, coefficients: materials.coefficients, activeTimeMs: activeMs)]
        } else {
            readings = records.map { OttaiParser.toReading($0, method: materials.method, coefficients: materials.coefficients, activeTimeMs: activeMs) }
        }
        let previousDataNo = lastDataNo
        // A dataNo far past the sensor's real position means a broken packet.
        // Throw those records away before we change any state.
        let ceiling = dataNoCeiling(live: live)
        let plausible = ceiling == Int.max ? readings : readings.filter { $0.record.dataNo <= ceiling }
        if plausible.count < readings.count {
            trace("%{public}@ dropped %{public}d corrupt records dataNo>ceiling=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, kind, readings.count - plausible.count, ceiling)
        }
        noteCeilingOutcome(offered: readings.count, kept: plausible.count, ceiling: ceiling)
        if live && !plausible.isEmpty { lastLiveFrameAtMs = receivedAtMs }

        var emitted: [(dataNo: Int, glucose: GlucoseData)] = []
        for (index, r) in plausible.enumerated() {
            if !r.valid {
                trace("%{public}@ record rejected dataNo=%{public}d runtime=%{public}d raw=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, kind, r.record.dataNo, r.record.runtimeSec, r.record.rawCurrent)
                continue
            }
            if materials.method.isEmpty {
                trace("no method — skipping emit dataNo=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, r.record.dataNo)
                continue
            }
            if let e = emitReading(r, live: live, receivedAtMs: receivedAtMs, batch: plausible, batchIndex: index) {
                emitted.append(e)
            }
        }
        let newestDataNo = records.map { OttaiParser.parseRecord($0).dataNo }.max() ?? -1
        trace("%{public}@ decoded records=%{public}d newestDataNo=%{public}d emitted=%{public}d activeMs=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, kind, records.count, newestDataNo, emitted.count, "\(effectiveActiveTimeMs())")

        if !emitted.isEmpty { deliverOrBuffer(emitted) }

        if live {
            let liveDataNo = lastDataNo
            let previousForHistory = previousDataNoForHistory(previousDataNo, liveDataNo)
            if !initialFlushDone && !initialHistoryRequested && liveDataNo > 0 {
                initialHistoryRequested = true
                let start = max(0, liveDataNo - Self.initialBackfillRecords)
                _ = requestHistoryRange("room-backfill", start: start, count: liveDataNo - start)
            } else if previousForHistory < 0 || liveDataNo - previousForHistory - 1 > 0 {
                afterDelay(1.5) { [weak self] in self?.requestHistoryAfterLive(previousForHistory, liveDataNo) }
            }
        } else {
            if !continueHistoryAfterPayload(plausible) {
                // A long history burst can end a few minutes behind the clock. Read
                // live right after it, unless live is already fresh.
                if shouldReadLiveAfterHistory(receivedAtMs) {
                    afterDelay(1.0) { [weak self] in
                        guard let self = self, self.commandStatus < 4 else { return }
                        self.readLiveGlucose("post-history")
                        self.scheduleLivePoll()
                    }
                }
            }
        }
    }

    /// An ended sensor gives no live readings. We only take the last dataNo from
    /// the live buffer and fetch history up to it. No glucose is published.
    private func handleEndedLiveBuffer(_ cipher: [UInt8]) {
        guard let payload = OttaiCrypto.decryptPayload(cipher, sessionKeyHex: sessionKeyHex) else { return }
        let latest = OttaiParser.frameRecords(payload, deviceVersion: materials.deviceVersion)
            .map(OttaiParser.parseRecord).max { $0.dataNo < $1.dataNo }
        guard let latest = latest else {
            trace("ended live buffer has no records", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
            return
        }
        noteSeenDataNo(latest.dataNo)
        // Only a confirmed activation time may date this backfill. A guessed time
        // would give wrong dates.
        if streamStartTimeMs <= 0 && materials.activeTimeMs > 0 {
            _ = seedStreamTimeAnchor(latest.dataNo, materials.activeTimeMs + Int64(latest.runtimeSec) * 1000, "ended-live")
        }
        trace("ended live buffer indexed dataNo=%{public}d; glucose suppressed", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, latest.dataNo)
        afterDelay(4.5) { [weak self] in
            guard let self = self, self.commandStatus >= 4, self.phase == .streaming, !self.sessionKeyHex.isEmpty else { return }
            let end = self.lastDataNo + 1
            guard end > 0, !self.initialHistoryRequested else { return }
            self.initialHistoryRequested = true
            let start = max(0, end - Self.initialBackfillRecords)
            _ = self.requestHistoryRange("ended-backfill", start: start, count: end - start)
        }
    }

    // MARK: - one reading and all its checks (same order as the Kotlin)

    private func emitReading(_ r: OttaiReading, live: Bool, receivedAtMs: Int64, batch: [OttaiReading], batchIndex: Int) -> (dataNo: Int, glucose: GlucoseData)? {
        let mmol = Float(r.adjustGlucose)
        let mgdl = Double(mmol) * Self.mgdlPerMmoll
        if let reason = OttaiOutputFilter.hardRejectReason(record: r.record, mmol: mmol) {
            return rejectReading(r, mmol: mmol, live: live, reason: "hard-\(reason)")
        }
        if mgdl <= 1 { return rejectReading(r, mmol: mmol, live: live, reason: "mgdl=\(mgdl)") }
        if let reason = recentRejectedSampleReason(r, mmol: mmol) {
            return rejectReading(r, mmol: mmol, live: live, reason: reason)
        }
        repairAheadLastDataNoIfNeeded(acceptedDataNo: r.record.dataNo, live: live)
        let advancesDataNo = r.record.dataNo > lastDataNo
        let sampleMs = resolveSampleTimeMs(r, live: live, receivedAtMs: receivedAtMs)
        if sampleMs <= 0 {
            trace("no active-time anchor — skipping emit dataNo=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, r.record.dataNo)
            return nil
        }
        if OttaiConstants.isWithinWarmup(activationStartMs: warmupAnchorMs(), sampleMs: sampleMs) {
            return rejectReading(r, mmol: mmol, live: live, reason: "warmup")
        }
        if let reason = continuityRejectReason(r, mmol: mmol, sampleMs: sampleMs, live: live, batch: batch, batchIndex: batchIndex) {
            noteContinuityRejection(dataNo: r.record.dataNo, sampleMs: sampleMs)
            return rejectReading(r, mmol: mmol, live: live, reason: reason)
        }
        let previousGlucoseAtMs = lastGlucoseAtMs
        let freshLiveSample = live && isFreshLiveSample(receivedAtMs: receivedAtMs, sampleMs: sampleMs)
        let newest = sampleMs >= previousGlucoseAtMs
        if newest && (!live || freshLiveSample) {
            lastGlucoseAtMs = sampleMs
        }
        rememberAcceptedReading(r, mmol: mmol, sampleMs: sampleMs)
        if advancesDataNo { noteSeenDataNo(r.record.dataNo) }
        trace("BG dataNo=%{public}d mmol=%{public}.2f mgdl=%{public}.0f raw=%{public}d T=%{public}.1f", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, r.record.dataNo, Double(mmol), mgdl, r.record.rawCurrent, r.record.temperatureC)
        // Like the Kotlin: history is always kept. A live reading is kept only when
        // it is fresh and newer than the last one. An old record that comes from the
        // live characteristic is never shown as the current value.
        let shouldPersist = !live || (freshLiveSample && sampleMs > previousGlucoseAtMs)
        if !shouldPersist {
            trace("live sample not persisted (fresh=%{public}@ newer=%{public}@) dataNo=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, freshLiveSample.description, (sampleMs > previousGlucoseAtMs).description, r.record.dataNo)
            return nil
        }
        // xDrip only: the same reading also goes to the Syai cloud (if turned on)
        cloudUploader.enqueue(reading: r, mmol: Double(mmol), sampleMs: sampleMs, receivedAtMs: receivedAtMs, live: live)
        return (r.record.dataNo, GlucoseData(timeStamp: Date(timeIntervalSince1970: Double(sampleMs) / 1000.0), glucoseLevelRaw: mgdl))
    }

    private func rejectReading(_ r: OttaiReading, mmol: Float, live: Bool, reason: String) -> (dataNo: Int, glucose: GlucoseData)? {
        rememberRejectedReading(r, mmol: mmol)
        trace("%{public}@ BG rejected reason=%{public}@ dataNo=%{public}d mmol=%{public}.2f raw=%{public}d T=%{public}.1f", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, live ? "live" : "history", reason, r.record.dataNo, Double(mmol), r.record.rawCurrent, r.record.temperatureC)
        return nil
    }

    private func rememberRejectedReading(_ r: OttaiReading, mmol: Float) {
        let key = r.record.dataNo
        if recentlyRejectedSamples[key] == nil {
            recentlyRejectedOrder.append(key)
            if recentlyRejectedOrder.count > 64 {
                recentlyRejectedSamples.removeValue(forKey: recentlyRejectedOrder.removeFirst())
            }
        }
        recentlyRejectedSamples[key] = RejectedSample(rawCurrent: r.record.rawCurrent, mmol: mmol)
    }

    private func recentRejectedSampleReason(_ r: OttaiReading, mmol: Float) -> String? {
        guard let rejected = recentlyRejectedSamples[r.record.dataNo] else { return nil }
        let sameRaw = rejected.rawCurrent == r.record.rawCurrent
        let sameValue = abs(rejected.mmol - mmol) < 0.05
        return (sameRaw || sameValue) ? "recent-rejected raw=\(rejected.rawCurrent) mmol=\(rejected.mmol)" : nil
    }

    private func isFreshLiveSample(receivedAtMs: Int64, sampleMs: Int64) -> Bool {
        receivedAtMs > 0 && sampleMs > 0 &&
            abs(receivedAtMs - sampleMs) <= Self.currentSampleFreshMs + Self.currentSampleFloorGraceMs
    }

    private func shouldReadLiveAfterHistory(_ receivedAtMs: Int64) -> Bool {
        if lastLiveFrameAtMs <= 0 { return true }
        let since = receivedAtMs - lastLiveFrameAtMs
        return since < 0 || since >= Self.recordIntervalMs
    }

    // MARK: - dataNo bookkeeping

    private func noteSeenDataNo(_ dataNo: Int) {
        if dataNo <= lastDataNo { return }
        lastDataNo = dataNo
        OttaiRegistry.saveLastDataNo(sensorId, dataNo)
    }

    private func isPersistedDataNoAheadOfLive(_ previousDataNo: Int, _ liveDataNo: Int) -> Bool {
        previousDataNo >= 0 && liveDataNo >= 0 && previousDataNo > liveDataNo + Self.maxReasonableDataNoAhead
    }

    private func previousDataNoForHistory(_ previousDataNo: Int, _ liveDataNo: Int) -> Int {
        isPersistedDataNoAheadOfLive(previousDataNo, liveDataNo) ? -1 : previousDataNo
    }

    private func repairAheadLastDataNoIfNeeded(acceptedDataNo: Int, live: Bool) {
        guard live, isPersistedDataNoAheadOfLive(lastDataNo, acceptedDataNo) else { return }
        trace("reset ahead lastDataNo previous=%{public}d acceptedLive=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, lastDataNo, acceptedDataNo)
        lastDataNo = acceptedDataNo - 1
        OttaiRegistry.saveLastDataNo(sensorId, lastDataNo)
    }

    /// The highest dataNo we accept. Only a real activation time (from the cloud
    /// or confirmed by two anchors) may set this limit.
    private func dataNoCeiling(live: Bool) -> Int {
        if ceilingDistrusted { return Int.max }
        let start = materials.activeTimeMs
        let now = nowMs()
        if start > 0 && start < now {
            let elapsed = Int(min((now - start) / Self.recordIntervalMs, Int64(Int.max / 2)))
            return elapsed + Self.maxReasonableDataNoAhead
        }
        if live { return Int.max }
        return lastDataNo > 0 ? lastDataNo + Self.maxReasonableDataNoAhead : Int.max
    }

    private func noteCeilingOutcome(offered: Int, kept: Int, ceiling: Int) {
        if offered <= 0 || ceiling == Int.max { return }
        if kept > 0 { consecutiveCeilingFullDrops = 0; return }
        consecutiveCeilingFullDrops += 1
        if !ceilingDistrusted && consecutiveCeilingFullDrops >= Self.maxConsecutiveCeilingFullDrops {
            ceilingDistrusted = true
            trace("dataNo ceiling=%{public}d rejected %{public}d payloads in a row — distrusting it for this session", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, ceiling, consecutiveCeilingFullDrops)
        }
    }

    // MARK: - continuity check (spike filter)

    private func rememberAcceptedReading(_ r: OttaiReading, mmol: Float, sampleMs: Int64) {
        recentlyRejectedSamples.removeValue(forKey: r.record.dataNo)
        noteContinuityEvaluated(dataNo: r.record.dataNo, sampleMs: sampleMs)
        // The baseline only moves forward. An old history record must not replace
        // a newer baseline.
        if lastAcceptedDataNo >= 0 && r.record.dataNo < lastAcceptedDataNo { return }
        lastAcceptedDataNo = r.record.dataNo
        lastAcceptedSampleMs = sampleMs
        lastAcceptedMmol = mmol
        lastAcceptedRawCurrent = r.record.rawCurrent
        consecutiveContinuityRejects = 0
        OttaiRegistry.saveContinuityBaseline(sensorId, dataNo: r.record.dataNo, sampleMs: sampleMs, mmol: mmol, rawCurrent: r.record.rawCurrent)
    }

    private func noteContinuityRejection(dataNo: Int, sampleMs: Int64) {
        consecutiveContinuityRejects += 1
        noteContinuityEvaluated(dataNo: dataNo, sampleMs: sampleMs)
    }

    private func noteContinuityEvaluated(dataNo: Int, sampleMs: Int64) {
        if dataNo < lastEvaluatedDataNo { return }
        lastEvaluatedDataNo = dataNo
        lastEvaluatedSampleMs = sampleMs
    }

    private func isAdjacentSample(previousDataNo: Int, previousSampleMs: Int64, dataNo: Int, sampleMs: Int64) -> Bool {
        if previousDataNo < 0 { return false }
        if (1 ... 2).contains(dataNo - previousDataNo) { return true }
        if previousSampleMs <= 0 || sampleMs <= previousSampleMs { return false }
        return (1 ... (2 * Self.recordIntervalMs + 15_000)).contains(sampleMs - previousSampleMs)
    }

    private func isAdjacentToLastEvaluated(dataNo: Int, sampleMs: Int64) -> Bool {
        isAdjacentSample(previousDataNo: lastEvaluatedDataNo, previousSampleMs: lastEvaluatedSampleMs, dataNo: dataNo, sampleMs: sampleMs)
    }

    private func isImmediatelyBeforeLastAccepted(dataNo: Int, sampleMs: Int64) -> Bool {
        let nextDataNo = lastAcceptedDataNo
        if nextDataNo < 0 { return false }
        if (1 ... 2).contains(nextDataNo - dataNo) { return true }
        let nextMs = lastAcceptedSampleMs
        if nextMs <= 0 || sampleMs >= nextMs { return false }
        return (1 ... (2 * Self.recordIntervalMs + 15_000)).contains(nextMs - sampleMs)
    }

    private func continuityRejectReason(_ r: OttaiReading, mmol: Float, sampleMs: Int64, live: Bool, batch: [OttaiReading], batchIndex: Int) -> String? {
        // After a few rejections in a row, give up and take the next sample as the
        // new baseline (the sensor may really have jumped, e.g. an electrode restart).
        if consecutiveContinuityRejects >= Self.maxConsecutiveContinuityRejects {
            trace("continuity gate yielding after %{public}d consecutive rejections; re-baselining on dataNo=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, consecutiveContinuityRejects, r.record.dataNo)
            return nil
        }
        if isAdjacentToLastEvaluated(dataNo: r.record.dataNo, sampleMs: sampleMs),
           OttaiOutputFilter.isOneMinuteRawExcursion(candidateMmol: mmol, candidateRaw: r.record.rawCurrent, baselineMmol: lastAcceptedMmol, baselineRaw: lastAcceptedRawCurrent) {
            return "continuity-prev dataNo=\(lastAcceptedDataNo) mmol=\(lastAcceptedMmol) raw=\(lastAcceptedRawCurrent)"
        }
        if !live,
           isImmediatelyBeforeLastAccepted(dataNo: r.record.dataNo, sampleMs: sampleMs),
           OttaiOutputFilter.isOneMinuteRawExcursion(candidateMmol: mmol, candidateRaw: r.record.rawCurrent, baselineMmol: lastAcceptedMmol, baselineRaw: lastAcceptedRawCurrent) {
            return "continuity-next dataNo=\(lastAcceptedDataNo) mmol=\(lastAcceptedMmol) raw=\(lastAcceptedRawCurrent)"
        }
        if !live, let reason = historyIsolatedSpikeReason(batch, batchIndex, r, mmol) { return reason }
        return nil
    }

    private struct NeighborSample { let dataNo: Int; let mmol: Float; let rawCurrent: Int }

    private func historyIsolatedSpikeReason(_ batch: [OttaiReading], _ batchIndex: Int, _ candidate: OttaiReading, _ candidateMmol: Float) -> String? {
        let previous = neighborSample(batch, start: batchIndex - 1, step: -1)
        let next = neighborSample(batch, start: batchIndex + 1, step: 1)
        let previousAdjacent = previous.map { (1 ... 2).contains(candidate.record.dataNo - $0.dataNo) } ?? false
        let nextAdjacent = next.map { (1 ... 2).contains($0.dataNo - candidate.record.dataNo) } ?? false
        if previousAdjacent, nextAdjacent, let p = previous, let n = next {
            let neighborsAgree = abs(p.mmol - n.mmol) < OttaiOutputFilter.singleSampleDeltaMmol
            if neighborsAgree,
               OttaiOutputFilter.isOneMinuteRawExcursion(candidateMmol: candidateMmol, candidateRaw: candidate.record.rawCurrent, baselineMmol: p.mmol, baselineRaw: p.rawCurrent),
               OttaiOutputFilter.isOneMinuteRawExcursion(candidateMmol: candidateMmol, candidateRaw: candidate.record.rawCurrent, baselineMmol: n.mmol, baselineRaw: n.rawCurrent) {
                return "history-isolated prev=\(p.dataNo) next=\(n.dataNo)"
            }
        }
        if !previousAdjacent, nextAdjacent, candidate.record.dataNo <= 5, let n = next,
           OttaiOutputFilter.isOneMinuteRawExcursion(candidateMmol: candidateMmol, candidateRaw: candidate.record.rawCurrent, baselineMmol: n.mmol, baselineRaw: n.rawCurrent) {
            return "history-start next=\(n.dataNo)"
        }
        return nil
    }

    private func neighborSample(_ batch: [OttaiReading], start: Int, step: Int) -> NeighborSample? {
        var index = start
        while batch.indices.contains(index) {
            let reading = batch[index]
            if reading.valid {
                let mmol = Float(reading.adjustGlucose)
                if OttaiOutputFilter.hardRejectReason(record: reading.record, mmol: mmol) == nil {
                    return NeighborSample(dataNo: reading.record.dataNo, mmol: mmol, rawCurrent: reading.record.rawCurrent)
                }
            }
            index += step
        }
        return nil
    }

    // MARK: - sample times

    private func effectiveActiveTimeMs() -> Int64 {
        if materials.activeTimeMs > 0 { return materials.activeTimeMs }
        if streamStartTimeMs > 0 { return streamStartTimeMs }
        return provisionalActiveTimeMs > 0 ? provisionalActiveTimeMs : 0
    }

    /// The start time the warmup check may trust: the cloud time, or else the
    /// moment we sent the activation command. Never a guessed time.
    private func warmupAnchorMs() -> Int64 {
        materials.activeTimeMs > 0 ? materials.activeTimeMs : (activationCommandSentAtMs > 0 ? activationCommandSentAtMs : 0)
    }

    private func resolveSampleTimeMs(_ r: OttaiReading, live: Bool, receivedAtMs: Int64) -> Int64 {
        if streamStartTimeMs > 0 && (materials.activeTimeMs > 0 || !live) {
            return streamStartTimeMs + Int64(r.record.dataNo) * Self.recordIntervalMs
        }
        if live && receivedAtMs > 0 && r.record.dataNo >= 0 {
            let monitorMs = r.monitorTimeMs
            if monitorMs > 0 && abs(receivedAtMs - monitorMs) <= Self.currentSampleFreshMs {
                return seedStreamTimeAnchor(r.record.dataNo, monitorMs, "monitor-live", reliable: true)
            }
            if monitorMs > 0 {
                trace("ignore stale live monitor timestamp dataNo=%{public}d delta=%{public}ds", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, r.record.dataNo, Int(abs(receivedAtMs - monitorMs) / 1000))
            }
            return seedStreamTimeAnchor(r.record.dataNo, receivedAtMs, "live", reliable: true)
        }
        if r.monitorTimeMs > 0 {
            return seedStreamTimeAnchor(r.record.dataNo, r.monitorTimeMs, "monitor")
        }
        let activeMs = effectiveActiveTimeMs()
        if activeMs > 0 {
            return seedStreamTimeAnchor(r.record.dataNo, activeMs + Int64(r.record.runtimeSec) * 1000, "active")
        }
        return r.monitorTimeMs
    }

    private func seedStreamTimeAnchor(_ dataNo: Int, _ sampleHintMs: Int64, _ reason: String, reliable: Bool = false) -> Int64 {
        if dataNo < 0 || sampleHintMs <= 0 { return sampleHintMs }
        let sampleMs = (sampleHintMs / Self.recordIntervalMs) * Self.recordIntervalMs
        let start = sampleMs - Int64(dataNo) * Self.recordIntervalMs
        if start > 0 {
            let old = streamStartTimeMs
            // A time from the real clock is never replaced by a guessed time.
            if old > 0 && streamStartReliable && !reliable {
                return old + Int64(dataNo) * Self.recordIntervalMs
            }
            streamStartTimeMs = start
            streamStartReliable = reliable
            if old == 0 || abs(old - start) > Self.recordIntervalMs {
                trace("stream time anchor dataNo=%{public}d start=%{public}@ source=%{public}@ reliable=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, dataNo, "\(start / 1000)", reason, reliable.description)
            }
            if reliable { offerConfirmedActiveTime(start) }
        }
        return sampleMs
    }

    /// Two start times, found on their own, must agree before we save the
    /// activation time. A broken dataNo gives a time far away; a real pair is
    /// within a minute or two.
    private func offerConfirmedActiveTime(_ startMs: Int64) {
        if startMs <= 0 || materials.activeTimeMs > 0 { return }
        let now = nowMs()
        if startMs > now || now - startMs > OttaiConstants.extendedLifetimeMs {
            trace("implausible activation start=%{public}@ ignored", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, "\(startMs / 1000)")
            return
        }
        let pending = pendingConfirmedStartMs
        if pending <= 0 {
            pendingConfirmedStartMs = startMs
            trace("activation start candidate=%{public}@ awaiting corroboration", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, "\(startMs / 1000)")
            return
        }
        if abs(pending - startMs) <= Self.confirmedStartAgreementMs {
            materials.activeTimeMs = startMs
            provisionalActiveTimeMs = 0
            OttaiRegistry.saveActiveTimeMs(sensorId, startMs)
            OttaiRegistry.saveProvisionalActiveTime(sensorId, 0)
            trace("confirmed activeTime=%{public}@ persisted from live anchor", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, "\(startMs / 1000)")
            reportSensorSessionIfNeeded()
            return
        }
        trace("activation start candidates disagree: %{public}@ vs %{public}@; re-arming corroboration", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, "\(pending / 1000)", "\(startMs / 1000)")
        pendingConfirmedStartMs = startMs
    }

    private func setProvisionalActiveTime(_ activeTimeMs: Int64, _ reason: String) {
        if activeTimeMs <= 0 || materials.activeTimeMs > 0 { return }
        // The guessed time may only move to an earlier moment.
        if provisionalActiveTimeMs > 0 && activeTimeMs >= provisionalActiveTimeMs { return }
        provisionalActiveTimeMs = activeTimeMs
        OttaiRegistry.saveProvisionalActiveTime(sensorId, activeTimeMs)
        trace("provisional activeTime set source=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason)
    }

    private func sensorAgeTimeInterval() -> TimeInterval? {
        let start = effectiveActiveTimeMs()
        if start <= 0 { return nil }
        return TimeInterval(Double(nowMs() - start) / 1000.0)
    }

    /// xDrip only: tell xDrip when this sensor started, so the home screen shows the
    /// warm-up countdown and the sensor age. Without this, the session is only created
    /// when the first reading is processed — and during the warm-up no reading is
    /// processed, so the screen said "waiting for data" with no countdown.
    /// Reports each start once. Does nothing when xDrip already has a session within
    /// 10 minutes of ours (a report stops and starts the xDrip sensor session).
    private func reportSensorSessionIfNeeded() {
        let startMs = effectiveActiveTimeMs()
        guard startMs > 0, startMs != lastReportedSensorStartMs else { return }
        lastReportedSensorStartMs = startMs
        if let existing = UserDefaults.standard.activeSensorStartDate,
           abs(existing.timeIntervalSince1970 - Double(startMs) / 1000.0) < 10 * 60 {
            return
        }
        trace("reporting sensor session start=%{public}@ to xDrip", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, "\(startMs / 1000)")
        DispatchQueue.main.async { [weak self] in
            self?.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: Date(timeIntervalSince1970: Double(startMs) / 1000.0))
        }
    }

    // MARK: - giving readings to xDrip (see the file header)

    private func deliverOrBuffer(_ emitted: [(dataNo: Int, glucose: GlucoseData)]) {
        if !initialFlushDone {
            for p in emitted { initialBuffer[p.dataNo] = p.glucose }
            flushGeneration += 1
            let gen = flushGeneration
            workQueue.asyncAfter(deadline: .now() + 5.0) { [weak self] in self?.flushInitialBufferIfIdle(gen) }
        } else {
            deliver(emitted.map { $0.glucose }.sorted { $0.timeStamp > $1.timeStamp })
        }
    }

    private func flushInitialBufferIfIdle(_ generation: Int) {
        guard !initialFlushDone, flushGeneration == generation else { return }
        initialFlushDone = true
        let arr = Array(initialBuffer.values).sorted { $0.timeStamp > $1.timeStamp }
        initialBuffer.removeAll()
        guard !arr.isEmpty else { return }
        trace("flushing initial backfill count=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, arr.count)
        deliver(arr)
    }

    private func deliver(_ readings: [GlucoseData]) {
        guard !readings.isEmpty else { return }
        let sensorAge = sensorAgeTimeInterval()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var arr = readings
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &arr, transmitterBatteryInfo: nil, sensorAge: sensorAge)
        }
    }

    // MARK: - cgm-info packets

    private func handleCgmInfo(_ value: [UInt8]) {
        let head = value.prefix(2).map { String(format: "%02x", $0) }.joined()
        trace("cgm-info len=%{public}d head=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, value.count, head)
        // Note: the 0x0477 packet is NOT glucose. Nothing is published from cgm-info.
        guard value.count >= 4, value[0] == 0x07, value[1] == 0x77 else { return }
        let seconds = Int(value[2]) | (Int(value[3]) << 8)
        guard seconds >= 5, seconds <= 3600 else { return }
        let next = min(Int64(seconds) * 1000, Self.maxLivePollIntervalMs)
        if next == livePollIntervalMs { return }
        livePollIntervalMs = next
        trace("live poll interval=%{public}ds from cgm-info raw=%{public}ds", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, Int(next / 1000), seconds)
        if phase == .streaming, !sessionKeyHex.isEmpty { scheduleLivePoll() }
    }

    private func handleMaxActiveRead(_ value: [UInt8]) {
        let plain = OttaiCrypto.decryptPayload(value, sessionKeyHex: sessionKeyHex) ?? value
        guard plain.count >= 4 else { return }
        let n = plain.count >= 8 ? 8 : 4
        var secs: Int64 = 0
        for i in 0 ..< n { secs |= Int64(plain[i]) << (i * 8) }
        if secs < 10 * 86_400 || secs > 45 * 86_400 { return }
        adoptActivatedMaxActive(secs * 1000, "sensor-readback")
    }

    // MARK: - live poll

    private func scheduleLivePoll() {
        livePollTimer?.cancel()
        guard phase == .streaming, !sessionKeyHex.isEmpty else { return }
        let delayMs = min(max(livePollIntervalMs, 5_000), 3_600_000)
        let timer = DispatchSource.makeTimerSource(queue: workQueue)
        timer.schedule(deadline: .now() + .milliseconds(Int(delayMs)))
        timer.setEventHandler { [weak self] in self?.livePollFired() }
        timer.resume()
        livePollTimer = timer
    }

    private func livePollFired() {
        guard phase == .streaming, !sessionKeyHex.isEmpty, commandStatus < 4 else { return }
        // Wait while notifications keep coming on time.
        let sinceNotifyMs = nowMs() - lastLiveNotifyAtMs
        if lastLiveNotifyAtMs > 0 && sinceNotifyMs < livePollIntervalMs {
            scheduleLivePoll()
            return
        }
        readLiveGlucose("poll")
        scheduleLivePoll()
    }

    // MARK: - history requests, block chain and watchdog

    @discardableResult
    private func requestRecentHistory(_ reason: String) -> Bool {
        let endExclusive = lastDataNo
        guard endExclusive > 0 else { return false }
        let start = max(0, endExclusive - Self.recentHistoryRecords)
        return requestHistoryRange(reason, start: start, count: endExclusive - start)
    }

    private func requestHistoryAfterLive(_ previousDataNo: Int, _ liveDataNo: Int) {
        guard liveDataNo > 0 else { return }
        let missingBeforeLive = liveDataNo - previousDataNo - 1
        if previousDataNo >= 0 && missingBeforeLive <= 0 { return }
        let count = previousDataNo < 0 ? liveDataNo : missingBeforeLive
        guard count > 0, count <= 0xFFFF else { return }
        let start = previousDataNo < 0 ? 0 : previousDataNo + 1
        _ = requestHistoryRange("post-live", start: start, count: count)
    }

    @discardableResult
    private func requestHistoryRange(_ reason: String, start: Int, count: Int) -> Bool {
        if start < 0 || count <= 0 || count > 0xFFFF { return false }
        let bypassCooldown = reason == "manual" || reason == "room-backfill" || reason == "initial" || reason == "ended-backfill"
        if !bypassCooldown && nowMs() - lastHistoryRequestAtMs < Self.historyRequestCooldownMs { return false }
        clearPendingHistoryRange()
        let requestCount = min(count, Self.historyRequestChunkRecords)
        let issued = issueHistoryRequest(reason, start: start, count: requestCount)
        if issued && requestCount < count {
            pendingHistoryReason = reason
            pendingHistoryNextStart = start + requestCount
            pendingHistoryEndExclusive = start + count
            trace("history chunked reason=%{public}@ start=%{public}d count=%{public}d first=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason, start, count, requestCount)
        }
        return issued
    }

    private func issueHistoryRequest(_ reason: String, start: Int, count: Int) -> Bool {
        guard phase == .streaming, !sessionKeyHex.isEmpty, start >= 0, count > 0 else { return false }
        let payload = shortLE(start) + shortLE(count)
        guard writeChar(OttaiConstants.charHistoryRequest, payload) else { return false }
        lastHistoryRequestAtMs = nowMs()
        if start != activeHistoryStart || start + count != activeHistoryEndExclusive { historyChunkBestDataNo = -1 }
        activeHistoryStart = start
        activeHistoryEndExclusive = start + count
        armHistoryWatchdog()
        trace("request history reason=%{public}@ start=%{public}d count=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason, start, count)
        return true
    }

    private func requestPendingHistoryChunk() {
        guard let reason = pendingHistoryReason else { return }
        let start = pendingHistoryNextStart
        let endExclusive = pendingHistoryEndExclusive
        let remaining = endExclusive - start
        if remaining <= 0 { clearPendingHistoryRange(); return }
        let count = min(remaining, Self.historyRequestChunkRecords)
        guard issueHistoryRequest("\(reason)-chunk", start: start, count: count) else {
            clearPendingHistoryRange()
            return
        }
        pendingHistoryNextStart = start + count
        if pendingHistoryNextStart >= endExclusive {
            pendingHistoryReason = nil
            pendingHistoryNextStart = 0
            pendingHistoryEndExclusive = 0
        }
    }

    /// Returns true while the chain is still running.
    private func continueHistoryAfterPayload(_ readings: [OttaiReading]) -> Bool {
        let activeEnd = activeHistoryEndExclusive
        if activeEnd <= 0 { return pendingHistoryReason != nil }
        guard let maxDataNo = readings.map({ $0.record.dataNo }).max() else { return false }
        if maxDataNo > historyChunkBestDataNo { historyRetryCount = 0; historyChunkBestDataNo = maxDataNo }
        if maxDataNo + 1 < activeEnd {
            armHistoryWatchdog() // only part of the block came
            return true
        }
        cancelHistoryWatchdog()
        activeHistoryEndExclusive = -1
        activeHistoryStart = -1
        if pendingHistoryReason == nil { return false }
        scheduleNextChunk()
        trace("history chunk complete through=%{public}d next=%{public}d end=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, maxDataNo, pendingHistoryNextStart, pendingHistoryEndExclusive)
        return true
    }

    private func advanceHistoryChunkChain() {
        activeHistoryEndExclusive = -1
        activeHistoryStart = -1
        if pendingHistoryReason == nil { return }
        scheduleNextChunk()
    }

    private func scheduleNextChunk() {
        historyChunkWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.requestPendingHistoryChunk() }
        historyChunkWork = work
        workQueue.asyncAfter(deadline: .now() + Self.historyChunkDelay, execute: work)
    }

    private func armHistoryWatchdog() {
        historyWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.checkHistoryWatchdog() }
        historyWatchdog = work
        workQueue.asyncAfter(deadline: .now() + Self.historyPageTimeout, execute: work)
    }

    private func cancelHistoryWatchdog() {
        historyWatchdog?.cancel()
        historyWatchdog = nil
    }

    private func checkHistoryWatchdog() {
        guard phase == .streaming, !sessionKeyHex.isEmpty else { return }
        let end = activeHistoryEndExclusive
        let start = activeHistoryStart
        if end <= 0 { return }
        if start < 0 || end <= start { historyRetryCount = 0; advanceHistoryChunkChain(); return }
        if historyRetryCount < Self.historyMaxRetries {
            historyRetryCount += 1
            trace("history page watchdog: no progress for chunk [%{public}d,%{public}d) — retry %{public}d/%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, start, end, historyRetryCount, Self.historyMaxRetries)
            if !issueHistoryRequest("watchdog-retry", start: start, count: end - start) { advanceHistoryChunkChain() }
        } else {
            trace("history page watchdog: chunk [%{public}d,%{public}d) failed after retries — skipping", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, start, end)
            historyRetryCount = 0
            advanceHistoryChunkChain()
        }
    }

    private func clearPendingHistoryRange() {
        historyChunkWork?.cancel(); historyChunkWork = nil
        cancelHistoryWatchdog()
        historyRetryCount = 0
        historyChunkBestDataNo = -1
        pendingHistoryReason = nil
        pendingHistoryNextStart = 0
        pendingHistoryEndExclusive = 0
        activeHistoryEndExclusive = -1
        activeHistoryStart = -1
    }

    // MARK: - activation (cannot be undone)

    /// Android looks up the services again before the activation writes. The
    /// handles found before login gave "invalid handle" for b8fd9848 / 6aa799b6.
    /// We do the same and start the writes when all services are back.
    private func requestActivationWithRediscovery() {
        guard let peripheral = connectedPeripheral else {
            trace("activation refused — no connected peripheral", log: log, category: ConstantsLog.categoryCGMOttai, type: .error)
            return
        }
        pendingActivation = true
        rediscoveredServices.removeAll()
        expectedRediscoveryCount = 0
        trace("re-discovering services before activation", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
        // All services, like Android's gatt.discoverServices(); this also brings in the
        // destruction service (84c5b711), which the normal connection does not look up.
        peripheral.discoverServices(nil)
        afterDelay(10.0) { [weak self] in
            guard let self = self, self.pendingActivation else { return }
            // Same as Android: a discovery that does not finish means the link is bad.
            // Reconnect and try again after the next login (activationRequested stays set).
            self.pendingActivation = false
            self.activationRequested = true
            self.recoverAndReconnect("service discovery callback timeout")
        }
    }

    private func startActivationWrites() {
        if maxActiveCandidatesMs.isEmpty {
            let cloudExpireMs = materials.activeExpireTimeMs > 0 ? materials.activeExpireTimeMs : OttaiConstants.defaultActiveExpireMs
            maxActiveCandidatesMs = OttaiConstants.activationMaxActiveCandidatesMs(cloudActiveExpireMs: cloudExpireMs)
            maxActiveCandidateIndex = 0
        }
        trace("starting activation sequence attempt=%{public}d/%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, maxActiveCandidateIndex + 1, maxActiveCandidatesMs.count)
        actStep = .rtc
        writeRtc()
    }

    private func advanceActivation() {
        switch actStep {
        case .rtc: actStep = .maxActive; writeMaxActiveTime()
        case .maxActive: actStep = .destruction; writeDestructionTime()
        case .destruction: actStep = .command; writeActivateCmd()
        case .command: actStep = .done; markActivationCommandSent()
        default: break
        }
    }

    private func writeRtc() {
        let secs = Int32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970))
        if !writeChar(OttaiConstants.charCurrentTime, OttaiBleAuth.intToBytesLE(secs)) {
            failActivation("RTC characteristic is unavailable")
        }
    }

    private func writeMaxActiveTime() {
        let cloudExpireMs = materials.activeExpireTimeMs > 0 ? materials.activeExpireTimeMs : OttaiConstants.defaultActiveExpireMs
        let expireMs = maxActiveCandidatesMs.indices.contains(maxActiveCandidateIndex) ? maxActiveCandidatesMs[maxActiveCandidateIndex] : cloudExpireMs
        maxActiveAttemptMs = expireMs
        trace("maxActive attempt=%{public}d/%{public}d target=%{public}ds", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, maxActiveCandidateIndex + 1, maxActiveCandidatesMs.count, Int(expireMs / 1000))
        guard let payload = OttaiCrypto.encryptPayload(longToBytesLE(expireMs / 1000), sessionKeyHex: sessionKeyHex) else {
            failActivation("maxActive encryption failed"); return
        }
        if !writeChar(OttaiConstants.charMaxActiveTime, payload) {
            trace("maxActive char absent — skipping to destruction", log: log, category: ConstantsLog.categoryCGMOttai, type: .error)
            advanceActivation()
        }
    }

    /// The sensor said no to this lifetime. Try the next shorter one on a new connection.
    private func retryMaxActiveTime() -> Bool {
        let nextIndex = maxActiveCandidateIndex + 1
        guard maxActiveCandidatesMs.indices.contains(nextIndex) else { return false }
        trace("maxActive rejected duration=%{public}ds; will reconnect and retry %{public}ds", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, Int(maxActiveAttemptMs / 1000), Int(maxActiveCandidatesMs[nextIndex] / 1000))
        maxActiveCandidateIndex = nextIndex
        maxActiveAttemptMs = 0
        actStep = .none
        activationRequested = true
        afterDelay(0.2) { [weak self] in self?.disconnect() }
        return true
    }

    private func markMaxActiveAccepted() {
        guard maxActiveAttemptMs > 0 else { return }
        // Save it now. The sensor accepted the value, even if the activate command fails later.
        adoptActivatedMaxActive(maxActiveAttemptMs, "activation-accept")
    }

    private func writeDestructionTime() {
        // retainTime is a short DURATION, not a date. Writing a date made the sensor drop the link.
        let retainMs = materials.retainTimeMs > 0 ? materials.retainTimeMs : OttaiConstants.defaultRetainTimeMs
        let payload = longToBytesLE(retainMs / 1000) + [0x04]
        if !writeChar(OttaiConstants.charDestructive, payload) {
            failActivation("destruction characteristic is unavailable")
        }
    }

    private func writeActivateCmd() {
        guard let cmd = OttaiCrypto.encryptActivateCmd([OttaiConstants.activateCmd], sessionKeyHex: sessionKeyHex) else {
            failActivation("activation command encryption failed"); return
        }
        if !writeChar(OttaiConstants.charCommand, cmd) {
            failActivation("activation command characteristic is unavailable")
        }
    }

    private func markActivationCommandSent() {
        activationCommandSentAtMs = nowMs()
        maxActiveCandidatesMs = []
        maxActiveCandidateIndex = 0
        OttaiRegistry.setActivationAttempted(sensorId, true)
        if materials.activeTimeMs <= 0 { setProvisionalActiveTime(activationCommandSentAtMs, "activation-command") }
        reportSensorSessionIfNeeded()
        trace("activation command sent; sensor accepted activation writes", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
        // Check that the activation worked. Send nothing else in the meantime (only one
        // Bluetooth operation at a time).
        activationConfirmAttempt = 0
        afterDelay(Self.postActivationConfirmDelay) { [weak self] in self?.activationConfirmTick() }
    }

    private func activationConfirmTick() {
        if commandStatus == 3 { return }
        if activationConfirmAttempt >= Self.postActivationConfirmMaxAttempts {
            trace("activation confirmation read never landed after %{public}d attempts; awaiting the next poll or reconnect", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, activationConfirmAttempt)
            return
        }
        activationConfirmAttempt += 1
        readChar(OttaiConstants.charCommand)
        afterDelay(Self.postActivationConfirmRetry) { [weak self] in self?.activationConfirmTick() }
    }

    private func adoptActivatedMaxActive(_ ms: Int64, _ source: String) {
        if ms <= 0 || ms == activatedMaxActiveMs { return }
        activatedMaxActiveMs = ms
        OttaiRegistry.saveAcceptedMaxActive(sensorId, ms)
        trace("activated lifetime = %{public}dd source=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, Int(ms / 86_400_000), source)
    }

    private func failActivation(_ reason: String) {
        trace("activation failed: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, reason)
        actStep = .none
        pendingActivation = false
        maxActiveCandidatesMs = []
        maxActiveCandidateIndex = 0
    }

    // MARK: - Bluetooth helpers

    private func readLiveGlucose(_ reason: String) {
        guard !sessionKeyHex.isEmpty else { return }
        trace("read live glucose reason=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason)
        liveReadInFlight = true
        readChar(OttaiConstants.charGlucoseLive)
    }

    private func readChar(_ characteristic: String) {
        guard let ch = char(characteristic) else {
            trace("read skipped: characteristic %{public}@ not discovered", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, String(characteristic.prefix(8)))
            return
        }
        readValueForCharacteristic(for: ch)
    }

    @discardableResult
    private func writeChar(_ characteristic: String, _ value: [UInt8]) -> Bool {
        guard let ch = char(characteristic) else {
            trace("write skipped: characteristic %{public}@ not discovered", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, String(characteristic.prefix(8)))
            return false
        }
        return writeDataToPeripheral(data: Data(value), characteristicToWriteTo: ch, type: .withResponse)
    }

    override func prepareForRelease() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            self.livePollTimer?.cancel()
            self.livePollTimer = nil
            self.clearPendingHistoryRange()
        }
        super.prepareForRelease()
    }

    // MARK: - small helpers

    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private func shortLE(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func longToBytesLE(_ v: Int64) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 8)
        for i in 0 ..< 8 { out[i] = UInt8((v >> (i * 8)) & 0xFF) }
        return out
    }
}

private extension CBUUID {
    /// The full 128-bit UUID as lower-case text, so short (16-bit) and long forms compare equal.
    var full128: String {
        let s = uuidString.lowercased()
        switch s.count {
        case 4: return "0000\(s)-0000-1000-8000-00805f9b34fb"
        case 8: return "\(s)-0000-1000-8000-00805f9b34fb"
        default: return s
        }
    }
}
