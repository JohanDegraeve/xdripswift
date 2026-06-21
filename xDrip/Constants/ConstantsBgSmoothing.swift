import Foundation

enum ConstantsBgSmoothing {
    
    /// default smoothing period in minutes
    static let defaultSmoothingPeriodInMinutes = 30

    /// default smoothing strength
    static let defaultSmoothingStrength = 1

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
}
