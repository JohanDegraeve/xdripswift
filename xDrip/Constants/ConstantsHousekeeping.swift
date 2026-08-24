import Foundation

enum ConstantsHousekeeping {
    /// The only supported retention/import blocks, shared by housekeeping and data import UI.
    static let retentionPeriodsInDays = [7, 30, 90, 180, 365]

    /// New installs continue to use the established recommended retention period.
    static let defaultRetentionPeriodInDays = 90

    /// Minimum time to keep bgReadings and calibrations and treatments
    static let minimumRetentionPeriodInDays = retentionPeriodsInDays[0]

    /// Maximum time to keep bgReadings and calibrations and treatments
    static let maximumRetentionPeriodInDays = retentionPeriodsInDays[retentionPeriodsInDays.count - 1]

    /// Converts legacy/custom values to the nearest supported block, preferring the shorter tie.
    static func normalizedRetentionPeriodInDays(_ days: Int) -> Int {
        guard days > 0 else { return defaultRetentionPeriodInDays }
        return retentionPeriodsInDays.min {
            let leftDistance = abs($0 - days)
            let rightDistance = abs($1 - days)
            return leftDistance == rightDistance ? $0 < $1 : leftDistance < rightDistance
        } ?? defaultRetentionPeriodInDays
    }

}
