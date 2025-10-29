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

/// Computes reading success for a transmitter/sensor session over a recent time window.
/// This manager depends only on BgReadingsAccessor; it does not touch Core Data directly.
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

    /// Compute reading success for the given sensor and return 6h/12h/24h windows (always queries 24h once).
    /// - Parameters:
    ///   - sensor: Current sensor/session to evaluate.
    ///   - now: Optional override of current time; defaults to `nowProvider()`.
    ///   - cutoff: Optional cutoff date to clamp analysis to readings no earlier than this timestamp.
    /// - Returns: A display model with expected/actual/success for 6h, 12h, 24h.
    func getReadSuccess(forSensor sensor: Sensor, now: Date? = nil, notBefore cutoff: Date? = nil) -> TransmitterReadSuccessDisplay {
        let now = now ?? nowProvider()

        // Pull window counts and 24h boundaries in a single roundtrip
        let windowCounts = bgReadingsAccessor.getTransmitterReadSuccessWindowCounts(endingAt: now, forSensor: sensor)
        
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

        // Helper to compute expected for a given window size (in hours)
        func expectedSlots(forWindowHours hours: Int) -> Int {
            guard nominalGapInSeconds > 0 else { return 0 }
            guard let earliest24h = earliest24h else { return 0 }
            
            let windowSeconds = Double(hours) * 3600.0
            let fixed = Int(floor(windowSeconds / Double(nominalGapInSeconds)))
            
            let startOfWindow = now.addingTimeInterval(-windowSeconds)
            
            if earliest24h > startOfWindow {
                // From-first-reading within this window (inclusive end)
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

        let success6h  = expected6h  > 0 ? (Double(actual6h)  * 100.0) / Double(expected6h)  : 0.0
        let success12h = expected12h > 0 ? (Double(actual12h) * 100.0) / Double(expected12h) : 0.0
        let success24h = expected24h > 0 ? (Double(actual24h) * 100.0) / Double(expected24h) : 0.0

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
}

