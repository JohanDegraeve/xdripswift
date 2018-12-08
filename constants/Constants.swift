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
}
