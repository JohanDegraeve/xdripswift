import Foundation
import os
import WatchConnectivity
import WatchKit

/// Event-driven history delivery using the host's WCSession. No display polling or extra
/// background runtime: Apple schedules queued transfers when the companion is unavailable.
final class Libre2WatchHistorySync {
    static let shared = Libre2WatchHistorySync()
    private let log = Logger(subsystem: "xDrip", category: "Libre2WatchHistorySync")
    private var queue: Libre2HistoryQueue?
    private var sendingBatchID: UUID?
    private var lastAttempt: (id: UUID, date: Date)?
    private var lastLatestAttempt: (id: String, date: Date)?
    private var lastReachability: Bool?
    private var activationObserver: NSObjectProtocol?
    private let now: () -> Date

    init(queue: Libre2HistoryQueue? = nil, now: @escaping () -> Date = Date.init) {
        self.queue = queue
        self.now = now
        activationObserver = NotificationCenter.default.addObserver(
            forName: WKExtension.applicationDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.resume() }
    }

    deinit {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }

    func resume() {
        lastAttempt = nil
        lastLatestAttempt = nil
        flush()
    }

    func collect(_ sample: GlucoseData, sensorMinute: UInt16, session: Libre2WatchSession) {
        do {
            let reading = Libre2HistoryReading(sessionID: session.id, sensorUID: session.sensorUID,
                sensorMinute: sensorMinute, date: sample.timeStamp, glucose: sample.glucoseLevelRaw)
            try outbox().append(reading)
            flush()
        } catch { report(error) }
    }

