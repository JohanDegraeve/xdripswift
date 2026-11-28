//
//  ConstantsBgSmoothing.swift
//  xdrip
//
//  Created by Paul Plant on 1/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

enum BgSmoothingAlgorithm: String, CaseIterable {
    case savitzkyGolay = "savitzkyGolay"
    case exponential = "exponential"
    case kalman = "kalman"
    case loess = "loess"

    var description: String {
        switch self {
        case .savitzkyGolay:
            return Texts_HomeView.postProcessingAlgorithmSavitzkyGolay
        case .exponential:
            return Texts_HomeView.postProcessingAlgorithmExponential
        case .kalman:
            return Texts_HomeView.postProcessingAlgorithmKalman
        case .loess:
            return Texts_HomeView.postProcessingAlgorithmLoess
        }
    }

    var footerDescription: String {
        switch self {
        case .savitzkyGolay:
            return Texts_HomeView.postProcessingAlgorithmSavitzkyGolayDescription
        case .exponential:
            return Texts_HomeView.postProcessingAlgorithmExponentialDescription
        case .kalman:
            return Texts_HomeView.postProcessingAlgorithmKalmanDescription
        case .loess:
            return Texts_HomeView.postProcessingAlgorithmLoessDescription
        }
    }

    var plugin: BgSmoothingAlgorithmPlugin {
        switch self {
        case .savitzkyGolay:
            return HampelSavitzkyGolayBgSmoothing()
        case .exponential:
            return ExponentialBgSmoothing()
        case .kalman:
            return KalmanBgSmoothing()
        case .loess:
            return LoessBgSmoothing()
        }
    }
}

enum ConstantsBgSmoothing {
    
    /// default smoothing period in minutes
    static let defaultSmoothingPeriodInMinutes = 30

    /// default smoothing strength
    static let defaultSmoothingStrength = 1

    /// default smoothing algorithm
    static let defaultSmoothingAlgorithm: BgSmoothingAlgorithm = .savitzkyGolay

    /// default state for reducing faster CGM streams down to one visible reading
    /// approximately every 5 minutes
    static let defaultUseFiveMinuteReadings = false

    /// use the same spacing already used by the normal 5 minute upload filter
    /// so post processing suppresses readings with the same project tolerance
    static let fiveMinuteCadenceMinimumTimeBetweenReadingsInMinutes = ConstantsNightscout.minimiumTimeBetweenTwoReadingsInMinutes
    
    /// minimum number of readings needed before smoothing can be applied
    static let minimumReadingsForSmoothing = 5
    
    /// once two glucose readings are further apart than the normal continuity
    /// limit, smoothing should stop at the gap instead of blending across it
    static let maximumGapBetweenReadingsInMinutes = ConstantsBGGraphBuilder.maxSlopeInMinutes

    /// automatic live post processing can re-evaluate a recent history tail so
    /// smoothing has enough context to update the newest readings consistently.
    /// Three hours gives the recursive smoothers enough settled historical context
    /// without requiring that entire context window to be stored again.
    static let automaticProcessingLookbackInterval: TimeInterval = .hours(3)

    /// automatic downstream replacement should stay much tighter than the local
    /// smoothing context so metadata churn in older readings does not fan out
    /// into broad Nightscout history rewrites.
    static let automaticDownstreamRewriteLookbackInterval: TimeInterval = .minutes(30)

    /// Savitzky-Golay filter width to use for each smoothing strength.
    /// The existing filter utility accepts:
    /// - 2 = 5-point filter
    /// - 3 = 7-point filter
    /// - 4 = 9-point filter
    static func filterWidth(forSmoothingStrength smoothingStrength: Int) -> Int {
        switch smoothingStrength {
        case 0:
            return 2
        case 2:
            return 4
        default:
            return 3
        }
    }
    
    static func maximumDeviationForMostRecentReading(forSmoothingStrength smoothingStrength: Int) -> Double {
        switch smoothingStrength {
        case 0:
            return 6.0
        case 2:
            return 12.0
        default:
            return 8.0
        }
    }

