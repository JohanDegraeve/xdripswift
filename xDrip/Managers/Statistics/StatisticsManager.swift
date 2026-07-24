//
//  StatisticsManager.swift
//  xdrip
//
//  Created by Paul Plant on 26/04/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

/// Central statistics service for app views and generated reports.
///
/// This class was re-written when the standalone Statistics tab and PDF reporting were added.
/// The previous implementation only served the compact root view statistics, while the report
/// feature temporarily introduced its own analytics service for AGP, trend, daily pattern and
/// report-period calculations. Keeping those paths separate would make the same clinical metrics
/// easy to calculate differently in different parts of the app.
///
/// `StatisticsManager` is now the single owner for CGM-derived statistics used by the home screen,
/// Statistics tab and PDF reports. It deliberately returns small value types instead of managed
/// objects. All Core Data work is serialized through `operationQueue` and fetched on the private
/// context so heavyweight report/statistics requests cannot block the main context used by the
/// home chart. Report analytics are cached and invalidated when stored CGM readings change.
///
/// The manager is marked `@unchecked Sendable` because callers may request async analytics from
/// SwiftUI tasks, but all internal mutable state is isolated manually on the serial operation queue.
public final class StatisticsManager: @unchecked Sendable {
    private struct CGMSample {
        let date: Date
        let valueMgDl: Double
        let deviceName: String?
        let sensorID: String?
    }

    private struct ReportSensorSummary {
        let count: Int
        let averageDuration: TimeInterval?
    }

    private struct CGMWindowCache {
        let startDate: Date
        let endDate: Date
        let samples: [CGMSample]
    }

    private struct ReportAnalyticsCacheKey: Hashable {
        let period: GlucoseReportPeriod
        let usesMgDl: Bool
    }

    private let operationQueue: OperationQueue
    private let coreDataManager: CoreDataManager
    private let calendar = Calendar.current

    private var sampleCache: CGMWindowCache?
    private var availableReportPeriodsCache: [GlucoseReportPeriod: Bool]?
    private var reportAnalyticsCache: [ReportAnalyticsCacheKey: GlucoseReportAnalytics] = [:]

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager

