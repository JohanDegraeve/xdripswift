//Application level constants
import Foundation

struct Constants {
    
    enum BloodGlucose {
        static let mmollToMgdl = 18.01801801801802
        static let mgDlToMmoll = 0.0555
        static let libreMultiplier = 117.64705
    }
    
    enum BGGraphBuilder {
        static let maxSlopeInMinutes = 21
        static let defaultLowMarkInMgdl = 70.0
        static let defaultHighMmarkInMgdl = 170.0
    }
    
    /// constants used in calibration algorithm
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
        // application data bgreadings
        static let categoryApplicationDataBgReadings = "categoryApplicationDataBgReadings"
        // application data calibrations
        static let categoryApplicationDataCalibrations = "categoryApplicationDataCalibrations"
        // application data sensors
        static let categoryApplicationDataSensors = "categoryApplicationDataSensors"
        // application data alerttypes
        static let categoryApplicationDataAlertTypes = "categoryApplicationDataAlertTypes"
        // application data alertentries
        static let categoryApplicationDataAlertEntries = "categoryApplicationDataAlertEntries"
        // nightscout uploader
        static let categoryNightScoutUploader = "categoryNightScoutUploader"
        // alertmanager
        static let categoryAlertManager = "categoryAlertManager"
        // playsound
        static let categoryPlaySound = "categoryPlaySound"
    }
    
    enum Notifications {
        /// identifiers for alert notifications
        enum NotificationIdentifiersForAlerts {
            /// for initial calibration
            static let initialCalibrationRequest = "InititalCalibrationRequest"
            /// subsequent calibration request
            static let subsequentCalibrationRequest = "SubsequentCalibrationRequest"
            /// high alert
            static let highAlert = "highAlert"
            /// low alert
            static let lowAlert = "lowAlert"
            /// very high alert
            static let veryHighAlert = "veryHighAlert"
            /// very low alert
            static let veryLowAlert = "veryLowAlert"
            /// missed reading alert
            static let missedReadingAlert = "missedReadingAlert"
            /// battery low
            static let batteryLow = "batteryLow"
        }
        
        /// identifiers for alert categories
        enum CategoryIdentifiersForAlerts {
            /// for initial calibration
            static let initialCalibrationRequest = "InititalCalibrationRequest"
            /// subsequent calibration request
            static let subsequentCalibrationRequest = "SubsequentCalibrationRequest"
            /// high alert
            static let highAlert = "highAlert"
            /// low alert
            static let lowAlert = "lowAlert"
            /// very high alert
            static let veryHighAlert = "veryHighAlert"
            /// very low alert
            static let veryLowAlert = "veryLowAlert"
            /// missed reading alert
            static let missedReadingAlert = "missedReadingAlert"
            /// battery low
            static let batteryLow = "batteryLow"
        }
    }
    
    /// dexcom G5 specific constants
    enum DexcomG5 {
        /// how often to read battery level
        static let batteryReadPeriodInHours = 12.0
    }
    
    /// default alert levels to be used when creating defalt alert entries
    enum DefaultAlertLevels {
        // default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
        static let defaultBatteryAlertLevelDexcomG5 = 300
        static let defaultBatteryAlertLevelDexcomG4 = 210
        static let defaultBatteryAlertLevelMiaoMiao = 20
        static let defaultBatteryAlertLevelGNSEntry = 20
        
        // blood glucose level alert values in mgdl
        static let veryHigh = 250
        static let veryLow = 50
        static let high = 170
        static let low = 70
        
        // in minutes, after how many minutes of now reading should alert be raised
        static let missedReading = 30
        
        // in hours, after how many hours alert to request a new calibration
        static let calibration = 24
    }
    
    /// coredata specific constants
    enum CoreData {
        static let modelName = "xdrip"
    }
    
    /// defines name of the Soundfile and name of the sound shown to the user with an extra function - both are defined in one case, seperated by a backslash
    enum Sounds: String, CaseIterable {
        // here using case iso properties because we want to iterate through them
        /// name of the sound as shown to the user, and also stored in the alerttype
        case batterwakeup = "Better Wake Up/betterwakeup.mp3"
        case bruteforce = "Brute Force/bruteforce.mp3"
        case modernalarm2 = "Modern Alarm 2/modern2.mp3"
        case modernalarm = "Modern Alarm/modernalarm.mp3"
        case shorthigh1 = "Short High 1/shorthigh1.mp3"
        case shorthigh2 = "Short High 2/shorthigh2.mp3"
        case shorthigh3 = "Short High 3/shorthigh3.mp3"
        case shorthigh4 = "Short High 4/shorthigh4.mp3"
        case shortlow1  = "Short Low 1/shortlow1.mp3"
        case shortlow2  = "Short Low 2/shortlow2.mp3"
        case shortlow3  = "Short Low 3/shortlow3.mp3"
        case shortlow4  = "Short Low 4/shortlow4.mp3"
        case spaceship = "Space Ship/spaceship.mp3"
        case xdripalert = "xDrip Alert/xdripalert.aif"
    }
}