    /// Faster-than-5-minute CGM streams need a wider real-time smoothing span
    /// than a single short Savitzky-Golay pass can provide. Reuse the previous
    /// Libre-style two-stage behavior here so minute cadence sources keep a
    /// smooth curve without flattening the overall signal.
    static let fastCadenceNativeFilterWidth = 5
    static let fastCadenceNativeRepeatCount = 2
    static let fastCadenceFiveMinuteFilterWidth = 3
    static let fastCadenceFiveMinuteRepeatCount = 3

    static func fastCadenceBlendWeight(forSmoothingStrength smoothingStrength: Int) -> Double {
        switch smoothingStrength {
        case 0:
            return 0.35
        case 2:
            return 1.0
        default:
            return 0.7
        }
    }

    static func exponentialAlpha(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Double {
        let baseAlpha: Double

        switch smoothingStrength {
        case 0:
            baseAlpha = 0.4
        case 2:
            baseAlpha = 0.2
        default:
            baseAlpha = 0.34
        }

        return isFastCadence ? baseAlpha * 0.85 : baseAlpha
    }

    static func exponentialPassCount(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Int {
        switch smoothingStrength {
        case 0:
            return 1
        case 2:
            return isFastCadence ? 3 : 2
        default:
            return isFastCadence ? 2 : 1
        }
    }

    static func exponentialFastCadenceFilterWidth(forSmoothingStrength smoothingStrength: Int) -> Int {
        switch smoothingStrength {
        case 0:
            return 2
        case 2:
            return 3
        default:
            return 2
        }
    }

    static func exponentialFastCadenceRepeatCount(forSmoothingStrength smoothingStrength: Int) -> Int {
        switch smoothingStrength {
        case 0:
            return 1
        case 2:
            return 2
        default:
            return 1
        }
    }

    static func kalmanMeasurementNoise(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Double {
        let baseNoise: Double

        switch smoothingStrength {
        case 0:
            baseNoise = 20.0
        case 2:
            baseNoise = 42.0
        default:
            baseNoise = 30.0
        }

        return isFastCadence ? baseNoise * 0.8 : baseNoise
    }

    static func kalmanBaseProcessNoise(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Double {
        let baseNoise: Double

        switch smoothingStrength {
        case 0:
            baseNoise = 4.0
        case 2:
            baseNoise = 1.2
        default:
            baseNoise = 2.2
        }

        return isFastCadence ? baseNoise * 0.8 : baseNoise
    }

    static func kalmanSlopeProcessScale(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Double {
        let baseScale: Double

        switch smoothingStrength {
        case 0:
            baseScale = 0.7
        case 2:
            baseScale = 0.28
        default:
            baseScale = 0.45
        }

        return isFastCadence ? baseScale * 0.85 : baseScale
    }

    static func loessSpan(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool, sampleCount: Int) -> Int {
        let baseSpan: Int

        switch smoothingStrength {
        case 0:
            baseSpan = isFastCadence ? 7 : 5
        case 2:
            baseSpan = isFastCadence ? 11 : 9
        default:
            baseSpan = isFastCadence ? 9 : 7
        }

        let cappedSpan = min(baseSpan, sampleCount)
        return cappedSpan.isMultiple(of: 2) ? max(3, cappedSpan - 1) : max(3, cappedSpan)
    }

    static func loessRobustnessIterations(forSmoothingStrength smoothingStrength: Int) -> Int {
        switch smoothingStrength {
        case 0:
            return 0
        case 2:
            return 2
        default:
            return 1
        }
    }

    static func hampelWindowRadius(forSmoothingStrength smoothingStrength: Int, isFastCadence: Bool) -> Int {
        switch smoothingStrength {
        case 0:
            return isFastCadence ? 3 : 2
        case 2:
            return isFastCadence ? 5 : 4
        default:
            return isFastCadence ? 4 : 3
        }
    }

    static func hampelThresholdScale(forSmoothingStrength smoothingStrength: Int) -> Double {
        switch smoothingStrength {
        case 0:
            return 3.4
        case 2:
            return 2.8
        default:
            return 3.1
        }
    }
}

enum LatestReadingSmoothing {
    enum Mode: String, CaseIterable {
        case off, light, medium, strong

        var isEnabled: Bool { self != .off }

        var correction: (fraction: Double, maximum: Double) {
            switch self {
            case .off: return (0, 0)
            case .light: return (0.25, 4)
            case .medium: return (0.50, 8)
            case .strong: return (0.75, 8)
            }
        }
    }

    struct LiveState: Codable, Equatable {
        let readingID: String
        let smoothedValue: Double?
        var comparisonID: String? = nil
        var comparisonValue: Double? = nil
        var presentedValues: [String: Double] = [:]
    }

    static let stateKey = "latestReadingSmoothingState"
    private static let stateLock = NSLock()
    private static var savedLiveState = UserDefaults.standard.data(forKey: stateKey).flatMap {
        try? JSONDecoder().decode(LiveState.self, from: $0)
    }

    /// Keep the current display decision and its short comparison history outside the readings database.
    static var liveState: LiveState? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return savedLiveState
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            guard savedLiveState != newValue else { return }

            savedLiveState = newValue
            if let newValue, let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: stateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: stateKey)
            }
        }
    }

    struct Sample {
        let date: Date
        let value: Double
    }

    // Allow for small timing variations around the nominal five-minute cadence.
    private static let timingTolerance: TimeInterval = 60
    private static let lookback: TimeInterval = 15 * 60 + timingTolerance
    static let confirmationLookback: TimeInterval = 20 * 60 + timingTolerance
    private static let minimumHistory: TimeInterval = 10 * 60 - timingTolerance
    private static let minimumNoiseBand = 8.0

    /// Uses measurements only. A second departure in the same direction confirms a new level.
    static func value(for current: Sample, previous: [Sample], mode: Mode = .medium) -> Double {
        guard mode.isEnabled, current.value.isFinite, current.value > 0 else { return current.value }

        var samples = [Sample]()
        for sample in previous.reversed() {
            let interval = current.date.timeIntervalSince(sample.date)
            guard interval <= confirmationLookback else { break }
            guard interval > 0, sample.value.isFinite, sample.value > 0,
                  samples.last?.date != sample.date else { continue }
            samples.append(sample)
        }
        samples.reverse()

        if let last = samples.last,
           let previousDeviation = deviation(for: last, samples: Array(samples.dropLast())),
           abs(previousDeviation.residual) > previousDeviation.noiseBand,
           let currentDeviation = deviation(for: current, samples: Array(samples.dropLast()), window: confirmationLookback) {
            if abs(currentDeviation.residual) > currentDeviation.noiseBand,
               currentDeviation.residual.sign == previousDeviation.residual.sign {
                return current.value
            }

            // A previously isolated outlier should not pull the estimate toward itself.
            return correctedValue(current.value, deviation: currentDeviation, mode: mode)
        }

        guard let estimate = deviation(for: current, samples: samples) else { return current.value }
        return correctedValue(current.value, deviation: estimate, mode: mode)
    }

    private static func correctedValue(_ value: Double, deviation: (residual: Double, noiseBand: Double), mode: Mode) -> Double {
        let excess = max(0, abs(deviation.residual) - deviation.noiseBand)
        let (fraction, maximum) = mode.correction
        let correction = min(maximum, excess * fraction)
        return value - (deviation.residual < 0 ? -correction : correction)
    }

    private static func deviation(for current: Sample, samples: [Sample], window: TimeInterval = lookback) -> (residual: Double, noiseBand: Double)? {
        let samples = samples.filter { current.date.timeIntervalSince($0.date) <= window }
        guard samples.count >= 3, let first = samples.first, let last = samples.last,
              last.date.timeIntervalSince(first.date) >= minimumHistory else { return nil }

        let gaps = zip(samples, samples.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
        let cadence = median(gaps)
        guard cadence > 0, current.date.timeIntervalSince(last.date) <= 2 * cadence,
              gaps.allSatisfy({ $0 <= 2 * cadence }) else { return nil }

        var slopes = [Double]()
        for (index, sample) in samples.enumerated() {
            for later in samples.dropFirst(index + 1) {
                slopes.append((later.value - sample.value) / later.date.timeIntervalSince(sample.date))
            }
        }

        let slope = median(slopes)
        let projections = samples.map { $0.value + slope * current.date.timeIntervalSince($0.date) }
        let prediction = median(projections)
        let deviation = median(projections.map { abs($0 - prediction) })
        return (current.value - prediction, max(minimumNoiseBand, 3 * 1.4826 * deviation))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return (sorted[(sorted.count - 1) / 2] + sorted[sorted.count / 2]) / 2
    }
}
