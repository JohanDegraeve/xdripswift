//
//  TransmitterReadSuccessManager.swift
//  xdrip
//
//  Created by Paul Plant on 23/9/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import Foundation

/// UI‑ready result payload produced by the manager
public struct TransmitterReadSuccessDisplay {
    public let nominalGapInSeconds: Int   // 60 or 300
    public let earliestTimestampInLast24h: Date?
    public let hourlyBuckets: [TransmitterReadSuccessHourlyBucket]

    public let expected24h: Int
    public let actual24h: Int
    public let success24h: Double
}

public struct TransmitterReadSuccessHourlyBucket: Identifiable {
    public let id: Int
    public let expected: Int
    public let actual: Int
    public let success: Double
}

final class TransmitterReadSuccessManager {

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor
    
    private let nowProvider: () -> Date
    
    // MARK: - initializer
    
    init(bgReadingsAccessor: BgReadingsAccessor, nowProvider: @escaping () -> Date = { Date() }) {
        self.bgReadingsAccessor = bgReadingsAccessor
        self.nowProvider = nowProvider
    }
    
    // MARK: - public functions

    /// Compute reading success for the given sensor and return 24h totals plus hourly buckets.
    /// - Parameters:
    ///   - sensor: Current sensor/session to evaluate.
    ///   - now: Optional override of current time; defaults to `nowProvider()`.
    ///   - cutoff: Optional cutoff date to clamp analysis to readings no earlier than this timestamp.
    /// - Returns: A display model with expected/actual/success for 24h and hourly bucket data.
    func getReadSuccess(forSensor sensor: Sensor, now: Date? = nil, notBefore cutoff: Date? = nil) -> TransmitterReadSuccessDisplay {
        let now = now ?? nowProvider()
        let analysisStartDate = max(
            sensor.startDate,
            now.addingTimeInterval(-24 * 60 * 60)
        )

        // Read success is about the current physical sensor session. Do not filter by the current
        // Core Data Sensor relationship because that can change during one transmitter session.
        let rawTimestamps = bgReadingsAccessor.getReadingTimestamps(
            fromDate: analysisStartDate,
            toDate: now,
            forSensor: nil
        )
        let allTimestamps = cutoff.map { cutoff in rawTimestamps.filter { $0 >= cutoff } } ?? rawTimestamps

        let earliest24h = allTimestamps.first
        let latest24h = allTimestamps.last

        // Infer nominal gap from 24h
        let nominalGapInSeconds = TransmitterReadSuccessManager.inferNominalGapSeconds(earliest: earliest24h, latest: latest24h, distinctCount: allTimestamps.count)

        let expected24h = expectedSlots(forWindowHours: 24, now: now, earliest: earliest24h, periodSeconds: nominalGapInSeconds)
        let actual24h = min(countPhaseAlignedDistinctSlots(timestamps: allTimestamps, now: now, periodSeconds: nominalGapInSeconds), expected24h)
        let missing24 = max(0, expected24h - actual24h)
        let success24h = flooredPercent(actual: actual24h, expected: expected24h, hasMisses: missing24 > 0)

        return TransmitterReadSuccessDisplay(
            nominalGapInSeconds: nominalGapInSeconds,
            earliestTimestampInLast24h: earliest24h,
            hourlyBuckets: makeHourlyBuckets(
                timestamps: allTimestamps,
                now: now,
                earliest: earliest24h,
                periodSeconds: nominalGapInSeconds
            ),
            expected24h: expected24h,
            actual24h: actual24h,
            success24h: success24h
        )
    }
    
    /// Convenience accessor intended for log production. Ensures that at most one result is returned per hour.
    /// - Parameters:
    ///   - sensor: Current sensor/session to evaluate.
    ///   - now: Optional override of current time; defaults to `nowProvider()`.
    ///   - cutoff: Optional cutoff date to clamp analysis.
    /// - Returns: Display model when allowed by throttle, otherwise `nil`.
    func getReadSuccessForLogs(forSensor sensor: Sensor, now: Date? = nil, notBefore cutoff: Date? = nil, timeStampOfLastLogCreated: Date?) -> TransmitterReadSuccessDisplay? {
        let nowInstant = now ?? nowProvider()
        if let last = timeStampOfLastLogCreated, nowInstant.timeIntervalSince(last) < (60 * 60) {
            return nil
        }
        
        return getReadSuccess(forSensor: sensor, now: nowInstant, notBefore: cutoff)
    }
    
    // MARK: - private functions

