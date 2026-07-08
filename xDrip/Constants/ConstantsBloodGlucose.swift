import Foundation

enum ConstantsBloodGlucose {
    static let mmollToMgdl = 18.01801801801802
    static let mgDlToMmoll = 0.0555
    static let libreMultiplier = 117.64705

    /// Minimum delay between a reading timestamp and when it is received/stored before it is treated as backfilled.
    static let minimumSecondsToConsiderAsBackfillDelay = TimeInterval(30)
}
