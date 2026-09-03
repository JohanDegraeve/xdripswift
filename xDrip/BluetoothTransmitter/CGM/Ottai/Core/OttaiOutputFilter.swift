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

import Foundation

enum OttaiOutputFilter {

    static let minRawCurrent = 1000
    static let maxTemperatureC = 45.0
    /// A sensor on the body is never this cold. Without a lower limit, a broken
    /// packet with a low temperature would pass.
    static let minTemperatureC = 15.0
    static let maxGlucoseMmol: Float = 40.0

    /// A one-minute jump this big, together with a big jump in the raw current,
    /// is treated as noise.
    static let singleSampleDeltaMmol: Float = 1.5
    static let rawExcursionRatio: Float = 0.18

    /// Returns a reason text if the record must be thrown away, or nil if it is fine.
    static func hardRejectReason(record: OttaiRecord, mmol: Float) -> String? {
        if !mmol.isFinite || mmol <= 0 { return "glucose=\(mmol)" }
        if mmol > maxGlucoseMmol { return "glucose=\(mmol)" }
        if record.rawCurrent < minRawCurrent { return "raw=\(record.rawCurrent)" }
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
