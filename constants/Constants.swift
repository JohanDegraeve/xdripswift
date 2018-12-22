//Application level constants
import Foundation

struct Constants {
    struct BloodGlucose {
        static let mmollToMgdl = 18.01801801801802
        static let mgDlToMmoll = 0.0555
    }
    
    struct BGGraphBuilder {
        static let maxSlopeInMinutes = 21
    }
    
    struct BgReadingAlgorithms {
        static let ageAdjustmentTime = 86400000 * 1.9
        static let ageAdjustmentFactor = 0.45
    }
    
    struct CalibrationAlgorithms {
        static let dexParameters = SlopeParameters(LOW_SLOPE_1: 0.95, LOW_SLOPE_2: 0.85, HIGH_SLOPE_1: 1.3, HIGH_SLOPE_2: 0.85, DEFAULT_LOW_SLOPE_LOW: 1.08, DEFAULT_LOW_SLOPE_HIGH: 1.15, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.3, DEFAUL_HIGH_SLOPE_LOW: 1.2)
        
        static let liParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)

    }
}
