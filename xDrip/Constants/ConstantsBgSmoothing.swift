import Foundation

enum ConstantsBgSmoothing {
    
    /// default smoothing period in minutes
    static let defaultSmoothingPeriodInMinutes = 30
    
    /// default smoothing strength
    static let defaultSmoothingStrength = 1
    
    /// minimum number of readings needed before smoothing can be applied
    static let minimumReadingsForSmoothing = 5
    
    /// once two glucose readings are further apart than the normal continuity
    /// limit, smoothing should stop at the gap instead of blending across it
    static let maximumGapBetweenReadingsInMinutes = ConstantsBGGraphBuilder.maxSlopeInMinutes

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
}
