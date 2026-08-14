//
//  SensorNoiseManager.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

/// One stored noise point detached from Core Data for safe use by SwiftUI.
struct SensorNoiseHistoryPoint: Equatable, Identifiable {
    let id: String
    let timeStamp: Date
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let persistentNoise: Double?
    let persistentCoverage: Double
    let state: SensorNoiseState
}

/// All current and historic noise data needed by the sensor management views.
struct SensorNoiseHistorySnapshot {
    let sensorStartDate: Date
    let sensorEndDate: Date?
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let shortTermCoverage: Double
    let longTermCoverage: Double
    let persistentNoise: Double?
    let persistentCoverage: Double
    let state: SensorNoiseState
    let points: [SensorNoiseHistoryPoint]
}

extension Notification.Name {
    /// Posted after stored noise history changes for the sensor ID supplied as the notification object.
    static let sensorNoiseHistoryDidChange = Notification.Name("sensorNoiseHistoryDidChange")
}

/// Calculates and stores rolling noise measurements on the active sensor.
///
/// Current thirty-minute and four-hour values remain on `Sensor`. Chart points are stored as
/// `SensorNoiseSample` records, and their twelve-hour median is derived when history is loaded.
/// Existing sessions are rebuilt lazily, then normal updates append at the ten-minute cadence.
final class SensorNoiseManager {

    // MARK: - private properties

    /// CoreDataManager instance
    private let coreDataManager: CoreDataManager

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor: BgReadingsAccessor

    /// SensorNoiseCalculator instance
    private let calculator = SensorNoiseCalculator()

    /// Shared sensor-health episode manager
    private let sensorHealthIssueManager: SensorHealthIssueManager

    /// completion handlers waiting for the same sensor history build
    private var historyBuildCompletions = [String: [() -> Void]]()