        operationQueue = OperationQueue()
        operationQueue.name = "xDrip StatisticsManager"
        operationQueue.maxConcurrentOperationCount = 1
    }

    /// Clears cached sample windows and derived analytics.
    ///
    /// Call this after importing, deleting, or receiving CGM data. Existing root statistics APIs
    /// still compute through the same serialized queue, so invalidation never races active work.
    public func invalidate() {
        operationQueue.addOperation { [weak self] in
            self?.sampleCache = nil
            self?.availableReportPeriodsCache = nil
            self?.reportAnalyticsCache.removeAll()
        }
    }

    /// Calculates the compact statistics used by the home screen.
    /// - Parameters:
    ///   - fromDate: Start of the statistics window.
    ///   - toDate: Optional end of the statistics window.
    ///   - callback: Called on the main thread with the calculated values.
    public func calculateStatistics(fromDate: Date, toDate: Date? = Date(), callback: @escaping (Statistics) -> Void) {
        operationQueue.addOperation { [weak self] in
            guard let self else { return }

            let statistics = self.makeRootStatistics(fromDate: fromDate, toDate: toDate)
            DispatchQueue.main.async {
                callback(statistics)
            }
        }
    }

    /// Calculates per-day TIR statistics in a single serialized Core Data fetch.
    /// - Parameters:
    ///   - fromDate: Start of the range.
    ///   - toDate: End of the range.
    ///   - callback: Called on the main thread with one statistics value per day.
    public func calculateDailyTIR(fromDate: Date, toDate: Date? = Date(), callback: @escaping ([Date: Statistics]) -> Void) {
        operationQueue.addOperation { [weak self] in
            guard let self else { return }

            let statisticsByDay = self.makeDailyTIRStatistics(fromDate: fromDate, toDate: toDate)
            DispatchQueue.main.async {
                callback(statisticsByDay)
            }
        }
    }

    /// Returns available report periods based on CGM coverage.
    ///
    /// The 70% coverage threshold follows the same consensus target used by the report:
    /// https://doi.org/10.2337/dci19-0028
    func availableReportPeriods() async -> [GlucoseReportPeriod: Bool] {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: [:])
                    return
                }

                if let cached = self.availableReportPeriodsCache {
                    continuation.resume(returning: cached)
                    return
                }

                let endDate = Date()
                let samples = self.cachedSamples(
                    fromDate: endDate.addingTimeInterval(-Double(GlucoseReportPeriod.oneYear.rawValue + 1) * 24 * 60 * 60),
                    toDate: endDate
                )

                let availability = Dictionary(uniqueKeysWithValues: GlucoseReportPeriod.allCases.map { period in
                    let requiredStart = endDate.addingTimeInterval(-Double(period.rawValue) * 24 * 60 * 60)
                    let sampleCount = samples.filter { $0.date >= requiredStart }.count
                    return (period, Self.hasEnoughCoverage(sampleCount: sampleCount, period: period))
                })

                self.availableReportPeriodsCache = availability
                continuation.resume(returning: availability)
            }
        }
    }

    /// Returns full CGM analytics for the Statistics tab and PDF reports.
    ///
    /// This is intentionally separate from `calculateStatistics` so the home screen never needs to
    /// build AGP percentiles, daily bars, trend points, or device metadata.
    func reportAnalytics(for configuration: GlucoseReportConfiguration) async -> GlucoseReportAnalytics {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: StatisticsManager.emptyReportAnalytics(for: configuration, periodEnd: Date()))
                    return
                }

                let cacheKey = ReportAnalyticsCacheKey(
                    period: configuration.period,
                    usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl
                )

                if let cached = self.reportAnalyticsCache[cacheKey] {
                    continuation.resume(returning: cached)
                    return
                }

                let analytics = self.makeReportAnalytics(for: configuration)
                self.reportAnalyticsCache[cacheKey] = analytics
                continuation.resume(returning: analytics)
            }
        }
    }

    private func makeRootStatistics(fromDate: Date, toDate: Date?) -> Statistics {
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let lowLimitForTIR = UserDefaults.standard.timeInRangeType.lowerLimit
        let highLimitForTIR = UserDefaults.standard.timeInRangeType.higherLimit
        let samples = fetchSamples(fromDate: fromDate, toDate: toDate ?? Date())

        guard !samples.isEmpty else {
            return Statistics(
                lowStatisticValue: 0,
                highStatisticValue: 0,
                inRangeStatisticValue: 0,
                averageStatisticValue: 0,
                a1CStatisticValue: 0,
                cVStatisticValue: 0,
                lowLimitForTIR: lowLimitForTIR,
                highLimitForTIR: highLimitForTIR,
                numberOfDaysUsed: 0
            )
        }

        let filteredValues = filteredRootStatisticValues(samples: samples, isMgDl: isMgDl)
        guard !filteredValues.isEmpty else {
            return Statistics(
                lowStatisticValue: 0,
                highStatisticValue: 0,
                inRangeStatisticValue: 0,
                averageStatisticValue: 0,
                a1CStatisticValue: 0,
                cVStatisticValue: 0,
                lowLimitForTIR: lowLimitForTIR,
                highLimitForTIR: highLimitForTIR,
                numberOfDaysUsed: 0
            )
        }

        let lowCount = filteredValues.lazy.filter { $0 < lowLimitForTIR }.count
        let highCount = filteredValues.lazy.filter { $0 > highLimitForTIR }.count
        let lowStatisticValue = Double((lowCount * 200) / (filteredValues.count * 2))
        let highStatisticValue = Double((highCount * 200) / (filteredValues.count * 2))
        let averageStatisticValue = filteredValues.reduce(0, +) / Double(filteredValues.count)
        let a1CStatisticValue = Self.a1cValue(forAverage: averageStatisticValue, isMgDl: isMgDl)
        let cVStatisticValue = Self.coefficientOfVariation(values: filteredValues, average: averageStatisticValue)
        let firstDate = samples.first?.date ?? Date()
        var numberOfDaysUsed = calendar.dateComponents([.day], from: firstDate - 5 * 60, to: Date()).day ?? 0

        // Keep the existing root-view 90-day display behavior.
        numberOfDaysUsed += (numberOfDaysUsed == 89 ? 1 : 0)

        return Statistics(
            lowStatisticValue: lowStatisticValue,
            highStatisticValue: highStatisticValue,
            inRangeStatisticValue: 100 - lowStatisticValue - highStatisticValue,
            averageStatisticValue: averageStatisticValue,
            a1CStatisticValue: a1CStatisticValue,
            cVStatisticValue: cVStatisticValue,
            lowLimitForTIR: lowLimitForTIR,
            highLimitForTIR: highLimitForTIR,
            numberOfDaysUsed: numberOfDaysUsed
        )
    }

    private func makeDailyTIRStatistics(fromDate: Date, toDate: Date?) -> [Date: Statistics] {
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let lowLimitForTIR = UserDefaults.standard.timeInRangeType.lowerLimit
        let highLimitForTIR = UserDefaults.standard.timeInRangeType.higherLimit
        let startDay = calendar.startOfDay(for: fromDate)
        let endDate = toDate ?? Date()
        let endDay = calendar.startOfDay(for: endDate)
        let samples = fetchSamples(fromDate: fromDate, toDate: endDate)
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        var statisticsByDay: [Date: Statistics] = [:]
        var day = startDay

        while day <= endDay {
            let daySamples = grouped[day] ?? []
            let values = filteredRootStatisticValues(samples: daySamples, isMgDl: isMgDl)
            statisticsByDay[day] = makeStatisticsForDay(
                values: values,
                lowLimitForTIR: lowLimitForTIR,
                highLimitForTIR: highLimitForTIR,
                isMgDl: isMgDl
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return statisticsByDay
    }

    private func makeStatisticsForDay(values: [Double], lowLimitForTIR: Double, highLimitForTIR: Double, isMgDl: Bool) -> Statistics {
        guard !values.isEmpty else {
            return Statistics(
                lowStatisticValue: 0,
                highStatisticValue: 0,
                inRangeStatisticValue: 0,
                averageStatisticValue: 0,
                a1CStatisticValue: 0,
                cVStatisticValue: 0,
                lowLimitForTIR: lowLimitForTIR,
                highLimitForTIR: highLimitForTIR,
                numberOfDaysUsed: 0
            )
        }

        let lowCount = values.lazy.filter { $0 < lowLimitForTIR }.count
        let highCount = values.lazy.filter { $0 > highLimitForTIR }.count
        let lowStatisticValue = Double((lowCount * 200) / (values.count * 2))
        let highStatisticValue = Double((highCount * 200) / (values.count * 2))
        let averageStatisticValue = values.reduce(0, +) / Double(values.count)

        return Statistics(
            lowStatisticValue: lowStatisticValue,
            highStatisticValue: highStatisticValue,
            inRangeStatisticValue: 100 - lowStatisticValue - highStatisticValue,
            averageStatisticValue: averageStatisticValue,
            a1CStatisticValue: Self.a1cValue(forAverage: averageStatisticValue, isMgDl: isMgDl),
            cVStatisticValue: Self.coefficientOfVariation(values: values, average: averageStatisticValue),
            lowLimitForTIR: lowLimitForTIR,
            highLimitForTIR: highLimitForTIR,
            numberOfDaysUsed: 1
        )
    }

    private func makeReportAnalytics(for configuration: GlucoseReportConfiguration) -> GlucoseReportAnalytics {
        let periodEnd = Date()
        let periodStart = periodEnd.addingTimeInterval(-Double(configuration.period.rawValue) * 24 * 60 * 60)
        let samples = cachedSamples(fromDate: periodStart, toDate: periodEnd)
            .filter { Self.isValidGlucoseMgDl($0.valueMgDl) }
            .sorted { $0.date < $1.date }

        guard !samples.isEmpty else {
            return Self.emptyReportAnalytics(for: configuration, periodEnd: periodEnd)
        }

        let values = samples.map(\.valueMgDl)
        let average = values.reduce(0, +) / Double(values.count)
        let standardDeviation = Self.standardDeviation(values: values, average: average)
        let expectedSamples = Double(Self.expectedSamples(for: configuration.period))
        let deviceNames = Array(
            Set(samples.compactMap { sample in
                let name = sample.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
                return name?.isEmpty == false ? name : nil
            })
        ).sorted()
        let reportSensorSummary = sensorSummary(fromDate: periodStart, toDate: periodEnd)

        return GlucoseReportAnalytics(
            periodStart: periodStart,
            periodEnd: periodEnd,
            firstReading: samples.first?.date,
            lastReading: samples.last?.date,
            sampleCount: samples.count,
            dataCapturePercentage: min(100, Double(samples.count) / expectedSamples * 100),
            readingsPerDay: Double(samples.count) / Double(configuration.period.rawValue),
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            averageMgDl: average,
            standardDeviationMgDl: standardDeviation,
            coefficientOfVariation: average > 0 ? standardDeviation / average * 100 : 0,
            gmiPercentage: GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: average),
            rangeDistribution: makeRangeDistribution(samples: samples),
            tightRangeDistribution: makeTightRangeDistribution(samples: samples),
            agpPoints: makeAGPPoints(samples: samples),
            dailySummaries: makeDailySummaries(samples: samples, periodEnd: periodEnd, periodDays: configuration.period.rawValue),
            trendPoints: makeTrendPoints(samples: samples),
            deviceNames: deviceNames,
            sensorCount: reportSensorSummary.count,
            averageSensorDuration: reportSensorSummary.averageDuration,
            calibrationCount: calibrationCount(fromDate: periodStart, toDate: periodEnd),
            lowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeLowMgDl, isBelow: true),
            veryLowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryLowMgDl, isBelow: true),
            highEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeHighMgDl, isBelow: false),
            veryHighEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryHighMgDl, isBelow: false)
        )
    }

    private func cachedSamples(fromDate: Date, toDate: Date) -> [CGMSample] {
        if let sampleCache,
           sampleCache.startDate <= fromDate,
           sampleCache.endDate >= toDate {
            return sampleCache.samples.filter { $0.date >= fromDate && $0.date <= toDate }
        }

        let samples = fetchSamples(fromDate: fromDate, toDate: toDate)
        sampleCache = CGMWindowCache(startDate: fromDate, endDate: toDate, samples: samples)
        availableReportPeriodsCache = nil
        reportAnalyticsCache.removeAll()
        return samples
    }

    private func fetchSamples(fromDate: Date, toDate: Date) -> [CGMSample] {
        let context = coreDataManager.privateManagedObjectContext
        var samples: [CGMSample] = []

        context.performAndWait {
            let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "timeStamp > %@ AND timeStamp < %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(format: "isSuppressedByFiveMinuteCadence == NO")
            ])
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.includesPropertyValues = true
            fetchRequest.relationshipKeyPathsForPrefetching = ["sensor", "calibration"]

            do {
                let readings = try context.fetch(fetchRequest)
                samples = readings.compactMap { reading in
                    guard reading.finalValue != 0,
                          Self.isValidGlucoseMgDl(reading.finalValue) else {
                        return nil
                    }

                    return CGMSample(
                        date: reading.timeStamp,
                        valueMgDl: reading.finalValue,
                        deviceName: reading.deviceName,
                        sensorID: reading.sensor?.id
                    )
                }
            } catch {
                trace("in StatisticsManager.fetchSamples, Unable to execute BgReading fetch request: %{public}@", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBgReadings), category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, error.localizedDescription)
            }
        }

        return samples
    }

    private func sensorSummary(fromDate: Date, toDate: Date) -> ReportSensorSummary {
        let intervals = normalizedSensorIntervals(fromDate: fromDate, toDate: toDate)
        guard !intervals.isEmpty else {
            return ReportSensorSummary(count: 0, averageDuration: nil)
        }

        let totalDuration = intervals.reduce(0) { duration, interval in
            duration + interval.end.timeIntervalSince(interval.start)
        }

        return ReportSensorSummary(
            count: intervals.count,
            averageDuration: totalDuration / Double(intervals.count)
        )
    }

    private func normalizedSensorIntervals(fromDate: Date, toDate: Date) -> [(start: Date, end: Date)] {
        let context = coreDataManager.privateManagedObjectContext
        var intervals: [(start: Date, end: Date)] = []

        context.performAndWait {
            let fetchRequest: NSFetchRequest<Sensor> = Sensor.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: true)]
            fetchRequest.predicate = NSPredicate(
                format: "startDate < %@ AND (endDate == nil OR endDate > %@)",
                toDate as NSDate,
                fromDate as NSDate
            )
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.includesPropertyValues = true

            do {
                intervals = try context.fetch(fetchRequest).compactMap { sensor in
                    let clippedStart = max(sensor.startDate, fromDate)
                    let clippedEnd = min(sensor.endDate ?? toDate, toDate)

                    guard clippedEnd > clippedStart else { return nil }

                    return (start: clippedStart, end: clippedEnd)
                }
            } catch {
                trace("in StatisticsManager.normalizedSensorIntervals, Unable to execute Sensor fetch request: %{public}@", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataSensors), category: ConstantsLog.categoryApplicationDataSensors, type: .error, error.localizedDescription)
            }
        }

        guard let firstInterval = intervals.first else { return [] }

        // Sensor metadata can contain duplicate or overlapping rows after transmitter imports,
        // Nightscout sync, or manual repair. Merge overlaps so the report describes effective
        // sensor periods instead of raw Core Data rows.
        let mergeTolerance: TimeInterval = .minutes(30)
        return intervals.dropFirst().reduce(into: [firstInterval]) { merged, interval in
            guard let last = merged.last else {
                merged.append(interval)
                return
            }

            if interval.start <= last.end.addingTimeInterval(mergeTolerance) {
                merged[merged.count - 1] = (start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
    }

    private func calibrationCount(fromDate: Date, toDate: Date) -> Int {
        let context = coreDataManager.privateManagedObjectContext
        var count = 0

        context.performAndWait {
            let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "timeStamp > %@ AND timeStamp < %@", fromDate as NSDate, toDate as NSDate)

            do {
                count = try context.count(for: fetchRequest)
            } catch {
                trace("in StatisticsManager.calibrationCount, Unable to execute Calibration count request: %{public}@", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations), category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, error.localizedDescription)
            }
        }

        return count
    }

    private func filteredRootStatisticValues(samples: [CGMSample], isMgDl: Bool) -> [Double] {
        let minimumSecondsBetweenReadings = Double(ConstantsStatistics.minimumFilterTimeBetweenReadings) * 60
        var values: [Double] = []
        var previousDate: Date?

        for sample in samples {
            let shouldAppend = previousDate.map { sample.date.timeIntervalSince($0) >= minimumSecondsBetweenReadings } ?? true
            guard shouldAppend else { continue }

            values.append(isMgDl ? sample.valueMgDl : sample.valueMgDl * ConstantsBloodGlucose.mgDlToMmoll)
            previousDate = sample.date
        }

        return values
    }

    private func makeRangeDistribution(samples: [CGMSample]) -> GlucoseReportRangeDistribution {
        let total = Double(samples.count)
        func percentage(_ predicate: (Double) -> Bool) -> Double {
            Double(samples.filter { predicate($0.valueMgDl) }.count) / total * 100
        }

        return GlucoseReportRangeDistribution(
            veryLow: percentage { $0 < GlucoseReportClinicalConstants.veryLowMgDl },
            low: percentage { $0 >= GlucoseReportClinicalConstants.veryLowMgDl && $0 < GlucoseReportClinicalConstants.timeInRangeLowMgDl },
            target: percentage { $0 >= GlucoseReportClinicalConstants.timeInRangeLowMgDl && $0 <= GlucoseReportClinicalConstants.timeInRangeHighMgDl },
            high: percentage { $0 > GlucoseReportClinicalConstants.timeInRangeHighMgDl && $0 <= GlucoseReportClinicalConstants.veryHighMgDl },
            veryHigh: percentage { $0 > GlucoseReportClinicalConstants.veryHighMgDl }
        )
    }

    private func makeTightRangeDistribution(samples: [CGMSample]) -> GlucoseReportRangeDistribution {
        let total = Double(samples.count)
        func percentage(_ predicate: (Double) -> Bool) -> Double {
            Double(samples.filter { predicate($0.valueMgDl) }.count) / total * 100
        }

        return .tightRange(
            below: percentage { $0 < GlucoseReportClinicalConstants.timeInTightRangeLowMgDl },
            target: percentage { $0 >= GlucoseReportClinicalConstants.timeInTightRangeLowMgDl && $0 <= GlucoseReportClinicalConstants.timeInTightRangeHighMgDl },
            above: percentage { $0 > GlucoseReportClinicalConstants.timeInTightRangeHighMgDl }
        )
    }

    private func makeAGPPoints(samples: [CGMSample]) -> [GlucoseReportAGPPoint] {
        let bucketSize = 30
        let grouped = Dictionary(grouping: samples) { sample in
            let components = calendar.dateComponents([.hour, .minute], from: sample.date)
            let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            return minuteOfDay / bucketSize
        }

        return grouped.keys.sorted().compactMap { bucket -> GlucoseReportAGPPoint? in
            let values = grouped[bucket]?.map(\.valueMgDl).sorted() ?? []
            guard values.count >= 3 else { return nil }

            return GlucoseReportAGPPoint(
                minuteOfDay: bucket * bucketSize,
                p5MgDl: Self.percentile(0.05, values: values),
                p25MgDl: Self.percentile(0.25, values: values),
                medianMgDl: Self.percentile(0.50, values: values),
                p75MgDl: Self.percentile(0.75, values: values),
                p95MgDl: Self.percentile(0.95, values: values)
            )
        }
    }

    private func makeDailySummaries(samples: [CGMSample], periodEnd: Date, periodDays: Int) -> [GlucoseReportDailySummary] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        let endDay = calendar.startOfDay(for: periodEnd)
        let startDay = calendar.date(byAdding: .day, value: -(periodDays - 1), to: endDay) ?? endDay
        var summaries: [GlucoseReportDailySummary] = []
        var day = startDay

        while day <= endDay {
            if let daySamples = grouped[day], !daySamples.isEmpty {
                let values = daySamples.map(\.valueMgDl)
                let average = values.reduce(0, +) / Double(values.count)
                let total = Double(values.count)
                summaries.append(GlucoseReportDailySummary(
                    date: day,
                    averageMgDl: average,
                    targetPercentage: Double(daySamples.filter { $0.valueMgDl >= GlucoseReportClinicalConstants.timeInRangeLowMgDl && $0.valueMgDl <= GlucoseReportClinicalConstants.timeInRangeHighMgDl }.count) / total * 100,
                    lowPercentage: Double(daySamples.filter { $0.valueMgDl < GlucoseReportClinicalConstants.timeInRangeLowMgDl }.count) / total * 100,
                    highPercentage: Double(daySamples.filter { $0.valueMgDl > GlucoseReportClinicalConstants.timeInRangeHighMgDl }.count) / total * 100,
                    sampleCount: daySamples.count
                ))
            } else {
                summaries.append(GlucoseReportDailySummary(date: day, averageMgDl: 0, targetPercentage: 0, lowPercentage: 0, highPercentage: 0, sampleCount: 0))
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return summaries
    }

    private func makeTrendPoints(samples: [CGMSample]) -> [GlucoseReportTrendPoint] {
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: sample.date)) ?? calendar.startOfDay(for: sample.date)
        }

        return grouped.keys.sorted().compactMap { date -> GlucoseReportTrendPoint? in
            guard let bucketSamples = grouped[date], bucketSamples.count >= 12 else { return nil }
            let values = bucketSamples.map(\.valueMgDl)
            let average = values.reduce(0, +) / Double(values.count)
            let standardDeviation = Self.standardDeviation(values: values, average: average)

            return GlucoseReportTrendPoint(
                date: date,
                interval: .weekly,
                averageMgDl: average,
                coefficientOfVariation: average > 0 ? standardDeviation / average * 100 : 0,
                sampleCount: bucketSamples.count
            )
        }
    }

    private func countEvents(samples: [CGMSample], threshold: Double, isBelow: Bool) -> Int {
        var eventCount = 0
        var isInsideEvent = false
        var previousEventSampleDate: Date?

        for sample in samples {
            let matches = isBelow ? sample.valueMgDl < threshold : sample.valueMgDl > threshold
            let continuesPreviousEvent = previousEventSampleDate.map { sample.date.timeIntervalSince($0) <= 15 * 60 } ?? false

            if matches {
                if !isInsideEvent || !continuesPreviousEvent {
                    eventCount += 1
                }
                isInsideEvent = true
                previousEventSampleDate = sample.date
            } else if !continuesPreviousEvent {
                isInsideEvent = false
                previousEventSampleDate = nil
            }
        }

        return eventCount
    }

    private static func a1cValue(forAverage average: Double, isMgDl: Bool) -> Double {
        let averageMgDl = isMgDl ? average : average / ConstantsBloodGlucose.mgDlToMmoll

        // NGSP/DCCT and IFCC conversion equations: http://www.ngsp.org/ifccngsp.asp
        if UserDefaults.standard.useIFCCA1C {
            return (((46.7 + averageMgDl) / 28.7) - 2.152) / 0.09148
        } else {
            return (46.7 + averageMgDl) / 28.7
        }
    }

    private static func coefficientOfVariation(values: [Double], average: Double) -> Double {
        guard average > 0 else { return 0 }
        return standardDeviation(values: values, average: average) / average * 100
    }

    private static func standardDeviation(values: [Double], average: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sumOfSquares = values.reduce(0) { partialResult, value in
            partialResult + pow(value - average, 2)
        }
        return sqrt(sumOfSquares / Double(values.count))
    }

    private static func percentile(_ percentile: Double, values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let position = percentile * Double(values.count - 1)
        let lower = Int(floor(position))
        let upper = Int(ceil(position))
        guard lower != upper else { return values[lower] }

        let weight = position - Double(lower)
        return values[lower] * (1 - weight) + values[upper] * weight
    }

    private static func isValidGlucoseMgDl(_ value: Double) -> Bool {
        value >= ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl && value <= 450
    }

    private static func hasEnoughCoverage(sampleCount: Int, period: GlucoseReportPeriod) -> Bool {
        Double(sampleCount) >= Double(expectedSamples(for: period)) * GlucoseReportClinicalConstants.minimumDataCapturePercentage / 100
    }

    private static func expectedSamples(for period: GlucoseReportPeriod) -> Int {
        period.rawValue * GlucoseReportClinicalConstants.expectedReadingsPerDay
    }

    private static func emptyReportAnalytics(for configuration: GlucoseReportConfiguration, periodEnd: Date) -> GlucoseReportAnalytics {
        let periodStart = periodEnd.addingTimeInterval(-Double(configuration.period.rawValue) * 24 * 60 * 60)

        return GlucoseReportAnalytics(
            periodStart: periodStart,
            periodEnd: periodEnd,
            firstReading: nil,
            lastReading: nil,
            sampleCount: 0,
            dataCapturePercentage: 0,
            readingsPerDay: 0,
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            averageMgDl: 0,
            standardDeviationMgDl: 0,
            coefficientOfVariation: 0,
            gmiPercentage: 0,
            rangeDistribution: GlucoseReportRangeDistribution(veryLow: 0, low: 0, target: 0, high: 0, veryHigh: 0),
            tightRangeDistribution: .tightRange(below: 0, target: 0, above: 0),
            agpPoints: [],
            dailySummaries: [],
            trendPoints: [],
            deviceNames: [],
            sensorCount: 0,
            averageSensorDuration: nil,
            calibrationCount: 0,
            lowEventCount: 0,
            veryLowEventCount: 0,
            highEventCount: 0,
            veryHighEventCount: 0
        )
    }

    /// Result model used by existing root/landscape statistics views.
    public struct Statistics {
        var lowStatisticValue: Double
        var highStatisticValue: Double
        var inRangeStatisticValue: Double
        var averageStatisticValue: Double
        var a1CStatisticValue: Double
        var cVStatisticValue: Double
        var lowLimitForTIR: Double
        var highLimitForTIR: Double
        var numberOfDaysUsed: Int
    }
}
