import Foundation

extension UserDefaults {
    
    /// shared user defaults
    private static let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    /// common function to be called if user default needs to be stored in shared user defaults
    public static func storeInSharedUserDefaults(value: Any, forKey key: String) {
        
        // setting to be stored also in shared userdefaults because it's used by the today widget
        if let sharedUserDefaults = sharedUserDefaults {
            sharedUserDefaults.set(value, forKey: key)
        }
        
    }

    /// keys for settings and user defaults. For reading and writing settings, the keys should not be used, the specific functions kan be used.
    public enum Key: String {
        // User configurable Settings
        
        // General
        
        /// bloodglucose  unit
        case bloodGlucoseUnitIsMgDl = "bloodGlucoseUnit"
        /// urgent high value
        case isMaster = "isMaster"
        /// should notification be shown with reading yes or no
        case showReadingInNotification = "showReadingInNotification"
        /// should readings be shown in app badge yes or no
        case showReadingInAppBadge = "showReadingInAppBadge"
        /// should reading by multiplied by 10
        case multipleAppBadgeValueWith10 = "multipleAppBadgeValueWith10"
        
        // Home Screen and graph settings
        
        /// show the objectives and make them display on the graph? Or just hide it all because it's too complicated to waste time with?
        case useObjectives = "useObjectives"
        /// show the objective lines in color or grey?
        case urgentHighMarkValue = "urgentHighMarkValue"
        /// high value
        case highMarkValue = "highMarkValue"
        /// low value
        case lowMarkValue = "lowMarkValue"
        /// urgent low value
        case urgentLowMarkValue = "urgentLowMarkValue"
        /// master or follower
        case showColoredObjectives = "showColoredObjectives"
        /// show the target line or hide it?
        case showTarget = "showTarget"
        /// target value
        case targetMarkValue = "targetMarkValue"
        
        // Transmitter
        
        /// transmitter type
        case transmitterTypeAsString = "transmitterTypeAsString"

        // Nightscout
        
        /// should readings be uploaded to nightscout
        case nightScoutEnabled = "nightScoutEnabled"
        /// should schedule be used for nightscout upload ?
        case nightScoutUseSchedule = "nightScoutUseSchedule"
        /// - schedule for nightscout use, only applicable if nightScoutUseSchedule = true
        /// - string of values, seperate by '-', values are int values and represent minutes
        case nightScoutSchedule = "nightScoutSchedule"
        /// nightscout url
        case nightScoutUrl = "nightScoutUrl"
        /// nightscout api key
        case nightScoutAPIKey = "nightScoutAPIKey"
        /// send sensor start time to nightscout ?
        case uploadSensorStartTimeToNS = "uploadSensorStartTimeToNS"
        /// port number to use, 0 means not set
        case nightScoutPort = "nightScoutPort"
        
        // Dexcom Share
        
        /// should readings be uploaded to Dexcom share
        case uploadReadingstoDexcomShare = "uploadReadingstoDexcomShare"
        /// dexcom share account name
        case dexcomShareAccountName = "dexcomShareAccountName"
        /// dexcom share password
        case dexcomSharePassword = "dexcomSharePassword"
        /// use US dexcomshare url true or false
        case useUSDexcomShareurl = "useUSDexcomShareurl"
        /// dexcom share serial number
        case dexcomShareSerialNumber = "dexcomShareSerialNumber"
        /// should schedule be used for dexcom share upload ?
        case dexcomShareUseSchedule = "dexcomShareUseSchedule"
        /// - schedule for dexcomShare use, only applicable if dexcomShareUseSchedule = true
        /// - string of values, seperate by '-', values are int values and represent minutes
        case dexcomShareSchedule = "dexcomShareSchedule"

        // Healthkit
        
        /// should readings be stored in healthkit, true or false
        case storeReadingsInHealthkit = "storeReadingsInHealthkit"
        
        // Speak readings
        
        /// speak readings
        case speakReadings = "speakReadings"
        /// speak reading language
        case speakReadingLanguageCode = "speakReadingLanguageCode"
        /// speak delta
        case speakDelta = "speakDelta"
        /// speak trend
        case speakTrend = "speakTrend"
        /// speak interval
        case speakInterval = "speakInterval"
        
        // Settings that Keep track of alert and info messages shown to the user ======
        
        /// message shown when user starts a sensor, which tells that timing should be exact, was it already shown or not
        case startSensorTimeInfoGiven = "startSensorTimeInfoGiven"
        
        /// license info accepted by user yes or no
        case licenseInfoAccepted = "licenseInfoAccepted"
        
        // M5Stack
        
        /// M5Stack blepassword, needed for authenticating App to M5Stack
        case m5StackBlePassword = "M5StackBlePassword"
        
        /// M5Stack text color
        case m5StackTextColor = "m5StackTextColor"
        
        /// M5Stack background color
        case m5StackBackGroundColor = "m5StackBackGroundColor"
        
