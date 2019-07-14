//Application level constants
import Foundation

struct Constants {
    
    enum BGGraphBuilder {
        static let maxSlopeInMinutes = 21
        static let defaultLowMarkInMgdl = 70.0
        static let defaultHighMmarkInMgdl = 170.0
    }
    
    enum BloodGlucose {
        static let mmollToMgdl = 18.01801801801802
        static let mgDlToMmoll = 0.0555
        static let libreMultiplier = 117.64705
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
    
    /// coredata specific constants
    enum CoreData {
        static let modelName = "xdrip"
    }
    
    /// default alert levels to be used when creating defalt alert entries
    enum DefaultAlertLevels {
        // default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
        static let defaultBatteryAlertLevelDexcomG5 = 300
        static let defaultBatteryAlertLevelDexcomG4 = 210
        static let defaultBatteryAlertLevelMiaoMiao = 20
        static let defaultBatteryAlertLevelGNSEntry = 20
        static let defaultBatteryAlertLevelBlucon = 20
        
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
    
    /// dexcom G5 specific constants
    enum DexcomG5 {
        /// how often to read battery level
        static let batteryReadPeriodInHours = 12.0
        
        /// in case transmitter needs pairing, how long to keep connection up to give time to the user to accept the pairing request, inclusive opening the notification
        static let maxTimeToAcceptPairingInSeconds = 60
    }

    /// for use in OSLog
    enum Log {
        /// for use in OSLog
        static let subSystem = "xDrip"
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
        /// G5
        static let categoryCGMG5 = "categoryCGMG5"
        /// GNSEntry
        static let categoryCGMGNSEntry = "categoryCGMGNSEntry"
        /// Blucon
        static let categoryBlucon = "categoryBlucon"
        /// core data manager
        static let categoryCoreDataManager = "categoryCoreDataManager"
        /// application data bgreadings
        static let categoryApplicationDataBgReadings = "categoryApplicationDataBgReadings"
        /// application data calibrations
        static let categoryApplicationDataCalibrations = "categoryApplicationDataCalibrations"
        /// application data sensors
        static let categoryApplicationDataSensors = "categoryApplicationDataSensors"
        /// application data alerttypes
        static let categoryApplicationDataAlertTypes = "categoryApplicationDataAlertTypes"
        /// application data alertentries
        static let categoryApplicationDataAlertEntries = "categoryApplicationDataAlertEntries"
        /// nightscout uploader
        static let categoryNightScoutUploadManager = "categoryNightScoutUploadManager"
        /// nightscout follow
        static let categoryNightScoutFollowManager = "categoryNightScoutFollowManager"
        /// alertmanager
        static let categoryAlertManager = "categoryAlertManager"
        /// playsound
        static let categoryPlaySound = "categoryPlaySound"
        /// healthkit manager
        static let categoryHealthKitManager = "categoryHealthKitManager"
        /// SettingsViewHealthKitSettingsViewModel
        static let categorySettingsViewHealthKitSettingsViewModel = "categorySettingsViewHealthKitSettingsViewModel"
        /// dexcom share upload manager
        static let categoryDexcomShareUploadManager = "categoryDexcomShareUploadManager"
    }
    
    enum Notifications {
        
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

        /// identifiers for alert notifications
        enum NotificationIdentifiersForAlerts {
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
        
        /// identifiers for calibration requests
        enum NotificationIdentifiersForCalibration {
            /// for initial calibration
            static let initialCalibrationRequest = "initialCalibrationRequest"
            /// subsequent calibration request
            static let subsequentCalibrationRequest = "subsequentCalibrationRequest"
        }
        
        enum NotificationIdentifierForBgReading {
            /// bgreading notification
            static let bgReadingNotificationRequest = "bgReadingNotificationRequest"
        }
        
        enum NotificationIdentifierForSensorNotDetected {
            /// sensor not detected notification
            static let sensorNotDetected = "sensorNotDetected"
        }
        
        enum NotificationIdentifierForTransmitterNeedsPairing {
            /// transmitter needs pairing
            static let transmitterNeedsPairing = "transmitterNeedsPairing"
        }

        enum NotificationIdentifierForResetResult {
            /// transmitter reset result
            static let transmitterResetResult = "transmitterResetResult"
        }
    }
    
    /// defines name of the Soundfile and name of the sound shown to the user with an extra function - both are defined in one case, seperated by a backslash - to be used for alerts - all these sounds will be shown
    enum Sounds: String, CaseIterable {
        
        // here using case iso properties because we want to iterate through them
        /// name of the sound as shown to the user, and also stored in the alerttype
        case batterwakeup = "Better Wake Up/betterwakeup.mp3"
        case bruteforce = "Brute Force/bruteforce.mp3"
        case modernalarm2 = "Modern Alert 2/modern2.mp3"
        case modernalarm = "Modern Alert/modernalarm.mp3"
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
        
        /// gets all sound names in array, ie part of the case before the /
        static func allSoundsBySoundNameAndFileName() -> (soundNames:[String], fileNames:[String]) {
            var soundNames = [String]()
            var soundFileNames = [String]()

            soundloop: for sound in Constants.Sounds.allCases {
                
                // Constants.Sounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash
                // get array of indexes, of location of "/"
                let indexOfBackSlash = sound.rawValue.indexes(of: "/")
                
                // define range to get the soundname (as shown in UI)
                let soundNameRange = sound.rawValue.startIndex..<indexOfBackSlash[0]
                
                // now get the soundName in a string
                let soundName = String(sound.rawValue[soundNameRange])
                
                // add the soundName to the returnvalue
                soundNames.append(soundName)
                
                // define range to get the soundFileName
                let languageCodeRange = sound.rawValue.index(after: indexOfBackSlash[0])..<sound.rawValue.endIndex
                
                // now get the language in a string
                let fileName = String(sound.rawValue[languageCodeRange])
                // add the languageCode to the returnvalue
                
                soundFileNames.append(fileName)

            }
            return (soundNames, soundFileNames)
        }
        
