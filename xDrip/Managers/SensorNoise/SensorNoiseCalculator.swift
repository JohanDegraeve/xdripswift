//
//  SensorNoiseCalculator.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// states used to describe the sensor noise measurements
enum SensorNoiseState: Int16 {
    case collecting = 0
    case low = 1
    case elevated = 2
    case veryHigh = 3
    case extreme = 4
    case flatlineSuspected = 5
}

/// user-facing tolerance used when interpreting stored sensor noise values
enum SensorNoiseSensitivity: Int, CaseIterable {
    case sensitive = 0
    case normal = 1
    case permissive = 2

    var description: String {
        switch self {
        case .sensitive:
            return Texts_SettingsView.sensorNoiseSensitivitySensitive
        case .normal:
            return Texts_SettingsView.sensorNoiseSensitivityNormal
        case .permissive:
            return Texts_SettingsView.sensorNoiseSensitivityPermissive
        }
    }

    /// multiplier applied only when classifying noise for display and warnings
    var classificationMultiplier: Double {
        switch self {
        case .sensitive:
            return ConstantsSensorNoise.sensitiveNoiseClassificationMultiplier
        case .normal:
            return ConstantsSensorNoise.normalNoiseClassificationMultiplier
        case .permissive:
            return ConstantsSensorNoise.permissiveNoiseClassificationMultiplier
        }
    }
}

/// sensor noise calculation and warning limits
enum ConstantsSensorNoise {
    static let algorithmVersion: Int16 = 1

    /// Base multiplier used to tune all user-facing sensor noise classifications together.
    ///
    /// Lower this value to make every sensitivity level more permissive, or raise it to make every
    /// sensitivity level stricter. This affects display and warning limits only. It does not change
    /// stored noise values, the calculated algorithm state or flatline detection.
    ///
    /// For example, if the default would usually be 1.0. Adjust upwards to 1.2 to make the UI
    /// more sensitive when showing noise
    static let baseNoiseClassificationMultiplier = 1.15

    /// Interprets stored noise values more strictly by classifying them x% higher than measured.
    ///
    /// This can help naturally stable sensors produce warnings more easily, without changing
    /// the stored noise history or bypassing flatline detection.
    static let sensitiveNoiseClassificationMultiplier = baseNoiseClassificationMultiplier * 1.3

    /// Uses the base noise classification level when classifying display and warning state.
    static let normalNoiseClassificationMultiplier = baseNoiseClassificationMultiplier

    /// Interprets stored noise values more gently by classifying them x% lower than measured.
    ///
    /// This can help naturally jumpier sensors remain in a lower warning state, without changing
    /// the stored noise history or bypassing flatline detection.
    static let permissiveNoiseClassificationMultiplier = baseNoiseClassificationMultiplier * 0.85

    static let shortTermWindow: TimeInterval = 30 * 60
    static let longTermWindow: TimeInterval = 4 * 60 * 60
    static let longTermContextWindow: TimeInterval = longTermWindow + shortTermWindow
    static let minimumShortTermSpan: TimeInterval = 20 * 60
    static let minimumLongTermSpan: TimeInterval = 3.5 * 60 * 60
    static let maximumGap: TimeInterval = 12 * 60

    static let minimumReadingsForQuadraticFit = 6
    static let minimumReadingsForNeighbourJitter = 6
    static let minimumLongTermEstimates = 12
    static let minimumLongTermCoverage = 0.70
    static let historyMinimumInterval: TimeInterval = ConstantsNightscout.minimiumTimeBetweenTwoReadingsInMinutes * 60

    /// Point-to-point changes smaller than this are ignored when deciding if a segment is directional.
    static let smoothTrendDeltaDeadbandInMgDl = 1.0

    /// Required share of movement in one direction before a segment can be treated as a smooth trend.
    static let smoothTrendDirectionalConsistency = 0.92

    /// Maximum total movement against the main direction still allowed inside a smooth trend.
    static let smoothTrendMaximumOppositeMovementInMgDl = 3.0

    /// Maximum single movement against the main direction still allowed inside a smooth trend.
    static let smoothTrendMaximumOppositeDeltaInMgDl = 2.5

