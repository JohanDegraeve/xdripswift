import Foundation

/// One small selection record, separate from the counter file used by the collector.
/// Missing data means ordinary phone collection; unreadable existing data fails closed.
final class Libre2ConnectionStore {
    enum Phase: String, Codable { case phone, preparingWatch, watch, returningToPhone }
    struct Selection: Codable {
        var phase: Phase = .phone
        var sessionID: UUID?
        var retiredIDs: Set<UUID> = []
        var allowsPhone: Bool { phase == .phone || phase == .preparingWatch }
        var allowsWatch: Bool { phase == .watch }
    }

    static let shared = Libre2ConnectionStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DirectLibre", isDirectory: true))
    static let didChange = Notification.Name("Libre2ConnectionStoreDidChange")
    let sessionURL: URL
    private let selectionURL: URL
    private let lock = NSLock()
    private var selection: Selection?

    init(directory: URL) {
        sessionURL = directory.appendingPathComponent("session.json")
        selectionURL = directory.appendingPathComponent("selection.json")
        if FileManager.default.fileExists(atPath: selectionURL.path) {
            selection = try? JSONDecoder().decode(Selection.self, from: Data(contentsOf: selectionURL))
        } else {
            selection = Selection()
        }
    }

    var snapshot: Selection? {
        lock.lock(); defer { lock.unlock() }
        return selection
    }

    func select(_ phase: Phase, sessionID: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        guard var next = selection else { throw Libre2ConnectionError("Saved selection is unreadable. Scan the sensor on the phone.") }
        if phase == .phone && next.phase == .phone && next.sessionID == sessionID { return }
        guard !next.retiredIDs.contains(sessionID) else {
            throw Libre2ConnectionError("This transfer has been retired. Use the current phone selection or scan the sensor again.")
        }
        if phase == .preparingWatch {
            guard next.phase == .phone || (next.phase == .preparingWatch && next.sessionID == sessionID) else {
                throw Libre2ConnectionError("Return the current connection before preparing another transfer.")
            }
        } else {
            guard next.sessionID == sessionID else { throw Libre2ConnectionError("Stale Libre transfer rejected.") }
            let allowed: Bool
            switch phase {
            case .watch: allowed = next.phase == .preparingWatch || next.phase == .watch
            case .returningToPhone: allowed = next.phase != .phone
            case .phone: allowed = next.phase == .returningToPhone
            case .preparingWatch: allowed = false
            }
            guard allowed else { throw Libre2ConnectionError("Unexpected Libre transfer phase.") }
        }
        if phase == .phone { next.retiredIDs.insert(sessionID) }
        next.phase = phase
        next.sessionID = sessionID
        try save(next)
    }

    /// NFC is authoritative. A reset also works when an old selection file is unreadable.
    func resetToPhone() throws {
        lock.lock(); defer { lock.unlock() }
        var next = selection ?? Selection()
        if let id = next.sessionID { next.retiredIDs.insert(id) }
        if let session = try? Libre2WatchSession.load(from: sessionURL) { next.retiredIDs.insert(session.id) }
        next.phase = .phone
        next.sessionID = nil
        try save(next)
    }

    /// Receiving an old revocation must not stop a newer, unrelated session.
    func revoke(_ ids: Set<UUID>) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        var next = selection ?? Selection()
        next.retiredIDs.formUnion(ids)
        let stop = next.sessionID.map { ids.contains($0) } ?? false
        if stop { next.phase = .phone; next.sessionID = nil }
        try save(next)
        return stop
    }

    private func save(_ next: Selection) throws {
        try FileManager.default.createDirectory(at: selectionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: selectionURL, options: .atomic)
        selection = next
        // Observers may read snapshot. Deliver after releasing the store lock.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
    }
}

struct Libre2ConnectionError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
