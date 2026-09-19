import Combine
import CoreBluetooth
import Foundation
import WatchConnectivity

/// Owns the Watch collector's lifetime; it starts only after an ACTIVATE from the phone.
final class Libre2WatchConnection: NSObject, ObservableObject, BluetoothTransmitterDelegate {
    static let shared = Libre2WatchConnection()
    private let store = Libre2ConnectionStore.shared
    private var transmitter: Libre2WatchTransmitter?
    private var restarting = false
    var readingsReceived: (([GlucoseData], UInt16) -> Void)?
    @Published private(set) var status = "iPhone selected"
    @Published private(set) var connected = false
    @Published private(set) var direct = false

    func restore() {
        // Apply the latest authoritative reset before restarting a saved Watch selection.
        let context = WCSession.default.receivedApplicationContext
        if context[Libre2ConnectionMessage.key] != nil { receive(context, reply: { _ in }) }
        direct = store.snapshot?.phase != .phone && store.snapshot != nil
        if store.snapshot?.phase == .preparingWatch { status = "Prepared" }
        if store.snapshot?.phase == .returningToPhone { status = "Returning" }
        if store.snapshot?.allowsWatch == true { startCollector() }
    }

    func receive(_ dictionary: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        do {
            let message = try Libre2ConnectionMessage.decode(dictionary)
            if message.kind == .revoke {
                let stopped = try store.revoke(message.retiredIDs ?? [])
                if stopped { stopCollector { self.status = "iPhone selected"; self.direct = false } }
                Libre2ConnectionMessage.reply(.success(.init(kind: .acknowledged)), to: reply)
                return
            }
            guard let id = message.id else { throw Libre2ConnectionError("Missing transfer identifier.") }
            switch message.kind {
            case .prepare:
                guard let session = message.session, session.id == id,
                      let selection = store.snapshot, !selection.retiredIDs.contains(id),
                      selection.phase == .phone || (selection.phase == .preparingWatch && selection.sessionID == id) else {
                    throw Libre2ConnectionError("The Watch cannot prepare this transfer. Return collection or scan on the phone.")
                }
                guard transmitter == nil else { throw Libre2ConnectionError("Previous Watch connection is still disconnecting. Retry preparation.") }
                var prepared = session
                try prepared.validate()
                if let existing = try? Libre2WatchSession.load(from: store.sessionURL), existing.id == id {
                    guard existing.sensorUID == session.sensorUID, existing.patchInfo == session.patchInfo,
                          existing.unlockCode == session.unlockCode else { throw Libre2ConnectionError("Sensor credentials changed during preparation.") }
                    prepared.unlockCount = max(existing.unlockCount, session.unlockCount)
                }
                // Create the directory/selection first. A failed session save cannot enable BLE.
                try store.select(.preparingWatch, sessionID: id)
                try prepared.save(to: store.sessionURL)
                direct = true
                status = "Prepared"
                Libre2ConnectionMessage.reply(.success(.init(kind: .ready, id: id)), to: reply)
            case .activate:
                guard let selection = store.snapshot, selection.sessionID == id,
                      selection.phase == .preparingWatch || selection.phase == .watch,
                      try Libre2WatchSession.load(from: store.sessionURL).id == id else {
                    throw Libre2ConnectionError("Stale Watch activation rejected.")
                }
                try store.select(.watch, sessionID: id)
                try startCollectorIfNeeded()
                Libre2ConnectionMessage.reply(.success(.init(kind: .acknowledged, id: id)), to: reply)
            case .returnPrepare:
                guard let selection = store.snapshot, selection.sessionID == id else {
                    throw Libre2ConnectionError("Stale return request rejected.")
                }
                if selection.phase != .phone { try store.select(.returningToPhone, sessionID: id) }
                status = "Returning"
                if transmitter == nil && (selection.phase == .watch || selection.phase == .returningToPhone) {
                    // Recreate a disabled collector solely to release a handle after an interrupted return.
                    transmitter = try Libre2WatchTransmitter(sessionURL: store.sessionURL, bluetoothTransmitterDelegate: self, readingsReceived: { _, _ in })
                }
                // Freeze first: a reconnect cannot advance the counter after it has been reported.
                stopCollector {
                    do {
                        guard self.store.snapshot?.sessionID == id else { throw Libre2ConnectionError("Transfer was reset.") }
                        let final = try Libre2WatchSession.load(from: self.store.sessionURL)
                        Libre2ConnectionMessage.reply(.success(.init(kind: .ready, session: final, id: id)), to: reply)
                    } catch { Libre2ConnectionMessage.reply(.failure(error), to: reply) }
                }
            case .returnCommit:
                guard let selection = store.snapshot, selection.sessionID == id,
                      selection.phase == .returningToPhone || selection.phase == .phone,
                      transmitter == nil else { throw Libre2ConnectionError("Watch release has not completed.") }
                try store.select(.phone, sessionID: id)
                direct = false
                status = "iPhone selected"
                Libre2ConnectionMessage.reply(.success(.init(kind: .acknowledged, id: id)), to: reply)
            default:
                throw Libre2ConnectionError("Unexpected Libre transfer message.")
            }
        } catch {
            status = error.localizedDescription
            Libre2ConnectionMessage.reply(.failure(error), to: reply)
        }
    }

