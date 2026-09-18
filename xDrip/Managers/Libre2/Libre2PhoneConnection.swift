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
    private var lastReading: Date?
    private var operationID: UUID?
    @Published private(set) var phase: Libre2ConnectionStore.Phase?
    @Published private(set) var status = "iPhone selected"
    @Published private(set) var reachable = false
    @Published private(set) var busy = false
    @Published private(set) var recentReading = false

    private init() {
        phase = store.snapshot?.phase
        switch phase {
        case .phone: status = "iPhone selected"
        case .preparingWatch: status = "Watch preparation pending"
        case .watch: status = "Watch selected"
        case .returningToPhone: status = "Return to iPhone pending"
        case nil: status = "Saved selection is unreadable. Scan the sensor on the phone."
        }
    }

    func refresh() {
        phase = store.snapshot?.phase
        reachable = WCSession.default.activationState == .activated && WCSession.default.isReachable
        recentReading = lastReading.map { Date().timeIntervalSince($0) < 180 } ?? false
    }

    var canSwitchToWatch: Bool {
        recentReading && reachable && transmitter?.getConnectionStatus() == .connected &&
        transmitter?.isWebOOPEnabled() == true && !UserDefaults.standard.suppressUnLockPayLoad
    }

    func received(_ readings: [GlucoseData], from transmitter: CGMLibre2Transmitter) {
        guard self.transmitter === transmitter else { return }
        if let latest = readings.map({ $0.timeStamp }).max() { lastReading = latest }
        refresh()
    }

    func switchToWatch() {
        refresh()
        guard !busy, canSwitchToWatch, let transmitter = transmitter else { return }
        do {
            let id = store.snapshot?.phase == .preparingWatch ? store.snapshot?.sessionID ?? UUID() : UUID()
            let session = try transmitter.watchSession(id: id)
            try store.select(.preparingWatch, sessionID: id)
            try session.save(to: store.sessionURL)
            operationID = UUID()
            busy = true
            status = "Preparing Watch"
            refresh()
            prepare(session, transmitter: transmitter, operation: operationID!)
        } catch { failed(error) }
    }

    private func prepare(_ session: Libre2WatchSession, transmitter: CGMLibre2Transmitter, operation: UUID) {
        Libre2ConnectionMessage(kind: .prepare, session: session, id: session.id).send { [weak self, weak transmitter] result in
            guard let self = self, let transmitter = transmitter, self.current(session.id, operation) else { return }
            do {
                let reply = try result.get()
                guard reply.kind == .ready, reply.id == session.id else { throw Libre2ConnectionError("Unexpected preparation reply.") }
                try self.store.select(.watch, sessionID: session.id)
                self.status = "Stopping iPhone collection"
                self.refresh()
                transmitter.suspendConnection(waitForDisconnect: false) { [weak self, weak transmitter] in
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

    func returnToPhone() {
        guard !busy, let id = store.snapshot?.sessionID else { return }
        operationID = UUID()
        let operation = operationID!
        busy = true
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
        status = "Transfer interrupted. Return to iPhone or use an ordinary NFC scan."
        refresh()
    }

    private func current(_ id: UUID, _ operation: UUID) -> Bool {
        operationID == operation && store.snapshot?.sessionID == id
    }

    private func failed(_ error: Error) {
        busy = false
        status = error.localizedDescription
        refresh()
    }
}
