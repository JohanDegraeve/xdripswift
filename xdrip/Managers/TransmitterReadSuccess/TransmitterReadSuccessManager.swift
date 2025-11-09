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
    public let latestTimestampInLast24h: Date?

    public let expected6h: Int
    public let actual6h: Int
    public let success6h: Double

    public let expected12h: Int
    public let actual12h: Int
    public let success12h: Double

    public let expected24h: Int
    public let actual24h: Int
    public let success24h: Double
}

final class TransmitterReadSuccessManager {
    
    /// Computes reading success for a transmitter/sensor session over a recent time window.
    /// This manager depends only on BgReadingsAccessor; it does not touch Core Data directly.
    private struct SlotOccupancy {
        let distinct6h: Int
        let distinct12h: Int
        let distinct24h: Int
        let earliest24h: Date?
        let latest24h: Date?
    }
    
    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor
    
    private let nowProvider: () -> Date
    
    // MARK: - initializer
    
    init(bgReadingsAccessor: BgReadingsAccessor, nowProvider: @escaping () -> Date = { Date() }) {
        self.bgReadingsAccessor = bgReadingsAccessor
        self.nowProvider = nowProvider
    }
    
    // MARK: - public functions

    /// Compute reading success for the given sensor and return 6h/12h/24h windows (always queries 24h once).
    /// - Parameters:
    ///   - sensor: Current sensor/session to evaluate.
    ///   - now: Optional override of current time; defaults to `nowProvider()`.
    ///   - cutoff: Optional cutoff date to clamp analysis to readings no earlier than this timestamp.
    /// - Returns: A display model with expected/actual/success for 6h, 12h, 24h.
    func getReadSuccess(forSensor sensor: Sensor, now: Date? = nil, notBefore cutoff: Date? = nil) -> TransmitterReadSuccessDisplay {
        let now = now ?? nowProvider()

        // Pull window counts and 24h boundaries in a single roundtrip
        var windowCounts = bgReadingsAccessor.getTransmitterReadSuccessWindowCounts(endingAt: now, forSensor: sensor)
        
        let allTimestamps = bgReadingsAccessor.getReadingTimestampsForLast24h(forSensor: sensor, endingAt: now)
        let slotOccupancy = countPhaseAlignedDistinctSlots(timestamps: allTimestamps, now: now, periodSeconds: 300)
        windowCounts.distinctCountLast6h = slotOccupancy.distinct6h
        windowCounts.distinctCountLast12h = slotOccupancy.distinct12h
        windowCounts.distinctCountLast24h = slotOccupancy.distinct24h
        
        let rawEarliest24h = windowCounts.earliestTimestampInLast24h
        let latest24h = windowCounts.latestTimestampInLast24h
        let earliest24h: Date? = {
            guard let rawEarliest24h = rawEarliest24h else { return nil }
            if let cutoff = cutoff {
                return max(rawEarliest24h, cutoff)
            }
            return rawEarliest24h
        }()

        // Infer nominal gap from 24h
        let nominalGapInSeconds = TransmitterReadSuccessManager.inferNominalGapSeconds(earliest: earliest24h, latest: latest24h, distinctCount: windowCounts.distinctCountLast24h)

        // Helper to compute expected slots using the actual span between
        // the effective window start and the timestamp of the latest reading.
        // This avoids under-counting when the last reading is a few minutes old
        // and prevents masking isolated gaps as 100% success.
        func expectedSlots(forWindowHours hours: Int) -> Int {
            guard nominalGapInSeconds > 0 else { return 0 }
            guard let earliest24h = earliest24h else { return 0 }

            let windowSeconds = Double(hours) * 3600.0
            let fixed = Int(floor(windowSeconds / Double(nominalGapInSeconds)))

            let startOfWindow = now.addingTimeInterval(-windowSeconds)

            if earliest24h > startOfWindow {
                // From first reading within this window (inclusive end)
                let span = max(0.0, now.timeIntervalSince(earliest24h))
                return max(1, Int(floor(span / Double(nominalGapInSeconds))) + 1)
            } else {
                return fixed
            }
        }

        let expected6h  = expectedSlots(forWindowHours: 6)
        let expected12h = expectedSlots(forWindowHours: 12)
        let expected24h = expectedSlots(forWindowHours: 24)

        // Cap actuals to expected and enforce correct missed counts across windows
        var actual6h  = min(windowCounts.distinctCountLast6h, expected6h)
        var actual12h = min(windowCounts.distinctCountLast12h, expected12h)
        var actual24h = min(windowCounts.distinctCountLast24h, expected24h)
        
        let missing6  = max(0, expected6h  - actual6h)
        let missing12 = max(missing6, max(0, expected12h - actual12h))
        let missing24 = max(missing12, max(0, expected24h - actual24h))

        actual6h  = expected6h  - missing6
        actual12h = expected12h - missing12
        actual24h = expected24h - missing24

        // Compute display percentages: floor to one decimal place and never show 100% if there are misses
        func flooredPercent(actual: Int, expected: Int, hasMisses: Bool) -> Double {
            guard expected > 0 else { return 0.0 }
            let raw = (Double(actual) * 100.0) / Double(expected)
            // floor to one decimal place
            let floored = floor(raw * 10.0) / 10.0
            if hasMisses {
                return min(floored, 99.9)
            }
            return floored
        }

        let success6h  = flooredPercent(actual: actual6h,  expected: expected6h,  hasMisses: missing6  > 0)
        let success12h = flooredPercent(actual: actual12h, expected: expected12h, hasMisses: missing12 > 0)
        let success24h = flooredPercent(actual: actual24h, expected: expected24h, hasMisses: missing24 > 0)

        return TransmitterReadSuccessDisplay(
            nominalGapInSeconds: nominalGapInSeconds,
            earliestTimestampInLast24h: earliest24h,
            latestTimestampInLast24h: latest24h,
            expected6h: expected6h,
            actual6h: actual6h,
            success6h: success6h,
            expected12h: expected12h,
            actual12h: actual12h,
            success12h: success12h,
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

    /// Counts the number of distinct phase-aligned slots (bins) containing readings in 6h, 12h, and 24h windows.
    /// Each slot is centered based on the inferred phase offset to align with actual reading timing.
    /// - Parameters:
    ///   - timestamps: All reading timestamps in the last 24 hours.
    ///   - now: Current reference time.
    ///   - periodSeconds: Nominal expected gap between readings (e.g. 300 or 60 seconds).
    /// - Returns: A `SlotOccupancy` structure containing the distinct slot counts and earliest/latest timestamps.
    private func countPhaseAlignedDistinctSlots(timestamps: [Date], now: Date, periodSeconds: Int) -> SlotOccupancy {
        guard periodSeconds > 0 else {
            return SlotOccupancy(distinct6h: 0, distinct12h: 0, distinct24h: 0, earliest24h: nil, latest24h: nil)
        }

        let window24Start = now.addingTimeInterval(-24 * 3600)
        let filtered = timestamps.filter { $0 >= window24Start && $0 <= now }.sorted()
        guard let earliest = filtered.first, let latest = filtered.last else {
            return SlotOccupancy(distinct6h: 0, distinct12h: 0, distinct24h: 0, earliest24h: nil, latest24h: nil)
        }

        let arrivalPhaseOffset = estimateArrivalPhaseOffset(timestamps: Array(filtered.suffix(120)), periodSeconds: periodSeconds)
        func slotIndex(for timestamp: Date) -> Int {
            let phaseAdjustedTimestamp = timestamp.timeIntervalSince1970 - arrivalPhaseOffset + Double(periodSeconds) / 2.0
            return Int(floor(phaseAdjustedTimestamp / Double(periodSeconds)))
        }

        let indexSet24h = Set(filtered.map(slotIndex))
        let indexSet12h = Set(filtered.filter { $0 >= now.addingTimeInterval(-12 * 3600) }.map(slotIndex))
        let indexSet6h  = Set(filtered.filter { $0 >= now.addingTimeInterval(-6 * 3600) }.map(slotIndex))

        return SlotOccupancy(distinct6h: indexSet6h.count,
                             distinct12h: indexSet12h.count,
                             distinct24h: indexSet24h.count,
                             earliest24h: earliest,
                             latest24h: latest)
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
