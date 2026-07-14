import Foundation
import os

/// Removes historical Core Data records according to the user's automatic retention policy.
final class HouseKeeper {
    private static let minimumRunInterval: TimeInterval = 24 * 60 * 60

    private let service: DataManagementService
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHouseKeeper)

    init(coreDataManager: CoreDataManager) {
        service = DataManagementService(coreDataManager: coreDataManager)
    }

    /// Starts housekeeping when it is enabled and has not already been attempted in the last day.
    func doAppStartUpHouseKeeping() {
        let defaults = UserDefaults.standard
        guard defaults.automaticHousekeepingEnabled else {
            trace(
                "in doAppStartUpHouseKeeping, automatic housekeeping is disabled",
                log: log,
                category: ConstantsLog.categoryHouseKeeper,
                type: .info
            )
            return
        }

        let retentionPeriodInDays = defaults.retentionPeriodInDays
        guard shouldRun(retentionPeriodInDays: retentionPeriodInDays, defaults: defaults) else { return }

        let startedAt = Date()
        defaults.lastHousekeepingAttemptDate = startedAt
        defaults.lastHousekeepingAttemptRetentionPeriodInDays = retentionPeriodInDays
        let throughDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionPeriodInDays,
            to: startedAt
        ) ?? startedAt
        trace(
            "in doAppStartUpHouseKeeping, starting. retention period = %{public}@ days",
            log: log,
            category: ConstantsLog.categoryHouseKeeper,
            type: .info,
            retentionPeriodInDays.description
        )

        Task(priority: .utility) {
            do {
                let counts: (bgReadings: Int, treatments: Int, calibrations: Int)
                do {
                    let plan = try await service.deletionPlan(
                        selection: CleanDataSelection(
                            includesBgReadings: true,
                            includesTreatments: true
                        ),
                        rangeMode: .keepRecent,
                        fromDate: nil,
                        throughDate: throughDate
                    )
                    let result = try await service.delete(plan: plan)
                    counts = (
                        result.bgReadingCount,
                        result.treatmentCount,
                        result.calibrationCount
                    )
                } catch CleanDataError.noMatchingData {
                    counts = (0, 0, 0)
                }

                storeCompletion(
                    at: Date(),
                    retentionPeriodInDays: retentionPeriodInDays,
                    counts: counts,
                    defaults: defaults
                )
                trace(
                    "in doAppStartUpHouseKeeping, completed. duration = %{public}@ ms, BG readings = %{public}@, treatments = %{public}@, unused calibrations = %{public}@",
                    log: log,
                    category: ConstantsLog.categoryHouseKeeper,
                    type: .info,
                    Int(Date().timeIntervalSince(startedAt) * 1000).description,
                    counts.bgReadings.description,
                    counts.treatments.description,
                    counts.calibrations.description
                )
            } catch {
                trace(
                    "in doAppStartUpHouseKeeping, failed. error = %{public}@",
                    log: log,
                    category: ConstantsLog.categoryHouseKeeper,
                    type: .error,
                    String(describing: type(of: error))
                )
            }
        }
    }

    private func shouldRun(retentionPeriodInDays: Int, defaults: UserDefaults) -> Bool {
        guard let lastAttemptDate = defaults.lastHousekeepingAttemptDate else { return true }
        guard defaults.lastHousekeepingAttemptRetentionPeriodInDays == retentionPeriodInDays else { return true }
        return Date().timeIntervalSince(lastAttemptDate) >= Self.minimumRunInterval
    }

    private func storeCompletion(
        at date: Date,
        retentionPeriodInDays: Int,
        counts: (bgReadings: Int, treatments: Int, calibrations: Int),
        defaults: UserDefaults
    ) {
        defaults.lastHousekeepingDate = date
        defaults.lastHousekeepingRetentionPeriodInDays = retentionPeriodInDays
        defaults.lastHousekeepingBgReadingsDeleted = counts.bgReadings
        defaults.lastHousekeepingTreatmentsDeleted = counts.treatments
        defaults.lastHousekeepingCalibrationsDeleted = counts.calibrations
    }
}