        /// name of wifi 1 to be configured in M5Stack
        case m5StackWiFiName1 = "m5StackWiFiName1"
        
        /// name of wifi 2 to be configured in M5Stack
        case m5StackWiFiName2 = "m5StackWiFiName2"
        
        /// name of wifi 3 to be configured in M5Stack
        case m5StackWiFiName3 = "m5StackWiFiName3"
        
        /// Password of wifi 1 to be configured in M5Stack
        case m5StackWiFiPassword1 = "m5StackWiFiPassword1"
        
        /// Password of wifi 2 to be configured in M5Stack
        case m5StackWiFiPassword2 = "m5StackWiFiPassword2"
        
        /// Password of wifi 3 to be configured in M5Stack
        case m5StackWiFiPassword3 = "m5StackWiFiPassword3"
        
        // Apple Watch
        
        /// create calendar event yes or no
        case createCalendarEvent = "createCalendarEvent"
        
        /// selected calender id (name of the calendar) in which the event should be created
        case calenderId = "calenderId"
        
        /// should trend be displayed yes or no
        case displayTrendInCalendarEvent = "displayTrend"
        
        /// should delta be displayed yes or no
        case displayDeltaInCalendarEvent = "displayDelta"
        
        /// should units be displayed yes or no
        case displayUnitInCalendarEvent = "displayUnits"
        
        // Other Settings (not user configurable)
        
        /// - in case missed reading alert settings are changed by user, this value will be set to true
        /// - alertmanager will observe that value and when changed, verify if missed reading alert needs to be changed
        case missedReadingAlertChanged = "missedReadingAlertChanged"
        
        /// when was the app launched, used in trace info that is sent via email. Just to be able to see afterwards if the app ever crashed. Because sometimes users say it crashed, but maybe it just stopped receiving readings and restarted by opening the app, but didn't really crash
        case timeStampAppLaunch = "timeStampAppLaunch"
        
        // Nightscout
        /// timestamp lastest reading uploaded to NightScout
        case timeStampLatestNSUploadedBgReadingToNightScout = "timeStampLatestUploadedBgReading"
        
        /// timestamp latest calibration uploaded to NightScout
        case timeStampLatestNSUploadedCalibrationToNightScout = "timeStampLatestUploadedCalibration"
        
        // Transmitter
        /// Transmitter Battery Level
        case transmitterBatteryInfo = "transmitterbatteryinfo"
        
        /// timestamp last battery reading (will only be used for dexcom G5 where we need to explicitly ask for the battery)
        case timeStampOfLastBatteryReading = "timeStampOfLastBatteryReading"
        
        // HealthKit
        /// did user authorize the storage of readings in healthkit or not
        case storeReadingsInHealthkitAuthorized = "storeReadingsInHealthkitAuthorized"
        
        /// timestamp of last bgreading that was stored in healthkit
        case timeStampLatestHealthKitStoreBgReading = "timeStampLatestHealthKitStoreBgReading"
        
        // Dexcom Share
        /// timestamp of latest reading uploaded to Dexcom Share
        case timeStampLatestDexcomShareUploadedBgReading = "timeStampLatestDexcomShareUploadedBgReading"
        
        // Loop
        /// dictionary representation of readings that were shared  with Loop. This is not the json representation, it's an array of dictionary
        case readingsStoredInSharedUserDefaultsAsDictionary = "readingsStoredInSharedUserDefaultsAsDictionary"
            
        /// timestamp lastest reading shared with Loop
        case timeStampLatestLoopSharedBgReading = "timeStampLatestLoopSharedBgReading"
            
        // Trace
        /// should debug level logs be added in trace file or not, and also in NSLog
        case addDebugLevelLogsInTraceFileAndNSLog = "addDebugLevelLogsInTraceFileAndNSLog"
        
        // non fixed slope values for oop web Libre
        /// web oop parameters, only for bubble, miaomiao and Libre 2
        case libre1DerivedAlgorithmParameters = "algorithmParameters"

        // development settings
        
        /// G6 factor1 - for testing G6 scaling
        case G6v2ScalingFactor1 = "G6v2ScalingFactor1"

        /// G6 factor2 - for testing G6 scaling
        case G6v2ScalingFactor2 = "G6v2ScalingFactor2"
        
        /// NSLog enabled or not
        case NSLogEnabled = "NSLogEnabled"
                
        /// OSLogEnabled enabled or not
        case OSLogEnabled = "OSLogEnabled"
        
        /// if webOOP enabled, what site to use
        case webOOPsite = "webOOPsite"
        /// if webOOP enabled, value of the token
        case webOOPtoken = "webOOPtoken"
        
        /// case smooth libre values
        case smoothLibreValues = "smoothLibreValues"
        
        /// used for Libre data parsing - only for Libre 1 or Libre 2 read via transmitter, ie full NFC block
        case previousRawLibreValues = "previousRawLibreValues"
        
        /// used for storing data read with Libre 2 direct
        case previousRawGlucoseValues = "previousRawGlucoseValues"
        
