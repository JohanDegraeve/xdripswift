//
//  SavitzkyGolayBgSmoothing.swift
//  xdrip
//
//  Created by Codex on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Wraps the project's established Savitzky-Golay based smoother.
///
/// Provenance:
/// - This is not a new external port.
/// - It reuses the existing open-source Savitzky-Golay utility already shipped in
///   this repository under `xDrip/Utilities/SavitzkyGolayFilter`.
struct SavitzkyGolayBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        return support.savitzkyGolayStyleSmoothedValues(values, readingDates, smoothingStrength)
    }
}
