//Application level constants
import Foundation

struct Constants {
    
    enum BloodGlucose {
        static let mmollToMgdl = 18.01801801801802
        static let mgDlToMmoll = 0.0555
    }
    
    enum BGGraphBuilder {
        static let maxSlopeInMinutes = 21
        static let defaultLowMarkInMgdl = 70.0
        static let defaultHighMmarkInMgdl = 170.0
    }
    
    enum CalibrationAlgorithms {
        // age adjustment constants, only for non Libre
        static let ageAdjustmentTime = 86400000 * 1.9
        static let ageAdjustmentFactor = 0.45
        
        // minimum and maxium values for a reading
        static let minimumBgReadingCalculatedValue = 39.0
        static let maximumBgReadingCalculatedValue = 400.0
        static let bgReadingErrorValue = 38.0
    }
    
    /// for use in OSLog
    enum Log {
        /// for use in OSLog
        static let subSystem = "net.johandegraeve.beatit"
        /// for use in OSLog
        static let categoryBlueTooth = "bluetooth"
        /// for use in cgm transmitter miaomiao
        static let categoryCGMMiaoMiao = "cgmmiaomiao"
        /// for use in cgm xdripg4
        static let categoryCGMxDripG4 = "cgmxdripg4"
        /// for use in firstview
        static let categoryFirstView = "firstview"
        /// calibration
        static let calibration = "Calibration"
        /// debuglogging
        static let debuglogging = "xdripdebuglogging"
        // G5
        static let categoryCGMG5 = "categoryCGMG5"
        // GNSEntry
        static let categoryCGMGNSEntry = "categoryCGMGNSEntry"
        // core data manager
        static let categoryCoreDataManager = "categoryCoreDataManager"
    }
    
    // identifiers for local notifications
    enum NotificationIdentifiers {
        /// for initial calibration
        static let initialCalibrationRequest = "InititalCalibrationRequest"
    }
    
    enum Libre {
        static let libreMultiplier = 117.64705
    }
    
    enum DexcomG5 {
        static let batteryReadPeriodInHours = 12.0
    }
    
    enum CoreData {
        static let modelName = "xdrip"
    }
    
}
