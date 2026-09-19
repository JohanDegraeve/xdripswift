import Foundation

/// Phone-local mappings survive completed handoffs and sensor replacement. Never attach a
/// delayed upload to whichever sensor happens to be active when WatchConnectivity delivers it.
final class Libre2HistoryRegistry {
    struct Entry: Codable, Equatable {
        let sessionID: UUID
        let sensorUID: Data
        let sensorID: String
        let preparedAt: Date
    }

    private(set) var entries: [Entry]
    private let persist: ([Entry]) throws -> Void

    init(entries: [Entry] = [], persist: @escaping ([Entry]) throws -> Void) {
        self.entries = entries
        self.persist = persist
    }

    convenience init(url: URL = Libre2JournalFile.url("phone-history-sensors.json")) throws {
        let entries = try Libre2JournalFile.load([Entry].self, from: url, fallback: [])
        self.init(entries: entries) { try Libre2JournalFile.save($0, to: url) }
    }

    func register(_ session: Libre2WatchSession, sensorID: String, preparedAt: Date = Date()) throws {
        guard !sensorID.isEmpty else { throw Libre2HistoryError.unknownSensor }
        let entry = Entry(sessionID: session.id, sensorUID: session.sensorUID,
                          sensorID: sensorID, preparedAt: preparedAt)
        if let existing = entries.first(where: { $0.sessionID == session.id }) {
            guard existing.sensorUID == entry.sensorUID && existing.sensorID == entry.sensorID else { throw Libre2HistoryError.unknownSensor }
            return
        }
        let next = entries + [entry]
        try persist(next)
        entries = next
    }

    func sensorID(for reading: Libre2HistoryReading) throws -> String {
        guard let entry = entries.first(where: { $0.sessionID == reading.sessionID }),
            entry.sensorUID == reading.sensorUID,
            reading.date >= entry.preparedAt.addingTimeInterval(-180)
        else { throw Libre2HistoryError.unknownSensor }
        return entry.sensorID
    }
}
