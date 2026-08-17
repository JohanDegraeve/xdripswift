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
/// home chart. Report analytics are cached and invalidated whenever either persistent app context
/// saves, including device-status-only imports, restores and cleanup operations.
///
/// The manager is marked `@unchecked Sendable` because callers may request async analytics from
/// SwiftUI tasks, but all internal mutable state is isolated manually on the serial operation queue.
public final class StatisticsManager: @unchecked Sendable {
    /// The minimum data needed to draw a recent AGP comparison without building full report analytics.
    struct LandscapeBaseline {
        let dayCount: Int
        let usesMgDl: Bool
        let agpPoints: [GlucoseReportAGPPoint]
    }

    struct LandscapeLoopalyzerSnapshot {
        let points: [GlucoseReportLoopalyzerPoint]
        let insulinTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
        let carbTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
    }

    struct LandscapeAnalytics {
        let baseline: LandscapeBaseline
        let loopalyzer: LandscapeLoopalyzerSnapshot?
    }

    struct NightscoutLoopSnapshots {
        let deviceStatuses: [NightscoutDeviceStatusSnapshot]
        let profiles: [NightscoutProfileSnapshot]
    }

    private struct CGMSample {
        let date: Date
        let valueMgDl: Double
        let sensorID: String?
    }

    private struct TreatmentSample {
        let date: Date
        let value: Double
        let type: TreatmentType
        let enteredBy: String?
    }

    private struct BasalTreatmentSample {
        let date: Date
        let rate: Double
        let durationMinutes: Double

        var endDate: Date {
            date.addingTimeInterval(durationMinutes * 60)
        }
    }

    private struct ReportSensorSummary {
        let count: Int
        let averageDuration: TimeInterval?
    }

    private struct AIDStatusInterval {
        let status: NightscoutDeviceStatusSnapshot
        let duration: TimeInterval
    }

    private struct CGMWindowCache {
        let startDate: Date
        let endDate: Date
        let samples: [CGMSample]
    }

    private struct ReportAnalyticsCacheKey: Hashable {
        let period: GlucoseReportPeriod
        let aidPeriod: GlucoseReportAIDPeriod
        let usesMgDl: Bool
        let aidAnalyticsSource: AIDAnalyticsSource?
    }

    private let operationQueue: OperationQueue
    private let coreDataManager: CoreDataManager
    private let calendar = Calendar.current
    private var contextSaveObservers = [NSObjectProtocol]()

    private var sampleCache: CGMWindowCache?
    private var availableReportPeriodsCache: [GlucoseReportPeriod: Bool]?
    private var reportAnalyticsCache: [ReportAnalyticsCacheKey: GlucoseReportAnalytics] = [:]

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager

        operationQueue = OperationQueue()
        operationQueue.name = "xDrip StatisticsManager"
        operationQueue.maxConcurrentOperationCount = 1

