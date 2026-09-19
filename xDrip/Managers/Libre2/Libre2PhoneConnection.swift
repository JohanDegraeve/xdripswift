import Combine
import CoreBluetooth
import Foundation
import WatchConnectivity

/// The phone owns the switch. A lost reply leaves collection suspended until retry or NFC reset.
final class Libre2PhoneConnection: ObservableObject {
    static let shared = Libre2PhoneConnection()
    private let store = Libre2ConnectionStore.shared
    weak var transmitter: CGMLibre2Transmitter? {
        didSet { lastReading = nil; refresh() }
    }
    var registerHistorySession: ((Libre2WatchSession, @escaping (Result<Void, Error>) -> Void) -> Void)?
    @Published private(set) var lastReading: Date?
    private var operationID: UUID?
    @Published private(set) var phase: Libre2ConnectionStore.Phase?
    @Published private(set) var status = "iPhone selected" {
        didSet { if status != oldValue { recordActivity(status) } }
    }
    @Published private(set) var reachable = false
    @Published private(set) var busy = false
    @Published private(set) var recentReading = false
    @Published private(set) var historyStatus = "" {
        didSet { if historyStatus != oldValue && !historyStatus.isEmpty { recordActivity(historyStatus) } }
    }
    @Published private(set) var unresolvedReadings: Libre2UnresolvedReadings?
    @Published private(set) var phoneConnected = false
    @Published private(set) var sensorConfigured = false
    @Published private(set) var nativeAlgorithmEnabled = false
    @Published private(set) var unlockPayloadEnabled = false
    @Published private(set) var transferFailed = false

    struct Activity: Codable, Identifiable {
        let id: UUID
        let date: Date
        let message: String
    }
    static let maximumActivityEntries = 80
    @Published private(set) var activity: [Activity] = []
    private let activityURL = Libre2JournalFile.url("phone-activity.json")
    var settingsVisible = false

    var hasExperiment: Bool {
        guard let selection = store.snapshot else { return true }
        return selection.sessionID != nil || !selection.retiredIDs.isEmpty
    }

    var canSwitchDevice: Bool {
        guard !busy else { return false }
        if phase == .phone { return canSwitchToWatch }
        return phase != nil && reachable && store.snapshot?.sessionID != nil
    }

    /// An interrupted preparation uses the normal return transaction, without granting phone BLE early.
    func switchDevice() {
        if phase == .phone { switchToWatch() }
        else if phase != nil { returnToPhone() }
    }

    var readingExpiration: Date? {
        recentReading ? lastReading?.addingTimeInterval(180) : nil
    }

    func connectionChanged(from transmitter: BluetoothTransmitter) {
        guard self.transmitter === transmitter else { return }
        refresh()
    }

    func recordActivity(_ message: String) {
        let message = String(message.prefix(300))
        guard activity.last?.message != message else { return }
        activity = Array((activity + [Activity(id: UUID(), date: Date(), message: message)]).suffix(Self.maximumActivityEntries))
        // A diagnostic write failure must never affect collection or transfer safety.
        try? Libre2JournalFile.save(activity, to: activityURL)
    }

    func inspectUnresolvedReadings() { requestHistoryCleanup(.inspect) }
    func deleteUnresolvedReadings(_ confirmed: Libre2UnresolvedReadings) { requestHistoryCleanup(.delete(confirmed)) }