    /// A manual retry replaces the collector so callbacks from the cancelled attempt
    /// cannot revive it. Persisted credentials/counter and device selection are retained.
    func restartConnection() {
        guard let selection = store.snapshot, selection.allowsWatch, !restarting else { return }
        guard let previous = transmitter else { startCollector(reuseKnownPeripheral: false); return }
        restarting = true
        connected = false
        status = "Restarting connection"
        previous.suspendConnection(waitForDisconnect: false) { [weak self, weak previous] in
            guard let self = self else { return }
            self.restarting = false
            guard let previous = previous, self.transmitter === previous else { return }
            // A return/NFC reset may have overtaken the tap. Its release owns cleanup.
            guard self.store.snapshot?.allowsWatch == true,
                  self.store.snapshot?.sessionID == selection.sessionID else { return }
            previous.prepareForRelease()
            self.transmitter = nil
            self.startCollector(reuseKnownPeripheral: false)
        }
    }

    private func startCollector(reuseKnownPeripheral: Bool = true) {
        do { try startCollectorIfNeeded(reuseKnownPeripheral: reuseKnownPeripheral) }
        catch { status = error.localizedDescription }
    }

    private func startCollectorIfNeeded(reuseKnownPeripheral: Bool = true) throws {
        guard store.snapshot?.allowsWatch == true else { return }
        direct = true
        guard transmitter == nil else { return }
        let expectedID = store.snapshot?.sessionID
        let session = try Libre2WatchSession.load(from: store.sessionURL)
        guard session.id == expectedID else {
            throw Libre2ConnectionError("Saved Watch session does not match the selected transfer.")
        }
        transmitter = try Libre2WatchTransmitter(sessionURL: store.sessionURL, bluetoothTransmitterDelegate: self, reuseKnownPeripheral: reuseKnownPeripheral) { [weak self] readings, age in
            guard let self = self, self.store.snapshot?.allowsWatch == true,
                  self.store.snapshot?.sessionID == expectedID else { return }
            if let latest = readings.max(by: { $0.timeStamp < $1.timeStamp }) {
                Libre2WatchHistorySync.shared.collect(latest, sensorMinute: age, session: session)
            }
            self.readingsReceived?(readings, age)
        }
        status = "Connecting"
        transmitter?.connect()
    }

    private func stopCollector(completion: @escaping () -> Void) {
        guard let transmitter = transmitter else { connected = false; completion(); return }
        transmitter.suspendConnection { [weak self, weak transmitter] in
            guard let self = self else { return }
            if self.transmitter === transmitter {
                transmitter?.prepareForRelease()
                self.transmitter = nil
                self.connected = false
            }
            completion()
        }
    }

    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        guard transmitter === bluetoothTransmitter, store.snapshot?.allowsWatch == true, !restarting else { return }
        bluetoothTransmitter.rememberDevice()
        connected = true
        status = "Direct connected"
    }
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        guard transmitter === bluetoothTransmitter else { return }
        connected = false
        status = store.snapshot?.phase == .returningToPhone ? "Returning" : "Connecting"
    }
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        guard transmitter === bluetoothTransmitter else { return }
        if state == .poweredOn && store.snapshot?.allowsWatch == true { bluetoothTransmitter.connect() }
        if state != .poweredOn { connected = false; status = "Bluetooth unavailable" }
    }
    func error(message: String) { status = message }
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {}
    func successfullyPaired() {}
    func pairingFailed() {}
    func heartBeat() {}
}
