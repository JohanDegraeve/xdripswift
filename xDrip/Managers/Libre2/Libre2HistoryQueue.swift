import Foundation

/// Main-queue Watch outbox. Keep unacknowledged readings across return, NFC reset and restart.
/// Only the newest actual measurement from each BLE frame is collected; interpolated graph
/// points are deliberately excluded. This is not a sensor-history/backfill implementation.
final class Libre2HistoryQueue {
    // Recovery interval, not a delivery deadline. Collection/activation events drive retries.
    // At one actual measurement per minute, this holds over two weeks offline.
    // Never discard unacknowledged data silently when full.
    static let maximumStoredReadings = 22_000
    static let backgroundRetryInterval: TimeInterval = 5 * 60

    struct State: Codable, Equatable {
        var pending: [Libre2HistoryReading] = []
        var batch: Libre2HistoryBatch?
        var lastBackgroundSubmission: Date?
        var lastCollectedMinute: [String: UInt16] = [:]
        var unresolved: [Libre2HistoryReading] = []
    }

    private(set) var state: State
    private let persist: (State) throws -> Void
    private var unresolvedRevision = UUID()

    var unresolvedReadings: Libre2UnresolvedReadings {
        Libre2UnresolvedReadings(id: unresolvedRevision, count: state.unresolved.count)
    }

    init(state: State = State(), persist: @escaping (State) throws -> Void) {
        self.state = state
        self.persist = persist
    }

    convenience init(url: URL = Libre2JournalFile.url("watch-history.json")) throws {
        let state = try Libre2JournalFile.load(State.self, from: url, fallback: State())
        self.init(state: state) { try Libre2JournalFile.save($0, to: url) }
    }

    func append(_ reading: Libre2HistoryReading) throws {
        try reading.validate()
        if let minute = state.lastCollectedMinute[reading.sensorKey], minute >= reading.sensorMinute { return }
        guard state.pending.count + state.unresolved.count < Self.maximumStoredReadings else {
            throw Libre2HistoryError.storageFull
        }
        var next = state
        next.pending.append(reading)
        next.lastCollectedMinute[reading.sensorKey] = reading.sensorMinute
        try save(next)
    }

    /// The batch is immutable once sent: a late acknowledgement cannot delete newer readings.
    func nextBatch() throws -> Libre2HistoryBatch? {
        if let batch = state.batch { return batch }
        guard !state.pending.isEmpty else { return nil }
        var next = state
        next.batch = Libre2HistoryBatch(readings: Array(next.pending.prefix(Libre2HistoryBatch.maximumReadings)))
        next.lastBackgroundSubmission = nil
        try save(next)
        return next.batch
    }

    /// Completion of a WC transfer does not acknowledge storage. Keep this reservation
    /// with the immutable batch so foreground events and restarts cannot flood the phone.
    func canRetryBackgroundTransfer(at date: Date) -> Bool {
        guard let submitted = state.lastBackgroundSubmission else { return true }
        let elapsed = date.timeIntervalSince(submitted)
        // A wall-clock correction must not strand the journal behind a future timestamp.
        return !elapsed.isFinite || elapsed < 0 || elapsed >= Self.backgroundRetryInterval
    }

    func reserveBackgroundTransfer(batchID: UUID, at date: Date) throws -> Bool {
        guard state.batch?.id == batchID else { throw Libre2HistoryError.staleAcknowledgement }
        guard canRetryBackgroundTransfer(at: date) else { return false }
        var next = state
        next.lastBackgroundSubmission = date
        try save(next)
        return true
    }

    func acknowledge(_ acknowledgement: Libre2HistoryAcknowledgement) throws {
        guard let batch = state.batch, acknowledgement.batchID == batch.id,
            acknowledgement.readingIDs == batch.readings.map(\.id)
        else { throw Libre2HistoryError.staleAcknowledgement }
        var next = state
        let savedIDs = Set(acknowledgement.readingIDs)
        next.pending.removeAll { savedIDs.contains($0.id) }
        next.batch = nil
        next.lastBackgroundSubmission = nil
        try save(next)
    }

    /// Persist rejected readings before releasing the batch. No measurements are deleted or
    /// reassigned to a different sensor. Late replies cannot affect a subsequent batch.
    func retainUnresolved(_ rejection: Libre2HistoryRejection) throws {
        let rejectedIDs = Set(rejection.readingIDs)
        guard let batch = state.batch, rejection.batchID == batch.id,
            !rejectedIDs.isEmpty, rejectedIDs.count == rejection.readingIDs.count,
            rejectedIDs.isSubset(of: Set(batch.readings.map(\.id)))
        else { throw Libre2HistoryError.staleAcknowledgement }
        var next = state
        next.unresolved.append(contentsOf: next.pending.filter { rejectedIDs.contains($0.id) })
        next.pending.removeAll { rejectedIDs.contains($0.id) }
        next.batch = nil
        next.lastBackgroundSubmission = nil
        try save(next)
        unresolvedRevision = UUID()
    }

    /// Require the count the user confirmed. A restart, new rejection or prior deletion
    /// invalidates that confirmation. Pending uploads and collection deduplication stay intact.
    func deleteUnresolved(_ confirmed: Libre2UnresolvedReadings) throws {
        guard confirmed == unresolvedReadings else { throw Libre2HistoryError.staleCleanup }
        var next = state
        next.unresolved.removeAll()
        try save(next)
        unresolvedRevision = UUID()
    }

    private func save(_ next: State) throws {
        try persist(next)
        state = next
    }
}
