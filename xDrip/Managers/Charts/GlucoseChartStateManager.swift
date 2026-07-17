//
//  GlucoseChartStateManager.swift
//  xdrip
//
//  Created by Paul Plant on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import CoreData
import Foundation
import os.log
import SwiftUI

/// Incremental data source for the SwiftUI glucose chart.
///
/// It keeps a local copy of chart data and moves the visible window through that cache instead of
/// rebuilding the complete payload on every scroll update. The append, prepend and trim pattern is
/// applied to glucose, original glucose, calibrations, treatments and derived basal points so the
/// renderer receives stable, already-materialised data.
final class GlucoseChartStateManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: GlucoseChartState

    // MARK: - Dependencies

    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let calibrationsAccessor: CalibrationsAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let nightscoutSyncManager: NightscoutSyncManager
    private let operationQueue = OperationQueue()
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryGlucoseChartManager)

    // MARK: - Cached Data

    /// Raw Core Data snapshots kept outside the visible range.
    ///
    /// These arrays are intentionally wider than `state.startDate ... state.endDate`. When the user
    /// scrolls a little, `loadMissingData` only loads the missing leading or trailing date range and
    /// `trimCache` later removes points that are too far away to be useful. Glucose, treatments and
    /// basal source data all follow the same cache boundaries.
    private var cachedReadings = [CachedBgReading]()
    private var cachedOriginalReadings = [CachedBgReading]()
    private var cachedCalibrations = [CachedCalibration]()
    private var cachedTreatments = [CachedTreatment]()

    /// Sensor noise snapshots are cached with the same wider date range as glucose.
    ///
    /// This keeps chart scrolling smooth because the background bands can be rebuilt from memory
    /// while Swift Charts is changing the visible window.
    private var cachedNoiseSamples = [CachedSensorNoiseSample]()

    /// Derived treatment chart points created from `cachedTreatments`.
    ///
    /// Bolus/carbs/bg-check/note points can be appended and prepended just like glucose. Basal points
    /// are also held here, but they are refreshed for the cached treatment range because step lines
    /// need clean start/end edge points and depend on the current basal scale.
    private var cachedTreatmentPoints = GlucoseChartTreatmentPoints()
    private var cacheStartDate: Date?
    private var cacheEndDate: Date?
    private var treatmentPointsStartDate: Date?
    private var treatmentPointsEndDate: Date?
    private var treatmentPointsMinimumChartValue: Double?
    private let showsSensorNoiseBands: Bool

    // MARK: - Basal State

    /// Scheduled basal values expanded around the chart start date.
    ///
    /// The array is refreshed when the chart start moves by more than a few hours. Temp basal gaps
    /// can then use the scheduled profile without expanding it on every small scroll update.
    private var scheduledBasalRates = [(date: Date, value: Double)]()
    private var scheduledBasalRatesLastUpdatedForStartDate: Date = .distantPast
    private var basalRateMaximum: Double = 0
    private var basalRateScaler: Double = 20

    private static let basalTreatmentLookbackTimeInterval: TimeInterval = 60 * 120
    private static let cacheRefreshLookbackTimeInterval: TimeInterval = .hours(6)
    private static let minimumScrollCacheBufferTimeInterval: TimeInterval = .hours(6)
    private static let maximumScrollCacheBufferTimeInterval: TimeInterval = .hours(24)

    /// Moves short-term noise bands back onto the glucose readings that created the noise score.
    ///
    /// A sample written at the end of a 30 minute noise window describes the previous 30 minutes,
    /// not just the moment when the sample was stored. A partial offset keeps the bands closer to
    /// the glucose movement that caused them without making current noise look too far in the past.
    private static let sensorNoiseChartBandTimeOffset: TimeInterval = 15 * 60

    // MARK: - Initialisation

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager, showsSensorNoiseBands: Bool = false) {
        self.coreDataManager = coreDataManager
        self.nightscoutSyncManager = nightscoutSyncManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        self.showsSensorNoiseBands = showsSensorNoiseBands

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours))
        self.state = GlucoseChartState.empty(startDate: startDate, endDate: endDate)

        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.name = "GlucoseChartStateManager"
    }

    // MARK: - Public API

    /// Updates the published chart state for a visible date window.
    ///
    /// Calls are serialized on a single operation queue. If scrolling produces several updates in
    /// one frame, the manager keeps the most recent cache/state work moving and avoids starting
    /// overlapping Core Data reads for stale intermediate positions.
    /// - Parameters:
    ///   - endDate: Visible chart end date.
    ///   - startDate: Visible chart start date. When nil, the current chart width is preserved.
    ///   - forceReset: Clears all caches before loading the requested range.
    ///   - refreshCachedData: Replaces the recent cached tail before rebuilding state. This is used
    ///     when Core Data changes inside a date range that the manager has already loaded.
    ///   - showTreatments: Whether treatment and basal points should be included.
    ///   - showOriginalReadingsOnly: Temporarily render original readings instead of processed readings.
    ///   - completionHandler: Called on the main queue after the state has been published.
    func updateState(endDate: Date = Date(), startDate: Date? = nil, forceReset: Bool = false, refreshCachedData: Bool = false, showTreatments: Bool = UserDefaults.standard.showTreatmentsOnChart, showOriginalReadingsOnly: Bool = false, completionHandler: ((GlucoseChartState) -> Void)? = nil) {
        let startDateToUse = startDate ?? endDate.addingTimeInterval(-state.endDate.timeIntervalSince(state.startDate))

        operationQueue.addOperation { [weak self] in
            guard let self = self else { return }

            guard self.operationQueue.operations.count <= 1 else {
                DispatchQueue.main.async {
                    completionHandler?(self.state)
                }

                return
            }

            if forceReset {
                self.resetCache()
            }

            let hadCachedData = self.cacheStartDate != nil
            self.loadMissingData(startDate: startDateToUse, endDate: endDate)

            if refreshCachedData && hadCachedData {
                self.reloadRecentData(endDate: endDate)
            }

            self.trimCache(visibleStartDate: startDateToUse, visibleEndDate: endDate)

            let chartState = self.makeState(startDate: startDateToUse, endDate: endDate, showTreatments: showTreatments, showOriginalReadingsOnly: showOriginalReadingsOnly)

            DispatchQueue.main.async {
                self.state = chartState
                completionHandler?(chartState)
            }
        }
    }

    func cleanUpMemory() {
        operationQueue.cancelAllOperations()
        resetCache()
    }

    // MARK: - Cache Loading

    private func resetCache() {
        cachedReadings.removeAll()
        cachedOriginalReadings.removeAll()
        cachedCalibrations.removeAll()
        cachedTreatments.removeAll()
        cachedNoiseSamples.removeAll()
        cachedTreatmentPoints = GlucoseChartTreatmentPoints()
        cacheStartDate = nil
        cacheEndDate = nil
        treatmentPointsStartDate = nil
        treatmentPointsEndDate = nil
        treatmentPointsMinimumChartValue = nil
        scheduledBasalRates.removeAll()
        scheduledBasalRatesLastUpdatedForStartDate = .distantPast
        basalRateMaximum = 0
        basalRateScaler = 20
    }

    /// Loads only the missing leading/trailing ranges around the requested visible window.
    ///
    /// This is the key scrolling performance rule. If the new requested cache range overlaps the
    /// current cache, we append or prepend just the missing date range. Only a fully disjoint jump
    /// resets the cache. The extra basal lookback is needed because a temp basal that began before
    /// the visible window can still determine the first rendered basal segment.
    private func loadMissingData(startDate: Date, endDate: Date) {
        guard startDate < endDate else { return }

        let visibleWidth = endDate.timeIntervalSince(startDate)
        let cacheBuffer = min(max(visibleWidth * 0.5, Self.minimumScrollCacheBufferTimeInterval), Self.maximumScrollCacheBufferTimeInterval)
        let cacheStartDateToUse = startDate.addingTimeInterval(-max(cacheBuffer, Self.basalTreatmentLookbackTimeInterval))
        let cacheEndDateToUse = min(endDate.addingTimeInterval(cacheBuffer), Date())

        if let cacheStartDate = cacheStartDate, let cacheEndDate = cacheEndDate {
            if cacheStartDateToUse > cacheEndDate || cacheEndDateToUse < cacheStartDate {
                resetCache()
                loadRange(startDate: cacheStartDateToUse, endDate: cacheEndDateToUse)
                self.cacheStartDate = cacheStartDateToUse
                self.cacheEndDate = cacheEndDateToUse

                return
            }

            if cacheStartDateToUse < cacheStartDate {
                loadRange(startDate: cacheStartDateToUse, endDate: cacheStartDate)
                self.cacheStartDate = cacheStartDateToUse
            }

            if cacheEndDateToUse > cacheEndDate {
                loadRange(startDate: cacheEndDate, endDate: cacheEndDateToUse)
                self.cacheEndDate = cacheEndDateToUse
            }
        } else {
            loadRange(startDate: cacheStartDateToUse, endDate: cacheEndDateToUse)
            cacheStartDate = cacheStartDateToUse
            cacheEndDate = cacheEndDateToUse
        }
    }

    private func loadRange(startDate: Date, endDate: Date) {
        guard startDate < endDate else { return }

        let managedObjectContext = coreDataManager.privateManagedObjectContext

        // Load all source series for the same missing range so no series is rebuilt independently.
        cachedReadings.merge(
            mapBgReadings(
                bgReadingsAccessor.getBgReadings(from: startDate, to: endDate, on: managedObjectContext),
                on: managedObjectContext
            )
        )

        cachedOriginalReadings.merge(
            mapBgReadings(
                bgReadingsAccessor.getBgReadings(from: startDate, to: endDate, on: managedObjectContext, includingSuppressed: true),
                on: managedObjectContext
            )
        )

        cachedCalibrations.merge(
            mapCalibrations(
                calibrationsAccessor.getCalibrations(from: startDate, to: endDate, on: managedObjectContext),
                on: managedObjectContext
            )
        )

        if showsSensorNoiseBands {
            cachedNoiseSamples.merge(loadNoiseSamples(from: startDate, to: endDate, on: managedObjectContext))
        }

        cachedTreatments.merge(
            mapTreatments(
                treatmentEntryAccessor.getTreatments(fromDate: startDate, toDate: endDate, on: managedObjectContext),
                on: managedObjectContext
            )
        )
    }

    /// Reloads a small overlapping tail without discarding the wider scrolling cache.
    ///
    /// A follower or transmitter can insert a reading whose timestamp sits inside a range already
    /// marked as loaded. Removing and reloading this tail lets the new or edited records replace the
    /// cached snapshots while all older glucose, treatment and basal data remains available for
    /// smooth scrolling.
    private func reloadRecentData(endDate: Date) {
        guard let cacheStartDate else { return }

        let refreshEndDate = min(endDate, Date())
        let refreshStartDate = max(cacheStartDate, refreshEndDate.addingTimeInterval(-Self.cacheRefreshLookbackTimeInterval))
        guard refreshStartDate < refreshEndDate else { return }

        cachedReadings.removeAll { $0.date >= refreshStartDate && $0.date <= refreshEndDate }
        cachedOriginalReadings.removeAll { $0.date >= refreshStartDate && $0.date <= refreshEndDate }
        cachedCalibrations.removeAll { $0.date >= refreshStartDate && $0.date <= refreshEndDate }
        cachedTreatments.removeAll { $0.date >= refreshStartDate && $0.date <= refreshEndDate }
        cachedNoiseSamples.removeAll { $0.date >= refreshStartDate && $0.date <= refreshEndDate }

        loadRange(startDate: refreshStartDate, endDate: refreshEndDate)

        // Treatment positions and basal edges depend on both treatment and glucose snapshots.
        // Rebuild this derived cache once after replacing the source tail.
        cachedTreatmentPoints = GlucoseChartTreatmentPoints()
        treatmentPointsStartDate = nil
        treatmentPointsEndDate = nil
        treatmentPointsMinimumChartValue = nil
    }

    /// Keeps a buffer around the visible window and drops older cached points to limit chart cost.
    ///
    /// The buffer is deliberately wider than the visible chart so small scroll gestures are served
    /// from memory. Once points are far enough outside the visible range, they are removed so Swift
    /// Charts does not keep diffing/rendering historical data the user cannot see.
    private func trimCache(visibleStartDate: Date, visibleEndDate: Date) {
        let visibleWidth = visibleEndDate.timeIntervalSince(visibleStartDate)
        let buffer = min(max(visibleWidth, Self.minimumScrollCacheBufferTimeInterval), Self.maximumScrollCacheBufferTimeInterval)
        let keepStartDate = visibleStartDate.addingTimeInterval(-buffer)
        let keepEndDate = visibleEndDate.addingTimeInterval(buffer)

        cachedReadings.removeAll { $0.date < keepStartDate || $0.date > keepEndDate }
        cachedOriginalReadings.removeAll { $0.date < keepStartDate || $0.date > keepEndDate }
        cachedCalibrations.removeAll { $0.date < keepStartDate || $0.date > keepEndDate }
        cachedTreatments.removeAll { $0.date < keepStartDate || $0.date > keepEndDate }
        cachedNoiseSamples.removeAll { $0.date < keepStartDate || $0.date > keepEndDate }
        cachedTreatmentPoints.trim(from: keepStartDate, to: keepEndDate)

        if let cacheStartDate = cacheStartDate {
            self.cacheStartDate = max(cacheStartDate, keepStartDate)
        }

        if let cacheEndDate = cacheEndDate {
            self.cacheEndDate = min(cacheEndDate, keepEndDate)
        }

        if let treatmentPointsStartDate = treatmentPointsStartDate {
            self.treatmentPointsStartDate = max(treatmentPointsStartDate, keepStartDate)
        }

        if let treatmentPointsEndDate = treatmentPointsEndDate {
            self.treatmentPointsEndDate = min(treatmentPointsEndDate, keepEndDate)
        }
    }

    // MARK: - State Construction

    /// Builds the immutable render state for the current visible range.
    ///
    /// `GlucoseChartView` still filters the renderable arrays to the visible window. Passing the
    /// wider cached arrays through the state keeps the renderer stable while new leading/trailing
    /// points arrive, and lets step-based basal drawing synthesize clean visible edges.
    private func makeState(startDate: Date, endDate: Date, showTreatments: Bool, showOriginalReadingsOnly: Bool) -> GlucoseChartState {
        let cachedReadingsForTreatmentPositions = cachedReadings.filter { $0.finalValue > 0 }
        let cachedReadingsToRender = showOriginalReadingsOnly ? [] : cachedReadingsForTreatmentPositions
        let cachedOriginalReadingsToRender = shouldShowOriginalReadings || showOriginalReadingsOnly ? cachedOriginalReadings.filter { $0.calculatedValue > 0 } : []
        let cachedCalibrationsToRender = cachedCalibrations.filter { $0.value > 0 }
        let dataStartDate = cacheStartDate ?? startDate
        let dataEndDate = cacheEndDate ?? endDate

        let additionalDataSets = cachedOriginalReadingsToRender.isEmpty ? [] : [
            GlucoseChartDataSet(
                bgReadingValues: cachedOriginalReadingsToRender.map { $0.calculatedValue },
                bgReadingDates: cachedOriginalReadingsToRender.map { $0.date },
                seriesIdentifier: "original",
                lineColor: nil,
                pointColor: showOriginalReadingsOnly ? ConstantsGlucoseChart.glucoseOriginalPeekColor : ConstantsGlucoseChart.glucoseOriginalColor,
                lineWidth: 0,
                dash: [],
                showLine: false,
                showPoints: true,
                pointSizeMultiplier: 1.0,
                pointBorderColor: nil,
                pointBorderSizeMultiplier: nil
            )
        ]

        let minimumChartValue = minimumChartValue(startDate: startDate, endDate: endDate, showTreatments: showTreatments)
        updateTreatmentPointCacheIfNeeded(
            startDate: dataStartDate,
            endDate: dataEndDate,
            bgReadings: cachedReadingsForTreatmentPositions,
            minimumChartValue: minimumChartValue,
            showTreatments: showTreatments
        )

        return GlucoseChartState(
            startDate: startDate,
            endDate: endDate,
            dataStartDate: dataStartDate,
            dataEndDate: dataEndDate,
            bgReadingValues: cachedReadingsToRender.map { $0.finalValue },
            bgReadingDates: cachedReadingsToRender.map { $0.date },
            additionalBgReadingDataSets: additionalDataSets,
            calibrationPoints: cachedCalibrationsToRender.map { GlucoseChartPoint(date: $0.date, value: $0.value, idPrefix: "calibration") },
            treatmentPoints: showTreatments ? cachedTreatmentPoints : GlucoseChartTreatmentPoints(),
            minimumChartValueInMgDl: minimumChartValue,
            backgroundBands: chartBackgroundBands(startDate: dataStartDate, endDate: dataEndDate)
        )
    }

    private var shouldShowOriginalReadings: Bool {
        UserDefaults.standard.showOriginalBGReadings && (UserDefaults.standard.enableAdjustment || UserDefaults.standard.enableSmoothing)
    }

    private var shouldShowSensorNoiseBands: Bool {
        showsSensorNoiseBands && UserDefaults.standard.isMaster && UserDefaults.standard.showSensorNoiseOnChart
    }

    private func minimumChartValue(startDate: Date, endDate: Date, showTreatments: Bool) -> Double {
        guard showTreatments, UserDefaults.standard.nightscoutFollowType != .none else {
            return ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
        }

        if endDate.timeIntervalSince(startDate) >= .hours(24) {
            return ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal24hrChart
        }

        return ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal
    }

    private func chartBackgroundBands(startDate: Date, endDate: Date) -> [GlucoseChartBackgroundBand]? {
        guard shouldShowSensorNoiseBands, startDate < endDate else { return nil }

        let visibleNoiseSamples = cachedNoiseSamples
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }

        guard !visibleNoiseSamples.isEmpty else { return nil }

        var bands = [GlucoseChartBackgroundBand]()

        for (index, sample) in visibleNoiseSamples.enumerated() {
            guard let style = sample.bandStyle else { continue }

            let nextDate = index + 1 < visibleNoiseSamples.count
                ? visibleNoiseSamples[index + 1].date
                : sample.date.addingTimeInterval(ConstantsSensorNoise.historyMinimumInterval)
            // shift each stored noise sample back by the short-term window so the band follows the
            // glucose values being assessed instead of lagging behind them on the chart.
            let offsetStartDate = sample.date.addingTimeInterval(-Self.sensorNoiseChartBandTimeOffset)
            let offsetEndDate = nextDate.addingTimeInterval(-Self.sensorNoiseChartBandTimeOffset)
            let clippedStartDate = max(offsetStartDate, startDate)
            let clippedEndDate = min(offsetEndDate, sample.date, endDate)

            guard clippedStartDate < clippedEndDate else { continue }

            if let lastBand = bands.last,
               lastBand.style == style,
               abs(lastBand.endDate.timeIntervalSince(clippedStartDate)) < 1 {
                bands[bands.count - 1] = GlucoseChartBackgroundBand(
                    startDate: lastBand.startDate,
                    endDate: clippedEndDate,
                    style: style
                )
            } else {
                bands.append(
                    GlucoseChartBackgroundBand(
                        startDate: clippedStartDate,
                        endDate: clippedEndDate,
                        style: style
                    )
                )
            }
        }

        return bands.isEmpty ? nil : bands
    }

    private func loadNoiseSamples(from startDate: Date, to endDate: Date, on managedObjectContext: NSManagedObjectContext) -> [CachedSensorNoiseSample] {
        var cachedSamples = [CachedSensorNoiseSample]()

        managedObjectContext.performAndWait {
            guard let activeSensorSnapshot = activeSensorSnapshot(on: managedObjectContext),
                  activeSensorSnapshot.noiseAlgorithmVersion == ConstantsSensorNoise.algorithmVersion
            else {
                return
            }

            let request: NSFetchRequest<SensorNoiseSample> = SensorNoiseSample.fetchRequest()
            request.predicate = NSPredicate(
                format: "%K == %@ AND %K >= %@ AND %K <= %@",
                #keyPath(SensorNoiseSample.sensorID),
                activeSensorSnapshot.id,
                #keyPath(SensorNoiseSample.timeStamp),
                startDate as NSDate,
                #keyPath(SensorNoiseSample.timeStamp),
                endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SensorNoiseSample.timeStamp), ascending: true)]
            request.returnsObjectsAsFaults = false

            do {
                cachedSamples = try managedObjectContext.fetch(request).compactMap {
                    CachedSensorNoiseSample(
                        date: $0.timeStamp,
                        shortTermNoise: $0.shortTermNoise?.doubleValue
                    )
                }
            } catch {
                os_log("Failed to fetch sensor noise samples for chart range: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }

        return cachedSamples
    }

    private func activeSensorSnapshot(on managedObjectContext: NSManagedObjectContext) -> (id: String, noiseAlgorithmVersion: Int16)? {
        let request: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: false)]
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        request.includesPropertyValues = true
        request.predicate = NSPredicate(format: "%K == nil", #keyPath(Sensor.endDate))

        do {
            guard let activeSensor = try managedObjectContext.fetch(request).first else {
                return nil
            }

            return (
                id: activeSensor.id,
                noiseAlgorithmVersion: activeSensor.noiseAlgorithmVersion
            )
        } catch {
            os_log("Failed to fetch active sensor for chart range: %{public}@", log: log, type: .error, error.localizedDescription)
            return nil
        }
    }

    // MARK: - Treatment Points

    /// Ensures derived treatment chart points cover the current cached source range.
    ///
    /// Treatment points are materialised into the local cache and only missing leading or trailing
    /// ranges are generated.
    ///
    /// Basal lines are refreshed after appending/prepending because a step series needs a consistent
    /// first/last point and because the basal scaler can change if a newly loaded basal treatment is
    /// larger than the previous known maximum.
    private func updateTreatmentPointCacheIfNeeded(startDate: Date, endDate: Date, bgReadings: [CachedBgReading], minimumChartValue: Double, showTreatments: Bool) {
        guard showTreatments else {
            cachedTreatmentPoints = GlucoseChartTreatmentPoints()
            treatmentPointsStartDate = nil
            treatmentPointsEndDate = nil
            treatmentPointsMinimumChartValue = nil

            return
        }

        guard startDate < endDate else { return }

        if treatmentPointsMinimumChartValue != minimumChartValue {
            cachedTreatmentPoints = GlucoseChartTreatmentPoints()
            treatmentPointsStartDate = nil
            treatmentPointsEndDate = nil
            treatmentPointsMinimumChartValue = minimumChartValue
        }

        guard let currentStartDate = treatmentPointsStartDate, let currentEndDate = treatmentPointsEndDate else {
            cachedTreatmentPoints = makeTreatmentPoints(startDate: startDate, endDate: endDate, bgReadings: bgReadings, minimumChartValue: minimumChartValue)
            treatmentPointsStartDate = startDate
            treatmentPointsEndDate = endDate
            treatmentPointsMinimumChartValue = minimumChartValue

            return
        }

        if startDate > currentEndDate || endDate < currentStartDate {
            cachedTreatmentPoints = makeTreatmentPoints(startDate: startDate, endDate: endDate, bgReadings: bgReadings, minimumChartValue: minimumChartValue)
            treatmentPointsStartDate = startDate
            treatmentPointsEndDate = endDate

            return
        }

        if startDate < currentStartDate {
            let treatmentPointsToPrepend = makeTreatmentPoints(startDate: startDate, endDate: currentStartDate, bgReadings: bgReadings, minimumChartValue: minimumChartValue)
            cachedTreatmentPoints.merge(treatmentPointsToPrepend)
            treatmentPointsStartDate = startDate
        }

        if endDate > currentEndDate {
            let treatmentPointsToAppend = makeTreatmentPoints(startDate: currentEndDate, endDate: endDate, bgReadings: bgReadings, minimumChartValue: minimumChartValue)
            cachedTreatmentPoints.merge(treatmentPointsToAppend)
            treatmentPointsEndDate = endDate
        }

        updateBasalPoints(
            in: &cachedTreatmentPoints,
            startDate: treatmentPointsStartDate ?? startDate,
            endDate: treatmentPointsEndDate ?? endDate,
            minimumChartValue: minimumChartValue
        )
    }

    private func makeTreatmentPoints(startDate: Date, endDate: Date, bgReadings: [CachedBgReading], minimumChartValue: Double) -> GlucoseChartTreatmentPoints {
        let visibleTreatments = cachedTreatments.filter { $0.date >= startDate && $0.date <= endDate && !$0.isDeleted }
        let insulinTreatments = visibleTreatments.filter { $0.type == .Insulin }
        let carbsTreatments = visibleTreatments.filter { $0.type == .Carbs }
        let bgCheckTreatments = visibleTreatments.filter { $0.type == .BgCheck }
        let noteTreatments = visibleTreatments.filter { $0.type == .Note }

        var treatmentPoints = GlucoseChartTreatmentPoints()
        let treatmentOffset = treatmentSeparationOffset()
        let sortedBgReadings = bgReadings.sorted { $0.date < $1.date }

        // Different bolus and carb magnitudes use separate arrays so the renderer can size and label them without
        // recalculating thresholds inside the view.
        for treatment in insulinTreatments {
            let yValue = closestYAxisValue(treatmentDate: treatment.date, bgReadings: sortedBgReadings) - treatmentOffset
            let point = GlucoseChartTreatmentPoint(date: treatment.date, yValue: yValue, treatmentValue: treatment.value, label: label(for: treatment), notes: treatment.notes, idPrefix: "bolus")

            if treatment.value < ConstantsGlucoseChart.smallBolusTreatmentThreshold {
                treatmentPoints.smallBolus.append(point)
            } else if treatment.value < ConstantsGlucoseChart.mediumBolusTreatmentThreshold {
                treatmentPoints.mediumBolus.append(point)
            } else if treatment.value < ConstantsGlucoseChart.largeBolusTreatmentThreshold {
                treatmentPoints.largeBolus.append(point)
            } else {
                treatmentPoints.veryLargeBolus.append(point)
            }
        }

        for treatment in carbsTreatments {
            let yValue = closestYAxisValue(treatmentDate: treatment.date, bgReadings: sortedBgReadings) + treatmentOffset
            let point = GlucoseChartTreatmentPoint(date: treatment.date, yValue: yValue, treatmentValue: treatment.value, label: label(for: treatment), notes: treatment.notes, idPrefix: "carbs")

            if treatment.value < Double(ConstantsGlucoseChart.smallCarbsTreatmentThreshold) {
                treatmentPoints.smallCarbs.append(point)
            } else if treatment.value < Double(ConstantsGlucoseChart.mediumCarbsTreatmentThreshold) {
                treatmentPoints.mediumCarbs.append(point)
            } else if treatment.value < Double(ConstantsGlucoseChart.largeCarbsTreatmentThreshold) {
                treatmentPoints.largeCarbs.append(point)
            } else {
                treatmentPoints.veryLargeCarbs.append(point)
            }
        }

        for treatment in bgCheckTreatments {
            treatmentPoints.bgChecks.append(
                GlucoseChartTreatmentPoint(
                    date: treatment.date,
                    yValue: treatment.value,
                    treatmentValue: treatment.value,
                    label: nil,
                    notes: treatment.notes,
                    idPrefix: "bg-check"
                )
            )
        }

        for treatment in noteTreatments {
            treatmentPoints.notes.append(
                GlucoseChartTreatmentPoint(
                    date: treatment.date,
                    yValue: closestYAxisValue(treatmentDate: treatment.date, bgReadings: sortedBgReadings) + (treatmentOffset * 0.5),
                    treatmentValue: treatment.value,
                    label: nil,
                    notes: treatment.notes,
                    idPrefix: "note"
                )
            )
        }

        updateBasalPoints(in: &treatmentPoints, startDate: startDate, endDate: endDate, minimumChartValue: minimumChartValue)

        return treatmentPoints
    }

    private func updateBasalPoints(in treatmentPoints: inout GlucoseChartTreatmentPoints, startDate: Date, endDate: Date, minimumChartValue: Double) {
        treatmentPoints.scheduledBasalRates.removeAll()
        treatmentPoints.basalRates.removeAll()
        treatmentPoints.basalRateFill.removeAll()

        guard UserDefaults.standard.nightscoutFollowType != .none else { return }

        let basalTreatments = cachedTreatments.filter { $0.date >= startDate && $0.date <= endDate && !$0.isDeleted && $0.type == .Basal }.sorted { $0.date < $1.date }

        // Keep scheduled profile, enacted temp basal line and baseline fill as separate series.
        updateScheduledBasalRatesIfNeeded(startDate: startDate)
        updateBasalScaler(minimumChartValue: minimumChartValue)
        treatmentPoints.scheduledBasalRates = makeScheduledBasalPoints(startDate: startDate, endDate: endDate, minimumChartValue: minimumChartValue)
        treatmentPoints.basalRates = makeTempBasalPoints(startDate: startDate, endDate: endDate, basalTreatments: basalTreatments, minimumChartValue: minimumChartValue)
        treatmentPoints.basalRateFill = basalRateFillPoints(startDate: startDate, endDate: endDate, basalRatePoints: treatmentPoints.basalRates, minimumChartValue: minimumChartValue)
    }

    private func treatmentSeparationOffset() -> Double {
        let maximumValue = cachedReadings.map { $0.finalValue }.max() ?? ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl

        switch maximumValue {
        case 0..<200:
            return ConstantsGlucoseChart.defaultOffsetTreatmentPositionFromBgMarker
        case 200..<300:
            return ConstantsGlucoseChart.defaultOffsetTreatmentPositionFromBgMarker + 5
        default:
            return ConstantsGlucoseChart.defaultOffsetTreatmentPositionFromBgMarker + 15
        }
    }

    private func closestYAxisValue(treatmentDate: Date, bgReadings: [CachedBgReading]) -> Double {
        guard !bgReadings.isEmpty else { return 120 }

        guard let first = bgReadings.first, let last = bgReadings.last else { return 120 }

        if treatmentDate <= first.date {
            return first.finalValue
        }

        if treatmentDate >= last.date {
            return last.finalValue
        }

        var lowerBound = 0
        var upperBound = bgReadings.count - 1

        while lowerBound + 1 < upperBound {
            let middleIndex = (lowerBound + upperBound) / 2

            if bgReadings[middleIndex].date <= treatmentDate {
                lowerBound = middleIndex
            } else {
                upperBound = middleIndex
            }
        }

        let previousReading = bgReadings[lowerBound]
        let nextReading = bgReadings[upperBound]
        let interval = nextReading.date.timeIntervalSince(previousReading.date)

        guard interval > 0 else { return previousReading.finalValue }

        let fraction = treatmentDate.timeIntervalSince(previousReading.date) / interval

        return previousReading.finalValue + ((nextReading.finalValue - previousReading.finalValue) * fraction)
    }

    // MARK: - Basal Points

    /// Calculates the basal-to-y-axis scaler once from recent basal history and scheduled profile.
    ///
    /// Basal U/hr values are not plotted on the glucose scale. They are compressed into the reserved
    /// basal band below the normal glucose floor so the
    /// basal graph can share the glucose chart without needing a second y-axis.
    private func updateBasalScaler(minimumChartValue: Double) {
        if basalRateMaximum == 0 {
            let managedObjectContext = coreDataManager.privateManagedObjectContext
            let basalHistory = mapTreatments(
                treatmentEntryAccessor.getTreatments(
                    fromDate: Date().addingTimeInterval(-60 * 60 * 24 * ConstantsGlucoseChart.basalScaleDaysForCalculation),
                    toDate: Date(),
                    on: managedObjectContext
                ),
                on: managedObjectContext
            ).filter { !$0.isDeleted && $0.type == .Basal }

            basalRateMaximum = max(
                basalHistory.map { $0.value }.max() ?? 0,
                scheduledBasalRates.map { $0.value }.max() ?? 0
            )

            if basalRateMaximum > 0 {
                basalRateScaler = (ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl - minimumChartValue) / basalRateMaximum
            } else {
                basalRateScaler = 0
            }

            trace("in updateBasalScaler, initial calculated max basal = %{public}@, basal scaler = %{public}@", log: log, category: ConstantsLog.categoryGlucoseChartManager, type: .info, basalRateMaximum.description, basalRateScaler.description)
        }
    }

    private func updateScheduledBasalRatesIfNeeded(startDate: Date) {
        guard let scheduledBasalRatesFromProfile = nightscoutSyncManager.profile.basal, nightscoutSyncManager.profile.hasData() else {
            scheduledBasalRates.removeAll()

            return
        }

        guard scheduledBasalRatesLastUpdatedForStartDate < startDate.addingTimeInterval(-60 * 60 * 6) || scheduledBasalRatesLastUpdatedForStartDate > startDate.addingTimeInterval(60 * 60 * 6) else {
            return
        }

        scheduledBasalRates.removeAll()

        // Expand yesterday, today and tomorrow to prevent gaps where the visible range crosses a
        // midnight or scheduled profile change.
        for hoursToAddToStartDate in stride(from: -24, to: 25, by: 24) {
            for scheduledBasalRate in scheduledBasalRatesFromProfile {
                scheduledBasalRates.append((date: scheduledBasalRate.toDate(date: startDate.toMidnight().addingTimeInterval(TimeInterval(60 * 60 * hoursToAddToStartDate))), value: scheduledBasalRate.value))
            }
        }

        scheduledBasalRates.sort { $0.date < $1.date }
        scheduledBasalRatesLastUpdatedForStartDate = startDate
    }

    private func makeScheduledBasalPoints(startDate: Date, endDate: Date, minimumChartValue: Double) -> [GlucoseChartPoint] {
        updateScheduledBasalRatesIfNeeded(startDate: startDate)

        guard !scheduledBasalRates.isEmpty else { return [] }

        var chartPoints = [GlucoseChartPoint]()
        var previousScheduledBasalRate: Double = 0
        var isFirstEntry = true
        let basalRates = scheduledBasalRates.filter { $0.date >= startDate && $0.date <= endDate }

        // Step charts need two points at a rate change: one to finish the previous rate and one to
        // start the new rate at the same timestamp.
        if basalRates.isEmpty {
            if let initialBasalRate = scheduledBasalRates.filter({ $0.date < startDate }).last {
                chartPoints.append(basalPoint(value: initialBasalRate.value, date: startDate, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))
                chartPoints.append(basalPoint(value: initialBasalRate.value, date: endDate, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))
            }

            return chartPoints
        }

        for basalRate in basalRates {
            if isFirstEntry, let initialBasalRate = scheduledBasalRates.filter({ $0.date < startDate }).last {
                chartPoints.append(basalPoint(value: initialBasalRate.value, date: startDate, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))
                previousScheduledBasalRate = initialBasalRate.value
                isFirstEntry = false
            }

            chartPoints.append(basalPoint(value: previousScheduledBasalRate, date: basalRate.date, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))
            chartPoints.append(basalPoint(value: basalRate.value, date: basalRate.date, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))
            previousScheduledBasalRate = basalRate.value
        }

        chartPoints.append(basalPoint(value: previousScheduledBasalRate, date: endDate, minimumChartValue: minimumChartValue, idPrefix: "scheduled-basal"))

        return chartPoints
    }

    private func makeTempBasalPoints(startDate: Date, endDate: Date, basalTreatments: [CachedTreatment], minimumChartValue: Double) -> [GlucoseChartPoint] {
        var chartPoints = [GlucoseChartPoint]()
        var previousBasalTreatment: CachedTreatment?

        // If a temp basal expires before the next one starts, fill the gap with scheduled basal
        // points so the rendered line remains continuous.
        func addScheduledBasalPointsIfNeeded(isFirstEntry: Bool, previousBasalRate: Double, previousBasalEndDate: Date, nextBasalDate: Date?) {
            let scheduledStartDate = max(previousBasalEndDate, startDate)
            let scheduledEndDate = nextBasalDate ?? min(endDate, Date())

            guard scheduledStartDate <= scheduledEndDate else { return }

            if isFirstEntry {
                if previousBasalEndDate > startDate {
                    chartPoints.append(basalPoint(value: previousBasalRate, date: startDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                    chartPoints.append(basalPoint(value: previousBasalRate, date: previousBasalEndDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                }
            } else {
                chartPoints.append(basalPoint(value: previousBasalRate, date: previousBasalEndDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
            }

            guard let previousScheduledBasalRateEntry = scheduledBasalRates.filter({ $0.date <= scheduledStartDate }).last else {
                return
            }

            var previousScheduledBasalRate = previousScheduledBasalRateEntry.value

            chartPoints.append(basalPoint(value: previousScheduledBasalRate, date: scheduledStartDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))

            let nextScheduledBasalRateEntries = scheduledBasalRates.filter { $0.date >= scheduledStartDate && $0.date <= scheduledEndDate }

            for nextScheduledBasalRateEntry in nextScheduledBasalRateEntries {
                chartPoints.append(basalPoint(value: previousScheduledBasalRate, date: nextScheduledBasalRateEntry.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                chartPoints.append(basalPoint(value: nextScheduledBasalRateEntry.value, date: nextScheduledBasalRateEntry.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                previousScheduledBasalRate = nextScheduledBasalRateEntry.value
            }

            chartPoints.append(basalPoint(value: previousScheduledBasalRate, date: scheduledEndDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
        }

        for basalTreatment in basalTreatments {
            if basalTreatment.value > basalRateMaximum {
                basalRateMaximum = basalTreatment.value
                basalRateScaler = basalRateMaximum > 0 ? (ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl - minimumChartValue) / basalRateMaximum : 0
            }

            if let previousBasalTreatment = previousBasalTreatment {
                if basalTreatment.value != previousBasalTreatment.value {
                    let previousBasalEndDate = previousBasalTreatment.date.addingTimeInterval(TimeInterval(previousBasalTreatment.valueSecondary * 60))

                    if previousBasalEndDate < basalTreatment.date && nightscoutSyncManager.profile.hasData() {
                        addScheduledBasalPointsIfNeeded(isFirstEntry: false, previousBasalRate: previousBasalTreatment.value, previousBasalEndDate: previousBasalEndDate, nextBasalDate: basalTreatment.date)
                    } else {
                        chartPoints.append(basalPoint(value: previousBasalTreatment.value, date: basalTreatment.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                    }
                }
            } else if let previousTreatment = cachedTreatments.filter({ !$0.isDeleted && $0.type == .Basal && $0.date < startDate && $0.date >= startDate.addingTimeInterval(-Self.basalTreatmentLookbackTimeInterval) }).last {
                let previousBasalEndDate = previousTreatment.date.addingTimeInterval(TimeInterval(previousTreatment.valueSecondary * 60))

                if previousBasalEndDate < basalTreatment.date && nightscoutSyncManager.profile.hasData() {
                    addScheduledBasalPointsIfNeeded(isFirstEntry: true, previousBasalRate: previousTreatment.value, previousBasalEndDate: previousBasalEndDate, nextBasalDate: basalTreatment.date)
                } else {
                    chartPoints.append(basalPoint(value: previousTreatment.value, date: startDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                    chartPoints.append(basalPoint(value: previousTreatment.value, date: basalTreatment.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                }
            } else {
                chartPoints.append(basalPoint(value: 0, date: basalTreatment.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
            }

            if basalTreatment.value != previousBasalTreatment?.value {
                chartPoints.append(basalPoint(value: basalTreatment.value, date: basalTreatment.date, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
            }

            previousBasalTreatment = basalTreatment
        }

        if let previousBasalTreatment = previousBasalTreatment {
            let previousBasalEndDate = previousBasalTreatment.date.addingTimeInterval(TimeInterval(previousBasalTreatment.valueSecondary * 60))

            if previousBasalEndDate < min(endDate, Date()) && nightscoutSyncManager.profile.hasData() {
                addScheduledBasalPointsIfNeeded(isFirstEntry: false, previousBasalRate: previousBasalTreatment.value, previousBasalEndDate: previousBasalEndDate, nextBasalDate: nil)
            } else {
                chartPoints.append(basalPoint(value: previousBasalTreatment.value, date: min(min(endDate, previousBasalEndDate), Date()), minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
            }

            if endDate > Date() {
                chartPoints.append(basalPoint(value: 0, date: Date(), minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
                chartPoints.append(basalPoint(value: 0, date: endDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal"))
            }
        }

        return chartPoints
    }

    /// Creates the filled basal area by closing the temp basal line down to the basal baseline.
    private func basalRateFillPoints(startDate: Date, endDate: Date, basalRatePoints: [GlucoseChartPoint], minimumChartValue: Double) -> [GlucoseChartPoint] {
        guard !basalRatePoints.isEmpty else { return [] }

        var fillPoints = [basalPoint(value: 0, date: startDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal-fill")]
        fillPoints.append(contentsOf: basalRatePoints)
        fillPoints.append(basalPoint(value: 0, date: endDate, minimumChartValue: minimumChartValue, idPrefix: "temp-basal-fill"))

        return fillPoints
    }

    private func basalPoint(value: Double, date: Date, minimumChartValue: Double, idPrefix: String) -> GlucoseChartPoint {
        GlucoseChartPoint(date: date, value: (value * basalRateScaler) + minimumChartValue, idPrefix: idPrefix)
    }

    private func label(for treatment: CachedTreatment) -> String? {
        let formatter = NumberFormatter()

        switch treatment.type {
        case .Insulin:
            formatter.maximumFractionDigits = 2
        default:
            formatter.maximumFractionDigits = 0
        }

        guard let formatted = formatter.string(from: NSNumber(value: treatment.value)) else {
            return nil
        }

        return "\(formatted)\(treatment.type.unit())"
    }

    // MARK: - Core Data Mapping

    private func mapBgReadings(_ bgReadings: [BgReading], on context: NSManagedObjectContext) -> [CachedBgReading] {
        var mapped = [CachedBgReading]()

        context.performAndWait {
            mapped = bgReadings.map {
                CachedBgReading(date: $0.timeStamp, finalValue: $0.finalValue, calculatedValue: $0.calculatedValue)
            }.sorted { $0.date < $1.date }
        }

        return mapped
    }

    private func mapCalibrations(_ calibrations: [Calibration], on context: NSManagedObjectContext) -> [CachedCalibration] {
        var mapped = [CachedCalibration]()

        context.performAndWait {
            mapped = calibrations.map {
                CachedCalibration(date: $0.timeStamp, value: $0.bg)
            }.sorted { $0.date < $1.date }
        }

        return mapped
    }

    private func mapTreatments(_ treatments: [TreatmentEntry], on context: NSManagedObjectContext) -> [CachedTreatment] {
        var mapped = [CachedTreatment]()

        context.performAndWait {
            mapped = treatments.map {
                CachedTreatment(date: $0.date, value: $0.value, valueSecondary: $0.valueSecondary, type: $0.treatmentType, isDeleted: $0.treatmentdeleted, notes: $0.notes)
            }.sorted { $0.date < $1.date }
        }

        return mapped
    }

}

// MARK: - Treatment Point Cache Helpers

private extension GlucoseChartTreatmentPoints {

    /// Merges newly materialised treatment point ranges without disturbing existing cached points.
    ///
    /// This is deliberately symmetric with the raw cache merge helpers below so all chart point
    /// types get the same append/prepend performance behaviour during scrolling.
    mutating func merge(_ treatmentPoints: GlucoseChartTreatmentPoints) {
        smallBolus.merge(treatmentPoints.smallBolus)
        mediumBolus.merge(treatmentPoints.mediumBolus)
        largeBolus.merge(treatmentPoints.largeBolus)
        veryLargeBolus.merge(treatmentPoints.veryLargeBolus)
        smallCarbs.merge(treatmentPoints.smallCarbs)
        mediumCarbs.merge(treatmentPoints.mediumCarbs)
        largeCarbs.merge(treatmentPoints.largeCarbs)
        veryLargeCarbs.merge(treatmentPoints.veryLargeCarbs)
        bgChecks.merge(treatmentPoints.bgChecks)
        notes.merge(treatmentPoints.notes)
    }

    mutating func trim(from startDate: Date, to endDate: Date) {
        smallBolus.removeAll { $0.date < startDate || $0.date > endDate }
        mediumBolus.removeAll { $0.date < startDate || $0.date > endDate }
        largeBolus.removeAll { $0.date < startDate || $0.date > endDate }
        veryLargeBolus.removeAll { $0.date < startDate || $0.date > endDate }
        smallCarbs.removeAll { $0.date < startDate || $0.date > endDate }
        mediumCarbs.removeAll { $0.date < startDate || $0.date > endDate }
        largeCarbs.removeAll { $0.date < startDate || $0.date > endDate }
        veryLargeCarbs.removeAll { $0.date < startDate || $0.date > endDate }
        bgChecks.removeAll { $0.date < startDate || $0.date > endDate }
        notes.removeAll { $0.date < startDate || $0.date > endDate }
        scheduledBasalRates.removeAll { $0.date < startDate || $0.date > endDate }
        basalRates.removeAll { $0.date < startDate || $0.date > endDate }
        basalRateFill.removeAll { $0.date < startDate || $0.date > endDate }
    }

}

// MARK: - Cached Core Data Snapshots

private struct CachedBgReading: Hashable {
    let date: Date
    let finalValue: Double
    let calculatedValue: Double
}

private struct CachedCalibration: Hashable {
    let date: Date
    let value: Double
}

private struct CachedTreatment: Hashable {
    let date: Date
    let value: Double
    let valueSecondary: Double
    let type: TreatmentType
    let isDeleted: Bool
    let notes: String?
}

private struct CachedSensorNoiseSample: Hashable {
    let date: Date
    let shortTermNoise: Double?

    var bandStyle: GlucoseChartBackgroundBand.Style? {
        guard let shortTermNoise else { return nil }

        switch ConstantsSensorNoise.state(for: shortTermNoise, sensitivity: UserDefaults.standard.sensorNoiseSensitivity) {
        case .veryHigh:
            return .sensorNoiseWarning
        case .extreme:
            return .sensorNoiseUrgent
        case .collecting, .low, .elevated, .flatlineSuspected:
            return nil
        }
    }
}

// MARK: - Cache Merge Helpers

private extension Array where Element == CachedBgReading {
    /// De-duplicates overlapping load ranges and keeps chart data in time order for binary searches
    /// and stable SwiftUI diffing.
    mutating func merge(_ elements: [CachedBgReading]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}

private extension Array where Element == CachedCalibration {
    mutating func merge(_ elements: [CachedCalibration]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}

private extension Array where Element == CachedTreatment {
    mutating func merge(_ elements: [CachedTreatment]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}

private extension Array where Element == CachedSensorNoiseSample {
    mutating func merge(_ elements: [CachedSensorNoiseSample]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}

private extension Array where Element == GlucoseChartPoint {
    mutating func merge(_ elements: [GlucoseChartPoint]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}

private extension Array where Element == GlucoseChartTreatmentPoint {
    mutating func merge(_ elements: [GlucoseChartTreatmentPoint]) {
        self = Array(Set(self).union(elements)).sorted { $0.date < $1.date }
    }
}