    /// Neighbour residuals smaller than this are ignored when counting local shape changes.
    static let smoothTrendResidualDeadbandInMgDl = 2.0

    /// Smooth curved rises and falls should not repeatedly alternate above and below their neighbours.
    static let smoothTrendMaximumResidualSignChanges = 1

    /// xDrip Android uses error-variance boundaries 10, 60 and 200. The persisted
    /// values here are standard deviations, so use the square roots of those values.
    static let elevatedNoiseStandardDeviation = sqrt(10.0)
    static let veryHighNoiseStandardDeviation = sqrt(60.0)
    static let extremeNoiseStandardDeviation = sqrt(200.0)

    /// Smooth directional rises and falls can have large quadratic residuals but should remain low.
    static let smoothTrendNoiseCapStandardDeviation = elevatedNoiseStandardDeviation * 0.75

    static let maximumGlucoseValueInMgDl = 600.0
    static let flatlineLookback: TimeInterval = 60 * 60
    static let flatlineMinimumSpan: TimeInterval = 25 * 60
    static let flatlineMinimumReadings = 6
    static let flatlineRangeToleranceInMgDl = 0.1
    static let rootWarningFreshness: TimeInterval = 15 * 60

    /// Maps a standard-deviation value to the matching display and warning state.
    static func state(for noise: Double) -> SensorNoiseState {
        state(forAdjustedNoise: noise)
    }

    /// Maps a stored standard-deviation value through the selected user tolerance.
    ///
    /// The raw stored noise values are unchanged. Only the display and warning classification moves.
    static func state(for noise: Double, sensitivity: SensorNoiseSensitivity) -> SensorNoiseState {
        state(forAdjustedNoise: noise * sensitivity.classificationMultiplier)
    }

    /// returns the raw noise value that matches a threshold under the selected user tolerance
    static func threshold(_ threshold: Double, sensitivity: SensorNoiseSensitivity) -> Double {
        threshold / sensitivity.classificationMultiplier
    }

    /// combines short and long-term values into the user-facing state without changing stored data
    static func displayState(rawState: SensorNoiseState, shortTermNoise: Double?, longTermNoise: Double?, sensitivity: SensorNoiseSensitivity) -> SensorNoiseState {
        if rawState == .flatlineSuspected { return .flatlineSuspected }

        let states = [shortTermNoise, longTermNoise]
            .compactMap { $0 }
            .map { state(for: $0, sensitivity: sensitivity) }

        return states.max(by: { $0.rawValue < $1.rawValue }) ?? .collecting
    }

    private static func state(forAdjustedNoise noise: Double) -> SensorNoiseState {
        if noise > extremeNoiseStandardDeviation {
            return .extreme
        } else if noise > veryHighNoiseStandardDeviation {
            return .veryHigh
        } else if noise > elevatedNoiseStandardDeviation {
            return .elevated
        }

        return .low
    }
}

/// input model used by the sensor noise calculator
struct SensorNoiseReading: Equatable {
    let timeStamp: Date
    let calculatedValue: Double
    let rawData: Double
    let calibrationID: String?
}

/// result produced by the sensor noise calculator
struct SensorNoiseMeasurement: Equatable {
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let shortTermCoverage: Double
    let longTermCoverage: Double
    let state: SensorNoiseState
    let latestReadingAt: Date?
}

/// One historic sensor noise measurement anchored to a reading timestamp.
struct SensorNoiseHistoryMeasurement: Equatable {
    let timeStamp: Date
    let measurement: SensorNoiseMeasurement
}

/// estimates sensor jitter after removing a local quadratic glucose trend
///
/// The short-term result is the residual standard deviation of the newest
/// contiguous 30-minute segment. The long-term result is the 75th percentile of
/// rolling short-term estimates over four hours, avoiding one unrealistic
/// polynomial fit across normal meals, corrections, rises and falls.
struct SensorNoiseCalculator {

    // MARK: - public functions

