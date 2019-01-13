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
        // age adjustment constants, only for non Libre
        static let ageAdjustmentTime = 86400000 * 1.9
        static let ageAdjustmentFactor = 0.45
        
        // minimum and maxium values for a reading
        static let minimumBgReadingCalculatedValue = 39.0
        static let maximumBgReadingCalculatedValue = 400.0
        static let bgReadingErrorValue = 38.0
    }
    
    struct CalibrationAlgorithms {
        static let dexParameters = SlopeParameters(LOW_SLOPE_1: 0.95, LOW_SLOPE_2: 0.85, HIGH_SLOPE_1: 1.3, HIGH_SLOPE_2: 0.85, DEFAULT_LOW_SLOPE_LOW: 1.08, DEFAULT_LOW_SLOPE_HIGH: 1.15, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.3, DEFAUL_HIGH_SLOPE_LOW: 1.2)
        
        static let liParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)
    }
       
    /// for use in OSLog
    struct Log {
        /// for use in OSLog
        static let subSystem = "net.johandegraeve.beatit"
        /// for use in OSLog
        static let categoryBlueTooth = "bluetooth"
        /// for use in cgm transmitter
        static let categoryCGMMiaoMiao = "cgmmiaomiao"
        /// for use in firstview
        static let categoryFirstView = "firstview"
        /// calibration
        static let calibration = "Calibration"
    }
    
    // identifiers for local notifications
    struct NotificationIdentifiers {
        /// for initial calibration
        static let initialCalibrationRequest = "InititalCalibrationRequest"
    }
    
    struct Libre {
        static let libreMultiplier = 117.64705
    }
}