        /// used for storing data read with Libre 2 direct
        case previousRawTemperatureValues = "previousRawTemperatureValues"
        
        /// used for storing data read with Libre 2 direct
        case previousTemperatureAdjustmentValues = "previousTemperatureAdjustmentValues"
        
        /// in case Libre 2 users want to use the local calibration algorithm
        case overrideWebOOPCalibration = "overrideWebOOPCalibration"
        
        /// to merge from 3.x to 4.x, can be deleted once 3.x is not used anymore
        case cgmTransmitterDeviceAddress = "cgmTransmitterDeviceAddress"
        
        
        // Libre
        /// Libre unlock code
        case libreActiveSensorUnlockCode = "activeSensorUnlockCode"
        
        /// Libre Unlock count
        case libreActiveSensorUnlockCount = "activeSensorUnlockCount"
        
        /// - Libre sensor id - used in Libre 2 setup - should be read first eg via bubble or mm and then used in Libre 2 communication
        /// - stored as data as read from transmitter
        case libreSensorUID = "libreSensorUID"
        
        
        /// - Libre patch info - used in Libre 2 setup - should be read first eg via bubble or mm and then used in Libre 2 communication
        /// - stored as data as read from transmitter
        case librePatchInfo = "librePatchInfo"
        
    }
    
    // MARK: - =====  User Configurable Settings ======
    
    // MARK: General
    
    /// true if unit is mgdl, false if mmol is used
    @objc dynamic var bloodGlucoseUnitIsMgDl: Bool {
        //default value for bool in userdefaults is false, false is for mgdl, true is for mmol
        get {
            return !bool(forKey: Key.bloodGlucoseUnitIsMgDl.rawValue)
        }
        set {
            set(!newValue, forKey: Key.bloodGlucoseUnitIsMgDl.rawValue)

            // setting to be stored also in shared userdefaults because it's used by the today widget
            UserDefaults.storeInSharedUserDefaults(value: !newValue, forKey: Key.bloodGlucoseUnitIsMgDl.rawValue)
            
        }
    }
    
    /// true if device is master, false if follower
    @objc dynamic var isMaster: Bool {
        // default value for bool in userdefaults is false, false is for master, true is for follower
        get {
            return !bool(forKey: Key.isMaster.rawValue)
        }
        set {
            set(!newValue, forKey: Key.isMaster.rawValue)
        }
    }
    
    /// should notification be shown with reading yes or no
    @objc dynamic var showReadingInNotification: Bool {
        // default value for bool in userdefaults is false, as default we want readings to be shown
        get {
            return !bool(forKey: Key.showReadingInNotification.rawValue)
        }
        set {
            set(!newValue, forKey: Key.showReadingInNotification.rawValue)
        }
    }

    /// should reading be shown in app badge yes or no
    @objc dynamic var showReadingInAppBadge: Bool {
        // default value for bool in userdefaults is false, as default we want readings not to be shown in app badge
        get {
            return bool(forKey: Key.showReadingInAppBadge.rawValue)
        }
        set {
            set(newValue, forKey: Key.showReadingInAppBadge.rawValue)
        }
    }
    
    /// should reading be multiplied by 10 or not
    @objc dynamic var multipleAppBadgeValueWith10: Bool {
        // default value for bool in userdefaults is false, as default we want readings not to be multiplied by 10
        get {
            return !bool(forKey: Key.multipleAppBadgeValueWith10.rawValue)
        }
        set {
            set(!newValue, forKey: Key.multipleAppBadgeValueWith10.rawValue)
        }
    }
    
    // MARK: Home Screen Settings
    