    /// calculates the short and long-term noise measurements for the supplied readings
    func calculate(readings: [SensorNoiseReading]) -> SensorNoiseMeasurement {
        let usableReadings = usableReadings(from: readings)

        guard let latestReading = usableReadings.last else {
            return SensorNoiseMeasurement(
                shortTermNoise: nil,
                longTermNoise: nil,
                shortTermCoverage: 0,
                longTermCoverage: 0,
                state: .collecting,
                latestReadingAt: nil
            )
        }

        let contextStart = latestReading.timeStamp.addingTimeInterval(-ConstantsSensorNoise.longTermContextWindow)
        let contextualReadings = usableReadings.filter { $0.timeStamp >= contextStart && $0.timeStamp <= latestReading.timeStamp }
        let shortSegment = contiguousTail(
            readings: contextualReadings,
            endingAt: latestReading.timeStamp,
            window: ConstantsSensorNoise.shortTermWindow
        )
        let shortTermCoverage = temporalCoverage(
            readings: shortSegment,
            window: ConstantsSensorNoise.shortTermWindow
        )
        let shortTermNoise = jitterAwareNoiseStandardDeviation(readings: shortSegment)

        let longTermStart = latestReading.timeStamp.addingTimeInterval(-ConstantsSensorNoise.longTermWindow)
        let longTermReadings = contextualReadings.filter { $0.timeStamp >= longTermStart }
        let longTermCoverage = temporalCoverage(
            readings: longTermReadings,
            window: ConstantsSensorNoise.longTermWindow
        )
        let longTermSpan: TimeInterval
        if let firstLongTermReading = longTermReadings.first,
           let lastLongTermReading = longTermReadings.last {
            longTermSpan = lastLongTermReading.timeStamp.timeIntervalSince(firstLongTermReading.timeStamp)
        } else {
            longTermSpan = 0
        }

        var rollingNoiseValues: [Double] = []
        rollingNoiseValues.reserveCapacity(longTermReadings.count)

        for endpoint in longTermReadings {
            let segment = contiguousTail(
                readings: contextualReadings,
                endingAt: endpoint.timeStamp,
                window: ConstantsSensorNoise.shortTermWindow
            )

            if let noise = jitterAwareNoiseStandardDeviation(readings: segment) {
                rollingNoiseValues.append(noise)
            }
        }

        let longTermNoise: Double?
        if longTermSpan >= ConstantsSensorNoise.minimumLongTermSpan,
           longTermCoverage >= ConstantsSensorNoise.minimumLongTermCoverage,
           rollingNoiseValues.count >= ConstantsSensorNoise.minimumLongTermEstimates {
            longTermNoise = percentile(rollingNoiseValues, percentile: 0.75)
        } else {
            longTermNoise = nil
        }

        let flatlineDetected = isFlatlineDetected(
            readings: contiguousTail(
                readings: contextualReadings,
                endingAt: latestReading.timeStamp,
                window: ConstantsSensorNoise.flatlineLookback
            )
        )
        let state = measurementState(
            shortTermNoise: shortTermNoise,
            longTermNoise: longTermNoise,
            flatlineDetected: flatlineDetected
        )

        return SensorNoiseMeasurement(
            shortTermNoise: shortTermNoise,
            longTermNoise: longTermNoise,
            shortTermCoverage: shortTermCoverage,
            longTermCoverage: longTermCoverage,
            state: state,
            latestReadingAt: latestReading.timeStamp
        )
    }

    /// Calculates measurements across the full supplied sensor session at the stored history cadence.
    ///
    /// Each endpoint is calculated with the same rolling context as a live update, so rebuilding
    /// history cannot produce values that differ from those stored while the sensor was running.
    func calculateHistory(readings: [SensorNoiseReading]) -> [SensorNoiseHistoryMeasurement] {
        let usableReadings = usableReadings(from: readings)
        guard !usableReadings.isEmpty else { return [] }

        var history = [SensorNoiseHistoryMeasurement]()
        var lastEndpointDate: Date?
        var contextStartIndex = 0

        for endpointIndex in usableReadings.indices {
            let endpoint = usableReadings[endpointIndex]

            if let lastEndpointDate,
               endpoint.timeStamp.timeIntervalSince(lastEndpointDate) < ConstantsSensorNoise.historyMinimumInterval {
                continue
            }

            lastEndpointDate = endpoint.timeStamp
            let contextStartDate = endpoint.timeStamp.addingTimeInterval(-ConstantsSensorNoise.longTermContextWindow)

            while contextStartIndex < endpointIndex,
                  usableReadings[contextStartIndex].timeStamp < contextStartDate {
                contextStartIndex += 1
            }

            let contextualReadings = Array(usableReadings[contextStartIndex ... endpointIndex])
            let measurement = calculate(readings: contextualReadings)

            guard measurement.shortTermNoise != nil
                    || measurement.longTermNoise != nil
                    || measurement.state == .flatlineSuspected else {
                continue
            }

            history.append(SensorNoiseHistoryMeasurement(timeStamp: endpoint.timeStamp, measurement: measurement))
        }

        return history
    }