    private func requestHistoryCleanup(_ request: Libre2HistoryCleanupRequest) {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            historyStatus = "Open the Watch app to inspect or delete unresolved readings."
            return
        }
        do {
            let message = try request.dictionary
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    do {
                        if let error = reply["error"] as? String { throw Libre2ConnectionError(error) }
                        let unresolved = try Libre2UnresolvedReadings.decode(reply)
                        self.unresolvedReadings = unresolved
                        self.historyStatus = "Unresolved readings on Watch: \(unresolved.count)"
                    } catch { self.historyStatus = error.localizedDescription }
                }
            }, errorHandler: { error in
                DispatchQueue.main.async { self.historyStatus = error.localizedDescription }
            })
        } catch { historyStatus = error.localizedDescription }
    }

    private init() {
        activity = Array(((try? Libre2JournalFile.load([Activity].self, from: activityURL, fallback: [])) ?? []).suffix(Self.maximumActivityEntries))
        phase = store.snapshot?.phase
        let initialStatus: String
        switch phase {
        case .phone: initialStatus = "iPhone selected"
        case .preparingWatch: initialStatus = "Watch preparation pending"
        case .watch: initialStatus = "Watch selected"
        case .returningToPhone: initialStatus = "Return to iPhone pending"
        case nil: initialStatus = "Saved selection is unreadable. Scan the sensor on the phone."
        }
        // Restoring the selection is not a new activity event.
        _status = Published(initialValue: initialStatus)
        transferFailed = phase == nil || phase == .preparingWatch || phase == .returningToPhone
    }

    func refresh() {
        let selection = store.snapshot?.phase
        if phase != selection { phase = selection }
        let watchReachable = WCSession.default.activationState == .activated && WCSession.default.isReachable
        if reachable != watchReachable {
            reachable = watchReachable
            if settingsVisible || hasExperiment {
                recordActivity(watchReachable ? "Watch app reachable" : "Watch app unreachable")
            }
        }
        let connected = transmitter?.getConnectionStatus() == .connected
        if phoneConnected != connected {
            phoneConnected = connected
            if settingsVisible || hasExperiment {
                recordActivity(connected ? "iPhone sensor connected" : "iPhone sensor disconnected")
            }
        }
        let configured = transmitter != nil
        if sensorConfigured != configured { sensorConfigured = configured }
        let native = transmitter?.isWebOOPEnabled() == true
        if nativeAlgorithmEnabled != native { nativeAlgorithmEnabled = native }
        let unlock = !UserDefaults.standard.suppressUnLockPayLoad
        if unlockPayloadEnabled != unlock { unlockPayloadEnabled = unlock }
        let recent = lastReading.map { Date().timeIntervalSince($0) < 180 } ?? false
        if recentReading != recent { recentReading = recent }
    }

    private var canSwitchToWatch: Bool {
        recentReading && reachable && phoneConnected && nativeAlgorithmEnabled && unlockPayloadEnabled
    }

    func received(_ readings: [GlucoseData], from transmitter: CGMLibre2Transmitter) {
        guard self.transmitter === transmitter else { return }
        if let latest = readings.map({ $0.timeStamp }).max() { lastReading = latest }
        refresh()
    }

    private func switchToWatch() {
        refresh()
        guard !busy, phase == .phone, canSwitchToWatch, let transmitter = transmitter else { return }
        do {
            let id = UUID()
            let session = try transmitter.watchSession(id: id)
            try store.select(.preparingWatch, sessionID: id)
            try session.save(to: store.sessionURL)
            operationID = UUID()
            busy = true
            transferFailed = false
            status = "Preparing Watch"
            refresh()
            guard let registerHistorySession = registerHistorySession else { throw Libre2HistoryError.unavailable }
            let operation = operationID!
            registerHistorySession(session) { [weak self, weak transmitter] result in
                guard let self = self, let transmitter = transmitter, self.current(session.id, operation) else { return }
                do {
                    try result.get()
                    self.prepare(session, transmitter: transmitter, operation: operation)
                } catch { self.failed(error) }
            }
        } catch { failed(error) }
    }

    private func prepare(_ session: Libre2WatchSession, transmitter: CGMLibre2Transmitter, operation: UUID) {
        Libre2ConnectionMessage(kind: .prepare, session: session, id: session.id).send { [weak self, weak transmitter] result in
            guard let self = self, let transmitter = transmitter, self.current(session.id, operation) else { return }
            do {
                let reply = try result.get()
                guard reply.kind == .ready, reply.id == session.id else { throw Libre2ConnectionError("Unexpected preparation reply.") }
                try self.store.select(.watch, sessionID: session.id)
                self.status = "Disconnecting iPhone"
                self.refresh()
                // Wait for xDrip's local release; other apps can still hold the physical link.
                transmitter.suspendConnection { [weak self, weak transmitter] in
                    guard let self = self, let transmitter = transmitter, self.current(session.id, operation) else { return }
                    do {
                        let final = try transmitter.watchSession(id: session.id)
                        try final.save(to: self.store.sessionURL)
                        // A phone reconnect during PREPARE may have consumed another counter.
                        // Refresh the prepared Watch before activation, now that the phone is stopped.
                        if final.unlockCount != session.unlockCount {
                            self.prepare(final, transmitter: transmitter, operation: operation)
                        } else {
                            self.activate(final.id, operation: operation)
                        }
                    } catch { self.failed(error) }
                }
            } catch { self.failed(error) }
        }
    }

    private func activate(_ id: UUID, operation: UUID) {
        status = "Activating Watch"
        Libre2ConnectionMessage(kind: .activate, id: id).send { [weak self] result in
            guard let self = self, self.current(id, operation) else { return }
            do {
                let reply = try result.get()
                guard reply.kind == .acknowledged, reply.id == id else { throw Libre2ConnectionError("Unexpected activation reply.") }
                self.busy = false
                self.status = "Watch selected"
                self.refresh()
            } catch { self.failed(error) }
        }
    }

    private func returnToPhone() {
        guard !busy, let id = store.snapshot?.sessionID else { return }
        operationID = UUID()
        let operation = operationID!
        busy = true
        transferFailed = false
        status = "Stopping Watch collection"
        do { try store.select(.returningToPhone, sessionID: id); refresh() }
        catch { failed(error); return }
        Libre2ConnectionMessage(kind: .returnPrepare, id: id).send { [weak self] result in
            guard let self = self, self.current(id, operation) else { return }
            do {
                let reply = try result.get()
                guard reply.kind == .ready, reply.id == id, let returned = reply.session,
                      returned.id == id else { throw Libre2ConnectionError("Unexpected return preparation reply.") }
                let previous = try Libre2WatchSession.load(from: self.store.sessionURL)
                guard returned.sensorUID == previous.sensorUID, returned.patchInfo == previous.patchInfo,
                      returned.unlockCode == previous.unlockCode, returned.unlockCount >= previous.unlockCount else {
                    throw Libre2ConnectionError("Returned sensor credentials or counter do not match.")
                }
                guard returned.unlockCount < UInt16.max,
                      returned.unlockCode <= UInt32.max - UInt32(returned.unlockCount) - 1 else {
                    throw Libre2ConnectionError("The unlock counter is exhausted. Use an ordinary NFC scan on the phone.")
                }
                // This durable copy also restores the phone counter if the app exits before COMMIT.
                try returned.save(to: self.store.sessionURL)
                self.status = "Committing return to iPhone"
                Libre2ConnectionMessage(kind: .returnCommit, id: id).send { [weak self] result in
                    guard let self = self, self.current(id, operation) else { return }
                    do {
                        let reply = try result.get()
                        guard reply.kind == .acknowledged, reply.id == id else { throw Libre2ConnectionError("Unexpected return commit reply.") }
                        UserDefaults.standard.libreActiveSensorUnlockCount = max(UserDefaults.standard.libreActiveSensorUnlockCount, returned.unlockCount)
                        try self.store.select(.phone, sessionID: id)
                        self.busy = false
                        self.status = "iPhone selected"
                        self.transmitter?.resumeConnection()
                        self.refresh()
                    } catch { self.failed(error) }
                }
            } catch { self.failed(error) }
        }
    }

    /// Called only after successful NFC enable-streaming; cancelled/failed scans do not transfer control.
    func sensorProvisioned() {
        guard store.snapshot?.sessionID != nil || store.snapshot == nil else { return }
        do {
            try store.resetToPhone()
            operationID = nil
            busy = false
            transferFailed = false
            status = "iPhone selected by NFC scan"
            publishRevocations()
            transmitter?.resumeConnection(startConnecting: false)
            refresh()
        } catch { failed(error) }
    }

    func publishRevocations() {
        guard WCSession.default.activationState == .activated,
              let ids = store.snapshot?.retiredIDs, !ids.isEmpty else { return }
        do {
            let message = Libre2ConnectionMessage(kind: .revoke, retiredIDs: ids)
            let payload = try message.dictionary()
            var context = WCSession.default.applicationContext
            context.merge(payload) { _, new in new }
            try WCSession.default.updateApplicationContext(context)
            // Context carries the latest reset across app restarts; live messaging stops a reachable Watch now.
            if WCSession.default.isReachable { message.send { _ in } }
        } catch { status = "NFC reset saved; Watch reset delivery pending: \(error.localizedDescription)" }
    }

    func cancelTransfer() {
        operationID = nil
        busy = false
        transferFailed = true
        status = "Transfer interrupted. Return to iPhone or use an ordinary NFC scan."
        refresh()
    }

    private func current(_ id: UUID, _ operation: UUID) -> Bool {
        operationID == operation && store.snapshot?.sessionID == id
    }

    private func failed(_ error: Error) {
        busy = false
        transferFailed = true
        status = error.localizedDescription
        refresh()
    }
}
