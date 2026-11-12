//
//  OttaiOutputFilter.swift
//  xdrip
//
//  Ottai / Syai CGM driver — the last check before a reading is used.
//  This is a Swift copy of OttaiOutputFilter.kt from JugglucoNG.
//
//  The parser and the formula do not filter anything. This file throws away
//  impossible values and single-sample spikes seen on real sensors.
//
//  Unlike the Kotlin, there is no raw < 1000 floor: such readings are passed
//  on and show as LOW, so a weak sensor does not look like a dead connection.
//

import Foundation

enum OttaiOutputFilter {

    static let maxTemperatureC = 45.0
    /// A sensor on the body is never this cold. Without a lower limit, a broken
    /// packet with a low temperature would pass.
    static let minTemperatureC = 15.0
    static let maxGlucoseMmol: Float = 40.0

    /// A one-minute jump this big, together with a big jump in the raw current,
    /// is treated as noise.
    static let singleSampleDeltaMmol: Float = 1.5
    static let rawExcursionRatio: Float = 0.18

    /// Reject a whole frame only when most temperatures are impossible.
    /// Low current alone is not a reason to reject it.
    static func isMisframedFrame(_ readings: [OttaiReading]) -> Bool {
        guard readings.count >= 8 else { return false }
        let accepted = readings.reduce(0) { count, reading in
            count + (hardRejectReason(record: reading.record, mmol: Float(reading.adjustGlucose)) == nil ? 1 : 0)
        }
        guard accepted * 4 < readings.count else { return false }
        let impossible = readings.reduce(0) { count, reading in
            let temperature = reading.record.temperatureC
            return count + (!temperature.isFinite || temperature < 0 || temperature > 60 ? 1 : 0)
        }
        return impossible * 2 > readings.count
    }

    /// Returns a reason text if the record must be thrown away, or nil if it is fine.
    static func hardRejectReason(record: OttaiRecord, mmol: Float) -> String? {
        if !mmol.isFinite || mmol <= 0 { return "glucose=\(mmol)" }
        if mmol > maxGlucoseMmol { return "glucose=\(mmol)" }
        if !record.temperatureC.isFinite ||
            record.temperatureC > maxTemperatureC ||
            record.temperatureC < minTemperatureC {
            return "temp=\(record.temperatureC)"
        }
        return nil
    }

    /// True if this sample is a single-sample spike compared to the last good sample.
    static func isOneMinuteRawExcursion(candidateMmol: Float, candidateRaw: Int, baselineMmol: Float, baselineRaw: Int) -> Bool {
        if !candidateMmol.isFinite || !baselineMmol.isFinite { return false }
        if candidateMmol <= 0 || baselineMmol <= 0 { return false }
        if candidateRaw <= 0 || baselineRaw <= 0 { return false }

        let glucoseDelta = abs(candidateMmol - baselineMmol)
        let rawDeltaRatio = Float(abs(candidateRaw - baselineRaw)) / Float(baselineRaw)
        return glucoseDelta >= singleSampleDeltaMmol && rawDeltaRatio >= rawExcursionRatio
    }
}