    // MARK: - private functions

    /// Applies the shared validity checks before either a live or historic calculation is made.
    private func usableReadings(from readings: [SensorNoiseReading]) -> [SensorNoiseReading] {
        readings
            .filter { reading in
                reading.timeStamp.timeIntervalSince1970.isFinite
                    && reading.calculatedValue.isFinite
                    && reading.rawData.isFinite
                    && reading.calculatedValue >= ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
                    && reading.calculatedValue <= ConstantsSensorNoise.maximumGlucoseValueInMgDl
            }
            .sorted { $0.timeStamp < $1.timeStamp }
    }

    /// Returns the newest uninterrupted readings without crossing a calibration boundary.
    private func contiguousTail(readings: [SensorNoiseReading], endingAt endDate: Date, window: TimeInterval) -> [SensorNoiseReading] {
        let startDate = endDate.addingTimeInterval(-window)
        let candidates = readings.filter { $0.timeStamp >= startDate && $0.timeStamp <= endDate }

        guard let latest = candidates.last else { return [] }

        var result = [latest]
        for reading in candidates.dropLast().reversed() {
            guard let first = result.first else { break }
            let gap = first.timeStamp.timeIntervalSince(reading.timeStamp)

            if gap > ConstantsSensorNoise.maximumGap || crossesCalibrationBoundary(older: reading, newer: first) {
                break
            }

            result.insert(reading, at: 0)
        }

        return result
    }

    private func crossesCalibrationBoundary(older: SensorNoiseReading, newer: SensorNoiseReading) -> Bool {
        older.calibrationID != newer.calibrationID
            && (older.calibrationID != nil || newer.calibrationID != nil)
    }

    /// Combines trend residuals with local neighbour jitter so smooth rises and falls stay low.
    private func jitterAwareNoiseStandardDeviation(readings: [SensorNoiseReading]) -> Double? {
        guard let quadraticNoise = quadraticNoiseStandardDeviation(readings: readings) else { return nil }
        guard let neighbourJitter = neighbourJitterStandardDeviation(readings: readings) else { return quadraticNoise }

        if isSmoothDirectionalTrend(readings: readings) {
            return min(quadraticNoise, neighbourJitter, ConstantsSensorNoise.smoothTrendNoiseCapStandardDeviation)
        }

        return max(quadraticNoise, neighbourJitter)
    }

    /// Removes a local quadratic glucose trend and returns the residual standard deviation.
    private func quadraticNoiseStandardDeviation(readings: [SensorNoiseReading]) -> Double? {
        guard readings.count >= ConstantsSensorNoise.minimumReadingsForQuadraticFit,
              let firstDate = readings.first?.timeStamp,
              let lastDate = readings.last?.timeStamp,
              lastDate.timeIntervalSince(firstDate) >= ConstantsSensorNoise.minimumShortTermSpan else {
            return nil
        }

        let xValues = readings.map { $0.timeStamp.timeIntervalSince(firstDate) / 60.0 }
        let yValues = readings.map(\.calculatedValue)
        let count = Double(readings.count)

        let sumX = xValues.reduce(0, +)
        let sumX2 = xValues.reduce(0) { $0 + ($1 * $1) }
        let sumX3 = xValues.reduce(0) { $0 + ($1 * $1 * $1) }
        let sumX4 = xValues.reduce(0) { $0 + ($1 * $1 * $1 * $1) }
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).reduce(0) { $0 + ($1.0 * $1.1) }
        let sumX2Y = zip(xValues, yValues).reduce(0) { $0 + ($1.0 * $1.0 * $1.1) }

