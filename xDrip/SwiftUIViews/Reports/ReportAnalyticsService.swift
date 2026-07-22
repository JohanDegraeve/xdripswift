//
//  ReportAnalyticsService.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

final class GlucoseReportAnalyticsService {
    private struct Sample {
        let date: Date
        let valueMgDl: Double
    }

    private let accessor: BgReadingsAccessor
    private let calendar = Calendar.current

    init(coreDataManager: CoreDataManager) {
        accessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }

    func availablePeriods() async -> [GlucoseReportPeriod: Bool] {
        await Task.detached(priority: .userInitiated) {
            let snapshots = self.accessor.getLatestBgReadingSnapshots(
                limit: nil,
                fromDate: Date().addingTimeInterval(-Double(GlucoseReportPeriod.oneYear.rawValue + 1) * 24 * 60 * 60),
                forSensor: nil,
                ignoreRawData: true,
                ignoreCalculatedValue: false
            )
            let validSnapshots = snapshots
                .filter { Self.isValidGlucoseMgDl($0.finalValue) }

            return Dictionary(uniqueKeysWithValues: GlucoseReportPeriod.allCases.map { period in
                let requiredStart = Date().addingTimeInterval(-Double(period.rawValue) * 24 * 60 * 60)
                let sampleCount = validSnapshots.filter { $0.timeStamp >= requiredStart }.count
                return (period, Self.hasEnoughCoverage(sampleCount: sampleCount, period: period))
            })
        }.value
    }

    func analytics(for configuration: GlucoseReportConfiguration) async -> GlucoseReportAnalytics {
        await Task.detached(priority: .userInitiated) {
            self.makeAnalytics(for: configuration)
        }.value
    }

    private func makeAnalytics(for configuration: GlucoseReportConfiguration) -> GlucoseReportAnalytics {
        let periodEnd = Date()
        let snapshots = accessor.getLatestBgReadingSnapshots(
            limit: nil,
            fromDate: periodEnd.addingTimeInterval(-Double(configuration.period.rawValue) * 24 * 60 * 60),
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: false
        )

        let samples = snapshots
            .compactMap { snapshot -> Sample? in
                guard Self.isValidGlucoseMgDl(snapshot.finalValue) else { return nil }
                return Sample(date: snapshot.timeStamp, valueMgDl: snapshot.finalValue)
            }
            .sorted { $0.date < $1.date }
        let periodStart = periodEnd.addingTimeInterval(-Double(configuration.period.rawValue) * 24 * 60 * 60)
        let periodDays = configuration.period.rawValue

        guard !samples.isEmpty else {
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
                calibrationCount: 0,
                lowEventCount: 0,
                veryLowEventCount: 0,
                highEventCount: 0,
                veryHighEventCount: 0
            )
        }

