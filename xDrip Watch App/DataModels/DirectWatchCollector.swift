//
//  DirectWatchCollector.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 12/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine
import UserNotifications
import WatchConnectivity
import WatchKit

/// Collects native readings on the Watch and retains them until the phone acknowledges them.
/// CoreBluetooth callbacks and collector state are handled on the main queue.
final class DirectWatchCollector: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, DexcomG7AuthSessionTransport {
    @Published private(set) var status = TextsDirectWatch.collectionOff
    @Published private(set) var readings: [DirectWatchReading] = []
    @Published private(set) var collectionSessions: [DirectWatchCollectionSession] = []
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastConnectedAt: Date?
    @Published private(set) var phoneBLECollectionPaused = false
    @Published private(set) var collectionControl: DirectWatchCollectionControl?
    // A local Watch choice, independent of phone configuration and collection pause/resume.
    // A missing key defaults to false, including upgrades from the automatic alert.
    @Published private(set) var missedReadingNotificationsEnabled = UserDefaults.standard.bool(forKey: ConstantsDirectWatch.missedReadingNotificationsKey)
    @Published private(set) var urgentLowNotificationsEnabled = UserDefaults.standard.bool(forKey: ConstantsDirectWatch.urgentLowNotificationsKey)
    @Published private(set) var lowNotificationsEnabled = UserDefaults.standard.bool(forKey: ConstantsDirectWatch.lowNotificationsKey)
    private var lastPhoneContactAt = UserDefaults.standard.object(forKey: ConstantsDirectWatch.lastPhoneContactKey) as? Date
    private var lastPublishedControlID: String?

    var isPaused: Bool {
        isConfigured && collectionControl?.connection == connectionIdentity && collectionControl?.isPaused == true
    }
    var collectionResumedAt: Date? { collectionControl?.resumedAt(for: connectionIdentity) }
    // Configured means a binding exists. Enabled additionally requires an available sensor
    // configuration and an unpaused local choice. Keep those states separate during suspension.
    private var collectionIsEnabled: Bool { isConfigured && configuration != nil && !isPaused }

    var latestReadingAt: Date? {
        guard let configuration else { return nil }
        return readings.first { $0.belongs(to: configuration) }?.measuredAt
    }

    @Published private(set) var isConfigured = false
    private(set) var configuration: DirectWatchConfiguration?
    private var connectionIdentity: DirectWatchConnectionIdentity?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var auth: CBCharacteristic?
    private var control: CBCharacteristic?
    private var authStream: CBCharacteristic?
    private var g7AuthSession: DexcomG7AuthSession?
    private var g7Authenticated = false
    private var g7GlucoseRequested = false
    private var g7AuthenticationBlocked = false
    private var authSent = false
    private var challengeSent = false
    private var clock: (seconds: UInt32, start: UInt32, epoch: Date)?
    private var timeout: Timer?
    private var connectionTimeout: Timer?
    private var connectionRequestedAt: Date?
    private var lastCycleCompletedAt: Date?
    private var failedConnectionAttempts = 0
    private var connectionIsActive = false
    private var cycleCompletedThisConnection = false
    private var delayOptionUnavailable = false
    private var lastRequestUsedDelayOption = false
    private var connectionRequestBlocked = false
    private var recoveryCallbackTimeout: Timer?
    private var pendingRecovery: DirectWatchCollectionPolicy.PendingRecovery?
    private var savedPeripheralRetryCount = 0
    private var discoveryFallbackStartedAt: Date?
    private var discoveryFallbackTimeout: Timer?
    private var isForeground = false
    private var liveSyncID: UUID?
    private var liveSyncStartedAt: Date?
    private var liveSyncTimeout: Timer?
    private var lastQueuedBatchData: Data?
    private var lastQueuedBatchAt = Date.distantPast
    private var lastSync = Date.distantPast
    // Separate timers let an Urgent Low alert follow a Low alert immediately.
    private var lastUrgentLowAlert = UserDefaults.standard.object(forKey: ConstantsDirectWatch.lastUrgentLowAlertKey) as? Date
    private var lastLowAlert = UserDefaults.standard.object(forKey: ConstantsDirectWatch.lastLowAlertKey) as? Date
    private var journal: [String] = []
    private var pendingIDs: Set<String> = []
    private var configurationRevision: Double = 0
    private var storageFailed = false
    private var requestedNotifications = false

    private let service = CBUUID(string: "F8083532-849E-531C-C594-30F1F86A4EA5")
    private let advertisement = CBUUID(string: "FEBC")
    private let authUUID = CBUUID(string: "F8083535-849E-531C-C594-30F1F86A4EA5")
    private let controlUUID = CBUUID(string: "F8083534-849E-531C-C594-30F1F86A4EA5")
    private let authStreamUUID = CBUUID(string: "F8083538-849E-531C-C594-30F1F86A4EA5")
    private let storeURL = DirectWatchCompatibility.collectorStoreURL(in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
    private let logURL = DirectWatchCompatibility.logURL(in: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])

    // Bluetooth objects are transient. Persist only their identifier and recovery clocks so
    // watchOS restoration can reuse the same pending connection after an app update.
    private struct Store: Codable {
        var collectionControl: DirectWatchCollectionControl?
        var collectionSessions: [DirectWatchCollectionSession]?
        var configuration: DirectWatchConfiguration?
        var revision: Double
        var readings: [DirectWatchReading]
        var pendingIDs: Set<String>
        var peripheralID: UUID?
        var connectionRequestedAt: Date?
        var lastConnectedAt: Date?
        var lastCycleCompletedAt: Date?
        var delayOptionUnavailable: Bool?
        var connectionIdentity: DirectWatchConnectionIdentity?
        var isConfigured: Bool?
    }
    private var peripheralID: UUID?

    // MARK: - Initialization and stored data

