//
//  SavitzkyGolayBgSmoothing.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Wraps the project's established Savitzky-Golay based smoother.
///
/// Provenance:
/// - This is not a new external port.
/// - It reuses the existing open-source Savitzky-Golay utility already shipped in
///   this repository under `xDrip/Utilities/SavitzkyGolayFilter`.
///
/// Algorithm references:
/// - Original paper:
///   Savitzky & Golay, "Smoothing and Differentiation of Data by Simplified
///   Least Squares Procedures" (local polynomial least-squares windows).
///   https://doi.org/10.1021/ac60214a047
/// - Practical description:
///   https://en.wikipedia.org/wiki/Savitzky%E2%80%93Golay_filter
struct SavitzkyGolayBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        return support.savitzkyGolayStyleSmoothedValues(values, readingDates, smoothingStrength)
    }
}
