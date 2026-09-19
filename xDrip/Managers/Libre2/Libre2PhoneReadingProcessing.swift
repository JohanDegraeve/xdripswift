import CoreData
import Foundation

/// Bridges imported, already-converted glucose to the phone's existing derived-data rules.
enum Libre2PhoneReadingProcessing {
    /// Recompute the imported window and following slopes with a predecessor for context.
    /// A late reading can change an existing successor's slope, including at a handoff boundary.
    static func updateSlopes(sensorIDs: Set<String>, from start: Date, to end: Date,
                             context: NSManagedObjectContext) throws -> Set<String> {
        let interval = TimeInterval(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60)
        var changedSensors: Set<String> = []
        for sensorID in sensorIDs {
            let request = BgReading.fetchRequest()
            request.predicate = NSPredicate(
                format: "sensor.id == %@ AND timeStamp >= %@ AND timeStamp <= %@ AND calculatedValue > 0 AND isSuppressedByFiveMinuteCadence == NO",
                sensorID, start.addingTimeInterval(-interval) as NSDate, end.addingTimeInterval(interval) as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "timeStamp", ascending: true),
                                       NSSortDescriptor(key: "id", ascending: true)]
            var previous: BgReading?
            for reading in try context.fetch(request) {
                defer { previous = reading }
                guard reading.timeStamp >= start else { continue }
                let (slope, hidden) = previous.map { reading.calculateSlope(lastBgReading: $0) } ?? (0, true)
                if reading.calculatedValueSlope != slope || reading.hideSlope != hidden {
                    reading.calculatedValueSlope = slope
                    reading.hideSlope = hidden
                    changedSensors.insert(sensorID)
                }
            }
        }
        return changedSensors
    }

    /// Optional post processing can suppress a newly imported value. Recheck before live effects.
    static func isCurrentReading(_ date: Date?, coreDataManager: CoreDataManager?, now: Date = Date()) -> Bool {
        guard let date, let coreDataManager, UserDefaults.standard.isMaster,
            date <= now, now.timeIntervalSince(date) < ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds,
            let sensor = SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor(),
            let latest = BgReadingsAccessor(coreDataManager: coreDataManager).getLatestBgReadings(
                limit: 1, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).first
        else { return false }
        return latest.timeStamp == date && latest.sensor?.id == sensor.id
    }

    /// The existing delayed-sharing path reads a per-minute buffer instead of fetching glucose.
    /// Rebuild that bounded buffer after phone post processing, without modifying Loop itself.
    static func prepareDelayedSharing(coreDataManager: CoreDataManager?, loopManager: LoopManager?, now: Date = Date()) {
        guard let loopManager, LoopManager.loopDelay() > 0 else { return }
        loopManager.glucoseData.removeAll()
        guard let coreDataManager, UserDefaults.standard.isMaster,
            UserDefaults.standard.loopShareType != .disabled, LoopManager.osAidSharingPermitted,
            let sensor = SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor()
        else { return }

        let lastCalibration = CalibrationsAccessor(coreDataManager: coreDataManager)
            .lastCalibrationForActiveSensor(withActivesensor: sensor)?.timeStamp ?? Date(timeIntervalSince1970: 0)
        guard abs(now.timeIntervalSince(lastCalibration)) > LoopManager.loopDelay() + TimeInterval(minutes: 5.5) else { return }
        let from = (UserDefaults.standard.timeStampLatestLoopSharedBgReading ?? now).addingTimeInterval(-TimeInterval(minutes: 30))
        let readings = BgReadingsAccessor(coreDataManager: coreDataManager).getLatestBgReadings(
            limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: from,
            forSensor: sensor, ignoreRawData: true, ignoreCalculatedValue: false)
        loopManager.glucoseData = readings.filter { $0.timeStamp <= now }.map {
            GlucoseData(timeStamp: $0.timeStamp, glucoseLevelRaw: round($0.loopShareValue),
                        slopeOrdinal: $0.slopeOrdinal(), slopeName: $0.slopeName)
        }
    }
}