    override init() {
        super.init()
        if let data = try? Data(contentsOf: storeURL) {
            do {
                let store = try JSONDecoder().decode(Store.self, from: data)
                restore(store)
            } catch {
                storageFailed = true
                status = TextsDirectWatch.storageReadFailed
            }
        }
        if let text = try? String(contentsOf: logURL, encoding: .utf8) { journal = text.components(separatedBy: "\n").filter { !$0.isEmpty } }
        configureG7Authentication()
        if configuration == nil && isConfigured { status = TextsDirectWatch.suspendedCheckPhone }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        log("Direct to Watch collector 11 launched, app build=\(build), pending=\(pendingCount), savedPeripheral=\(peripheralID != nil), delayOptionUnavailable=\(delayOptionUnavailable), recovery=backgroundWakeSavedRetry, background BLE remains subject to watchOS limits")
        if isPaused {
            status = TextsDirectWatch.paused
            // Restore only to cancel any OS-held connection left across a process restart.
            central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: DirectWatchCompatibility.centralRestorationIdentifier])
        }
        if collectionIsEnabled && !storageFailed {
            updateCollectionSessions()
            if save() { start() }
        }
        // Old automatic high and sensor alerts are no longer part of the Watch alert settings.
        clearNotifications(collectionIsEnabled && !storageFailed
                           ? ConstantsDirectWatch.glucoseNotificationIDs + ConstantsDirectWatch.sensorNotificationIDs
                           : ConstantsDirectWatch.notificationIDs)
        // Replace any legacy eleven-minute request, or cancel it for the default-off setting.
        updateMissedReadingNotification()
    }

    // A single snapshot defines both the on-disk format and rollback after a failed save.
    // Keep old optional fields decodable: phone and Watch updates need not happen together.
    private var storedState: Store {
        Store(collectionControl: collectionControl, collectionSessions: collectionSessions,
              configuration: configuration, revision: configurationRevision,
              readings: readings, pendingIDs: pendingIDs, peripheralID: peripheralID,
              connectionRequestedAt: connectionRequestedAt, lastConnectedAt: lastConnectedAt,
              lastCycleCompletedAt: lastCycleCompletedAt, delayOptionUnavailable: delayOptionUnavailable,
              connectionIdentity: connectionIdentity, isConfigured: isConfigured)
    }

    private func restore(_ store: Store) {
        collectionControl = store.collectionControl
        collectionSessions = store.collectionSessions ?? []
        configuration = store.configuration
        configurationRevision = store.revision
        readings = store.readings
        pendingIDs = store.pendingIDs
        peripheralID = store.peripheralID
        connectionRequestedAt = store.connectionRequestedAt
        lastConnectedAt = store.lastConnectedAt
        lastCycleCompletedAt = store.lastCycleCompletedAt
        delayOptionUnavailable = store.delayOptionUnavailable ?? false
        connectionIdentity = store.connectionIdentity ?? store.configuration?.connectionIdentity
        isConfigured = store.isConfigured ?? (store.configuration != nil)
        pendingCount = pendingIDs.count
    }

    /// A completed atomic write is the boundary for changing controls and acknowledging samples.
    @discardableResult private func save() -> Bool {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(storedState)
            try data.write(to: storeURL, options: .atomic)
            pendingCount = pendingIDs.count
            return true
        } catch {
            status = String(format: TextsDirectWatch.storageSaveFailedFormat, error.localizedDescription)
            log(status)
            return false
        }
    }

    private func log(_ message: String) {
        journal.append("\(ISO8601DateFormatter().string(from: Date())) \(message)")
        journal = Array(journal.suffix(3000))
        try? (journal.joined(separator: "\n") + "\n").write(to: logURL, atomically: true, encoding: .utf8)
    }

    func recordPhoneLinkDiagnostic(_ message: String) {
        log("Phone link: \(message)")
    }

    // MARK: - Collection control

    func setPaused(_ paused: Bool) {
        guard isConfigured, let connectionIdentity, !storageFailed, paused != isPaused else { return }
        let control = DirectWatchCollectionControl(connection: connectionIdentity, isPaused: paused,
                                                    previousRevision: collectionControl?.revision ?? 0)
        if applyCollectionControl(control) {
            publishCollectionControl()
            // This entry point handles local buttons and triple tap. Remote controls stay silent.
            WKInterfaceDevice.current().play(paused ? .stop : .start)
        }
    }

    func receiveCollectionControl(_ payload: [String: Any]) {
        guard let control = DirectWatchCollectionControl.decode(DirectWatchCompatibility.normalized(payload)),
              isConfigured, control.supersedes(collectionControl, for: connectionIdentity) else { return }
        if applyCollectionControl(control) { lastPublishedControlID = control.id }
    }

    /// Save the choice and its Watch-applied boundary before affecting Bluetooth.
    /// A failed write leaves the previous choice available for retry, rather than acknowledging it.
    @discardableResult private func applyCollectionControl(_ control: DirectWatchCollectionControl) -> Bool {
        let previous = collectionControl
        let previousSessions = collectionSessions
        collectionControl = control
        updateCollectionSessions()
        guard save() else {
            collectionControl = previous
            collectionSessions = previousSessions
            return false
        }
        if isPaused {
            stop()
            status = TextsDirectWatch.paused
        } else { start() }
        updateMissedReadingNotification()
        log("Watch collection paused=\(isPaused), control=\(control.id)")
        return true
    }

    private func updateCollectionSessions() {
        DirectWatchCollectionSession.update(&collectionSessions, collecting: collectionIsEnabled,
                                            connection: connectionIdentity, paused: isPaused, now: Date())
        // Retain recent empty sessions and every session referenced by stored readings.
        let referenced = Set(readings.compactMap(\.collectionSessionID))
        let recent = Set(collectionSessions.suffix(ConstantsDirectWatch.maximumRecentCollectionSessions).map(\.id))
        collectionSessions.removeAll { !recent.contains($0.id) && !referenced.contains($0.id) }
    }

    private func publishCollectionControl() {
        let session = WCSession.default
        guard let control = collectionControl, control.connection == connectionIdentity,
              control.id != lastPublishedControlID, session.activationState == .activated else { return }
        let payload = DirectWatchCompatibility.outgoing(control.payload)
        // Queue the choice even when the phone is away. A live message provides immediate feedback.
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    self?.recordLivePhoneContact()
                    self?.receiveCollectionControl(response)
                }
            }, errorHandler: nil)
        }
        lastPublishedControlID = control.id
    }

    // MARK: - Configuration

    @discardableResult func receiveConfiguration(_ payload: [String: Any]) -> Bool {
        let payload = DirectWatchCompatibility.normalized(payload)
        // Reject reordered snapshots and invalid clocks before mutating the current binding.
        guard let revision = payload["directWatchRevision"] as? Double, revision.isFinite,
              revision >= configurationRevision else { return false }
        let next = payload["directWatchEnabled"] as? Bool == false ? nil
            : (payload["directWatchConfiguration"] as? Data).flatMap { try? JSONDecoder().decode(DirectWatchConfiguration.self, from: $0) }
        guard payload["directWatchEnabled"] as? Bool == false || next?.isValid() == true else { return false }
        guard !storageFailed else { return false }
        // A configuration transfer is also a background execution opportunity. Previously an
        // unchanged snapshot returned without checking the hours-old restored BLE request.
        // start() respects pause/suspension and connect() bounds recovery by request age.
        defer {
            start()
            updateMissedReadingNotification()
        }
        if let paused = payload["directWatchPhonePaused"] as? Bool, paused != phoneBLECollectionPaused {
            phoneBLECollectionPaused = paused
            log("Phone BLE collection paused=\(paused)")
        }
        let configured = payload["directWatchConfigured"] as? Bool ?? (next != nil)
        let connectionChanged = next.map { $0.connectionIdentity != connectionIdentity } ?? false
        let sensorChanged = next.map { $0.sensorStartDate != configuration?.sensorStartDate } ?? false
        let pairingCodeChanged = configuration?.transmitterFamily == .g7
            && configuration?.transmitterID == next?.transmitterID
            && configuration?.slot == next?.slot
            && configuration?.pairingCode != next?.pairingCode
        let changed = configuration != next || configurationRevision != revision || isConfigured != configured
        let restartBluetooth = DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: configuration, next: next)
        if let reason = payload["directWatchUnavailableReason"] as? String {
            if status != String(format: TextsDirectWatch.suspendedReasonFormat, reason) { log(String(format: TextsDirectWatch.suspendedReasonFormat, reason)) }
        }
        guard changed else {
            receiveCollectionControl(payload)
            if isPaused { status = TextsDirectWatch.paused }
            else if let reason = payload["directWatchUnavailableReason"] as? String { status = String(format: TextsDirectWatch.suspendedReasonFormat, reason) }
            return true
        }
        let previousState = storedState
        if restartBluetooth { stop() }
        if pairingCodeChanged { g7AuthSession?.updatePairingCode(next?.pairingCode) }
        // Suspension stops collection but keeps the binding for the same transmitter and slot.
        if connectionChanged {
            peripheralID = nil
            connectionIdentity = next?.connectionIdentity
        }
        if connectionChanged || sensorChanged {
            // A retained BLE target can be reused, but the previous sensor's connection time
            // must not count as a connection made for this sensor's new configuration.
            lastConnectedAt = nil
            lastCycleCompletedAt = nil
        }
        configuration = next
        isConfigured = configured
        if restartBluetooth { configureG7Authentication() }
        configurationRevision = revision
        // Apply configuration and any newer pause choice in one durable snapshot. In particular,
        // do not briefly start a newly received configuration whose accompanying choice is paused.
        let incomingControl = DirectWatchCollectionControl.decode(payload)
        let controlChanged = incomingControl?.supersedes(collectionControl, for: connectionIdentity) == true
        if controlChanged { collectionControl = incomingControl }
        updateCollectionSessions()
        guard save() else {
            // Leave the revision retryable. Without rollback an identical retransmission would
            // look already applied even though the new setup had never reached the disk.
            restore(previousState)
            configureG7Authentication()
            return false
        }
        if controlChanged { lastPublishedControlID = incomingControl?.id }
        log("Configuration received, enabled=\(next != nil), slot=\(next?.slot ?? 0)")
        if isPaused {
            stop()
            status = TextsDirectWatch.paused
        } else if next != nil && (restartBluetooth || controlChanged) { start() }
        else if let reason = payload["directWatchUnavailableReason"] as? String { status = String(format: TextsDirectWatch.suspendedReasonFormat, reason) }
        return true
    }

    // MARK: - App lifecycle

    func start() {
        guard collectionIsEnabled, configuration?.isValid() == true, !storageFailed else { return }
        requestNotificationAuthorization()
        if central == nil {
            status = TextsDirectWatch.waitingTransmitter
            central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: DirectWatchCompatibility.centralRestorationIdentifier])
        } else if central?.state == .poweredOn { connect() }
    }

    private func stop() {
        timeout?.invalidate()
        timeout = nil
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        recoveryCallbackTimeout?.invalidate()
        recoveryCallbackTimeout = nil
        discoveryFallbackTimeout?.invalidate()
        discoveryFallbackTimeout = nil
        discoveryFallbackStartedAt = nil
        pendingRecovery = nil
        savedPeripheralRetryCount = 0
        failedConnectionAttempts = 0
        connectionIsActive = false
        connectionRequestBlocked = false
        lastRequestUsedDelayOption = false
        connectionRequestedAt = nil
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        auth = nil
        control = nil
        authStream = nil
        g7AuthSession?.resetForConnection()
        status = TextsDirectWatch.collectionOff
        clearNotifications(ConstantsDirectWatch.notificationIDs)
    }

    func foreground() {
        isForeground = true
        log("App active, status=\(status)")
        if collectionIsEnabled { start() }
        sync()
    }

    func background() {
        isForeground = false
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        if discoveryFallbackStartedAt != nil { finishDiscoveryFallback(reason: "Watch app backgrounded") }
        log("App entered background, status=\(status)")
    }

    @MainActor func handleBluetoothBackground() async {
        log("Bluetooth background task started")
        guard collectionIsEnabled else {
            sync()
            log("Bluetooth background task completed, collection inactive")
            return
        }
        connect()
        // Keep the granted task alive briefly for the asynchronous auth/time/glucose exchange.
        // This does not extend watchOS's Bluetooth budget or create additional runtime.
        for _ in 0..<15 {
            if Task.isCancelled || !collectionIsEnabled { break }
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { break }
            // G7 has no G6 time-response tuple. Use the common completion flag so a finished
            // G7 exchange does not keep every granted background task alive for all 15 seconds.
            if cycleCompletedThisConnection && peripheral?.state != .connected { break }
        }
        sync()
        log("Bluetooth background task completed")
    }

    // MARK: - Connection and recovery

    private func connect() {
        guard let central, central.state == .poweredOn, collectionIsEnabled, !storageFailed, !g7AuthenticationBlocked, !connectionRequestBlocked else { return }
        if pendingRecovery != nil {
            if let peripheral {
                if peripheral.state == .disconnected { completePendingRecovery(for: peripheral) }
                else if isForeground && recoveryCallbackTimeout == nil { awaitPendingCancellation(of: peripheral, checksRemaining: 3) }
            }
            return
        }
        if let discoveryFallbackStartedAt {
            if !isForeground || Date().timeIntervalSince(discoveryFallbackStartedAt) >= DirectWatchCollectionPolicy.discoveryFallbackLimit {
                finishDiscoveryFallback(reason: isForeground ? "discovery window elapsed" : "Watch app backgrounded")
            } else if !central.isScanning {
                central.scanForPeripherals(withServices: [advertisement])
                log("Resumed foreground discovery fallback, saved peripheral retained")
            }
            return
        }
        if let peripheral, peripheral.state == .connected {
            if !connectionIsActive { centralManager(central, didConnect: peripheral) }
            return
        }
        if let peripheral, peripheral.state == .connecting {
            if connectionRequestedAt == nil {
                connectionRequestedAt = .now
                _ = save()
            }
            let recovery = DirectWatchCollectionPolicy.pendingRecovery(startedAt: connectionRequestedAt, now: .now,
                                                                        isForeground: isForeground, savedRetryCount: savedPeripheralRetryCount)
            if recovery == .wait { scheduleConnectionTimeout(for: peripheral) }
            else { beginPendingRecovery(recovery, for: peripheral) }
            return
        }
        if let peripheralID, let known = central.retrievePeripherals(withIdentifiers: [peripheralID]).first {
            peripheral = known
            known.delegate = self
            if known.state == .connected { centralManager(central, didConnect: known) }
            else { requestConnection(to: known) }
            log("Pending reconnect to saved Watch peripheral")
        } else {
            central.scanForPeripherals(withServices: [advertisement])
            log("Scanning for transmitter, saved peripheral available=\(peripheralID != nil), isScanning=\(central.isScanning)")
        }
    }

    private func scheduleConnectionTimeout(for target: CBPeripheral) {
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        // Pending connects survive suspension. Timers are only useful in the foreground.
        // Background recovery is checked on an actual wake, never by a suspended Timer.
        guard isForeground, let startedAt = connectionRequestedAt else { return }
        let remaining = max(0.1, DirectWatchCollectionPolicy.pendingConnectionLimit - Date().timeIntervalSince(startedAt))
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self, weak target] _ in
            guard let self, let target, self.peripheral === target, target.state == .connecting else { return }
            self.connect()
        }
    }

    private func requestConnection(to target: CBPeripheral) {
        guard collectionIsEnabled, let central, central.state == .poweredOn, let configuration, !storageFailed, !g7AuthenticationBlocked, !connectionRequestBlocked else { return }
        // Background callbacks and foreground refreshes may both reach this path.
        // Never replace a queued delayed connection or reset its recovery deadline.
        guard target.state == .disconnected else {
            if target.state == .connecting {
                if connectionRequestedAt == nil {
                    connectionRequestedAt = .now
                    _ = save()
                }
                scheduleConnectionTimeout(for: target)
            }
            return
        }
        let delay = delayOptionUnavailable ? 0 : DirectWatchCollectionPolicy.reconnectDelay(family: configuration.transmitterFamily,
                                                              completedAt: lastCycleCompletedAt,
                                                              failedAttempts: failedConnectionAttempts, now: .now)
        connectionRequestedAt = Date().addingTimeInterval(delay)
        guard save() else { return }
        status = delay > 0 ? TextsDirectWatch.waitingCycle : TextsDirectWatch.connectingSaved
        log("BLE reconnect queued, delay=\(Int(ceil(delay)))s, failedAttempts=\(failedConnectionAttempts), foreground=\(isForeground), authentication retained")
        lastRequestUsedDelayOption = delay > 0
        // Use integral seconds. If this Watch rejects the option, didFailToConnect
        // disables it and retries once with no options rather than repeating the request.
        central.connect(target, options: delay > 0 ? [CBConnectPeripheralOptionStartDelayKey: NSNumber(value: Int(ceil(delay)))] : nil)
        scheduleConnectionTimeout(for: target)
    }

    private func beginPendingRecovery(_ action: DirectWatchCollectionPolicy.PendingRecovery, for target: CBPeripheral) {
        guard action != .wait, pendingRecovery == nil else { return }
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        pendingRecovery = action
        let pendingAge = connectionRequestedAt.map { Int(Date().timeIntervalSince($0)) } ?? -1
        connectionRequestedAt = nil
        _ = save()
        status = action == .retrySavedPeripheral ? TextsDirectWatch.retryingSaved : TextsDirectWatch.checkingDiscovery
        log("Pending connection stale, age=\(pendingAge)s, action=\(action), savedRetries=\(savedPeripheralRetryCount), foreground=\(isForeground), saved peripheral retained")
        central?.cancelPeripheralConnection(target)
        awaitPendingCancellation(of: target, checksRemaining: 3)
    }

    private func awaitPendingCancellation(of target: CBPeripheral, checksRemaining: Int) {
        recoveryCallbackTimeout?.invalidate()
        recoveryCallbackTimeout = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self, weak target] _ in
            guard let self, let target, self.peripheral === target, self.pendingRecovery != nil else { return }
            self.recoveryCallbackTimeout = nil
            if target.state == .disconnected {
                self.completePendingRecovery(for: target)
            } else if !self.isForeground {
                self.log("Pending cancellation recovery deferred until foreground, saved peripheral retained")
            } else if checksRemaining > 1 {
                self.log("Waiting for saved peripheral cancellation, state=\(target.state.rawValue)")
                self.central?.cancelPeripheralConnection(target)
                self.awaitPendingCancellation(of: target, checksRemaining: checksRemaining - 1)
            } else {
                // A missing CoreBluetooth cancellation callback must not require a Watch reboot.
                self.log("Saved peripheral cancellation did not finish, recreating central manager and retaining identifier")
                self.recoveryCallbackTimeout = nil
                self.pendingRecovery = nil
                self.peripheral = nil
                self.connectionIsActive = false
                self.connectionRequestedAt = nil
                self.central = nil
                self.start()
            }
        }
    }

    private func completePendingRecovery(for target: CBPeripheral) {
        guard let action = pendingRecovery, peripheral === target else { return }
        recoveryCallbackTimeout?.invalidate()
        recoveryCallbackTimeout = nil
        pendingRecovery = nil
        if action == .discoverInForeground && isForeground,
           let central, central.state == .poweredOn, peripheralID != nil {
            startDiscoveryFallback(using: central)
        } else {
            savedPeripheralRetryCount += 1
            status = TextsDirectWatch.retryingSaved
            log("Retrying saved peripheral, attempt=\(savedPeripheralRetryCount), foreground=\(isForeground)")
            requestConnection(to: target)
        }
    }

    private func startDiscoveryFallback(using central: CBCentralManager) {
        peripheral = nil
        discoveryFallbackStartedAt = .now
        status = TextsDirectWatch.scanningRetained
        central.scanForPeripherals(withServices: [advertisement])
        log("Foreground discovery fallback started, saved peripheral retained, isScanning=\(central.isScanning)")
        discoveryFallbackTimeout?.invalidate()
        discoveryFallbackTimeout = Timer.scheduledTimer(withTimeInterval: DirectWatchCollectionPolicy.discoveryFallbackLimit, repeats: false) { [weak self] _ in
            self?.finishDiscoveryFallback(reason: "discovery window elapsed")
        }
    }

    private func finishDiscoveryFallback(reason: String) {
        guard discoveryFallbackStartedAt != nil else { return }
        discoveryFallbackTimeout?.invalidate()
        discoveryFallbackTimeout = nil
        discoveryFallbackStartedAt = nil
        central?.stopScan()
        savedPeripheralRetryCount = 0
        guard let central, central.state == .poweredOn, let peripheralID,
              let known = central.retrievePeripherals(withIdentifiers: [peripheralID]).first else {
            status = TextsDirectWatch.waitingDiscovery
            log("Discovery fallback ended (\(reason)), saved peripheral unavailable to CoreBluetooth")
            if isForeground { connect() }
            return
        }
        peripheral = known
        known.delegate = self
        status = TextsDirectWatch.reconnectingSaved
        log("Discovery fallback ended (\(reason)), reconnecting saved peripheral")
        if known.state == .connected { centralManager(central, didConnect: known) }
        else { requestConnection(to: known) }
    }

    /// Forget only this app's cached peripheral target. The Watch's system bond is managed by watchOS.
    // Automatic recovery keeps the saved target and authentication. This user-requested path
    // intentionally rediscovers the peripheral and, for G7, clears this slot's saved key.
    @discardableResult func resetBluetoothConnection() -> Bool {
        guard collectionIsEnabled, !storageFailed else { return false }
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        recoveryCallbackTimeout?.invalidate()
        recoveryCallbackTimeout = nil
        discoveryFallbackTimeout?.invalidate()
        discoveryFallbackTimeout = nil
        pendingRecovery = nil
        discoveryFallbackStartedAt = nil
        savedPeripheralRetryCount = 0
        failedConnectionAttempts = 0
        connectionIsActive = false
        lastCycleCompletedAt = nil
        let recreateCentral = connectionRequestBlocked
        connectionRequestBlocked = false
        connectionRequestedAt = nil
        timeout?.invalidate()
        timeout = nil
        central?.stopScan()
        let previous = peripheral
        peripheral = nil
        peripheralID = nil
        auth = nil
        control = nil
        authStream = nil
        if configuration?.transmitterFamily == .g7 {
            // This explicit action intentionally clears this Watch slot's confirmed key so an
            // unused or reset G7 slot can run ownership bootstrap again.
            g7AuthSession?.clearPersistedAuthentication()
            log("Cleared saved G7 Watch authentication for pair again")
        } else { g7AuthSession?.resetForConnection() }
        g7AuthenticationBlocked = false
        clock = nil
        if let previous { central?.cancelPeripheralConnection(previous) }
        if recreateCentral { central = nil }
        guard save() else { return false }
        status = TextsDirectWatch.scanningToPair
        log("User requested Reset connection, cleared saved Watch peripheral and starting discovery")
        if central == nil { start() }
        else { connect() }
        return true
    }

    // MARK: - CoreBluetooth callbacks

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === self.central else { return }
        guard !isPaused else {
            status = TextsDirectWatch.paused
            return
        }
        log("Bluetooth state=\(central.state.rawValue)")
        if central.state == .poweredOn { connect() }
        else {
            connectionIsActive = false
            status = String(format: TextsDirectWatch.bluetoothUnavailableFormat, central.state.rawValue)
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard self.central == nil || central === self.central else { return }
        guard collectionIsEnabled else {
            for restored in (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]) ?? [] {
                central.cancelPeripheralConnection(restored)
            }
            return
        }
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first,
              restored.identifier == peripheralID else { return }
        peripheral = restored
        restored.delegate = self
        log("CoreBluetooth restored saved peripheral, state=\(restored.state.rawValue), pendingAge=\(connectionRequestedAt.map { Int(Date().timeIntervalSince($0)) } ?? -1)s")
        if restored.state == .connecting {
            if connectionRequestedAt == nil { connectionRequestedAt = .now }
            scheduleConnectionTimeout(for: restored)
        }
        if restored.state == .connected && central.state == .poweredOn { self.centralManager(central, didConnect: restored) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === self.central else { return }
        guard collectionIsEnabled, let configuration, self.peripheral == nil else { return }
        let expected = configuration.transmitterFamily == .g7
            ? configuration.transmitterID.uppercased()
            : "DEXCOM" + configuration.transmitterID.suffix(2)
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard name?.uppercased() == expected else { return }
        discoveryFallbackTimeout?.invalidate()
        discoveryFallbackTimeout = nil
        discoveryFallbackStartedAt = nil
        savedPeripheralRetryCount = 0
        self.peripheral = peripheral
        peripheralID = peripheral.identifier
        peripheral.delegate = self
        guard save() else {
            self.peripheral = nil
            return
        }
        central.stopScan()
        requestConnection(to: peripheral)
        status = TextsDirectWatch.connectingTransmitter
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        log("Discovered transmitter, RSSI=\(RSSI), connectable=\(connectable.map { $0 ? "true" : "false" } ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard central === self.central else { return }
        guard self.peripheral === peripheral, collectionIsEnabled else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        guard !connectionIsActive else {
            log("Duplicate connected callback ignored")
            return
        }
        connectionIsActive = true
        cycleCompletedThisConnection = false
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        recoveryCallbackTimeout?.invalidate()
        recoveryCallbackTimeout = nil
        pendingRecovery = nil
        savedPeripheralRetryCount = 0
        connectionRequestedAt = nil
        lastConnectedAt = Date()
        _ = save()
        auth = nil
        control = nil
        authStream = nil
        authSent = false
        challengeSent = false
        g7Authenticated = false
        g7GlucoseRequested = false
        g7AuthSession?.resetForConnection()
        clock = nil
        status = TextsDirectWatch.authenticating
        log("Connected, family=\(configuration?.transmitterFamily.rawValue ?? "none"), slot=\(configuration?.slot ?? 0)")
        peripheral.discoverServices([service])
        sync()
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 75, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.log("Connection setup/read timed out")
            self.status = TextsDirectWatch.transmitterTimeout
            self.central?.cancelPeripheralConnection(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard central === self.central else { return }
        guard self.peripheral === peripheral else { return }
        connectionIsActive = false
        if pendingRecovery != nil {
            log("Saved peripheral cancellation completed, callback=disconnect")
            completePendingRecovery(for: peripheral)
            return
        }
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        connectionRequestedAt = nil
        timeout?.invalidate()
        timeout = nil
        if let error {
            let detail = error as NSError
            log("Disconnected: \(detail.localizedDescription), domain=\(detail.domain), code=\(detail.code)")
        } else { log("Disconnected: normal") }
        auth = nil
        control = nil
        authStream = nil
        g7AuthSession?.resetForConnection()
        if collectionIsEnabled && !storageFailed {
            if !cycleCompletedThisConnection { failedConnectionAttempts = min(failedConnectionAttempts + 1, 5) }
            status = TextsDirectWatch.waitingNextReading
            if !g7AuthenticationBlocked { requestConnection(to: peripheral) }
        }
        sync()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard central === self.central else { return }
        guard self.peripheral === peripheral else { return }
        if pendingRecovery != nil {
            log("Saved peripheral cancellation completed, callback=connect failure")
            completePendingRecovery(for: peripheral)
            return
        }
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        if let error {
            let detail = error as NSError
            log("Connect failed: \(detail.localizedDescription), domain=\(detail.domain), code=\(detail.code)")
        } else { log("Connect failed without error") }
        connectionRequestedAt = nil
        guard collectionIsEnabled, !storageFailed, !g7AuthenticationBlocked else { return }
        let detail = error as NSError?
        if detail?.domain == CBErrorDomain && detail?.code == CBError.invalidParameters.rawValue {
            switch DirectWatchCollectionPolicy.invalidConnectionRecovery(usedDelayOption: lastRequestUsedDelayOption) {
            case .retryWithoutOptions:
                delayOptionUnavailable = true
                lastRequestUsedDelayOption = false
                log("Watch rejected delayed connection option, disabled persistently, retrying saved peripheral once without options")
                guard save() else { return }
                requestConnection(to: peripheral)
            case .stopInvalidRequest:
                connectionRequestBlocked = true
                _ = save()
                status = TextsDirectWatch.bluetoothRejected
                log("Plain connection request rejected, automatic retries stopped to prevent an invalid-request loop")
            }
            sync()
            return
        }
        savedPeripheralRetryCount += 1
        failedConnectionAttempts = min(failedConnectionAttempts + 1, 5)
        status = TextsDirectWatch.retryingSaved
        log("Saved peripheral connection failed, retry=\(savedPeripheralRetryCount), identifier retained")
        requestConnection(to: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral === peripheral else { return }
        if let error {
            fail(error)
            return
        }
        for service in peripheral.services ?? [] where service.uuid == self.service {
            peripheral.discoverCharacteristics(configuration?.transmitterFamily == .g7
                ? [authUUID, controlUUID, authStreamUUID] : [authUUID, controlUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.peripheral === peripheral else { return }
        if let error {
            fail(error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == authUUID { auth = characteristic }
            if characteristic.uuid == controlUUID { control = characteristic }
            if characteristic.uuid == authStreamUUID { authStream = characteristic }
        }
        if configuration?.transmitterFamily == .g7 {
            if let auth, let authStream, control != nil {
                g7AuthSession?.configure(receiveAuthentication: auth, authStream: authStream)
            }
        } else if let auth, control != nil { peripheral.setNotifyValue(true, for: auth) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard collectionIsEnabled, self.peripheral === peripheral, let configuration else { return }
        if let error {
            fail(error)
            return
        }
        guard characteristic.isNotifying else { return }
        if configuration.transmitterFamily == .g7 {
            if characteristic.uuid == authUUID || characteristic.uuid == authStreamUUID {
                g7AuthSession?.notificationStateUpdated(for: characteristic)
            } else if characteristic.uuid == controlUUID, g7Authenticated {
                requestG7GlucoseIfReady()
            }
            return
        }
        if characteristic.uuid == authUUID && !authSent {
            authSent = true
            guard let slot = DexcomG6BluetoothSlot(rawValue: configuration.slot) else { return }
            write(AuthRequestTxMessage(slot: slot).data, to: auth)
        } else if characteristic.uuid == controlUUID {
            write(DexcomG6WatchProtocol.command(0x24), to: control)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral else { return }
        if let error { fail(error) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard collectionIsEnabled, self.peripheral === peripheral, let configuration else { return }
        if let error {
            fail(error)
            return
        }
        guard let data = characteristic.value, let opcode = data.first else { return }
        log("Received opcode=\(String(format: "%02X", opcode)), bytes=\(data.count)")
        if configuration.transmitterFamily == .g7 {
            if characteristic.uuid == authUUID { g7AuthSession?.receiveAuthentication(data) }
            else if characteristic.uuid == authStreamUUID { g7AuthSession?.receiveAuthStream(data) }
            else if characteristic.uuid == controlUUID { receiveG7Glucose(data, configuration: configuration) }
            return
        }
        if characteristic.uuid == authUUID {
            if opcode == 3, data.count >= 17, !challengeSent,
               let hash = DexcomG6WatchProtocol.challengeHash(transmitterID: configuration.transmitterID, challenge: data.subdata(in: 9..<17)) {
                challengeSent = true
                write(Data([4]) + hash, to: auth)
            } else if opcode == 5, data.count >= 3 {
                guard data[1] == 1 else {
                    status = TextsDirectWatch.g6AuthRejected
                    log(status)
                    return
                }
                if data[2] == 2 {
                    status = TextsDirectWatch.acceptPairing
                    write(Data([6, 60]), to: auth)
                    write(Data([7]), to: auth)
                } else if let control { peripheral.setNotifyValue(true, for: control) }
            } else if opcode == 8, let control { peripheral.setNotifyValue(true, for: control) }
            return
        }
        guard characteristic.uuid == controlUUID else { return }
        if opcode == 0x25, data.count >= 12, DexcomG6WatchProtocol.hasValidCRC(data),
           let seconds = DexcomWatchProtocol.uint32(data, at: 2), let start = DexcomWatchProtocol.uint32(data, at: 6),
           start > 0, start <= seconds, seconds <= UInt32(Int32.max) {
            clock = (seconds, start, Date().addingTimeInterval(-Double(seconds)))
            write(DexcomG6WatchProtocol.command(0x30), to: control)
        } else if let glucose = DexcomG6WatchProtocol.glucose(data), let clock,
                  glucose.seconds <= clock.seconds + 60, glucose.seconds >= clock.start {
            let reading = DirectWatchReading(transmitterID: configuration.transmitterID, sensorStartCounter: clock.start,
                                         sensorStartDate: clock.epoch.addingTimeInterval(Double(clock.start)),
                                         transmitterSeconds: glucose.seconds,
                                         measuredAt: clock.epoch.addingTimeInterval(Double(glucose.seconds)), mgDl: glucose.value, state: glucose.state)
            if reading.belongs(to: configuration) { accept(reading) }
            else {
                status = String(format: TextsDirectWatch.g6StateFormat, Int(glucose.state))
                log("No usable reading: state=\(glucose.state), session match=\(abs(reading.sensorStartDate.timeIntervalSince(configuration.sensorStartDate)) <= 120)")
            }
            // Match the phone's existing G6 flow: release BLE after collecting this cycle.
            lastCycleCompletedAt = .now
            cycleCompletedThisConnection = true
            failedConnectionAttempts = 0
            _ = save()
            central?.cancelPeripheralConnection(peripheral)
        }
    }

    private func write(_ data: Data, to characteristic: CBCharacteristic?) {
        guard collectionIsEnabled, let peripheral, let characteristic else { return }
        log("Sending opcode=\(String(format: "%02X", data.first ?? 0))")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    // MARK: - G7 authentication transport

    /// Reuse the phone's G7 authentication implementation. Only this Watch slot's keys are
    /// reset by the explicit Reset connection action. Ordinary reconnects retain ownership.
    private func configureG7Authentication() {
        guard let configuration, configuration.transmitterFamily == .g7,
              let slot = DexcomG7BluetoothSlot(rawValue: configuration.slot) else {
            g7AuthSession = nil
            return
        }
        let session = DexcomG7AuthSession(transmitterID: configuration.transmitterID,
                                         pairingCode: configuration.pairingCode, bluetoothSlot: slot)
        session.transport = self
        g7AuthSession = session
        g7AuthenticationBlocked = false
        log("G7 authentication prepared for slot \(configuration.slot)")
    }

    private func requestG7GlucoseIfReady() {
        guard g7Authenticated, !g7GlucoseRequested, let control, control.isNotifying else { return }
        g7GlucoseRequested = true
        // Primary G7 data requests are a bare 0x4E byte, without the G6 CRC.
        write(Data([0x4E]), to: control)
    }

    private func receiveG7Glucose(_ data: Data, configuration: DirectWatchConfiguration) {
        guard data.first == 0x4E else { return }
        cycleCompletedThisConnection = true
        failedConnectionAttempts = 0
        if let reading = DexcomG7WatchProtocol.reading(data, configuration: configuration) { accept(reading) }
        else { log("G7 reading rejected: status=\(data.count > 1 ? data[1] : 0), state=\(data.count > 14 ? data[14] : 0), invalid or mismatched session") }
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
    }

    func authSessionSetNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        guard collectionIsEnabled else { return }
        peripheral?.setNotifyValue(enabled, for: characteristic)
    }

    @discardableResult func authSessionWrite(_ data: Data, to characteristic: CBCharacteristic,
                                             type: CBCharacteristicWriteType) -> Bool {
        guard collectionIsEnabled, let peripheral, peripheral.state == .connected else { return false }
        peripheral.writeValue(data, for: characteristic, type: type)
        return true
    }

    func authSessionDidAuthenticate() {
        guard collectionIsEnabled else { return }
        g7Authenticated = true
        status = TextsDirectWatch.g7Requesting
        log(status)
        if let control {
            if control.isNotifying { requestG7GlucoseIfReady() }
            else { peripheral?.setNotifyValue(true, for: control) }
        }
    }

    func authSessionDidRejectPersistedKey() {
        guard collectionIsEnabled else { return }
        g7AuthenticationBlocked = true
        status = TextsDirectWatch.g7KeyRejected
        log(status)
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
    }

    func authSessionRequiresCleanReconnect() {
        guard collectionIsEnabled else { return }
        log("G7 ownership needs a clean reconnect")
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
    }

    func authSessionDidFail(_ message: String) {
        guard collectionIsEnabled else { return }
        status = TextsDirectWatch.g7AuthFailed
        log("G7 authentication: \(message)")
    }

    func authSessionDidProgress(_ message: String) {
        guard collectionIsEnabled else { return }
        // Detailed protocol progress stays in the log. The visible state uses the Watch language.
        status = TextsDirectWatch.authenticating
        log(message)
    }

    func authSessionSchedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard self?.collectionIsEnabled == true else { return }
            action()
        }
    }

    private func fail(_ error: Error) {
        let detail = error as NSError
        status = String(format: TextsDirectWatch.bluetoothErrorFormat, detail.localizedDescription)
        log("\(status), domain=\(detail.domain), code=\(detail.code)")
        if detail.domain == CBErrorDomain && (detail.code == CBError.Code.leGattNearBackgroundNotificationLimit.rawValue || detail.code == CBError.Code.leGattExceededBackgroundNotificationLimit.rawValue) {
            status = TextsDirectWatch.backgroundLimit
            log(status)
        }
        // Includes watchOS near/exceeded background-budget errors in the persistent journal.
    }

    // MARK: - Readings and local notifications

    /// Called only by live message receipts and replies, never delayed background transfers.
    /// Keep missed-reading delivery outside the sixty-second phone contact window even when
    /// watchOS suspends the app before the next transmitter cycle.
    func recordLivePhoneContact(at date: Date = .now) {
        lastPhoneContactAt = date
        // Preserve recent contact across a Watch process restart. A delayed transfer cannot
        // update this value, and no explicit disk flush is needed on the live-message path.
        UserDefaults.standard.set(date, forKey: ConstantsDirectWatch.lastPhoneContactKey)
        clearNotifications(ConstantsDirectWatch.glucoseNotificationIDs)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: DirectWatchCompatibility.missedReadingNotificationIDs)
        updateMissedReadingNotification()
    }

    private func requestNotificationAuthorization() {
        guard !requestedNotifications,
              urgentLowNotificationsEnabled || lowNotificationsEnabled || missedReadingNotificationsEnabled else { return }
        requestedNotifications = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] allowed, error in
            DispatchQueue.main.async {
                self?.log("Local notifications allowed=\(allowed), error=\(error?.localizedDescription ?? "none")")
                if allowed { self?.updateMissedReadingNotification() }
            }
        }
    }

    private func clearNotifications(_ identifiers: [String]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func setUrgentLowNotificationsEnabled(_ enabled: Bool) {
        urgentLowNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: ConstantsDirectWatch.urgentLowNotificationsKey)
        if !enabled { clearNotifications(["directWatch.urgentLow"]) }
        else { requestNotificationAuthorization() }
    }

    func setLowNotificationsEnabled(_ enabled: Bool) {
        lowNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: ConstantsDirectWatch.lowNotificationsKey)
        if !enabled { clearNotifications(["directWatch.low"]) }
        else { requestNotificationAuthorization() }
    }

    func setMissedReadingNotificationsEnabled(_ enabled: Bool) {
        guard enabled != missedReadingNotificationsEnabled else { return }
        missedReadingNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: ConstantsDirectWatch.missedReadingNotificationsKey)
        log("Missed reading notifications enabled=\(enabled)")
        if !enabled { clearNotifications(DirectWatchCompatibility.missedReadingNotificationIDs) }
        else { requestNotificationAuthorization() }
        updateMissedReadingNotification()
    }

    /// Use Watch receipt time, never phone sync time. A new session starts its own deadline
    /// even if it has not collected a first reading. Opening a screen cannot restart it.
    private func updateMissedReadingNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: DirectWatchCompatibility.missedReadingNotificationIDs)
        guard missedReadingNotificationsEnabled, collectionIsEnabled, !storageFailed,
              let configuration else { return }
        let collectedAt = readings.first(where: { $0.belongs(to: configuration) })?.collectedAt
        guard let reference = [collectedAt, collectionResumedAt, collectionSessions.last?.startedAt].compactMap({ $0 }).max() else { return }
        let content = UNMutableNotificationContent()
        content.title = TextsDirectWatch.noRecentReading
        content.body = TextsDirectWatch.checkConnection
        content.sound = .default
        let deadline = DirectWatchAlertPolicy.missedReadingDeadline(collectedAt: reference, lastPhoneContact: lastPhoneContactAt)
        center.add(UNNotificationRequest(identifier: "directWatch.missed", content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)))
    }

    /// Commit the sample and pending identity together before publishing glucose or alarms.
    /// A local storage failure stops collection instead of displaying an unsaved sample.
    private func accept(_ incoming: DirectWatchReading) {
        var reading = incoming
        if reading.collectedAt == nil { reading.collectedAt = Date() }
        guard collectionIsEnabled else { return }
        reading.collectionSessionID = collectionSessions.last.flatMap { $0.endedAt == nil ? $0.id : nil }
        guard !readings.contains(where: { $0.id == reading.id }) else { return }
        let previousReadings = readings
        let previousPending = pendingIDs
        let previousSessions = collectionSessions
        if let index = collectionSessions.indices.last, collectionSessions[index].endedAt == nil,
           collectionSessions[index].firstReadingID == nil,
           !readings.contains(where: { $0.collectionSessionID == collectionSessions[index].id }) {
            // Older sessions without this field retain their existing, unknown first boundary.
            collectionSessions[index].firstReadingID = reading.id
        }
        readings.append(reading)
        readings.sort { $0.measuredAt > $1.measuredAt }
        pendingIDs.insert(reading.id)
        readings.removeAll { $0.measuredAt < Date().addingTimeInterval(-ConstantsDirectWatch.localReadingRetention) && !pendingIDs.contains($0.id) }
        guard save() else {
            readings = previousReadings
            pendingIDs = previousPending
            collectionSessions = previousSessions
            storageFailed = true
            clearNotifications(ConstantsDirectWatch.notificationIDs)
            central?.stopScan()
            return
        }
        status = TextsDirectWatch.readingReceived
        log("Stored Watch reading at \(reading.measuredAt), mg/dL=\(reading.mgDl), pending=\(pendingCount)")
        updateMissedReadingNotification()
        let now = Date()
        if DirectWatchAlertPolicy.mayNotify(collecting: collectionIsEnabled && !storageFailed,
                                            lastPhoneContact: lastPhoneContactAt, now: now), let configuration,
           let alert = DirectWatchAlertPolicy.glucoseAlert(value: reading.mgDl, measuredAt: reading.measuredAt, now: now,
                urgent: DirectWatchAlertEntry.current(in: configuration.urgentLowSchedule, at: now),
                low: DirectWatchAlertEntry.current(in: configuration.lowSchedule, at: now),
                urgentEnabled: urgentLowNotificationsEnabled, lowEnabled: lowNotificationsEnabled,
                lastUrgent: lastUrgentLowAlert, lastLow: lastLowAlert) {
            let value = configuration.isMgDl ? String(format: "%.0f mg/dL", reading.mgDl) : String(format: "%.1f mmol/L", reading.mgDl / 18)
            notify(title: alert == .urgentLow ? TextsDirectWatch.urgentLowGlucose : TextsDirectWatch.lowGlucose,
                   body: value, identifier: "directWatch.\(alert.rawValue)")
            if alert == .urgentLow {
                lastUrgentLowAlert = now
                UserDefaults.standard.set(now, forKey: ConstantsDirectWatch.lastUrgentLowAlertKey)
            } else {
                lastLowAlert = now
                UserDefaults.standard.set(now, forKey: ConstantsDirectWatch.lastLowAlertKey)
            }
        }
        sync()
    }

    private func notify(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        log("Local alert queued: \(identifier), \(body)")
    }

    var connectionEventPayload: [String: Any] {
        guard isConfigured, let connectionIdentity, let lastConnectedAt else { return [:] }
        return DirectWatchConnectionEvent(connection: connectionIdentity, connectedAt: lastConnectedAt,
                                          controlID: collectionControl?.id).payload
    }

    // MARK: - Phone sync and diagnostics

    /// Live messages provide immediate delivery. Queued transfers survive a missing phone.
    /// Keep only one live reading batch in flight, falling back after a bounded reply timeout.
    func sync() {
        publishCollectionControl()
        let session = WCSession.default
        if session.activationState == .activated && session.isReachable {
            session.sendMessage(DirectWatchCompatibility.outgoing(["directWatchStatus": "\(status); pending=\(pendingCount)"].merging(collectionControl?.payload ?? [:], uniquingKeysWith: { _, new in new })
                .merging(connectionEventPayload, uniquingKeysWith: { _, new in new })), replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    self?.recordLivePhoneContact()
                    self?.receiveCollectionControl(response)
                }
            }, errorHandler: nil)
        }
        if let id = liveSyncID, let startedAt = liveSyncStartedAt, Date().timeIntervalSince(startedAt) >= DirectWatchCollectionPolicy.liveSyncReplyTimeout {
            expireLiveSync(id)
            return
        }
        guard session.activationState == .activated, liveSyncID == nil, Date().timeIntervalSince(lastSync) > 5 else { return }
        guard let batch = pendingBatch() else { return }
        let payload = batch.payload
        lastSync = Date()
        if session.isReachable {
            let id = UUID()
            liveSyncID = id
            liveSyncStartedAt = .now
            liveSyncTimeout?.invalidate()
            liveSyncTimeout = Timer.scheduledTimer(withTimeInterval: DirectWatchCollectionPolicy.liveSyncReplyTimeout, repeats: false) { [weak self] _ in
                self?.expireLiveSync(id)
            }
            log("Sending live batch, count=\(batch.count)")
            session.sendMessage(DirectWatchCompatibility.outgoing(payload), replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.recordLivePhoneContact()
                    self.finishLiveSync(id)
                    self.acknowledge(response)
                    if (response["directWatchAcknowledged"] as? [String])?.isEmpty == true {
                        self.log("Phone did not acknowledge batch, verify active sensor and native transmitter configuration")
                    }

                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    guard let self, self.liveSyncID == id else { return }
                    self.finishLiveSync(id)
                    self.log("Live sync failed: \(error.localizedDescription)")
                    self.queuePendingBatch()
                }
            })
        } else { queueBatch(payload) }
    }

    // A late reply can still acknowledge its own saved identities, but must not end a newer
    // batch's timeout. The UUID scopes completion independently of the actual reading IDs.
    private func finishLiveSync(_ id: UUID) {
        guard liveSyncID == id else { return }
        liveSyncTimeout?.invalidate()
        liveSyncTimeout = nil
        liveSyncID = nil
        liveSyncStartedAt = nil
    }

    private func expireLiveSync(_ id: UUID) {
        guard liveSyncID == id else { return }
        finishLiveSync(id)
        log("Live sync reply overdue, retaining readings and using queued transfer")
        queuePendingBatch()
    }

    /// Send oldest unsynced samples first, prioritising the active sensor. Never discard old
    /// pending identities merely because their configuration is temporarily unavailable.
    private func pendingBatch() -> (count: Int, payload: [String: Any])? {
        let pending = readings.filter { pendingIDs.contains($0.id) }
        let current = pending.filter { reading in configuration.map { reading.belongs(to: $0) } ?? false }
        let batch = Array((current.isEmpty ? pending : current).suffix(ConstantsDirectWatch.maximumSyncBatchReadings))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard !batch.isEmpty, let data = try? encoder.encode(batch) else { return nil }
        return (batch.count, ["directWatchReadings": data].merging(connectionEventPayload, uniquingKeysWith: { _, new in new }))
    }

    private func queuePendingBatch() {
        if let batch = pendingBatch() { queueBatch(batch.payload) }
    }

    private func queueBatch(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard !session.outstandingUserInfoTransfers.contains(where: { DirectWatchCompatibility.normalized($0.userInfo)["directWatchReadings"] != nil }) else { return }
        // Delivery may finish before the phone's acknowledgement returns. Avoid queuing
        // the same batch on every Bluetooth callback while preserving retry after a minute.
        let data = payload["directWatchReadings"] as? Data
        guard data != lastQueuedBatchData || Date().timeIntervalSince(lastQueuedBatchAt) >= 60 else { return }
        session.transferUserInfo(DirectWatchCompatibility.outgoing(payload))
        lastQueuedBatchData = data
        lastQueuedBatchAt = .now
        log("Queued batch for phone")
    }

    /// Transfer completion alone is not delivery confirmation: only the phone's post-save
    /// identities remove samples from the durable queue. Roll back the queue if saving fails.
    func acknowledge(_ payload: [String: Any]) {
        let payload = DirectWatchCompatibility.normalized(payload)
        receiveCollectionControl(payload)
        guard let ids = payload["directWatchAcknowledged"] as? [String], !ids.isEmpty else { return }
        let previous = pendingIDs
        pendingIDs.subtract(ids)
        guard pendingIDs != previous else { return }
        if save() {
            log("Phone acknowledged \(ids.count) readings, pending=\(pendingCount)")
            if pendingCount > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.sync() } }
        } else { pendingIDs = previous }
    }

    @discardableResult func sendLogs() -> Bool {
        guard WCSession.default.activationState == .activated else { return false }
        log("Log export requested")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Direct-to-Watch-\(UUID().uuidString).log")
        do {
            try (journal.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            WCSession.default.transferFile(url, metadata: DirectWatchCompatibility.outgoing(["directWatchLog": true]))
            // A queued transfer can wait for the phone. Only the phone can confirm receipt.
            return true
        } catch {
            status = String(format: TextsDirectWatch.exportFailedFormat, error.localizedDescription)
            return false
        }
    }
}