    /// the urgenthighmarkvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var urgentHighMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.urgentHighMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.urgentHighMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            UserDefaults.storeInSharedUserDefaults(value: bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.urgentHighMarkValue.rawValue)

        }
    }
    
    /// the highmarkvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var highMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.highMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultHighMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.highMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            UserDefaults.storeInSharedUserDefaults(value: bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.highMarkValue.rawValue)

        }
    }
    
    /// the targetvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var targetMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.targetMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultTargetMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.targetMarkValue.rawValue)
        }
    }
    
    /// the lowmarkvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var lowMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.lowMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultLowMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.lowMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            UserDefaults.storeInSharedUserDefaults(value: bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.lowMarkValue.rawValue)

        }
    }
    
    /// the urgentlowmarkvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var urgentLowMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.urgentLowMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.urgentLowMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            UserDefaults.storeInSharedUserDefaults(value: bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.urgentLowMarkValue.rawValue)

        }
    }
    
    /// the urgenthighmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    @objc dynamic var urgentHighMarkValueInUserChosenUnitRounded:String {
        get {
            return urgentHighMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.urgentHighMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            if let value = value {
                UserDefaults.storeInSharedUserDefaults(value: value, forKey: Key.urgentHighMarkValue.rawValue)
            }

        }
    }
    
    /// the highmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    @objc dynamic var highMarkValueInUserChosenUnitRounded:String {
        get {
            return highMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.highMarkValue.rawValue)

            // setting to be stored also in shared userdefaults because it's used by the today widget
            if let value = value {
                UserDefaults.storeInSharedUserDefaults(value: value, forKey: Key.highMarkValue.rawValue)
            }

        }
    }
    
    /// the targetmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    @objc dynamic var targetMarkValueInUserChosenUnitRounded:String {
        get {
            return targetMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.targetMarkValue.rawValue)
        }
    }
    
    /// the lowmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    @objc dynamic var lowMarkValueInUserChosenUnitRounded:String {
        get {
            return lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.lowMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            if let value = value {
                UserDefaults.storeInSharedUserDefaults(value: value, forKey: Key.lowMarkValue.rawValue)
            }

        }
    }
    
    /// the urgentlowmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    @objc dynamic var urgentLowMarkValueInUserChosenUnitRounded:String {
        get {
            return urgentLowMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.urgentLowMarkValue.rawValue)
            
            // setting to be stored also in shared userdefaults because it's used by the today widget
            if let value = value {
                UserDefaults.storeInSharedUserDefaults(value: value, forKey: Key.urgentLowMarkValue.rawValue)
            }

        }
    }
    
    /// should we use objectives for the BG values and graph lines etc?
    @objc dynamic var useObjectives: Bool {
        // default value for bool in userdefaults is false, by default we want the objective-based graph to be disabled so as not to scare anybody. They can enable it when they have time to understand it.
        get {
            return !bool(forKey: Key.useObjectives.rawValue)
        }
        set {
            set(!newValue, forKey: Key.useObjectives.rawValue)
        }
    }
    
    /// should the Guidelines be shown in color (yellow/red) on the graph?
    @objc dynamic var showColoredObjectives: Bool {
        // default value for bool in userdefaults is false, by default we want the guidelines to be shown in grey as per Nightscout
        get {
            return !bool(forKey: Key.showColoredObjectives.rawValue)
        }
        set {
            set(!newValue, forKey: Key.showColoredObjectives.rawValue)
        }
    }
    
    /// should the target line (always shown in green) be shown on the graph?
    @objc dynamic var showTarget: Bool {
        // default value for bool in userdefaults is false, by default we will hide the target line as it could confuse users
        get {
            return !bool(forKey: Key.showTarget.rawValue)
        }
        set {
            set(!newValue, forKey: Key.showTarget.rawValue)
        }
    }
    
    
    // MARK: Transmitter Settings
    
    /// cgm ransmittertype currently active
    var cgmTransmitterType:CGMTransmitterType? {
        get {
            if let transmitterTypeAsString = cgmTransmitterTypeAsString {
                return CGMTransmitterType(rawValue: transmitterTypeAsString)
            } else {
                return nil
            }
        }
    }
    
    /// transmittertype as String, just to be able to define dynamic dispatch and obj-c visibility
    @objc dynamic var cgmTransmitterTypeAsString:String? {
        get {
            return string(forKey: Key.transmitterTypeAsString.rawValue)
        }
        set {
            // if transmittertype has changed then also reset the transmitter id to nil
            // this is also a check to see if transmitterTypeAsString has really changed, because just calling a set without a new value may cause a transmittertype reset in other parts of the call (inclusive stopping sensor etc.)
            if newValue != string(forKey: Key.transmitterTypeAsString.rawValue) {
                set(newValue, forKey: Key.transmitterTypeAsString.rawValue)
            }
        }
    }
    
    // MARK: Nightscout Share Settings
    
    /// nightscout enabled ? this impacts follower mode (download) and master mode (upload)
    @objc dynamic var nightScoutEnabled: Bool {
        get {
            return bool(forKey: Key.nightScoutEnabled.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutEnabled.rawValue)
        }
    }
    
    /// use schedule for nightscoutupload ?
    @objc dynamic var nightScoutUseSchedule: Bool {
        get {
            return bool(forKey: Key.nightScoutUseSchedule.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutUseSchedule.rawValue)
        }
    }

    /// send sensor start time to nightscout ?
    @objc dynamic var uploadSensorStartTimeToNS: Bool {
        get {
            return bool(forKey: Key.uploadSensorStartTimeToNS.rawValue)
        }
        set {
            set(newValue, forKey: Key.uploadSensorStartTimeToNS.rawValue)
        }
    }
    
    /// Nightscout port number, 0 means not set
    @objc dynamic var nightScoutPort: Int {
        get {
            return integer(forKey: Key.nightScoutPort.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutPort.rawValue)
        }
    }

    /// the nightscout url - starts with http
    ///
    /// when assigning a new value, it will be checked if it starts with http, if not then automatically https:// will be added
    @objc dynamic var nightScoutUrl:String? {
        get {
            return string(forKey: Key.nightScoutUrl.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutUrl.rawValue)
        }
    }
    
    /// - schedule for nightscout use, only applicable if nightScoutUseSchedule = true
    /// - string of values, seperate by '-', values are int values and represent minutes
    var nightScoutSchedule: String? {
        get {
            return string(forKey: Key.nightScoutSchedule.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutSchedule.rawValue)
        }
    }
    

    /// the nightscout api key
    @objc dynamic var nightScoutAPIKey:String? {
        get {
            return string(forKey: Key.nightScoutAPIKey.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutAPIKey.rawValue)
        }
    }
    
    // MARK: Dexcom Share Settings
    
    /// should readings be uploaded to Dexcom share server, true or false
    @objc dynamic var uploadReadingstoDexcomShare:Bool {
        get {
            return bool(forKey: Key.uploadReadingstoDexcomShare.rawValue)
        }
        set {
            set(newValue, forKey: Key.uploadReadingstoDexcomShare.rawValue)
        }
    }
    
    /// dexcom share account name
    @objc dynamic var dexcomShareAccountName:String? {
        get {
            return string(forKey: Key.dexcomShareAccountName.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareAccountName.rawValue)
        }
    }
    
    /// dexcom share password
    @objc dynamic var dexcomSharePassword:String? {
        get {
            return string(forKey: Key.dexcomSharePassword.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomSharePassword.rawValue)
        }
    }
    
    /// use US dexcomshare url true or false
    @objc dynamic var useUSDexcomShareurl:Bool {
        get {
            return bool(forKey: Key.useUSDexcomShareurl.rawValue)
        }
        set {
            set(newValue, forKey: Key.useUSDexcomShareurl.rawValue)
        }
    }

    /// dexcom share serial number
    @objc dynamic var dexcomShareSerialNumber:String? {
        get {
            return string(forKey: Key.dexcomShareSerialNumber.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareSerialNumber.rawValue)
        }
    }
    
    /// - schedule for dexcomShare use, only applicable if dexcomShareUseSchedule = true
    /// - string of values, seperate by '-', values are int values and represent minutes
    var dexcomShareSchedule: String? {
        get {
            return string(forKey: Key.dexcomShareSchedule.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareSchedule.rawValue)
        }
    }
    
    /// use schedule for dexcomShareupload ?
    @objc dynamic var dexcomShareUseSchedule: Bool {
        get {
            return bool(forKey: Key.dexcomShareUseSchedule.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareUseSchedule.rawValue)
        }
    }

    // MARK: Healthkit Settings

    /// should readings be stored in healthkit ? true or false
    ///
    /// This is just the user selection, it doesn't say if user has authorized storage of readings in Healthkit - for that use storeReadingsInHealthkitAuthorized
    @objc dynamic var storeReadingsInHealthkit: Bool {
        get {
            return bool(forKey: Key.storeReadingsInHealthkit.rawValue)
        }
        set {
            set(newValue, forKey: Key.storeReadingsInHealthkit.rawValue)
        }
    }
    
    // MARK: Speak Settings
    
    /// should readings be spoken or not
    @objc dynamic var speakReadings: Bool {
        get {
            return bool(forKey: Key.speakReadings.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakReadings.rawValue)
        }
    }

    /// speakReading languageCode, eg "en" or "en-US"
    @objc dynamic var speakReadingLanguageCode: String? {
        get {
            return string(forKey: Key.speakReadingLanguageCode.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakReadingLanguageCode.rawValue)
        }
    }

    /// should trend be spoken or not
    @objc dynamic var speakTrend: Bool {
        get {
            return bool(forKey: Key.speakTrend.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakTrend.rawValue)
        }
    }
    
    /// should delta be spoken or not
    @objc dynamic var speakDelta: Bool {
        get {
            return bool(forKey: Key.speakDelta.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakDelta.rawValue)
        }
    }
    
    /// speak readings interval in minutes
    @objc dynamic var speakInterval: Int {
        get {
            return integer(forKey: Key.speakInterval.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakInterval.rawValue)
        }
    }
    
    // MARK: - Keep track of alert and info messages shown to the user
    
    /// message shown when user starts a sensor, which tells that timing should be exact, was it already shown or not
    var startSensorTimeInfoGiven:Bool {
        get {
            return bool(forKey: Key.startSensorTimeInfoGiven.rawValue)
        }
        set {
            set(newValue, forKey: Key.startSensorTimeInfoGiven.rawValue)
        }
    }
    
    /// license info accepted by user yes or no
    var licenseInfoAccepted:Bool {
        get {
            return bool(forKey: Key.licenseInfoAccepted.rawValue)
        }
        set {
            set(newValue, forKey: Key.licenseInfoAccepted.rawValue)
        }
    }
    
    // MARK: M5Stack

    /// M5StackBlePassword, used for authenticating xdrip app towards M5Stack
    var m5StackBlePassword: String? {
        get {
            return string(forKey: Key.m5StackBlePassword.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackBlePassword.rawValue)
        }
    }
    
    /// M5 Stack text color, this is the default text color for new m5Stacks. Per M5Stack it is possible to change the textcolor
    var m5StackTextColor: M5StackColor? {
        get {
            let textColorAsInt = integer(forKey: Key.m5StackTextColor.rawValue)
            if textColorAsInt > 0 {
                return M5StackColor(forUInt16: UInt16(textColorAsInt))
            } else {
                return nil
            }
        }
        set {
            let newValueAsInt:Int? = {if let newValue = newValue {return Int(newValue.rawValue)} else {return nil}}()
            set(newValueAsInt, forKey: Key.m5StackTextColor.rawValue)
        }
    }
    
    /// name of wifi 1 to be configured in M5Stack
    var m5StackWiFiName1: String? {
        get {
            return string(forKey: Key.m5StackWiFiName1.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiName1.rawValue)
        }
    }
    
    /// name of wifi 2 to be configured in M5Stack
    var m5StackWiFiName2: String? {
        get {
            return string(forKey: Key.m5StackWiFiName2.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiName2.rawValue)
        }
    }
    
    /// name of wifi 3 to be configured in M5Stack
    var m5StackWiFiName3: String? {
        get {
            return string(forKey: Key.m5StackWiFiName3.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiName3.rawValue)
        }
    }
    
    /// Password of wifi 1 to be configured in M5Stack
    var m5StackWiFiPassword1: String? {
        get {
            return string(forKey: Key.m5StackWiFiPassword1.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiPassword1.rawValue)
        }
    }
    
    /// Password of wifi 2 to be configured in M5Stack
    var m5StackWiFiPassword2: String? {
        get {
            return string(forKey: Key.m5StackWiFiPassword2.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiPassword2.rawValue)
        }
    }
    
    /// Password of wifi 3 to be configured in M5Stack
    var m5StackWiFiPassword3: String? {
        get {
            return string(forKey: Key.m5StackWiFiPassword3.rawValue)
        }
        set {
            set(newValue, forKey: Key.m5StackWiFiPassword3.rawValue)
        }
    }
    
    // MARK: - Apple Watch
    
    /// create calendar event yes or no, default false
    @objc dynamic var createCalendarEvent: Bool {
        get {
            return bool(forKey: Key.createCalendarEvent.rawValue)
        }
        set {
            set(newValue, forKey: Key.createCalendarEvent.rawValue)
        }
    }

    /// this is for showing readings on watch via the calendar. Selected calender id (name of the calendar) in which the event should be created
    @objc dynamic var calenderId: String? {
        get {
            return string(forKey: Key.calenderId.rawValue)
        }
        set {
            set(newValue, forKey: Key.calenderId.rawValue)
        }
    }
    
    /// this is for showing readings on watch via the calendar. Should trend be displayed  in calendar event, yes or no, default no
    @objc dynamic var displayTrendInCalendarEvent: Bool {
        get {
            return bool(forKey: Key.displayTrendInCalendarEvent.rawValue)
        }
        set {
            set(newValue, forKey: Key.displayTrendInCalendarEvent.rawValue)
        }
    }
    
    /// this is for showing readings on watch via the calendar. Should delta be displayed in calendar event, yes or no, default no
    @objc dynamic var displayDeltaInCalendarEvent: Bool {
        get {
            return bool(forKey: Key.displayDeltaInCalendarEvent.rawValue)
        }
        set {
            set(newValue, forKey: Key.displayDeltaInCalendarEvent.rawValue)
        }
    }
    
    /// this is for showing readings on watch via the calendar. Should unit be displayed in calendar event,  yes or no, default no
    @objc dynamic var displayUnitInCalendarEvent: Bool {
        get {
            return bool(forKey: Key.displayUnitInCalendarEvent.rawValue)
        }
        set {
            set(newValue, forKey: Key.displayUnitInCalendarEvent.rawValue)
        }
    }
    
    // MARK: - =====  Other Settings ======
    
    /// - in case missed reading alert settings are changed by user, this value will be set to true
    /// - alertmanager will observe that value and when changed, verify if missed reading alert needs to be changed
    @objc dynamic var missedReadingAlertChanged: Bool {
        get {
            return bool(forKey: Key.missedReadingAlertChanged.rawValue)
        }
        set {
            set(newValue, forKey: Key.missedReadingAlertChanged.rawValue)
        }
    }

    /// when was the app launched, used in trace info that is sent via email. Just to be able to see afterwards if the app ever crashed. Because sometimes users say it crashed, but maybe it just stopped receiving readings and restarted by opening the app, but didn't really crash
    var timeStampAppLaunch:Date? {
        get {
            return object(forKey: Key.timeStampAppLaunch.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampAppLaunch.rawValue)
        }
    }
    
    /// timestamp lastest reading uploaded to NightScout
    var timeStampLatestNightScoutUploadedBgReading:Date? {
        get {
            return object(forKey: Key.timeStampLatestNSUploadedBgReadingToNightScout.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampLatestNSUploadedBgReadingToNightScout.rawValue)
        }
    }
    
    /// timestamp latest calibration uploaded to NightScout
    var timeStampLatestNightScoutUploadedCalibration:Date? {
        get {
            return object(forKey: Key.timeStampLatestNSUploadedCalibrationToNightScout.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampLatestNSUploadedCalibrationToNightScout.rawValue)
        }
    }
    
    /// transmitterBatteryInfo, this should be the transmitter battery info of the latest active cgmTransmitter
    var transmitterBatteryInfo:TransmitterBatteryInfo? {
        get {
            if let data = object(forKey: Key.transmitterBatteryInfo.rawValue) as? Data {
                return TransmitterBatteryInfo(data: data)
            } else {
                return nil
            }
            
        }
        set {
            if let newValue = newValue {
                set(newValue.toData(), forKey: Key.transmitterBatteryInfo.rawValue)
            } else {
                set(nil, forKey: Key.transmitterBatteryInfo.rawValue)
            }
            timeStampOfLastBatteryReading = Date()
        }
    }
    
    /// timestamp latest calibration uploaded to NightScout
    var timeStampOfLastBatteryReading:Date? {
        get {
            return object(forKey: Key.timeStampOfLastBatteryReading.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampOfLastBatteryReading.rawValue)
        }
    }
    
    /// did user authorize the storage of readings in healthkit or not - this setting is actually only used to allow the HealthKitManager to listen for changes in the authorization status
    var storeReadingsInHealthkitAuthorized:Bool {
        get {
            return bool(forKey: Key.storeReadingsInHealthkitAuthorized.rawValue)
        }
        set {
            set(newValue, forKey: Key.storeReadingsInHealthkitAuthorized.rawValue)
        }
    }
    
    /// timestamp of last bgreading that was stored in healthkit
    var timeStampLatestHealthKitStoreBgReading:Date? {
        get {
            return object(forKey: Key.timeStampLatestHealthKitStoreBgReading.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampLatestHealthKitStoreBgReading.rawValue)
        }
    }
    
    /// timestamp lastest reading uploaded to Dexcom Share
    var timeStampLatestDexcomShareUploadedBgReading:Date? {
        get {
            return object(forKey: Key.timeStampLatestDexcomShareUploadedBgReading.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampLatestDexcomShareUploadedBgReading.rawValue)
        }
    }
    
    // MARK: - =====  Loop Share Settings ======
    
    /// dictionary representation of readings that were shared  with Loop. This is not the json representation, it's an array of dictionary
    var readingsStoredInSharedUserDefaultsAsDictionary: [Dictionary<String, Any>]? {
        get {
            return object(forKey: Key.readingsStoredInSharedUserDefaultsAsDictionary.rawValue) as? [Dictionary<String, Any>]
        }
        set {
            set(newValue, forKey: Key.readingsStoredInSharedUserDefaultsAsDictionary.rawValue)
        }
    }

    /// timestamp lastest reading uploaded to NightScout
    var timeStampLatestLoopSharedBgReading:Date? {
        get {
            return object(forKey: Key.timeStampLatestLoopSharedBgReading.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.timeStampLatestLoopSharedBgReading.rawValue)
        }
    }
    
    // MARK: - =====  technical settings for testing ======
    
    /// G6 factor 1
    @objc dynamic var G6v2ScalingFactor1:String? {
        get {
            return string(forKey: Key.G6v2ScalingFactor1.rawValue)
        }
        set {
            set(newValue, forKey: Key.G6v2ScalingFactor1.rawValue)
        }
    }
    
    /// G6 factor 2
    @objc dynamic var G6v2ScalingFactor2:String? {
        get {
            return string(forKey: Key.G6v2ScalingFactor2.rawValue)
        }
        set {
            set(newValue, forKey: Key.G6v2ScalingFactor2.rawValue)
        }
    }
    
    /// NSLogEnabled - default false
    var NSLogEnabled: Bool {
        get {
            return bool(forKey: Key.NSLogEnabled.rawValue)
        }
        set {
            set(newValue, forKey: Key.NSLogEnabled.rawValue)
        }
    }
    
    /// smoothLibreValues - default false
    var smoothLibreValues: Bool {
        get {
            return bool(forKey: Key.smoothLibreValues.rawValue)
        }
        set {
            set(newValue, forKey: Key.smoothLibreValues.rawValue)
        }
    }
    
    /// used for Libre data parsing - for processing in LibreDataParser which is only in case of reading with NFC (ie bubble etc)
    var previousRawLibreValues: [Double] {
        get {
            if let data = object(forKey: Key.previousRawLibreValues.rawValue) as? [Double] {
                return data as [Double]
            } else {
                return [Double]()
            }
            
        }
        set {
            set(newValue, forKey: Key.previousRawLibreValues.rawValue)
        }
    }
    
    /// used for storing data read with Libre 2 direct
    var previousRawGlucoseValues: [Int]? {
        get {
            if let data = object(forKey: Key.previousRawGlucoseValues.rawValue) as? [Int] {
                return data as [Int]
            } else {
                return nil
            }
            
        }
        set {
            set(newValue, forKey: Key.previousRawGlucoseValues.rawValue)
        }
    }
    
    /// used for storing data read with Libre 2 direct
    var previousRawTemperatureValues: [Int]? {
        get {
            if let data = object(forKey: Key.previousRawTemperatureValues.rawValue) as? [Int] {
                return data as [Int]
            } else {
                return nil
            }
            
        }
        set {
            set(newValue, forKey: Key.previousRawTemperatureValues.rawValue)
        }
    }
    
    /// used for storing data read with Libre 2 direct
    var previousTemperatureAdjustmentValues: [Int]? {
        get {
            if let data = object(forKey: Key.previousTemperatureAdjustmentValues.rawValue) as? [Int] {
                return data as [Int]
            } else {
                return nil
            }
            
        }
        set {
            set(newValue, forKey: Key.previousTemperatureAdjustmentValues.rawValue)
        }
    }
    
    /// OSLogEnabled - default false
    var OSLogEnabled: Bool {
        get {
            return bool(forKey: Key.OSLogEnabled.rawValue)
        }
        set {
            set(newValue, forKey: Key.OSLogEnabled.rawValue)
        }
    }
    
    /// addDebugLevelLogsInTraceFileAndNSLog - default false
    var addDebugLevelLogsInTraceFileAndNSLog: Bool {
        get {
            return bool(forKey: Key.addDebugLevelLogsInTraceFileAndNSLog.rawValue)
        }
        set {
            set(newValue, forKey: Key.addDebugLevelLogsInTraceFileAndNSLog.rawValue)
        }
    }
    
    /// web oop site
    @objc dynamic var webOOPSite:String? {
        get {
            return string(forKey: Key.webOOPsite.rawValue)
        }
        set {
            var value = newValue
            if let newValue = newValue {
                if !newValue.startsWith("http") {
                    value = "https://" + newValue
                }
            }
            set(value, forKey: Key.webOOPsite.rawValue)
        }
    }
    
    /// web oop token
    @objc dynamic var webOOPtoken:String? {
        get {
            return string(forKey: Key.webOOPtoken.rawValue)
        }
        set {
            set(newValue, forKey: Key.webOOPtoken.rawValue)
        }
    }
    
    /// in case Libre 2 users want to use the local calibration algorithm
    @objc dynamic var overrideWebOOPCalibration: Bool {
        get {
            return bool(forKey: Key.overrideWebOOPCalibration.rawValue)
        }
        set {
            set(newValue, forKey: Key.overrideWebOOPCalibration.rawValue)
        }
    }

    /// to merge from 3.x to 4.x, can be deleted once 3.x is not used anymore
    var cgmTransmitterDeviceAddress: String? {
        get {
            return string(forKey: Key.cgmTransmitterDeviceAddress.rawValue)
        }
        set {
            set(newValue, forKey: Key.cgmTransmitterDeviceAddress.rawValue)
        }
    }
    
    /// web oop parameters, only for bubble, miaomiao and Libre 2
    var libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters? {
        get {
            guard let jsonString = string(forKey: Key.libre1DerivedAlgorithmParameters.rawValue) else { return nil }
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }
            guard let value = try? JSONDecoder().decode(Libre1DerivedAlgorithmParameters.self, from: jsonData) else { return nil }
            return value
        }
        set {
            let encoder = JSONEncoder()
            guard let jsonData = try? encoder.encode(newValue) else { return }
            let jsonString = String(bytes: jsonData, encoding: .utf8)
            set(jsonString, forKey: Key.libre1DerivedAlgorithmParameters.rawValue)
        }
    }
    
    /// Libre Unlock code
    var libreActiveSensorUnlockCode: UInt32 {
        get {
            
            let value = UInt32(integer(forKey: Key.libreActiveSensorUnlockCode.rawValue))
            
            if value == 0 {
                return 42
            }
            
            return UInt32(integer(forKey: Key.libreActiveSensorUnlockCode.rawValue))
            
        }
        set {
            set(newValue, forKey: Key.libreActiveSensorUnlockCode.rawValue)
        }
    }

    /// Libre Unlock count
    var libreActiveSensorUnlockCount: UInt16 {
        get {
            return UInt16(integer(forKey: Key.libreActiveSensorUnlockCount.rawValue))
        }
        set {
            set(newValue, forKey: Key.libreActiveSensorUnlockCount.rawValue)
        }
    }
    
    /// Libre sensor id
    var libreSensorUID: Data? {
        get {
            if let data = object(forKey: Key.libreSensorUID.rawValue) as? Data {
                return data
            } else {
                return nil
            }
        }
        set {
            set(newValue, forKey: Key.libreSensorUID.rawValue)
        }
    }
    
    /// Libre librePatchInfo
    var librePatchInfo: Data? {
        get {
            if let data = object(forKey: Key.librePatchInfo.rawValue) as? Data {
                return data
            } else {
                return nil
            }
        }
        set {
            set(newValue, forKey: Key.librePatchInfo.rawValue)
        }
    }
    
}