    /// Estimates the phase offset (in seconds) of reading arrivals within a typical nominal gap period.
    /// - Parameters:
    ///   - timestamps: Array of reading timestamps to analyze.
    ///   - periodSeconds: Nominal expected gap between readings (e.g. 300 or 60 seconds).
    /// - Returns: The approximate offset (in seconds) within the nominal period where readings most frequently arrive.
    private func estimateArrivalPhaseOffset(timestamps: [Date], periodSeconds: Int) -> TimeInterval {
        guard !timestamps.isEmpty else { return 0 }
        let binSizeInSeconds: TimeInterval = 5
        let numberOfBins = max(1, periodSeconds / Int(binSizeInSeconds))
        var histogram = Array(repeating: 0, count: numberOfBins)
        for timestamp in timestamps {
            let remainder = timestamp.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(periodSeconds))
            let index = Int(floor(remainder / binSizeInSeconds)) % numberOfBins
            histogram[index] &+= 1
        }
        let peakBinIndex = histogram.indices.max(by: { histogram[$0] < histogram[$1] }) ?? 0
        return (Double(peakBinIndex) + 0.5) * binSizeInSeconds
    }

    /// Counts the number of distinct phase-aligned slots (bins) containing readings in the 24h window.
    /// Each slot is centered based on the inferred phase offset to align with actual reading timing.
    /// - Parameters:
    ///   - timestamps: All reading timestamps in the last 24 hours.
    ///   - now: Current reference time.
    ///   - periodSeconds: Nominal expected gap between readings (e.g. 300 or 60 seconds).
    /// - Returns: Distinct occupied slot count for the last 24 hours.
    private func countPhaseAlignedDistinctSlots(timestamps: [Date], now: Date, periodSeconds: Int) -> Int {
        guard periodSeconds > 0 else {
            return 0
        }

        let window24Start = now.addingTimeInterval(-24 * 3600)
        let filtered = timestamps.filter { $0 >= window24Start && $0 <= now }.sorted()
        guard !filtered.isEmpty else {
            return 0
        }

        let arrivalPhaseOffset = estimateArrivalPhaseOffset(timestamps: Array(filtered.suffix(120)), periodSeconds: periodSeconds)
        let slotIndex = makeSlotIndexCalculator(arrivalPhaseOffset: arrivalPhaseOffset, periodSeconds: periodSeconds)

        let indexSet24h = Set(filtered.map(slotIndex))

        return indexSet24h.count
    }

    private func makeHourlyBuckets(timestamps: [Date], now: Date, earliest: Date?, periodSeconds: Int) -> [TransmitterReadSuccessHourlyBucket] {
        guard periodSeconds > 0 else { return [] }

        let window24Start = now.addingTimeInterval(-24 * 3600)
        let filtered = timestamps.filter { $0 >= window24Start && $0 <= now }.sorted()
        let arrivalPhaseOffset = estimateArrivalPhaseOffset(timestamps: Array(filtered.suffix(120)), periodSeconds: periodSeconds)
        let slotIndex = makeSlotIndexCalculator(arrivalPhaseOffset: arrivalPhaseOffset, periodSeconds: periodSeconds)

        return (0..<24).map { index in
            let bucketStart = window24Start.addingTimeInterval(Double(index) * 3600.0)
            let bucketEnd = min(bucketStart.addingTimeInterval(3600.0), now)
            let bucketTimestamps = filtered.filter { $0 >= bucketStart && $0 < bucketEnd }
            // Count distinct phase-aligned slots so duplicate readings within one transmitter interval only count once.
            let actual = Set(bucketTimestamps.map(slotIndex)).count
            let expected = expectedSlots(from: bucketStart, to: bucketEnd, earliest: earliest, periodSeconds: periodSeconds)
            let success = flooredPercent(actual: min(actual, expected), expected: expected, hasMisses: expected > actual)

            return TransmitterReadSuccessHourlyBucket(
                id: index,
                expected: expected,
                actual: min(actual, expected),
                success: success
            )
        }
    }

    private func makeSlotIndexCalculator(arrivalPhaseOffset: TimeInterval, periodSeconds: Int) -> (Date) -> Int {
        { timestamp in
            let phaseAdjustedTimestamp = timestamp.timeIntervalSince1970 - arrivalPhaseOffset + Double(periodSeconds) / 2.0
            return Int(floor(phaseAdjustedTimestamp / Double(periodSeconds)))
        }
    }

    private func expectedSlots(from startDate: Date, to endDate: Date, earliest: Date?, periodSeconds: Int) -> Int {
        guard periodSeconds > 0, endDate > startDate, let earliest = earliest, earliest <= endDate else { return 0 }

        let effectiveStartDate = max(startDate, earliest)
        let span = max(0.0, endDate.timeIntervalSince(effectiveStartDate))

        if effectiveStartDate > startDate {
            return max(1, Int(floor(span / Double(periodSeconds))) + 1)
        }

        return Int(floor(span / Double(periodSeconds)))
    }

    private func expectedSlots(forWindowHours hours: Int, now: Date, earliest: Date?, periodSeconds: Int) -> Int {
        guard periodSeconds > 0, let earliest = earliest else { return 0 }

        let windowSeconds = Double(hours) * 3600.0
        let fullExpected = Int(floor(windowSeconds / Double(periodSeconds)))
        let startOfWindow = now.addingTimeInterval(-windowSeconds)

        if earliest > startOfWindow {
            let span = max(0.0, now.timeIntervalSince(earliest))
            return max(1, Int(floor(span / Double(periodSeconds))) + 1)
        }

        return fullExpected
    }

    private func flooredPercent(actual: Int, expected: Int, hasMisses: Bool) -> Double {
        guard expected > 0 else { return 0.0 }
        let raw = (Double(actual) * 100.0) / Double(expected)
        let floored = floor(raw * 10.0) / 10.0
        if hasMisses {
            return min(floored, 99.9)
        }
        return floored
    }
    
    // MARK: - Helper functions

    /// Infer 1‑minute vs 5‑minute gap using average gap; conservative fallback to 5 minutes.
    private static func inferNominalGapSeconds(earliest: Date?, latest: Date?, distinctCount: Int) -> Int {
        guard let earliest = earliest, let latest = latest, distinctCount >= 2 else {
            return 300 // fallback to Dexcom nominal gap
        }
        let avg = latest.timeIntervalSince(earliest) / Double(max(1, distinctCount - 1))
        if avg <= 90.0 { return 60 }
        return 300
    }
}