        let average = samples.map(\.valueMgDl).reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { partialResult, sample in
            partialResult + pow(sample.valueMgDl - average, 2)
        } / Double(samples.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = average > 0 ? standardDeviation / average * 100 : 0
        let expectedSamples = Double(Self.expectedSamples(for: configuration.period))
        let validSnapshots = snapshots.filter { Self.isValidGlucoseMgDl($0.finalValue) }
        let deviceNames = Array(
            Set(validSnapshots.compactMap { snapshot in
                let name = snapshot.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
                return name?.isEmpty == false ? name : nil
            })
        ).sorted()
        let sensorCount = Set(validSnapshots.compactMap(\.sensorID)).count
        let calibrationCount = validSnapshots.filter { $0.calibrationSnapshot != nil }.count

        return GlucoseReportAnalytics(
            periodStart: periodStart,
            periodEnd: periodEnd,
            firstReading: samples.first?.date,
            lastReading: samples.last?.date,
            sampleCount: samples.count,
            dataCapturePercentage: min(100, Double(samples.count) / expectedSamples * 100),
            readingsPerDay: Double(samples.count) / Double(periodDays),
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            averageMgDl: average,
            standardDeviationMgDl: standardDeviation,
            coefficientOfVariation: coefficientOfVariation,
            gmiPercentage: GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: average),
            rangeDistribution: makeRangeDistribution(samples: samples),
            tightRangeDistribution: makeTightRangeDistribution(samples: samples),
            agpPoints: makeAGPPoints(samples: samples),
            dailySummaries: makeDailySummaries(samples: samples, periodEnd: periodEnd, periodDays: periodDays),
            trendPoints: makeTrendPoints(samples: samples),
            deviceNames: deviceNames,
            sensorCount: sensorCount,
            calibrationCount: calibrationCount,
            lowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeLowMgDl, isBelow: true),
            veryLowEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryLowMgDl, isBelow: true),
            highEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.timeInRangeHighMgDl, isBelow: false),
            veryHighEventCount: countEvents(samples: samples, threshold: GlucoseReportClinicalConstants.veryHighMgDl, isBelow: false)
        )
    }

    private func makeRangeDistribution(samples: [Sample]) -> GlucoseReportRangeDistribution {
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

    private func makeTightRangeDistribution(samples: [Sample]) -> GlucoseReportRangeDistribution {
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

    private func makeAGPPoints(samples: [Sample]) -> [GlucoseReportAGPPoint] {
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
                p5MgDl: percentile(0.05, values: values),
                p25MgDl: percentile(0.25, values: values),
                medianMgDl: percentile(0.50, values: values),
                p75MgDl: percentile(0.75, values: values),
                p95MgDl: percentile(0.95, values: values)
            )
        }
    }

    private func makeDailySummaries(samples: [Sample], periodEnd: Date, periodDays: Int) -> [GlucoseReportDailySummary] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        let endDay = calendar.startOfDay(for: periodEnd)
        let startDay = calendar.date(byAdding: .day, value: -(periodDays - 1), to: endDay) ?? endDay
        var summaries: [GlucoseReportDailySummary] = []
        var day = startDay

        while day <= endDay {
            if let daySamples = grouped[day], !daySamples.isEmpty {
                let average = daySamples.map(\.valueMgDl).reduce(0, +) / Double(daySamples.count)
                let total = Double(daySamples.count)
                summaries.append(GlucoseReportDailySummary(
                    date: day,
                    averageMgDl: average,
                    targetPercentage: Double(daySamples.filter { $0.valueMgDl >= GlucoseReportClinicalConstants.timeInRangeLowMgDl && $0.valueMgDl <= GlucoseReportClinicalConstants.timeInRangeHighMgDl }.count) / total * 100,
                    lowPercentage: Double(daySamples.filter { $0.valueMgDl < GlucoseReportClinicalConstants.timeInRangeLowMgDl }.count) / total * 100,
                    highPercentage: Double(daySamples.filter { $0.valueMgDl > GlucoseReportClinicalConstants.timeInRangeHighMgDl }.count) / total * 100,
                    sampleCount: daySamples.count
                ))
            } else {
                summaries.append(GlucoseReportDailySummary(
                    date: day,
                    averageMgDl: 0,
                    targetPercentage: 0,
                    lowPercentage: 0,
                    highPercentage: 0,
                    sampleCount: 0
                ))
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return summaries
    }

    private func makeTrendPoints(samples: [Sample]) -> [GlucoseReportTrendPoint] {
        makeTrendPoints(samples: samples, components: [.yearForWeekOfYear, .weekOfYear], interval: .weekly)
    }

    private func makeTrendPoints(samples: [Sample], components: Set<Calendar.Component>, interval: GlucoseReportTrendInterval) -> [GlucoseReportTrendPoint] {
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.date(from: calendar.dateComponents(components, from: sample.date)) ?? calendar.startOfDay(for: sample.date)
        }

        return grouped.keys.sorted().compactMap { date -> GlucoseReportTrendPoint? in
            guard let bucketSamples = grouped[date], bucketSamples.count >= 12 else { return nil }
            let average = bucketSamples.map(\.valueMgDl).reduce(0, +) / Double(bucketSamples.count)
            let variance = bucketSamples.reduce(0) { partialResult, sample in
                partialResult + pow(sample.valueMgDl - average, 2)
            } / Double(bucketSamples.count)
            let standardDeviation = sqrt(variance)

            return GlucoseReportTrendPoint(
                date: date,
                interval: interval,
                averageMgDl: average,
                coefficientOfVariation: average > 0 ? standardDeviation / average * 100 : 0,
                sampleCount: bucketSamples.count
            )
        }
    }

    private func countEvents(samples: [Sample], threshold: Double, isBelow: Bool) -> Int {
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

    private func percentile(_ percentile: Double, values: [Double]) -> Double {
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
}