        let notificationCenter = NotificationCenter.default
        let contexts = [
            coreDataManager.mainManagedObjectContext,
            coreDataManager.privateManagedObjectContext
        ]
        contextSaveObservers = contexts.map { context in
            notificationCenter.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: context,
                queue: nil
            ) { [weak self] _ in
                self?.invalidate()
            }
        }
    }

    deinit {
        contextSaveObservers.forEach(NotificationCenter.default.removeObserver)
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
        return await withCheckedContinuation { continuation in
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
        // Capture the complete policy decision once. The queued calculation, cache identity and
        // provider-specific fetches must all describe the same configuration even if Settings are
        // changed while this request is waiting on the serial statistics queue.
        let aidAnalyticsSource = UserDefaults.standard.dataFlowPolicy.aidAnalyticsSource

        return await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: StatisticsManager.emptyReportAnalytics(for: configuration, periodEnd: Date()))
                    return
                }

                let cacheKey = ReportAnalyticsCacheKey(
                    period: configuration.period,
                    aidPeriod: configuration.aidPeriod,
                    usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                    aidAnalyticsSource: aidAnalyticsSource
                )

                if let cached = self.reportAnalyticsCache[cacheKey] {
                    continuation.resume(returning: cached)
                    return
                }

                let analytics = self.makeReportAnalytics(
                    for: configuration,
                    aidAnalyticsSource: aidAnalyticsSource
                )
                self.reportAnalyticsCache[cacheKey] = analytics
                continuation.resume(returning: analytics)
            }
        }
    }

    /// Returns a compact recent AGP baseline for the landscape comparison view.
    func landscapeBaseline(referenceDate: Date = Date(), daysBack: Int) async -> LandscapeBaseline {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: StatisticsManager.emptyLandscapeBaseline())
                    return
                }

                let periodEnd = self.calendar.startOfDay(for: referenceDate)
                guard let periodStart = self.calendar.date(
                    byAdding: .day,
                    value: -max(1, daysBack),
                    to: periodEnd
                ) else {
                    continuation.resume(returning: StatisticsManager.emptyLandscapeBaseline())
                    return
                }

                // The selected day is the overlay, so the baseline ends at its midnight and only
                // contains complete preceding calendar days.
                let samples = self.cachedSamples(fromDate: periodStart, toDate: periodEnd)
                    .filter { Self.isValidGlucoseMgDl($0.valueMgDl) }
                    .sorted { $0.date < $1.date }

                guard !samples.isEmpty else {
                    continuation.resume(returning: StatisticsManager.emptyLandscapeBaseline())
                    return
                }

                let days = Set(samples.map { self.calendar.startOfDay(for: $0.date) })

                continuation.resume(returning: LandscapeBaseline(
                    dayCount: days.count,
                    usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                    agpPoints: self.makeAGPPoints(samples: samples)
                ))
            }
        }
    }

    /// Returns the AGP baseline and optional selected-day OS-AID traces in one queued operation.
    func landscapeAnalytics(referenceDate: Date, daysBack: Int, includesAID: Bool) async -> LandscapeAnalytics {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: LandscapeAnalytics(
                        baseline: StatisticsManager.emptyLandscapeBaseline(),
                        loopalyzer: nil
                    ))
                    return
                }

                let selectedDayStart = self.calendar.startOfDay(for: referenceDate)
                let selectedDayEnd = min(
                    self.calendar.date(byAdding: .day, value: 1, to: selectedDayStart)?.addingTimeInterval(-1) ?? selectedDayStart,
                    Date()
                )
                guard let baselineStart = self.calendar.date(
                    byAdding: .day,
                    value: -max(1, daysBack),
                    to: selectedDayStart
                ) else {
                    continuation.resume(returning: LandscapeAnalytics(
                        baseline: StatisticsManager.emptyLandscapeBaseline(),
                        loopalyzer: nil
                    ))
                    return
                }

                // Fetch the complete window once, then keep the selected day out of its own AGP baseline.
                let samples = self.cachedSamples(fromDate: baselineStart, toDate: selectedDayEnd)
                    .filter { Self.isValidGlucoseMgDl($0.valueMgDl) }
                    .sorted { $0.date < $1.date }
                let baselineSamples = samples.filter { $0.date < selectedDayStart }
                let selectedDaySamples = samples.filter { $0.date >= selectedDayStart && $0.date <= selectedDayEnd }
                let baselineDays = Set(baselineSamples.map { self.calendar.startOfDay(for: $0.date) })
                let baseline = LandscapeBaseline(
                    dayCount: baselineDays.count,
                    usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                    agpPoints: self.makeAGPPoints(samples: baselineSamples)
                )

                guard includesAID else {
                    continuation.resume(returning: LandscapeAnalytics(baseline: baseline, loopalyzer: nil))
                    return
                }

                let statusAccessor = NightscoutDeviceStatusAccessor(coreDataManager: self.coreDataManager)
                let profileAccessor = NightscoutProfileAccessor(coreDataManager: self.coreDataManager)
                let statuses = statusAccessor.fetch(fromDate: selectedDayStart, toDate: selectedDayEnd)
                    .filter { $0.createdAt >= selectedDayStart && $0.createdAt <= selectedDayEnd }
                    .sorted { $0.createdAt < $1.createdAt }
                // Include the earliest known profile as a fallback when Nightscout has no
                // historical profile snapshot preceding the selected day.
                let profiles = profileAccessor.fetch(fromDate: nil, toDate: nil)
                    .sorted { $0.startDate < $1.startDate }
                let basalTreatments = self.basalTreatmentSamples(
                    fromDate: selectedDayStart.addingTimeInterval(-24 * 60 * 60),
                    toDate: selectedDayEnd
                )

                let loopalyzer = LandscapeLoopalyzerSnapshot(
                    points: self.makeLoopalyzerPoints(
                        statuses: statuses,
                        profiles: profiles,
                        samples: selectedDaySamples,
                        selectedDayRange: selectedDayStart ... selectedDayEnd,
                        basalTreatments: basalTreatments
                    ),
                    insulinTreatmentMarkers: self.loopalyzerTreatmentMarkers(
                        fromDate: selectedDayStart,
                        toDate: selectedDayEnd,
                        treatmentType: .Insulin
                    ),
                    carbTreatmentMarkers: self.loopalyzerTreatmentMarkers(
                        fromDate: selectedDayStart,
                        toDate: selectedDayEnd,
                        treatmentType: .Carbs
                    )
                )

                continuation.resume(returning: LandscapeAnalytics(baseline: baseline, loopalyzer: loopalyzer))
            }
        }
    }

    /// Returns persisted Nightscout loop data for the same period used by a generated report.
    ///
    /// Kept as a focused fetch helper for future views that need raw AID snapshots instead of the
    /// normalized clinical summary included in `GlucoseReportAnalytics`.
    func nightscoutLoopSnapshots(for configuration: GlucoseReportConfiguration) async -> NightscoutLoopSnapshots {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation { [weak self] in
                guard let self else {
                    continuation.resume(returning: NightscoutLoopSnapshots(deviceStatuses: [], profiles: []))
                    return
                }

                guard configuration.aidPeriod != .notIncluded else {
                    continuation.resume(returning: NightscoutLoopSnapshots(deviceStatuses: [], profiles: []))
                    return
                }

                let periodEnd = Date()
                let periodStart = periodEnd.addingTimeInterval(-Double(configuration.aidPeriod.rawValue) * 24 * 60 * 60)
                let deviceStatusAccessor = NightscoutDeviceStatusAccessor(coreDataManager: self.coreDataManager)
                let profileAccessor = NightscoutProfileAccessor(coreDataManager: self.coreDataManager)
                continuation.resume(returning: NightscoutLoopSnapshots(
                    deviceStatuses: deviceStatusAccessor.fetch(fromDate: periodStart, toDate: periodEnd),
                    // A profile that started before the report can remain active throughout it.
                    // Include retained history through the end so callers can resolve that baseline.
                    profiles: profileAccessor.fetch(fromDate: nil, toDate: periodEnd)
                ))
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

    private func makeReportAnalytics(
        for configuration: GlucoseReportConfiguration,
        aidAnalyticsSource: AIDAnalyticsSource?
    ) -> GlucoseReportAnalytics {
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
        let reportSensorSummary = sensorSummary(fromDate: periodStart, toDate: periodEnd)
        let aidAnalytics = makeAIDAnalytics(
            fromDate: periodStart,
            toDate: periodEnd,
            samples: samples,
            isIncluded: configuration.aidPeriod != .notIncluded,
            source: aidAnalyticsSource
        )

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
            dailyGlucoseProfiles: makeDailyGlucoseProfiles(samples: samples, periodEnd: periodEnd, dayCount: 7),
            dailySummaries: makeDailySummaries(samples: samples, periodEnd: periodEnd, periodDays: configuration.period.rawValue),
            trendPoints: makeTrendPoints(
                samples: samples,
                fromDate: periodStart,
                toDate: periodEnd,
                period: configuration.period,
                aidAnalyticsSource: aidAnalyticsSource
            ),
            sensorCount: reportSensorSummary.count,
            averageSensorDuration: reportSensorSummary.averageDuration,
            calibrationCount: calibrationCount(fromDate: periodStart, toDate: periodEnd),
            aidAnalytics: aidAnalytics,
            lowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeLowMgDl, isBelow: true),
            veryLowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryLowMgDl, isBelow: true),
            highEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeHighMgDl, isBelow: false),
            veryHighEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryHighMgDl, isBelow: false)
        )
    }

    /// Builds only the metrics supported by the resolved analytics provider.
    ///
    /// Policy eligibility and data sufficiency are separate decisions: `source` proves that the
    /// current configuration owns an AID-capable import path, while the status-count guard proves
    /// that enough persisted history exists to publish a clinically meaningful extra report page.
    private func makeAIDAnalytics(
        fromDate: Date,
        toDate: Date,
        samples: [CGMSample],
        isIncluded: Bool,
        source: AIDAnalyticsSource?
    ) -> GlucoseReportAIDAnalytics? {
        guard fromDate < toDate,
              isIncluded,
              let source else {
            return nil
        }

        let deviceStatusAccessor = NightscoutDeviceStatusAccessor(coreDataManager: coreDataManager)
        let profileAccessor = NightscoutProfileAccessor(coreDataManager: coreDataManager)
        let statuses = deviceStatusAccessor.fetch(fromDate: fromDate, toDate: toDate)
            // CareLink and Nightscout normalize into the same store. Never let stale records from
            // the previously selected provider contaminate the current clinical calculation.
            .filter {
                $0.createdAt >= fromDate
                    && $0.createdAt <= toDate
                    && source.ownsDeviceStatus(with: $0.device)
            }
            .sorted { $0.createdAt < $1.createdAt }

        guard statuses.count >= 3 else { return nil }

        // CareLink does not import Nightscout profile documents. An empty profile list deliberately
        // omits scheduled-basal/profile tables instead of borrowing another provider's history.
        let profiles: [NightscoutProfileSnapshot]
        switch source {
        case .nightscout:
            profiles = profileAccessor.fetch(fromDate: nil, toDate: toDate)
                .sorted { $0.startDate < $1.startDate }
        case .careLink:
            profiles = []
        }
        // Nightscout limits Loopalyzer reports to short periods because longer averaging flattens
        // meal responses. Summary tiles use the selected report period, while this chart keeps a
        // fixed 3-day average to avoid hiding meal and correction behaviour.
        let loopalyzerFromDate = max(fromDate, toDate.addingTimeInterval(-Double(GlucoseReportAIDPeriod.three.rawValue) * 24 * 60 * 60))
        let loopalyzerStatuses = statuses.filter { $0.createdAt >= loopalyzerFromDate }
        let loopalyzerSamples = samples.filter { $0.date >= loopalyzerFromDate }
        let insulinTreatmentMarkers = loopalyzerTreatmentMarkers(
            fromDate: loopalyzerFromDate,
            toDate: toDate,
            treatmentType: .Insulin,
            source: source
        )
        let carbTreatmentMarkers = loopalyzerTreatmentMarkers(
            fromDate: loopalyzerFromDate,
            toDate: toDate,
            treatmentType: .Carbs,
            source: source
        )
        let intervals = aidStatusIntervals(from: statuses, periodEnd: toDate)
        let suspendedDuration = intervals.reduce(0) { duration, interval in
            interval.status.pumpIsSuspended == true ? duration + interval.duration : duration
        }
        let statusDateRange = max(0, (statuses.last?.createdAt ?? toDate).timeIntervalSince(statuses.first?.createdAt ?? fromDate))
        let calculationDays = max(1, Int(ceil(statusDateRange / (24 * 60 * 60))))
        let loopingSuccessPercentage = loopingSuccessPercentage(from: intervals, fromDate: fromDate, toDate: toDate)
        let averageTDD = averageDailyTDD(
            from: statuses,
            source: source,
            fromDate: fromDate,
            toDate: toDate
        )
        let averageCarbsPerDay = averageCarbsPerDay(
            fromDate: fromDate,
            toDate: toDate,
            source: source
        )
        let latestStatus = statuses.last

        return GlucoseReportAIDAnalytics(
            systemName: aidSystemName(from: statuses, source: source),
            systemVersion: source == .careLink ? nil : latestStatus?.appVersion,
            pumpManufacturer: latestStatus?.pumpManufacturer,
            pumpModel: latestStatus?.pumpModel,
            calculationDays: calculationDays,
            periodDays: max(1, Int(ceil(toDate.timeIntervalSince(loopalyzerFromDate) / (24 * 60 * 60)))),
            loopalyzerStartDate: loopalyzerFromDate,
            loopalyzerEndDate: toDate,
            loopingTimePercentage: loopingSuccessPercentage,
            averageTDD: averageTDD,
            averageCarbsPerDay: averageCarbsPerDay,
            pumpSuspensionTime: suspendedDuration > 0 ? suspendedDuration : nil,
            latestReservoir: latestStatus?.pumpReservoir,
            latestPumpBatteryPercentage: latestStatus?.pumpBatteryPercent,
            // Meal markers are useful for CareLink, but only Nightscout device status provides the
            // algorithm's time-varying COB value used to draw an absorption/decay series.
            supportsCOB: source.supportsCOB,
            supportsScheduledBasalAnalytics: source.supportsScheduledBasalAnalytics,
            loopalyzerPoints: makeLoopalyzerPoints(statuses: loopalyzerStatuses, profiles: profiles, samples: loopalyzerSamples),
            insulinTreatmentMarkers: insulinTreatmentMarkers,
            carbTreatmentMarkers: carbTreatmentMarkers,
            profileSchedules: aidProfileSchedules(from: profiles, periodEnd: toDate)
        )
    }

    private func averageCarbsPerDay(
        fromDate: Date,
        toDate: Date,
        source: AIDAnalyticsSource
    ) -> Double? {
        let intervalDays = max(toDate.timeIntervalSince(fromDate) / (24 * 60 * 60), 1)
        let context = coreDataManager.privateManagedObjectContext
        var totalCarbs = 0.0

        context.performAndWait {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            var predicates: [NSPredicate] = [
                NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(format: "treatmentType == %@", NSNumber(value: TreatmentType.Carbs.rawValue)),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentdeleted == NO"),
                    NSPredicate(format: "treatmentdeleted == nil")
                ]),
                NSPredicate(format: "value > 0 AND value < 1000")
            ]
            predicates.append(treatmentSourcePredicate(for: source))
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            guard let treatments = try? context.fetch(request) else { return }
            totalCarbs = treatments.reduce(0) { $0 + $1.value }
        }

        return totalCarbs > 0 ? totalCarbs / intervalDays : nil
    }

    /// Calculates total daily delivered insulin using the authoritative shape for each provider.
    ///
    /// Nightscout AID clients publish an already-complete cumulative TDD in device status. CareLink
    /// does not, so its equivalent is reconstructed only from CareLink-entered boluses and native
    /// automatic-basal doses. Keeping these branches explicit avoids presenting bolus-only CareLink
    /// totals or silently mixing treatments left by another configured provider.
    private func averageDailyTDD(
        from statuses: [NightscoutDeviceStatusSnapshot],
        source: AIDAnalyticsSource,
        fromDate: Date,
        toDate: Date
    ) -> Double? {
        switch source {
        case .nightscout:
            return averageNightscoutDailyTDD(from: statuses)
        case .careLink:
            return averageCareLinkDailyTDD(fromDate: fromDate, toDate: toDate)
        }
    }

    private func averageNightscoutDailyTDD(from statuses: [NightscoutDeviceStatusSnapshot]) -> Double? {
        // Trio's published TDD is the complete delivered total: bolus + temporary basal +
        // scheduled basal. The newest value for each day is therefore the daily value to average.
        // Source: https://github.com/nightscout/Trio/blob/main/Trio/Sources/APS/Storage/TDDStorage.swift
        let validStatuses = statuses
            .filter { status in
                guard let tdd = status.tdd else { return false }
                return tdd > 0 && tdd < 300
            }

        let dailyStatuses = Dictionary(grouping: validStatuses) { status in
            calendar.startOfDay(for: status.createdAt)
        }

        let dailyValues = dailyStatuses.values.compactMap { statusesForDay in
            statusesForDay.max { $0.createdAt < $1.createdAt }?.tdd
        }

        return average(dailyValues)
    }

    private func averageCareLinkDailyTDD(fromDate: Date, toDate: Date) -> Double? {
        let context = coreDataManager.privateManagedObjectContext
        var dailyTotals = [Date: Double]()

        context.performAndWait {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(
                    format: "treatmentType IN %@",
                    [TreatmentType.Insulin.rawValue, TreatmentType.AutomaticBasal.rawValue].map(NSNumber.init(value:))
                ),
                NSPredicate(format: "enteredBy == %@", "CareLink"),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentdeleted == NO"),
                    NSPredicate(format: "treatmentdeleted == nil")
                ]),
                NSPredicate(format: "value > 0 AND value < 300")
            ])
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            guard let treatments = try? context.fetch(request) else { return }
            dailyTotals = treatments.reduce(into: [:]) { totals, treatment in
                totals[calendar.startOfDay(for: treatment.date), default: 0] += treatment.value
            }
        }

        let plausibleTotals = dailyTotals.values.filter { $0 > 0 && $0 < 300 }
        return average(Array(plausibleTotals))
    }

    /// Nightscout does not expose Trio's local LoopStatRecord objects, so completed loop
    /// timestamps are the closest portable equivalent. Deduplicating them into five-minute
    /// slots mirrors the expected 288 loop opportunities per day used by Trio statistics.
    /// The denominator uses only intervals with stored DeviceStatus coverage so a missing
    /// import window is not incorrectly reported as failed looping time.
    /// Source: https://github.com/nightscout/Trio/blob/main/Trio/Sources/Modules/Stat/StatStateModel%2BSetup/LoopChartSetup.swift
    private func loopingSuccessPercentage(
        from intervals: [AIDStatusInterval],
        fromDate: Date,
        toDate: Date
    ) -> Double {
        let loopInterval = 5 * 60.0
        let coveredDuration = intervals.reduce(0) { $0 + $1.duration }
        guard coveredDuration >= loopInterval else { return 0 }

        let successfulSlots = Set(intervals.compactMap { interval -> Int? in
            let loopDate = interval.status.lastLoopDate
            guard loopDate >= fromDate,
                  loopDate <= toDate,
                  loopDate <= interval.status.createdAt.addingTimeInterval(loopInterval) else {
                return nil
            }
            return Int(loopDate.timeIntervalSinceReferenceDate / loopInterval)
        })

        let expectedSlots = coveredDuration / loopInterval
        return min(100, Double(successfulSlots.count) / expectedSlots * 100)
    }

    private func aidStatusIntervals(from statuses: [NightscoutDeviceStatusSnapshot], periodEnd: Date) -> [AIDStatusInterval] {
        statuses.enumerated().map { index, status in
            let nextDate = index < statuses.index(before: statuses.endIndex) ? statuses[index + 1].createdAt : periodEnd
            let rawDuration = max(0, nextDate.timeIntervalSince(status.createdAt))

            // A status can represent the following interval only while the live UI would still
            // consider that device-status row current. Gaps beyond that limit count as unavailable
            // time rather than extending stale looping or suspension state.
            return AIDStatusInterval(
                status: status,
                duration: min(rawDuration, ConstantsHomeView.loopShowNoDataAfterMinutes)
            )
        }
    }

    /// Produces a clinical system label without inferring SmartGuard from CareLink connectivity.
    /// A CareLink pump is called SmartGuard only when persisted history contains a proven automated
    /// activity timestamp. Otherwise the accurate provider-level label remains CareLink.
    private func aidSystemName(
        from statuses: [NightscoutDeviceStatusSnapshot],
        source: AIDAnalyticsSource
    ) -> String? {
        switch source {
        case .careLink:
            let hasSmartGuardEvidence = statuses.contains { $0.lastLoopDate > .distantPast }
            return hasSmartGuardEvidence ? "MiniMed SmartGuard" : "CareLink"
        case .nightscout:
            guard let device = statuses.last?.device else { return nil }

            switch device {
            case let value where value.starts(with: "loop://"):
                return "Loop"
            case let value where value.starts(with: "openaps://"):
                return "AAPS"
            case "Trio", "iAPS":
                return device
            default:
                return nil
            }
        }
    }

    private func makeLoopalyzerPoints(
        statuses: [NightscoutDeviceStatusSnapshot],
        profiles: [NightscoutProfileSnapshot],
        samples: [CGMSample],
        selectedDayRange: ClosedRange<Date>? = nil,
        basalTreatments: [BasalTreatmentSample] = []
    ) -> [GlucoseReportLoopalyzerPoint] {
        let bucketSize = GlucoseReportLoopalyzerPoint.bucketDurationMinutes
        let groupedStatuses = Dictionary(grouping: statuses) { status in
            let components = calendar.dateComponents([.hour, .minute], from: status.createdAt)
            let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            return minuteOfDay / bucketSize
        }
        let groupedSamples = Dictionary(grouping: samples) { sample in
            let components = calendar.dateComponents([.hour, .minute], from: sample.date)
            let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            return minuteOfDay / bucketSize
        }

        let buckets = Set(groupedStatuses.keys).union(groupedSamples.keys).sorted()
        return buckets.compactMap { bucket -> GlucoseReportLoopalyzerPoint? in
            let bucketStatuses = groupedStatuses[bucket] ?? []
            let bucketSamples = groupedSamples[bucket] ?? []
            guard bucketStatuses.count >= 2 || bucketSamples.count >= 3 else { return nil }
            let minuteOfDay = bucket * bucketSize
            let selectedDayBasal = selectedDayRange.map {
                selectedDayBasalValues(
                    minuteOfDay: minuteOfDay,
                    dateRange: $0,
                    profiles: profiles,
                    basalTreatments: basalTreatments
                )
            }
            let scheduledRate = selectedDayBasal?.scheduledRate ?? average(
                bucketStatuses.compactMap { scheduledBasalRate(for: $0.createdAt, profiles: profiles) }
            )
            let basalDeltaRate = selectedDayBasal?.deltaRate ?? scheduledRate.flatMap { scheduled in
                average(bucketStatuses.compactMap(\.rate)).map { actual in actual - scheduled }
            }

            return GlucoseReportLoopalyzerPoint(
                minuteOfDay: minuteOfDay,
                glucoseMgDl: average(bucketSamples.map(\.valueMgDl)),
                scheduledBasalRate: scheduledRate,
                basalDeltaRate: basalDeltaRate,
                iob: average(bucketStatuses.compactMap(\.iob)),
                cob: average(bucketStatuses.compactMap(\.cob))
            )
        }
    }

    private func selectedDayBasalValues(
        minuteOfDay: Int,
        dateRange: ClosedRange<Date>,
        profiles: [NightscoutProfileSnapshot],
        basalTreatments: [BasalTreatmentSample]
    ) -> (scheduledRate: Double?, deltaRate: Double?) {
        let bucketStart = dateRange.lowerBound.addingTimeInterval(Double(minuteOfDay) * 60)
        let minuteSamples = (0 ..< GlucoseReportLoopalyzerPoint.bucketDurationMinutes)
            .map { bucketStart.addingTimeInterval((Double($0) + 0.5) * 60) }
            .filter { $0 <= dateRange.upperBound }

        let scheduledRates = minuteSamples.compactMap { scheduledBasalRate(for: $0, profiles: profiles) }
        let deltaRates = basalTreatments.isEmpty ? [] : minuteSamples.compactMap { date -> Double? in
            guard let scheduledRate = scheduledBasalRate(for: date, profiles: profiles) else { return nil }
            let enactedRate = basalTreatments.last { treatment in
                treatment.date <= date && treatment.endDate > date
            }?.rate

            // Outside a temp-basal interval, delivered basal follows the scheduled profile.
            return (enactedRate ?? scheduledRate) - scheduledRate
        }

        return (average(scheduledRates), average(deltaRates))
    }

    private func aidProfileSchedules(from profiles: [NightscoutProfileSnapshot], periodEnd: Date) -> [GlucoseReportAIDProfileSchedule] {
        profiles
            .filter { $0.startDate <= periodEnd }
            .suffix(1)
            .map { profile in
                GlucoseReportAIDProfileSchedule(
                    name: profileName(from: profile),
                    startDate: profile.startDate,
                    basal: aidScheduleValues(from: profile.basal),
                    carbRatio: aidScheduleValues(from: profile.carbRatio),
                    // Store sensitivity internally in mg/dL/U so every renderer can convert
                    // consistently to the report's selected glucose unit.
                    sensitivity: aidScheduleValues(
                        from: profile.sensitivity,
                        transform: { profile.isMgDl == false ? $0.mmolToMgdl() : $0 }
                    )
                )
            }
    }

    private func profileName(from profile: NightscoutProfileSnapshot) -> String {
        let name = profile.profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Profile" : name
    }

    private func aidScheduleValues(
        from values: [NightscoutProfile.TimeValue],
        transform: (Double) -> Double = { $0 }
    ) -> [GlucoseReportAIDProfileSchedule.ScheduleValue] {
        values.map {
            GlucoseReportAIDProfileSchedule.ScheduleValue(
                secondsFromMidnight: $0.timeAsSecondsFromMidnight,
                value: transform($0.value)
            )
        }
    }

    private func loopalyzerTreatmentMarkers(
        fromDate: Date,
        toDate: Date,
        treatmentType: TreatmentType,
        source: AIDAnalyticsSource? = nil
    ) -> [GlucoseReportLoopalyzerTreatmentMarker] {
        let context = coreDataManager.privateManagedObjectContext
        var markers = [GlucoseReportLoopalyzerTreatmentMarker]()

        context.performAndWait {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: true)]
            var predicates: [NSPredicate] = [
                NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(format: "treatmentType == %@", NSNumber(value: treatmentType.rawValue)),
                // `treatmentdeleted` was historically optional in the Core Data model. Include
                // legacy rows whose stored value is nil as well as explicitly active rows.
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentdeleted == NO"),
                    NSPredicate(format: "treatmentdeleted == nil")
                ]),
                NSPredicate(format: "value > 0")
            ]
            if let source {
                predicates.append(treatmentSourcePredicate(for: source))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            guard let treatments = try? context.fetch(request) else { return }
            markers = treatments.map { treatment in
                let components = calendar.dateComponents([.hour, .minute], from: treatment.date)
                return GlucoseReportLoopalyzerTreatmentMarker(
                    minuteOfDay: ((components.hour ?? 0) * 60) + (components.minute ?? 0),
                    amount: treatment.value
                )
            }
        }

        return markers
    }

    /// Treatment history can outlive a Settings change, just like normalized device status.
    /// CareLink has an explicit importer identity. Nightscout retains the established behavior of
    /// including imported and manual records while excluding only records proven to be CareLink's.
    private func treatmentSourcePredicate(for source: AIDAnalyticsSource) -> NSPredicate {
        switch source {
        case .careLink:
            return NSPredicate(format: "enteredBy == %@", "CareLink")
        case .nightscout:
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "enteredBy != %@", "CareLink"),
                NSPredicate(format: "enteredBy == nil")
            ])
        }
    }

    private func basalTreatmentSamples(fromDate: Date, toDate: Date) -> [BasalTreatmentSample] {
        let context = coreDataManager.privateManagedObjectContext
        var samples = [BasalTreatmentSample]()

        context.performAndWait {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: true)]
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(
                    format: "treatmentType IN %@",
                    [TreatmentType.Basal.rawValue, TreatmentType.AutomaticBasal.rawValue].map(NSNumber.init(value:))
                ),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentdeleted == NO"),
                    NSPredicate(format: "treatmentdeleted == nil")
                ]),
                NSPredicate(format: "value >= 0 AND valueSecondary > 0")
            ])
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            guard let treatments = try? context.fetch(request) else { return }
            samples = treatments.compactMap {
                let rate = $0.treatmentType == .AutomaticBasal
                    ? AutomaticBasalTreatmentMath.rate(amount: $0.value, durationSeconds: $0.valueSecondary * 60)
                    : $0.value
                guard let rate else { return nil }
                return BasalTreatmentSample(date: $0.date, rate: rate, durationMinutes: $0.valueSecondary)
            }
        }

        return samples
    }

    private func scheduledBasalRate(for date: Date, profiles: [NightscoutProfileSnapshot]) -> Double? {
        let profile = profiles.last { $0.startDate <= date && !$0.basal.isEmpty }
            ?? profiles.first { !$0.basal.isEmpty }
        guard let profile else {
            return nil
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let secondsFromMidnight = ((components.hour ?? 0) * 3600) + ((components.minute ?? 0) * 60) + (components.second ?? 0)
        return profile.basal.last(where: { $0.timeAsSecondsFromMidnight <= secondsFromMidnight })?.value ?? profile.basal.last?.value
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
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
            // Sensor identifiers are needed to group report sessions. Calibration objects are
            // counted separately and must not be materialized for every glucose sample.
            fetchRequest.relationshipKeyPathsForPrefetching = ["sensor"]

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

    private func makeDailyGlucoseProfiles(samples: [CGMSample], periodEnd: Date, dayCount: Int) -> [GlucoseReportDailyGlucoseProfile] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        let endDay = calendar.startOfDay(for: periodEnd)
        let startDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay
        var profiles = [GlucoseReportDailyGlucoseProfile]()
        var day = startDay

        while day <= endDay {
            let points = (grouped[day] ?? [])
                .sorted { $0.date < $1.date }
                .map { sample in
                    let components = calendar.dateComponents([.hour, .minute], from: sample.date)
                    return GlucoseReportDailyGlucosePoint(
                        minuteOfDay: ((components.hour ?? 0) * 60) + (components.minute ?? 0),
                        valueMgDl: sample.valueMgDl
                    )
                }

            profiles.append(GlucoseReportDailyGlucoseProfile(date: day, points: points))

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return profiles
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

    private func makeTrendPoints(
        samples: [CGMSample],
        fromDate: Date,
        toDate: Date,
        period: GlucoseReportPeriod,
        aidAnalyticsSource: AIDAnalyticsSource?
    ) -> [GlucoseReportTrendPoint] {
        // Short analysis windows need finer buckets to show a useful trend. Longer windows retain
        // weekly averages so the plots remain clinically readable instead of becoming noisy.
        let bucket = trendBucket(for: period)
        let grouped = Dictionary(grouping: samples) {
            trendBucketIndex(for: $0.date, fromDate: fromDate, duration: bucket.duration)
        }
        let treatmentTrendValues = treatmentTrendValues(
            fromDate: fromDate,
            toDate: toDate,
            bucketDuration: bucket.duration,
            source: aidAnalyticsSource
        )

        return grouped.keys.sorted().compactMap { bucketIndex -> GlucoseReportTrendPoint? in
            guard let bucketSamples = grouped[bucketIndex], bucketSamples.count >= 12 else { return nil }
            let values = bucketSamples.map(\.valueMgDl)
            let average = values.reduce(0, +) / Double(values.count)
            let standardDeviation = Self.standardDeviation(values: values, average: average)
            let date = trendBucketDate(at: bucketIndex, fromDate: fromDate, toDate: toDate, duration: bucket.duration)

            return GlucoseReportTrendPoint(
                date: date,
                interval: bucket.interval,
                averageMgDl: average,
                coefficientOfVariation: average > 0 ? standardDeviation / average * 100 : 0,
                averageTDDPerDay: treatmentTrendValues.averageTDDPerDay[bucketIndex],
                averageCarbsPerDay: treatmentTrendValues.averageCarbsPerDay[bucketIndex],
                sampleCount: bucketSamples.count
            )
        }
    }

    private func treatmentTrendValues(
        fromDate: Date,
        toDate: Date,
        bucketDuration: TimeInterval,
        source: AIDAnalyticsSource?
    ) -> (averageTDDPerDay: [Int: Double], averageCarbsPerDay: [Int: Double]) {
        // TDD and carbohydrate trends are the lightweight AID enhancement used by Statistics.
        // Do not infer eligibility merely because manual or stale treatments happen to exist.
        guard let source else { return ([:], [:]) }

        let treatments = treatmentSamples(fromDate: fromDate, toDate: toDate)
        let sourceTreatments = treatments.filter { treatment in
            switch source {
            case .careLink:
                return treatment.enteredBy == "CareLink"
            case .nightscout:
                // Preserve existing Nightscout/manual treatment behavior while excluding CareLink
                // records that can remain in Core Data after the authoritative source changes.
                return treatment.enteredBy != "CareLink"
            }
        }
        let insulinTreatments = sourceTreatments.filter {
            let isDeliveredInsulin = $0.type == .Insulin || (source == .careLink && $0.type == .AutomaticBasal)
            return isDeliveredInsulin && $0.value > 0 && $0.value < 300
        }
        let carbTreatments = sourceTreatments.filter { $0.type == .Carbs && $0.value > 0 && $0.value < 1000 }
        let intervalDays = max(toDate.timeIntervalSince(fromDate) / (24 * 60 * 60), 1)

        guard Double(insulinTreatments.count) / intervalDays >= 3 else {
            return ([:], [:])
        }

        return (
            averagePerDay(from: insulinTreatments, fromDate: fromDate, toDate: toDate, bucketDuration: bucketDuration),
            averagePerDay(from: carbTreatments, fromDate: fromDate, toDate: toDate, bucketDuration: bucketDuration)
        )
    }

    private func treatmentSamples(fromDate: Date, toDate: Date) -> [TreatmentSample] {
        let context = coreDataManager.privateManagedObjectContext
        var samples = [TreatmentSample]()

        context.performAndWait {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: true)]
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate),
                NSPredicate(
                    format: "treatmentType IN %@",
                    [TreatmentType.Insulin.rawValue, TreatmentType.Carbs.rawValue, TreatmentType.AutomaticBasal.rawValue]
                        .map(NSNumber.init(value:))
                ),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentdeleted == NO"),
                    NSPredicate(format: "treatmentdeleted == nil")
                ]),
                NSPredicate(format: "value > 0")
            ])
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            guard let treatments = try? context.fetch(request) else { return }
            samples = treatments.map {
                TreatmentSample(
                    date: $0.date,
                    value: $0.value,
                    type: $0.treatmentType,
                    enteredBy: $0.enteredBy
                )
            }
        }

        return samples
    }

    private func averagePerDay(
        from treatments: [TreatmentSample],
        fromDate: Date,
        toDate: Date,
        bucketDuration: TimeInterval
    ) -> [Int: Double] {
        let grouped = Dictionary(grouping: treatments) { treatment in
            trendBucketIndex(for: treatment.date, fromDate: fromDate, duration: bucketDuration)
        }

        return grouped.reduce(into: [Int: Double]()) { result, item in
            let bucketStart = fromDate.addingTimeInterval(Double(item.key) * bucketDuration)
            let bucketEnd = min(bucketStart.addingTimeInterval(bucketDuration), toDate)
            let days = max(bucketEnd.timeIntervalSince(bucketStart) / (24 * 60 * 60), 1)
            let total = item.value.map(\.value).reduce(0, +)
            result[item.key] = total / days
        }
    }

    private func trendBucket(for period: GlucoseReportPeriod) -> (duration: TimeInterval, interval: GlucoseReportTrendInterval) {
        switch period {
        case .seven:
            return (24 * 60 * 60, .daily)
        case .thirty:
            return (3 * 24 * 60 * 60, .threeDay)
        case .sixty, .ninety, .oneEighty, .oneYear:
            return (7 * 24 * 60 * 60, .weekly)
        }
    }

    private func trendBucketIndex(for date: Date, fromDate: Date, duration: TimeInterval) -> Int {
        Int(max(0, date.timeIntervalSince(fromDate)) / duration)
    }

    private func trendBucketDate(at index: Int, fromDate: Date, toDate: Date, duration: TimeInterval) -> Date {
        let bucketStart = fromDate.addingTimeInterval(Double(index) * duration)
        let bucketEnd = min(bucketStart.addingTimeInterval(duration), toDate)
        return bucketStart.addingTimeInterval(bucketEnd.timeIntervalSince(bucketStart) / 2)
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
            dailyGlucoseProfiles: [],
            dailySummaries: [],
            trendPoints: [],
            sensorCount: 0,
            averageSensorDuration: nil,
            calibrationCount: 0,
            aidAnalytics: nil,
            lowEventCount: 0,
            veryLowEventCount: 0,
            highEventCount: 0,
            veryHighEventCount: 0
        )
    }

    private static func emptyLandscapeBaseline() -> LandscapeBaseline {
        return LandscapeBaseline(
            dayCount: 0,
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            agpPoints: []
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
