//
//  LoessBgSmoothing.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Local regression smoother using tricube distance weighting.
///
/// Provenance:
/// - This is an in-project implementation of the well-known LOESS/LOWESS local
///   regression method from open statistical literature.
/// - It is intentionally not labeled as an AAPS or Trio port, because the code
///   here was written directly for xDrip's current smoothing plugin contract.
///
/// Algorithm references:
/// - Original paper:
///   Cleveland, "Robust Locally Weighted Regression and Smoothing Scatterplots"
///   (tricube local weighting with optional robust reweighting).
///   https://www.jstor.org/stable/2286407
/// - General overview:
///   https://en.wikipedia.org/wiki/Local_regression
struct LoessBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        let isFastCadence = support.isFastCadence(readingDates: readingDates)
        let span = ConstantsBgSmoothing.loessSpan(
            forSmoothingStrength: smoothingStrength,
            isFastCadence: isFastCadence,
            sampleCount: values.count
        )
        let iterationCount = ConstantsBgSmoothing.loessRobustnessIterations(forSmoothingStrength: smoothingStrength)

        let smoothedValues = loessSmoothedValues(
            values: values,
            readingDates: readingDates,
            span: span,
            iterationCount: iterationCount
        )

        return support.clampedMostRecentSmoothedValues(values, smoothedValues, smoothingStrength)
    }

    private func loessSmoothedValues(values: [Double], readingDates: [Date], span: Int, iterationCount: Int) -> [Double] {
        let xValues = readingDates.map { $0.timeIntervalSince1970 / 60.0 }
        var robustnessWeights = Array(repeating: 1.0, count: values.count)
        var fittedValues = values

        for iterationIndex in 0...iterationCount {
            fittedValues = localRegressionPass(
                xValues: xValues,
                yValues: values,
                span: span,
                robustnessWeights: robustnessWeights
            )

            guard iterationIndex < iterationCount else { break }

            let residuals = zip(values, fittedValues).map { abs($0 - $1) }
            let medianResidual = median(residuals)

            guard medianResidual > 0 else { break }

            let scale = 6.0 * medianResidual
            robustnessWeights = residuals.map { residual in
                let normalizedResidual = min(1.0, residual / scale)
                let weightBase = 1.0 - (normalizedResidual * normalizedResidual)
                return weightBase * weightBase
            }
        }

        return fittedValues
    }

    private func localRegressionPass(xValues: [Double], yValues: [Double], span: Int, robustnessWeights: [Double]) -> [Double] {
        var fittedValues = Array(repeating: 0.0, count: yValues.count)

        for targetIndex in yValues.indices {
            let neighborRange = neighborhoodRange(targetIndex: targetIndex, sampleCount: yValues.count, span: span)
            let targetX = xValues[targetIndex]
            let neighborhoodDistances = neighborRange.map { abs(xValues[$0] - targetX) }
            let maxDistance = neighborhoodDistances.max() ?? 0

            if maxDistance <= 0 {
                fittedValues[targetIndex] = yValues[targetIndex]
                continue
            }

            var weightedCount = 0
            var weightSum = 0.0
            var weightedXSum = 0.0
            var weightedYSum = 0.0
            var weightedXXSum = 0.0
            var weightedXYSum = 0.0

            for neighborIndex in neighborRange {
                let distance = abs(xValues[neighborIndex] - targetX)
                let distanceWeight = tricubeWeight(distance: distance, maxDistance: maxDistance)
                let weight = distanceWeight * robustnessWeights[neighborIndex]

                guard weight > 0 else { continue }

                weightedCount += 1
                let xValue = xValues[neighborIndex]
                let yValue = yValues[neighborIndex]

                weightSum += weight
                weightedXSum += weight * xValue
                weightedYSum += weight * yValue
                weightedXXSum += weight * xValue * xValue
                weightedXYSum += weight * xValue * yValue
            }

            guard weightedCount >= 2, weightSum > 0 else {
                fittedValues[targetIndex] = yValues[targetIndex]
                continue
            }

            let denominator = (weightSum * weightedXXSum) - (weightedXSum * weightedXSum)

            if abs(denominator) < 0.000_001 {
                fittedValues[targetIndex] = weightedYSum / weightSum
                continue
            }

            let slope = ((weightSum * weightedXYSum) - (weightedXSum * weightedYSum)) / denominator
            let intercept = (weightedYSum - (slope * weightedXSum)) / weightSum
            fittedValues[targetIndex] = intercept + (slope * targetX)
        }

        return fittedValues
    }

    private func neighborhoodRange(targetIndex: Int, sampleCount: Int, span: Int) -> ClosedRange<Int> {
        let halfSpan = span / 2
        var lowerBound = max(0, targetIndex - halfSpan)
        let upperBound = min(sampleCount - 1, lowerBound + span - 1)
        lowerBound = max(0, upperBound - span + 1)
        return lowerBound...upperBound
    }

    private func tricubeWeight(distance: Double, maxDistance: Double) -> Double {
        guard maxDistance > 0 else { return 1.0 }

        let normalizedDistance = min(1.0, distance / maxDistance)
        let base = 1.0 - pow(normalizedDistance, 3.0)
        return pow(base, 3.0)
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