    /// Called for new measurements and WCSession activation/reachability changes.
    func flush() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let reachable = session.isReachable
        if reachable && lastReachability != true {
            lastAttempt = nil
            lastLatestAttempt = nil
        }
        lastReachability = reachable
        do { try publishLatestReadingContext() } catch { report(error) }
        do {
            // Latest delivery is independent of every history batch and its callbacks.
            if reachable { try sendLatestReading() }
            guard let batch = try outbox().nextBatch() else { return }
            guard sendingBatchID == nil else { return }
            // Leave an existing background transfer to WatchConnectivity. Restored
            // reachability sends the latest reading, not a second copy of this batch.
            if session.outstandingUserInfoTransfers.contains(where: {
                (try? Libre2HistoryBatch.decode($0.userInfo).id) == batch.id
            }) {
                return
            }
            guard try outbox().canRetryBackgroundTransfer(at: now()) else { return }
            let dictionary = try batch.dictionary
            if reachable {
                if let lastAttempt, lastAttempt.id == batch.id, now().timeIntervalSince(lastAttempt.date) < 60 {
                    return
                }
                lastAttempt = (batch.id, now())
                sendingBatchID = batch.id
                session.sendMessage(dictionary, replyHandler: { reply in
                    DispatchQueue.main.async {
                        if self.sendingBatchID == batch.id { self.sendingBatchID = nil }
                        if !self.receive(reply) {
                            let error = reply["error"] as? String ?? Libre2HistoryError.invalidBatch.localizedDescription
                            self.record("History sync: \(error)")
                        }
                    }
                }, errorHandler: { error in
                    DispatchQueue.main.async {
                        if self.sendingBatchID == batch.id { self.sendingBatchID = nil }
                        // Interactive delivery is best effort. The durable outbox remains until
                        // an import acknowledgement arrives through either transport.
                        if self.queue?.state.batch?.id == batch.id, session.activationState == .activated {
                            self.queueTransfer(dictionary, batchID: batch.id)
                        }
                        self.report(error)
                    }
                })
            } else {
                queueTransfer(dictionary, batchID: batch.id)
            }
        } catch { report(error) }
    }

    /// Keep only the newest pending value in the background context, independently of
    /// history acknowledgements and live reachability. WCSession retains this context
    /// across launches; comparing it also prevents older remaining history replacing it.
    private func publishLatestReadingContext() throws {
        guard let reading = try outbox().state.pending.max(by: { $0.date < $1.date }) else { return }
        let session = WCSession.default
        if session.applicationContext[Libre2HistoryBatch.latestKey] as? Bool == true,
            let published = try? Libre2HistoryBatch.decode(session.applicationContext).readings.first,
            published.date >= reading.date { return }
        do {
            try session.updateApplicationContext(Libre2HistoryBatch(readings: [reading]).latestDictionary)
        } catch {
            report(error)
            // A failed context update must not prevent live delivery or history submission.
            // The next existing delivery event can retry; the journal remains untouched.
        }
    }

    private func sendLatestReading() throws {
        guard let reading = try outbox().state.pending.max(by: { $0.date < $1.date }) else { return }
        // Repeated frames/events may describe the same sensor minute. New measurements
        // bypass this retry throttle, even if a previous live reply never arrives.
        if let lastLatestAttempt, lastLatestAttempt.id == reading.id,
            now().timeIntervalSince(lastLatestAttempt.date) < 60 { return }
        let dictionary = try Libre2HistoryBatch(readings: [reading]).latestDictionary
        lastLatestAttempt = (reading.id, now())
        WCSession.default.sendMessage(dictionary, replyHandler: { reply in
            DispatchQueue.main.async {
                if let error = reply["error"] as? String {
                    self.record("Latest reading sync: \(error)")
                }
                // History alone removes saved readings from the journal. Neither success,
                // supersession nor failure here can release or block a history batch.
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.report(error)
            }
        })
    }

    private func queueTransfer(_ dictionary: [String: Any], batchID: UUID) {
        let session = WCSession.default
        guard !session.outstandingUserInfoTransfers.contains(where: {
            (try? Libre2HistoryBatch.decode($0.userInfo).id) == batchID
        }) else { return }
        do {
            guard try outbox().reserveBackgroundTransfer(batchID: batchID, at: now()) else { return }
        } catch {
            report(error)
            return
        }
        session.transferUserInfo(dictionary)
    }

    @discardableResult
    func receive(_ dictionary: [String: Any]) -> Bool {
        guard dictionary[Libre2HistoryAcknowledgement.key] != nil || dictionary[Libre2HistoryRejection.key] != nil else { return false }
        do {
            let resolvedBatchID: UUID
            if dictionary[Libre2HistoryRejection.key] != nil {
                let rejection = try Libre2HistoryRejection.decode(dictionary)
                try outbox().retainUnresolved(rejection)
                resolvedBatchID = rejection.batchID
                self.record(
                    "History sync: retained \(rejection.readingIDs.count) unmatched readings on Watch; continuing with other readings. batch=\(resolvedBatchID.uuidString.prefix(8))")
            } else {
                let acknowledgement = try Libre2HistoryAcknowledgement.decode(dictionary)
                try outbox().acknowledge(acknowledgement)
                resolvedBatchID = acknowledgement.batchID
                self.record("History saved on iPhone (\(acknowledgement.readingIDs.count) readings). batch=\(resolvedBatchID.uuidString.prefix(8))")
            }
            // Either route can finish first. Only release this batch, after saving its result;
            // late interactive callbacks must not clear a newer in-flight batch.
            if sendingBatchID == resolvedBatchID { sendingBatchID = nil }
            for transfer in WCSession.default.outstandingUserInfoTransfers where
                (try? Libre2HistoryBatch.decode(transfer.userInfo).id) == resolvedBatchID {
                transfer.cancel()
            }
        } catch Libre2HistoryError.staleAcknowledgement {
            // Duplicate delivery is normal. It must not clear a newer batch.
        } catch {
            report(error)
            return true
        }
        // Drain remaining readings immediately; stale replies cannot resolve a newer batch.
        flush()
        return true
    }

    /// Uses the existing interactive message delegate; independent of the active sensor.
    @discardableResult
    func receiveCleanup(_ dictionary: [String: Any], reply: ([String: Any]) -> Void) -> Bool {
        guard dictionary[Libre2HistoryCleanupRequest.key] != nil else { return false }
        do {
            let request = try Libre2HistoryCleanupRequest.decode(dictionary)
            let queue = try outbox()
            if case .delete(let confirmed) = request {
                try queue.deleteUnresolved(confirmed)
                self.record("Deleted \(confirmed.count) unresolved readings from Watch.")
            }
            // Success is acknowledged only after the journal has been saved.
            reply(try queue.unresolvedReadings.dictionary)
        } catch {
            report(error)
            reply(["error": error.localizedDescription])
        }
        return true
    }

    private func outbox() throws -> Libre2HistoryQueue {
        if let queue { return queue }
        let loaded = try Libre2HistoryQueue()
        queue = loaded
        return loaded
    }

    private func record(_ message: String) { log.info("\(message, privacy: .public)") }

    private func report(_ error: Error) {
        self.record("History sync: \(error.localizedDescription)")
    }
}
