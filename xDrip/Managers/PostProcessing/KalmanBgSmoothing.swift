//
//  KalmanBgSmoothing.swift
//  xdrip
//
//  Created by Codex on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// One-dimensional Kalman smoother with an adaptive process term based on the
/// local glucose change.
///
/// Provenance:
/// - This is an in-project implementation of a standard scalar Kalman filter
///   from general signal processing and state estimation literature.
/// - It is intentionally not labeled as an AAPS or Trio port, because the code
///   here was written to fit xDrip's current post-processing contract rather
///   than copied from those projects.
struct KalmanBgSmoothing: BgSmoothingAlgorithmPlugin {
    func smoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int, support: BgSmoothingSupport) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        let isFastCadence = support.isFastCadence(readingDates: readingDates)
        let measurementNoise = ConstantsBgSmoothing.kalmanMeasurementNoise(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence)
        let baseProcessNoise = ConstantsBgSmoothing.kalmanBaseProcessNoise(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence)
        let slopeProcessScale = ConstantsBgSmoothing.kalmanSlopeProcessScale(forSmoothingStrength: smoothingStrength, isFastCadence: isFastCadence)

        let forwardValues = kalmanPass(
            values: values,
            measurementNoise: measurementNoise,
            baseProcessNoise: baseProcessNoise,
            slopeProcessScale: slopeProcessScale
        )
        let backwardValues = Array(kalmanPass(
            values: Array(values.reversed()),
            measurementNoise: measurementNoise,
            baseProcessNoise: baseProcessNoise,
            slopeProcessScale: slopeProcessScale
        ).reversed())

        let blendedValues = zip(forwardValues, backwardValues).map { (forwardValue, backwardValue) in
            (forwardValue + backwardValue) / 2.0
        }

        return support.clampedMostRecentSmoothedValues(values, blendedValues, smoothingStrength)
    }

    private func kalmanPass(values: [Double], measurementNoise: Double, baseProcessNoise: Double, slopeProcessScale: Double) -> [Double] {
        guard let firstValue = values.first else { return values }

        var filteredValues = [firstValue]
        filteredValues.reserveCapacity(values.count)

        var estimate = firstValue
        var errorCovariance = measurementNoise

        for valueIndex in 1..<values.count {
            let measurement = values[valueIndex]
            let lastMeasurement = values[valueIndex - 1]
            let localDelta = abs(measurement - lastMeasurement)
            let processNoise = baseProcessNoise + (localDelta * slopeProcessScale)

            errorCovariance += processNoise

            let kalmanGain = errorCovariance / (errorCovariance + measurementNoise)
            estimate += kalmanGain * (measurement - estimate)
            errorCovariance *= (1.0 - kalmanGain)

            filteredValues.append(estimate)
        }

        return filteredValues
    }
}
