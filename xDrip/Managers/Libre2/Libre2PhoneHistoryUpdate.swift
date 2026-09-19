import Foundation

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
