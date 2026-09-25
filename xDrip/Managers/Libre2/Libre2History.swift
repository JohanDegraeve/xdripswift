import Foundation

/// Uploads contain converted mg/dL, never sensor credentials or display-clamped values.
/// Sensor minutes identify measurements across reconnects, retries and separate handoffs.
struct Libre2HistoryReading: Codable, Equatable {
    let sessionID: UUID
    let sensorUID: Data
    let sensorMinute: UInt16
    let date: Date
    let glucose: Double

    var sensorKey: String { sensorUID.map { String(format: "%02x", $0) }.joined() }
    var id: String { "direct-libre-watch:\(sensorKey):\(sensorMinute)" }

    func validate(now: Date = Date()) throws {
        guard sensorUID.count == 8, sensorMinute >= 60,
            date.timeIntervalSince1970.isFinite, date > Date(timeIntervalSince1970: 0),
            date <= now.addingTimeInterval(300), glucose.isFinite,
            glucose > 0, glucose < 3000
        else { throw Libre2HistoryError.invalidReading }
    }
}

struct Libre2HistoryBatch: Codable, Equatable {
    static let key = "libre2HistoryBatch"
    // A single-reading priority message uses the same validation and import format.
    // Its reply never acknowledges the Watch's durable history batch.
    static let latestKey = "libre2LatestReading"
    static let maximumReadings = 120
    let version: Int
    let id: UUID
    let readings: [Libre2HistoryReading]

    init(readings: [Libre2HistoryReading]) {
        version = 1
        id = UUID()
        self.readings = readings
    }

    func validate(now: Date = Date()) throws {
        guard version == 1, !readings.isEmpty, readings.count <= Self.maximumReadings,
            Set(readings.map(\.id)).count == readings.count
        else { throw Libre2HistoryError.invalidBatch }
        try readings.forEach { try $0.validate(now: now) }
    }

    var dictionary: [String: Any] { get throws { [Self.key: try JSONEncoder().encode(self)] } }

    var latestDictionary: [String: Any] {
        get throws {
            guard readings.count == 1 else { throw Libre2HistoryError.invalidBatch }
            var message = try dictionary
            message[Self.latestKey] = true
            return message
        }
    }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data, data.count <= 100_000 else {
            throw Libre2HistoryError.invalidBatch
        }
        let batch = try JSONDecoder().decode(Self.self, from: data)
        try batch.validate()
        if dictionary[latestKey] != nil {
            guard dictionary[latestKey] as? Bool == true, batch.readings.count == 1 else {
                throw Libre2HistoryError.invalidBatch
            }
        }
        return batch
    }
}

/// This is an application acknowledgement, sent only after the phone's database save succeeds.
struct Libre2HistoryAcknowledgement: Codable {
    static let key = "libre2HistoryAcknowledgement"
    let batchID: UUID
    let readingIDs: [String]

    init(batch: Libre2HistoryBatch) {
        batchID = batch.id
        readingIDs = batch.readings.map(\.id)
    }

    var dictionary: [String: Any] { get throws { [Self.key: try JSONEncoder().encode(self)] } }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data, data.count <= 100_000 else {
            throw Libre2HistoryError.invalidBatch
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

/// A sensor-matching rejection, never a save acknowledgement or a transient transport error.
/// Only the listed readings are retained separately; the rest of the batch can be retried.
struct Libre2HistoryRejection: Codable, Error {
    static let key = "libre2HistoryRejection"
    let batchID: UUID
    let readingIDs: [String]

    var dictionary: [String: Any] {
        get throws {
            [Self.key: try JSONEncoder().encode(self),
             "error": Libre2HistoryError.unknownSensor.localizedDescription]
        }
    }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data, data.count <= 100_000 else {
            throw Libre2HistoryError.invalidBatch
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

/// Interactive phone controls only. Cleanup is never queued for background delivery.
enum Libre2HistoryCleanupRequest: Codable, Equatable {
    static let key = "libre2HistoryCleanup"
    case inspect
    case delete(Libre2UnresolvedReadings)

    var dictionary: [String: Any] { get throws { [Self.key: try JSONEncoder().encode(self)] } }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data, data.count <= 1_000 else {
            throw Libre2HistoryError.invalidBatch
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

/// A count tied to one revision of the Watch's unresolved collection, not to sensor ownership.
struct Libre2UnresolvedReadings: Codable, Equatable, Identifiable {
    static let key = "libre2UnresolvedReadings"
    let id: UUID
    let count: Int

    var dictionary: [String: Any] { get throws { [Self.key: try JSONEncoder().encode(self)] } }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data, data.count <= 1_000 else {
            throw Libre2HistoryError.invalidBatch
        }
        let readings = try JSONDecoder().decode(Self.self, from: data)
        guard readings.count >= 0 else { throw Libre2HistoryError.invalidBatch }
        return readings
    }
}

enum Libre2HistoryError: LocalizedError {
    case invalidReading, invalidBatch, unknownSensor, staleAcknowledgement, unavailable, staleCleanup, storageFull

    var errorDescription: String? {
        switch self {
        case .invalidReading: return "Direct Libre history contains an invalid reading."
        case .invalidBatch: return "Direct Libre history format is not supported."
        case .unknownSensor: return "Direct Libre history could not be matched to its original iPhone sensor. Readings remain on the Watch."
        case .staleAcknowledgement: return "Ignored an outdated Direct Libre history acknowledgement."
        case .unavailable: return "Direct Libre history storage is unavailable."
        case .storageFull: return "Watch reading storage is full. Synchronise with the phone or delete unresolved readings."
        case .staleCleanup: return "The unresolved readings changed or the Watch app restarted. Check the count again before deleting."
        }
    }
}

/// A saved historical batch is not necessarily a new current reading.
/// Consume only after the final database save; duplicate replies must not repeat alerts.
struct Libre2PhoneHistoryUpdate {
    static let currentReadingDateKey = "directLibreCurrentReadingDate"
    static let changedSensorIDsKey = "directLibreChangedSensorIDs"
    private var lastNotifiedDate: Date?

    mutating func consume(_ date: Date?, maximumAge: TimeInterval, now: Date = Date()) -> Date? {
        guard let date, date.timeIntervalSince1970.isFinite,
            date <= now, now.timeIntervalSince(date) < maximumAge,
            lastNotifiedDate.map({ date > $0 }) ?? true
        else { return nil }
        lastNotifiedDate = date
        return date
    }
}