        let matrix = [
            [count, sumX, sumX2],
            [sumX, sumX2, sumX3],
            [sumX2, sumX3, sumX4]
        ]

        guard let coefficients = solve3x3(matrix: matrix, values: [sumY, sumXY, sumX2Y]) else {
            return nil
        }

        let squaredError = zip(xValues, yValues).reduce(0.0) { partialResult, pair in
            let predicted = coefficients[0] + coefficients[1] * pair.0 + coefficients[2] * pair.0 * pair.0
            let residual = pair.1 - predicted
            return partialResult + residual * residual
        }
        let degreesOfFreedom = Double(readings.count - 3)

        guard degreesOfFreedom > 0 else { return nil }

        return sqrt(max(squaredError / degreesOfFreedom, 0))
    }

    /// Measures how far each reading jumps away from the line between its neighbours.
    private func neighbourJitterStandardDeviation(readings: [SensorNoiseReading]) -> Double? {
        guard readings.count >= ConstantsSensorNoise.minimumReadingsForNeighbourJitter,
              let firstDate = readings.first?.timeStamp,
              let lastDate = readings.last?.timeStamp,
              lastDate.timeIntervalSince(firstDate) >= ConstantsSensorNoise.minimumShortTermSpan else {
            return nil
        }

        let residuals = neighbourResiduals(readings: readings)
        guard !residuals.isEmpty else { return nil }

        let squaredError = residuals.reduce(0.0) { $0 + ($1 * $1) }

        return sqrt(max(squaredError / Double(residuals.count), 0))
    }

    /// Returns the local residuals used to detect point-to-point jitter.
    private func neighbourResiduals(readings: [SensorNoiseReading]) -> [Double] {
        var residuals = [Double]()

        for index in readings.indices.dropFirst().dropLast() {
            let olderReading = readings[index - 1]
            let reading = readings[index]
            let newerReading = readings[index + 1]
            let neighbourSpan = newerReading.timeStamp.timeIntervalSince(olderReading.timeStamp)

            guard neighbourSpan > 0 else { continue }

            let readingPosition = reading.timeStamp.timeIntervalSince(olderReading.timeStamp) / neighbourSpan
            let expectedValue = olderReading.calculatedValue + ((newerReading.calculatedValue - olderReading.calculatedValue) * readingPosition)
            let residual = reading.calculatedValue - expectedValue
            residuals.append(residual)
        }

        return residuals
    }

    /// Returns true when the segment mainly rises or falls without meaningful opposite movement.
    private func isSmoothDirectionalTrend(readings: [SensorNoiseReading]) -> Bool {
        let deltas = zip(readings, readings.dropFirst())
            .map { $1.calculatedValue - $0.calculatedValue }
            .filter { abs($0) >= ConstantsSensorNoise.smoothTrendDeltaDeadbandInMgDl }

        guard !deltas.isEmpty else { return true }

        let positiveMovement = deltas
            .filter { $0 > 0 }
            .reduce(0.0, +)
        let negativeMovement = deltas
            .filter { $0 < 0 }
            .reduce(0.0) { $0 + abs($1) }
        let mainDirectionIsRising = positiveMovement >= negativeMovement
        let mainMovement = max(positiveMovement, negativeMovement)
        let oppositeMovement = min(positiveMovement, negativeMovement)
        let totalMovement = mainMovement + oppositeMovement
        let largestOppositeDelta = deltas
            .filter { ($0 > 0) != mainDirectionIsRising }
            .map { abs($0) }
            .max() ?? 0

        guard totalMovement > 0 else { return true }

        return mainMovement / totalMovement >= ConstantsSensorNoise.smoothTrendDirectionalConsistency
            && oppositeMovement <= ConstantsSensorNoise.smoothTrendMaximumOppositeMovementInMgDl
            && largestOppositeDelta <= ConstantsSensorNoise.smoothTrendMaximumOppositeDeltaInMgDl
            && neighbourResidualSignChanges(readings: readings) <= ConstantsSensorNoise.smoothTrendMaximumResidualSignChanges
    }

    /// Counts repeated local shape reversals after ignoring very small neighbour residuals.
    private func neighbourResidualSignChanges(readings: [SensorNoiseReading]) -> Int {
        let signs = neighbourResiduals(readings: readings)
            .filter { abs($0) >= ConstantsSensorNoise.smoothTrendResidualDeadbandInMgDl }
            .map { $0 > 0 ? 1 : -1 }

        return zip(signs, signs.dropFirst())
            .filter { $0.0 != $0.1 }
            .count
    }

    /// Solves the quadratic fit's three normal equations using pivoted elimination.
    private func solve3x3(matrix: [[Double]], values: [Double]) -> [Double]? {
        guard matrix.count == 3, matrix.allSatisfy({ $0.count == 3 }), values.count == 3 else { return nil }

        var augmented = zip(matrix, values).map { row, value in row + [value] }

        for column in 0..<3 {
            let pivotRow = (column..<3).max { abs(augmented[$0][column]) < abs(augmented[$1][column]) } ?? column
            if abs(augmented[pivotRow][column]) < 0.000_000_001 { return nil }

            if pivotRow != column {
                augmented.swapAt(pivotRow, column)
            }

            let pivot = augmented[column][column]
            for valueIndex in column..<4 {
                augmented[column][valueIndex] /= pivot
            }

            for row in 0..<3 where row != column {
                let factor = augmented[row][column]
                for valueIndex in column..<4 {
                    augmented[row][valueIndex] -= factor * augmented[column][valueIndex]
                }
            }
        }

        return augmented.map { $0[3] }
    }

    /// Measures how much of a rolling window contains usable, contiguous readings.
    private func temporalCoverage(readings: [SensorNoiseReading], window: TimeInterval) -> Double {
        guard readings.count > 1 else { return 0 }

        let coveredDuration = zip(readings, readings.dropFirst()).reduce(0.0) { partialResult, pair in
            let gap = pair.1.timeStamp.timeIntervalSince(pair.0.timeStamp)
            return partialResult + (gap <= ConstantsSensorNoise.maximumGap ? max(gap, 0) : 0)
        }

        return min(max(coveredDuration / window, 0), 1)
    }

    /// Returns a linearly interpolated percentile from the supplied values.
    private func percentile(_ values: [Double], percentile: Double) -> Double? {
        guard !values.isEmpty else { return nil }

        let sortedValues = values.sorted()
        let boundedPercentile = min(max(percentile, 0), 1)
        let position = boundedPercentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))

        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }

        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + fraction * (sortedValues[upperIndex] - sortedValues[lowerIndex])
    }

    /// Detects an implausibly unchanged suffix without treating ordinary low noise as a flatline.
    private func isFlatlineDetected(readings: [SensorNoiseReading]) -> Bool {
        guard let latest = readings.last else { return false }

        var suffix = [latest]
        var minimumValue = latest.calculatedValue
        var maximumValue = latest.calculatedValue

        for reading in readings.dropLast().reversed() {
            minimumValue = min(minimumValue, reading.calculatedValue)
            maximumValue = max(maximumValue, reading.calculatedValue)

            if maximumValue - minimumValue > ConstantsSensorNoise.flatlineRangeToleranceInMgDl {
                break
            }

            suffix.insert(reading, at: 0)
        }

        guard suffix.count >= ConstantsSensorNoise.flatlineMinimumReadings,
              let firstDate = suffix.first?.timeStamp else {
            return false
        }

        return latest.timeStamp.timeIntervalSince(firstDate) >= ConstantsSensorNoise.flatlineMinimumSpan
    }

    /// Chooses the most important state across flatline, short-term and long-term measurements.
    private func measurementState(shortTermNoise: Double?, longTermNoise: Double?, flatlineDetected: Bool) -> SensorNoiseState {
        if flatlineDetected { return .flatlineSuspected }

        let states = [shortTermNoise, longTermNoise]
            .compactMap { $0 }
            .map { ConstantsSensorNoise.state(for: $0) }

        return states.max(by: { $0.rawValue < $1.rawValue }) ?? .collecting
    }
}