    /// for logging
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataSensors)

    // MARK: - initializer

    init(
        coreDataManager: CoreDataManager,
        bgReadingsAccessor: BgReadingsAccessor,
        sensorHealthIssueManager: SensorHealthIssueManager
    ) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = bgReadingsAccessor
        self.sensorHealthIssueManager = sensorHealthIssueManager
    }

    // MARK: - public functions

    /// calculates and stores the latest noise measurements for the active sensor
    func update(activeSensor: Sensor?, now: Date = Date()) {
        guard UserDefaults.standard.isMaster, let activeSensor else { return }

        var shouldCalculate = false
        var sensorID: String?
        var sessionStartDate: Date?

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard !activeSensor.isDeleted, activeSensor.managedObjectContext != nil else { return }

            sensorID = activeSensor.id
            sessionStartDate = activeSensor.startDate

            if activeSensor.noiseAlgorithmVersion != ConstantsSensorNoise.algorithmVersion {
                shouldCalculate = true
            } else if let latestReadingAt = activeSensor.noiseLatestReadingAt {
                shouldCalculate = now.timeIntervalSince(latestReadingAt) >= ConstantsSensorNoise.measurementInterval
            } else {
                shouldCalculate = true
            }
        }

        guard shouldCalculate, let sensorID, let sessionStartDate else { return }

        let readingStartDate = max(
            now.addingTimeInterval(
                -(ConstantsSensorNoise.persistentNoiseContextWindow + ConstantsSensorNoise.rootWarningFreshness)
            ),
            sessionStartDate.addingTimeInterval(-ConstantsSensorNoise.sessionStartDateReachBackTolerance)
        )
        let snapshots = bgReadingsAccessor.getLatestBgReadingSnapshots(
            limit: nil,
            // Match history rebuilds by anchoring to the physical session start date rather than
            // only the current Sensor ID. This keeps 12-hour persistence working after harmless
            // internal Sensor object churn, while still refusing readings before the session start.
            fromDate: readingStartDate,
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: false,
            includingSuppressed: true
        )
        let readings = snapshots.map(Self.noiseReading)
        let measurement = calculator.calculate(readings: readings)
        let persistence = calculator.calculatePersistence(readings: readings)
        var didStoreHistorySample = false

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard !activeSensor.isDeleted, activeSensor.managedObjectContext != nil else { return }

            activeSensor.shortTermNoise = measurement.shortTermNoise.map(NSNumber.init(value:))
            activeSensor.longTermNoise = measurement.longTermNoise.map(NSNumber.init(value:))
            activeSensor.shortTermNoiseCoverage = measurement.shortTermCoverage
            activeSensor.longTermNoiseCoverage = measurement.longTermCoverage
            activeSensor.noiseStateRaw = measurement.state.rawValue
            activeSensor.noiseUpdatedAt = now
            activeSensor.noiseLatestReadingAt = measurement.latestReadingAt
            activeSensor.noiseAlgorithmVersion = ConstantsSensorNoise.algorithmVersion

            if let latestReadingAt = measurement.latestReadingAt {
                didStoreHistorySample = self.storeHistorySample(
                    timeStamp: latestReadingAt,
                    measurement: measurement,
                    sensor: activeSensor
                )
            }
        }

        coreDataManager.saveChanges()

        sensorHealthIssueManager.reportCalculatedState(
            sensorID: sensorID,
            sensorStartDate: sessionStartDate,
            measurement: measurement,
            persistence: persistence,
            sensitivity: UserDefaults.standard.sensorNoiseSensitivity,
            now: now
        )

        if didStoreHistorySample {
            NotificationCenter.default.post(name: .sensorNoiseHistoryDidChange, object: sensorID)
        }

        let displayNoiseState = ConstantsSensorNoise.displayState(
            rawState: measurement.state,
            shortTermNoise: measurement.shortTermNoise,
            longTermNoise: measurement.longTermNoise,
            sensitivity: UserDefaults.standard.sensorNoiseSensitivity
        )

        trace(
            "sensor noise updated: short = %{public}@ mg/dL, long = %{public}@ mg/dL, short coverage = %{public}@, long coverage = %{public}@, state = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            // The developer trace keeps its existing ten-minute calculation detail. The consumer
            // store accepts this controlled aggregate but enforces a one-hour cadence across app
            // relaunches, pairing the metric with the same sensitivity-aware status shown in the UI.
            troubleshooting: .standard(.sensorNoise(
                shortTermMgDl: measurement.shortTermNoise,
                longTermMgDl: measurement.longTermNoise,
                status: TroubleshootingSensorNoiseStatus(displayNoiseState)
            )),
            measurement.shortTermNoise?.round(toDecimalPlaces: 2).description ?? "nil",
            measurement.longTermNoise?.round(toDecimalPlaces: 2).description ?? "nil",
            measurement.shortTermCoverage.round(toDecimalPlaces: 2).description,
            measurement.longTermCoverage.round(toDecimalPlaces: 2).description,
            measurement.state.rawValue.description
        )
    }

    /// returns stored noise history for the active physical sensor session
    ///
    /// The current Sensor ID is still preferred, but the fetch is anchored to the current sensor
    /// start date. This keeps the chart intact if a transmitter reports a slightly shifted start
    /// time and the app creates a new internal Sensor object for the same physical session.
    func historySnapshot(sensorID: String, sessionStartDate: Date) -> SensorNoiseHistorySnapshot? {
        var snapshot: SensorNoiseHistorySnapshot?

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard let sensor = self.sensor(withID: sensorID, in: self.coreDataManager.mainManagedObjectContext) else { return }

            let historyStartDate = sessionStartDate.addingTimeInterval(-ConstantsSensorNoise.sessionStartDateReachBackTolerance)
            let request: NSFetchRequest<SensorNoiseSample> = SensorNoiseSample.fetchRequest()
            request.predicate = NSPredicate(
                format: "%K >= %@",
                #keyPath(SensorNoiseSample.timeStamp),
                historyStartDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SensorNoiseSample.timeStamp), ascending: true)]
            request.fetchBatchSize = 512

            do {
                let storedPoints = self.currentSessionPoints(
                    from: try request.execute(),
                    currentSensorID: sensorID
                ).map { sample in
                    SensorNoiseHistoryPoint(
                        id: sample.id,
                        timeStamp: sample.timeStamp,
                        shortTermNoise: sample.shortTermNoise?.doubleValue,
                        longTermNoise: sample.longTermNoise?.doubleValue,
                        persistentNoise: nil,
                        persistentCoverage: 0,
                        state: SensorNoiseState(rawValue: sample.stateRaw) ?? .collecting
                    )
                }
                let points = self.addingPersistentNoise(to: storedPoints)
                let latestPoint = points.last

                snapshot = SensorNoiseHistorySnapshot(
                    sensorStartDate: sensor.startDate,
                    sensorEndDate: sensor.endDate,
                    shortTermNoise: sensor.shortTermNoise?.doubleValue,
                    longTermNoise: sensor.longTermNoise?.doubleValue,
                    shortTermCoverage: sensor.shortTermNoiseCoverage,
                    longTermCoverage: sensor.longTermNoiseCoverage,
                    persistentNoise: latestPoint?.persistentNoise,
                    persistentCoverage: latestPoint?.persistentCoverage ?? 0,
                    state: SensorNoiseState(rawValue: sensor.noiseStateRaw) ?? .collecting,
                    points: points
                )
            } catch {
                self.traceHistoryError("fetch", error: error)
            }
        }

        return snapshot
    }

    /// Builds the existing sensor-session history once before incremental storage takes over.
    ///
    /// Multiple callers requesting the same rebuild share one operation and are all notified when
    /// its Core Data changes have been saved.
    @discardableResult
    func rebuildHistoryIfNeeded(sensorID: String, sessionStartDate: Date, completion: @escaping () -> Void) -> Bool {
        if var completions = historyBuildCompletions[sensorID] {
            completions.append(completion)
            historyBuildCompletions[sensorID] = completions
            return true
        }

        var sensorObjectID: NSManagedObjectID?
        var sensorStartDate: Date?
        var historyIsComplete = false

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard let sensor = self.sensor(withID: sensorID, in: self.coreDataManager.mainManagedObjectContext) else { return }

            historyIsComplete = sensor.noiseHistoryIsComplete
            sensorObjectID = sensor.objectID
            sensorStartDate = max(sensor.startDate, sessionStartDate)
        }

        if historyIsComplete {
            completion()
            return false
        }

        guard let sensorObjectID, let sensorStartDate else {
            completion()
            return false
        }

        historyBuildCompletions[sensorID] = [completion]
        let snapshots = bgReadingsAccessor.getLatestBgReadingSnapshots(
            limit: nil,
            fromDate: sensorStartDate.addingTimeInterval(-ConstantsSensorNoise.sessionStartDateReachBackTolerance),
            // Rebuild from the session time window rather than the current Sensor relationship.
            // This recovers history after harmless internal Sensor ID churn.
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: false,
            includingSuppressed: true
        )
        let readings = snapshots.map(Self.noiseReading)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let history = self.calculator.calculateHistory(readings: readings)
            self.replaceHistory(
                history,
                sensorID: sensorID,
                sensorObjectID: sensorObjectID
            )
        }

        return true
    }

    // MARK: - private functions

    private static func noiseReading(from snapshot: BgReadingSnapshot) -> SensorNoiseReading {
        SensorNoiseReading(
            timeStamp: snapshot.timeStamp,
            calculatedValue: snapshot.calculatedValue,
            rawData: snapshot.rawData,
            calibrationID: snapshot.calibrationSnapshot?.id
        )
    }

    private func sensor(withID sensorID: String, in context: NSManagedObjectContext) -> Sensor? {
        let request: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sensorID)
        request.fetchLimit = 1

        do {
            return try request.execute().first
        } catch {
            traceHistoryError("sensor fetch", error: error)
            return nil
        }
    }

    /// Returns one sample per reading timestamp, preferring samples already linked to this Sensor ID.
    private func currentSessionPoints(from samples: [SensorNoiseSample], currentSensorID: String) -> [SensorNoiseSample] {
        var pointsByTimestamp = [TimeInterval: SensorNoiseSample]()

        for sample in samples {
            let timestamp = sample.timeStamp.timeIntervalSince1970

            if let existingSample = pointsByTimestamp[timestamp] {
                if existingSample.sensorID != currentSensorID && sample.sensorID == currentSensorID {
                    pointsByTimestamp[timestamp] = sample
                }
            } else {
                pointsByTimestamp[timestamp] = sample
            }
        }

        return pointsByTimestamp.values.sorted { $0.timeStamp < $1.timeStamp }
    }

    /// Adds the rolling twelve-hour median to each stored chart point.
    private func addingPersistentNoise(to points: [SensorNoiseHistoryPoint]) -> [SensorNoiseHistoryPoint] {
        var estimates = [(timeStamp: Date, noise: Double)]()

        return points.map { point in
            if let shortTermNoise = point.shortTermNoise {
                estimates.append((point.timeStamp, shortTermNoise))
            }

            let assessment = calculator.calculatePersistence(
                estimates: estimates,
                endingAt: point.timeStamp
            )

            return SensorNoiseHistoryPoint(
                id: point.id,
                timeStamp: point.timeStamp,
                shortTermNoise: point.shortTermNoise,
                longTermNoise: point.longTermNoise,
                persistentNoise: assessment.value,
                persistentCoverage: assessment.coverage,
                state: point.state
            )
        }
    }

    /// stores no more than one history point per sensor-noise measurement interval
    private func storeHistorySample(timeStamp: Date, measurement: SensorNoiseMeasurement, sensor: Sensor) -> Bool {
        guard measurement.shortTermNoise != nil
                || measurement.longTermNoise != nil
                || measurement.state == .flatlineSuspected else {
            return false
        }

        let request: NSFetchRequest<SensorNoiseSample> = SensorNoiseSample.fetchRequest()
        request.predicate = NSPredicate(
            format: "sensorID == %@",
            sensor.id
        )
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SensorNoiseSample.timeStamp), ascending: false)]
        request.fetchLimit = 1

        do {
            if let latestSample = try request.execute().first {
                let interval = timeStamp.timeIntervalSince(latestSample.timeStamp)

                if abs(interval) < 1 {
                    latestSample.shortTermNoise = measurement.shortTermNoise.map(NSNumber.init(value:))
                    latestSample.longTermNoise = measurement.longTermNoise.map(NSNumber.init(value:))
                    latestSample.stateRaw = measurement.state.rawValue
                    return true
                }

                guard interval >= ConstantsSensorNoise.measurementInterval else { return false }
            }

            _ = SensorNoiseSample(
                timeStamp: timeStamp,
                measurement: measurement,
                sensor: sensor,
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext
            )
            return true
        } catch {
            traceHistoryError("incremental store", error: error)
            return false
        }
    }

    /// Replaces the rebuilt part of a session without deleting newer samples stored during the rebuild.
    private func replaceHistory(
        _ history: [SensorNoiseHistoryMeasurement],
        sensorID: String,
        sensorObjectID: NSManagedObjectID
    ) {
        let context = coreDataManager.privateChildManagedObjectContext()

        context.perform { [weak self] in
            guard let self,
                  let sensor = try? context.existingObject(with: sensorObjectID) as? Sensor else {
                DispatchQueue.main.async { self?.finishHistoryBuild(sensorID: sensorID) }
                return
            }

            let request: NSFetchRequest<SensorNoiseSample> = SensorNoiseSample.fetchRequest()
            request.predicate = NSPredicate(format: "sensorID == %@", sensorID)

            do {
                let replacementEndDate = history.last?.timeStamp
                let existingSamples = try request.execute()

                for sample in existingSamples {
                    if let replacementEndDate, sample.timeStamp <= replacementEndDate {
                        context.delete(sample)
                    }
                }

                for historicMeasurement in history {
                    _ = SensorNoiseSample(
                        timeStamp: historicMeasurement.timeStamp,
                        measurement: historicMeasurement.measurement,
                        sensor: sensor,
                        nsManagedObjectContext: context
                    )
                }

                sensor.noiseHistoryIsComplete = true
                try context.save()

                DispatchQueue.main.async {
                    self.coreDataManager.saveChanges()
                    NotificationCenter.default.post(name: .sensorNoiseHistoryDidChange, object: sensorID)
                    self.finishHistoryBuild(sensorID: sensorID)
                }
            } catch {
                self.traceHistoryError("rebuild", error: error)
                DispatchQueue.main.async { self.finishHistoryBuild(sensorID: sensorID) }
            }
        }
    }

    /// Completes every caller waiting on the same sensor rebuild and clears its in-flight state.
    private func finishHistoryBuild(sensorID: String) {
        let completions = historyBuildCompletions.removeValue(forKey: sensorID) ?? []
        completions.forEach { $0() }
    }

    private func traceHistoryError(_ operation: String, error: Error) {
        trace(
            "sensor noise history %{public}@ failed: %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .error,
            operation,
            error.localizedDescription
        )
    }
}
