//Application level constants
import Foundation

struct Constants {
    
    private init() {}
    
    struct BloodGlucose {

        private init() {}

        static let mmollToMgdl = 18.01801801801802
        static let mgDlToMmoll = 0.0555
    }
    
    struct BGGraphBuilder {

        private init() {}

        static let maxSlopeInMinutes = 21
    }
    
    struct BgReadingAlgorithms {

        private init() {}

        static let ageAdjustmentTime = 86400000 * 1.9
        static let ageAdjustmentFactor = 0.45
    }
    
    struct CalibrationAlgorithms {

        private init() {}

        static let dexParameters = SlopeParameters(LOW_SLOPE_1: 0.95, LOW_SLOPE_2: 0.85, HIGH_SLOPE_1: 1.3, HIGH_SLOPE_2: 0.85, DEFAULT_LOW_SLOPE_LOW: 1.08, DEFAULT_LOW_SLOPE_HIGH: 1.15, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.3, DEFAUL_HIGH_SLOPE_LOW: 1.2)
        
        static let liParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)

    }
       
    /// for use in OSLog
    struct Log {
        private init() {}

        /// for use in OSLog
        static let subSystem = "net.johandegraeve.beatit"
        /// for use in OSLog
        static let categoryBlueTooth = "bluetooth"
        
        static let categoryCGMMiaoMiao = "cgmmiaomiao"
    }
}
