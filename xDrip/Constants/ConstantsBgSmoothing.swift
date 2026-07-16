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

    var description: String {
        switch self {
        case .savitzkyGolay:
            return Texts_HomeView.postProcessingAlgorithmSavitzkyGolay
        case .exponential:
            return Texts_HomeView.postProcessingAlgorithmExponential
        case .kalman:
            return Texts_HomeView.postProcessingAlgorithmKalman
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
        }
    }

    var plugin: BgSmoothingAlgorithmPlugin {
        switch self {
        case .savitzkyGolay:
            return SavitzkyGolayBgSmoothing()
        case .exponential:
            return ExponentialBgSmoothing()
        case .kalman:
            return KalmanBgSmoothing()
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
}
