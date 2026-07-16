//
//  BgSmoothingAlgorithmPlugin.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Shared contract for pluggable smoothing strategies.
///
/// Keep provenance notes on each concrete implementation so future additions can
/// document whether they are:
/// - a direct port from another open-source project such as AAPS or Trio, or
/// - an in-project implementation of a published/general signal-processing method.
protocol BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double]
}

struct BgSmoothingSupport {
    let canUseFiveMinuteReadings: ([Date]) -> Bool
    let medianReadingGapInMinutes: ([Date]) -> Double?
    let savitzkyGolayStyleSmoothedValues: ([Double], [Date], Int) -> [Double]
    let sparseCadenceSmoothedValues: ([Double], Int, Int, Int) -> [Double]
    let clampedMostRecentSmoothedValues: ([Double], [Double], Int) -> [Double]

    func isFastCadence(readingDates: [Date]) -> Bool {
        return canUseFiveMinuteReadings(readingDates)
    }
}