        /// gets the soundname for specific case
        static func getSoundName(forSound:Sounds) -> String {
            let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
            let soundNameRange = forSound.rawValue.startIndex..<indexOfBackSlash[0]
            return String(forSound.rawValue[soundNameRange])
        }
        
        /// gets the soundFie for specific case
        static func getSoundFile(forSound:Sounds) -> String {
            let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
            let soundNameRange = forSound.rawValue.index(after: indexOfBackSlash[0])..<forSound.rawValue.endIndex
            return String(forSound.rawValue[soundNameRange])
        }
    }
    
    /// default values to be used when creating a new AlertType
    enum DefaultAlertTypeSettings {
        
        static let enabled = true
        static let name = Texts_Common.default0
        static let overrideMute = false
        static let snooze = true
        static let snoozePeriod = Int16(60)
        static let vibrate = true
        static let soundName:String? = nil
    }

    /// constants for home view, ie first view
    enum HomeView {
        
        /// how often to update the labels in the homeview (ie label with latest reading, minutes ago, etc..)
        static let updateHomeViewIntervalInSeconds = 15.0
        
        /// info email adres, appears in licenseInfo
        static let infoEmailAddress = "xdrip@proximus.be"
        
        /// application name, appears in licenseInfo as title
        static let applicationName = "xDrip"
    }
    
    /// constants for follower mode
    enum Follower {
        
        /// maximum days of readings to download
        static let maxiumDaysOfReadingsToDownload = 1
        
        /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
        static let maximumBgReadingAgeForAlertsInSeconds = 240.0
    }
    
    /// constants typically for master mode
    enum Master {
        
        /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
        static let maximumBgReadingAgeForAlertsInSeconds = 60.0
    }
    
    /// suspension prevention
    enum SuspensionPrevention {
        
        /// name of the file that has the sound to play
        static let soundFileName = "1-millisecond-of-silence.mp3"//20ms-of-silence.caf"
        
        /// how often to play the sound, in seconds
        static let interval = 5
    }
    
    /// supported languages for speak readings - defines name and language code, example "Dutch" and "nl-NL", both are defined in one case, seperated by a backslash
    ///
    /// alphabetically ordered
    enum SpeakReadingLanguages: String, CaseIterable {
        
        case chinese = "Chinese/zh"
        case dutch = "Dutch/nl"
        case english = "English/en"
        case french = "French/fr"
        case italian = "Italian/it"
        case polish = "Polish/pl-PL"
        case portugese_portugal = "Portuguese/pt"
        case portugese_brasil = "Portuguese (Brazil)/pt-BR"
        case russian = "Russian/ru"
        case slovenian = "Slovenian/sl"
        case spanish_mexico = "Spanish (Mexico)/es-MX"
        case spanish_spain = "Spanish (Spain)/es-ES"
        
        /// gets all language names and language codes in two arrays
        /// - returns:
        ///     ie part of the case before the / in the first array, part of the case after the / in the second array
        public static var allLanguageNamesAndCodes: (names:[String], codes:[String]) {
            var languageNames = [String]()
            var languageCodes = [String]()
            
            languageloop: for speakReadingLanguage in Constants.SpeakReadingLanguages.allCases {
                
                // SpeakReadingLanguages defines available languages. Per case there is a string which is the language as shown in the UI and the language code, seperated by backslash
                // get array of indexes, of location of "/"
                let indexOfBackSlash = speakReadingLanguage.rawValue.indexes(of: "/")
                
                // define range to get the language (as shown in UI)
                let languageNameRange = speakReadingLanguage.rawValue.startIndex..<indexOfBackSlash[0]
                
                // now get the language in a string
                let language = String(speakReadingLanguage.rawValue[languageNameRange])
                
                // add the soundName to the returnvalue
                languageNames.append(language)
                
                // define range to get the languagecode
                let languageCodeRange = speakReadingLanguage.rawValue.index(after: indexOfBackSlash[0])..<speakReadingLanguage.rawValue.endIndex
                
                // now get the language in a string
                let languageCode = String(speakReadingLanguage.rawValue[languageCodeRange])
                // add the languageCode to the returnvalue
                
                languageCodes.append(languageCode)
                
            }
            return (languageNames, languageCodes)
        }
        
        /// gets the language name for specific case
        static func languageName(forLanguageCode:String?) -> String {
            
            if let forLanguageCode = forLanguageCode {
                for (index, languageCode) in allLanguageNamesAndCodes.codes.enumerated() {
                    if languageCode == forLanguageCode {
                        return allLanguageNamesAndCodes.names[index]
                    }
                }
            }
            return Texts_SpeakReading.defaultLanguageCode
        }

    }
    
    /// constants for Dexcom Share
    enum DexcomShare {
        
        /// applicationId to use in Dexcom Share protocol
        static let applicationId = "d8665ade-9673-4e27-9ff6-92db4ce13d13"
        
        /// us share base url
        static let usBaseShareUrl = "https://share2.dexcom.com/ShareWebServices/Services"
        
        /// non us share base url
        static let nonUsBaseShareUrl = "https://shareous1.dexcom.com/ShareWebServices/Services"
        
    }
    
    /// constants related to Bluetooth pairing
    enum BluetoothPairing {
        
        /// minimum time in seconds between two pairing notifications
        static let minimumTimeBetweenTwoPairingNotificationsInSeconds = 30
        
    }
}
