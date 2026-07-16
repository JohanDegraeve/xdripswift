//
//  ExponentialBgSmoothing.swift
//  xdrip
//
//  Created by Codex on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Bidirectional exponential smoother tuned for low visible lag at the live edge.
///
/// Provenance:
/// - This is an in-project implementation of a standard exponential moving
///   average style filter from general signal processing.
/// - It is intentionally not labeled as an AAPS or Trio port, because the code
///   here was written to fit xDrip's current post-processing contract rather
///   than copied from those projects.
struct ExponentialBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        let isFastCadence = support.isFastCadence(readingDates: readingDates)
        let alpha = ConstantsBgSmoothing.exponentialAlpha(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence)
        var smoothedValues = values

        for _ in 0..<ConstantsBgSmoothing.exponentialPassCount(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence) {
            smoothedValues = bidirectionalExponentialSmoothedValues(values: smoothedValues, alpha: alpha)
        }

        if isFastCadence,
           let medianReadingGapInMinutes = support.medianReadingGapInMinutes(readingDates),
           medianReadingGapInMinutes > 0 {
            let readingsPerFiveMinutes = max(2, Int((5.0 / medianReadingGapInMinutes).rounded()))
            smoothedValues = support.sparseCadenceSmoothedValues(
                smoothedValues,
                readingsPerFiveMinutes,
                ConstantsBgSmoothing.exponentialFastCadenceFilterWidth(forSmoothingStrength: smoothingStrength),
                ConstantsBgSmoothing.exponentialFastCadenceRepeatCount(forSmoothingStrength: smoothingStrength)
            )
        }

        return support.clampedMostRecentSmoothedValues(values, smoothedValues, smoothingStrength)
    }

    private func bidirectionalExponentialSmoothedValues(values: [Double], alpha: Double) -> [Double] {
        let forwardValues = exponentialPass(values: values, alpha: alpha)
        let backwardValues = Array(exponentialPass(values: Array(values.reversed()), alpha: alpha).reversed())

        return zip(forwardValues, backwardValues).map { (forwardValue, backwardValue) in
            (forwardValue + backwardValue) / 2.0
        }
    }

    private func exponentialPass(values: [Double], alpha: Double) -> [Double] {
        guard let firstValue = values.first else { return values }

        var filteredValues = [firstValue]
        filteredValues.reserveCapacity(values.count)

        for valueIndex in 1..<values.count {
            let previousFilteredValue = filteredValues[valueIndex - 1]
            let filteredValue = (alpha * values[valueIndex]) + ((1.0 - alpha) * previousFilteredValue)
            filteredValues.append(filteredValue)
        }

        return filteredValues
    }
}
