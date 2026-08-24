//
//  HampelSavitzkyGolayBgSmoothing.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Hybrid smoother that first suppresses local outliers with a Hampel filter
/// and then reuses the existing Savitzky-Golay smoothing path.
///
/// Provenance:
/// - The Hampel stage is an in-project implementation of the standard Hampel
///   identifier from robust statistics literature.
/// - The second stage deliberately reuses xDrip's existing open-source
///   Savitzky-Golay implementation already shipped in this repository.
///
/// Algorithm references:
/// - Hampel stage:
///   local median plus MAD thresholding, replacing points beyond
///   k * 1.4826 * MAD with the window median.
///   https://en.wikipedia.org/wiki/Hampel_test
/// - Savitzky-Golay stage:
///   Savitzky & Golay, local polynomial least-squares smoothing.
///   https://doi.org/10.1021/ac60214a047
struct HampelSavitzkyGolayBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        let isFastCadence = support.isFastCadence(readingDates: readingDates)
        let filteredValues = hampelFilteredValues(
            values: values,
            windowRadius: ConstantsBgSmoothing.hampelWindowRadius(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence),
            thresholdScale: ConstantsBgSmoothing.hampelThresholdScale(forSmoothingStrength: smoothingStrength)
        )

        return support.savitzkyGolayStyleSmoothedValues(filteredValues, readingDates, smoothingStrength)
    }

    private func hampelFilteredValues(values: [Double], windowRadius: Int, thresholdScale: Double) -> [Double] {
        guard values.count >= 3 else { return values }

        var filteredValues = values

        for index in values.indices {
            let lowerBound = max(0, index - windowRadius)
            let upperBound = min(values.count - 1, index + windowRadius)
            let neighborhood = Array(values[lowerBound...upperBound])
            let neighborhoodMedian = median(neighborhood)
            let medianAbsoluteDeviation = median(neighborhood.map { abs($0 - neighborhoodMedian) })

            guard medianAbsoluteDeviation > 0 else { continue }

            let scaledDeviation = 1.4826 * medianAbsoluteDeviation
            let distanceFromMedian = abs(values[index] - neighborhoodMedian)

            if distanceFromMedian > (thresholdScale * scaledDeviation) {
                filteredValues[index] = neighborhoodMedian
            }
        }

        return filteredValues
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let sortedValues = values.sorted()
        let middleIndex = sortedValues.count / 2

        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2.0
        }

        return sortedValues[middleIndex]
    }
}
