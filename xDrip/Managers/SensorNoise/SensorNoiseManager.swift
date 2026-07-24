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
    let state: SensorNoiseState
    let points: [SensorNoiseHistoryPoint]
}

extension Notification.Name {
    /// Posted after stored noise history changes for the sensor ID supplied as the notification object.
    static let sensorNoiseHistoryDidChange = Notification.Name("sensorNoiseHistoryDidChange")
}

/// Calculates and stores rolling noise measurements on the active sensor.
///
/// Current values remain on `Sensor`, while chart points are stored separately as
/// `SensorNoiseSample` records. Existing sessions are rebuilt lazily when their history is first
/// opened, after which normal sensor updates append new samples at the standard reading cadence.
final class SensorNoiseManager {

    // MARK: - private properties

    /// CoreDataManager instance
    private let coreDataManager: CoreDataManager

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor: BgReadingsAccessor

    /// SensorNoiseCalculator instance
    private let calculator = SensorNoiseCalculator()

    /// completion handlers waiting for the same sensor history build
    private var historyBuildCompletions = [String: [() -> Void]]()

    /// for logging
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataSensors)

    // MARK: - initializer

    init(coreDataManager: CoreDataManager, bgReadingsAccessor: BgReadingsAccessor) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = bgReadingsAccessor
    }

    // MARK: - public functions

    /// calculates and stores the latest noise measurements for the active sensor
    func update(activeSensor: Sensor?, now: Date = Date()) {
        guard UserDefaults.standard.isMaster, let activeSensor else { return }

        let snapshots = bgReadingsAccessor.getLatestBgReadingSnapshots(
            limit: nil,
            // Include a freshness allowance so an app launch between sensor readings still
            // provides the full 30-minute context for every four-hour rolling estimate.
            fromDate: now.addingTimeInterval(
                -(ConstantsSensorNoise.longTermContextWindow + ConstantsSensorNoise.rootWarningFreshness)
            ),
            forSensor: activeSensor,
            ignoreRawData: true,
            ignoreCalculatedValue: false,
            includingSuppressed: true
        )
        let readings = snapshots.map(Self.noiseReading)
        let measurement = calculator.calculate(readings: readings)
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

        if didStoreHistorySample {
            NotificationCenter.default.post(name: .sensorNoiseHistoryDidChange, object: activeSensor.id)
        }

        trace(
            "sensor noise updated: short = %{public}@ mg/dL, long = %{public}@ mg/dL, short coverage = %{public}@, long coverage = %{public}@, state = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            measurement.shortTermNoise?.round(toDecimalPlaces: 2).description ?? "nil",
            measurement.longTermNoise?.round(toDecimalPlaces: 2).description ?? "nil",
            measurement.shortTermCoverage.round(toDecimalPlaces: 2).description,
            measurement.longTermCoverage.round(toDecimalPlaces: 2).description,
            measurement.state.rawValue.description
        )
    }

    /// returns the complete stored noise history for one sensor
    func historySnapshot(sensorID: String) -> SensorNoiseHistorySnapshot? {
        var snapshot: SensorNoiseHistorySnapshot?

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard let sensor = self.sensor(withID: sensorID, in: self.coreDataManager.mainManagedObjectContext) else { return }

            let request: NSFetchRequest<SensorNoiseSample> = SensorNoiseSample.fetchRequest()
            request.predicate = NSPredicate(
                format: "sensorID == %@",
                sensorID
            )
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SensorNoiseSample.timeStamp), ascending: true)]
            request.fetchBatchSize = 512

            do {
                let points = try request.execute().map { sample in
                    SensorNoiseHistoryPoint(
                        id: sample.id,
                        timeStamp: sample.timeStamp,
                        shortTermNoise: sample.shortTermNoise?.doubleValue,
                        longTermNoise: sample.longTermNoise?.doubleValue,
                        state: SensorNoiseState(rawValue: sample.stateRaw) ?? .collecting
                    )
                }

                snapshot = SensorNoiseHistorySnapshot(
                    sensorStartDate: sensor.startDate,
                    sensorEndDate: sensor.endDate,
                    shortTermNoise: sensor.shortTermNoise?.doubleValue,
                    longTermNoise: sensor.longTermNoise?.doubleValue,
                    shortTermCoverage: sensor.shortTermNoiseCoverage,
                    longTermCoverage: sensor.longTermNoiseCoverage,
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
    func rebuildHistoryIfNeeded(sensorID: String, completion: @escaping () -> Void) -> Bool {
        if var completions = historyBuildCompletions[sensorID] {
            completions.append(completion)
            historyBuildCompletions[sensorID] = completions
            return true
        }

        var sensorObjectID: NSManagedObjectID?
        var sensorStartDate: Date?
        var sensorForReadings: Sensor?
        var historyIsComplete = false

        coreDataManager.mainManagedObjectContext.performAndWait {
            guard let sensor = self.sensor(withID: sensorID, in: self.coreDataManager.mainManagedObjectContext) else { return }

            historyIsComplete = sensor.noiseHistoryIsComplete
            sensorObjectID = sensor.objectID
            sensorStartDate = sensor.startDate
            sensorForReadings = sensor
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
            fromDate: sensorStartDate.addingTimeInterval(-1),
            forSensor: sensorForReadings,
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

    /// stores no more than one history point per normal sensor reading interval
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

                guard interval >= ConstantsSensorNoise.historyMinimumInterval else { return false }
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
