import Foundation

extension UserDefaults {
    private enum Key: String {
        //User configurable Settings
        //General
        //blood glucose  unit
        case bloodGlucoseUnit = "bloodGlucoseUnit"
        //low value
        case lowMarkValue = "lowMarkValue"
        //high value
        case highMarkValue = "highMarkValue"
        // transmitter type
        case transmitterType = "transmitterType"
        // transmitterid
        case transmitterId = "transmitterId"
        // should readings be stored in healthkit, true or false
        case storeReadingsInHealthkit = "storeReadingsInHealthkit"
        // should readings be uploaded to nightscout
        case uploadReadingsToNightScout = "uploadReadingsToNightScout"
        // nightscout url
        case nightScoutUrl = "nightScoutUrl"
        // nightscout api key
        case nightScoutAPIKey = "nightScoutAPIKey"
        // should readings be uploaded to Dexcom share
        case uploadReadingstoDexcomShare = "uploadReadingstoDexcomShare"
        // dexcom share account name
        case dexcomShareAccountName = "dexcomShareAccountName"
        // dexcom share password
        case dexcomSharePassword = "dexcomSharePassword"
        // use US dexcomshare url true or false
        case useUSDexcomShareurl = "useUSDexcomShareurl"
        // dexcom share serial number
        case dexcomShareSerialNumber = "dexcomShareSerialNumber"
        // speak readings
        case speakReadings = "speakReadings"
        // speak delta
        case speakDelta = "speakDelta"
        // speak trend
        case speakTrend = "speakTrend"
        // speak interval
        case speakInterval = "speakInterval"
    }
    
    // MARK: - =====  User Configurable Settings ======
    
    // MARK: General
    /// true if unit is mgdl, false if mmol is used
    var bloodGlucoseUnitIsMgDl: Bool {
        //default value for bool in userdefaults is false, false is for mgdl, true is for mmol
        get {
            return !bool(forKey: Key.bloodGlucoseUnit.rawValue)
        }
        set {
            set(!newValue, forKey: Key.bloodGlucoseUnit.rawValue)
        }
    }
    
    /// the lowmarkvalue in unit selected by user ie, mgdl or mmol
    var lowMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.lowMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = Constants.BGGraphBuilder.defaultLowMarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.lowMarkValue.rawValue)
        }
    }
    
    /// the highmarkvalue in unit selected by user ie, mgdl or mmol
    var highMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.highMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = Constants.BGGraphBuilder.defaultHighMmarkInMgdl
            }
            if !bloodGlucoseUnitIsMgDl {
                returnValue = returnValue.mgdlToMmol()
            }
            return returnValue
        }
        set {
            // store in mgdl
            set(bloodGlucoseUnitIsMgDl ? newValue:newValue.mmolToMgdl(), forKey: Key.highMarkValue.rawValue)
        }
    }
    
    /// the highmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    var highMarkValueInUserChosenUnitRounded:String {
        get {
            return highMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.highMarkValue.rawValue)
        }
    }

    /// the lowmarkvalue in unit selected by user ie, mgdl or mmol - rounded
    var lowMarkValueInUserChosenUnitRounded:String {
        get {
            return lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: bloodGlucoseUnitIsMgDl)
        }
        set {
            var value = newValue.toDouble()
            if !bloodGlucoseUnitIsMgDl {
                value = value?.mmolToMgdl()
            }
            set(value, forKey: Key.lowMarkValue.rawValue)
        }
    }
    
    // MARK: Transmitter Settings
    
    /// setting a new transmittertype will also set the transmitterid to nil
    var transmitterType:CGMTransmitterType? {
        get {
            let transmitterTypeString = string(forKey: Key.transmitterType.rawValue)
            if let transmitterTypeString = transmitterTypeString {
                return CGMTransmitterType(rawValue: transmitterTypeString)
            } else {
                return nil
            }
        }
        set {
            // if transmittertype has changed then also reset the transmitter id to nil
            if newValue?.rawValue != string(forKey: Key.transmitterType.rawValue) {
                set(nil, forKey: Key.transmitterId.rawValue)
            }
            set(newValue?.rawValue, forKey: Key.transmitterType.rawValue)
        }
    }
    
    var transmitterId:String? {
        get {
            return string(forKey: Key.transmitterId.rawValue)
        }
        set {
            set(newValue, forKey: Key.transmitterId.rawValue)
        }
    }
    
    // MARK: Nightscout Share Settings
    
    /// should readings be uploaded in nightscout ? true or false
    var uploadReadingsToNightScout: Bool {
        get {
            return bool(forKey: Key.uploadReadingsToNightScout.rawValue)
        }
        set {
            set(newValue, forKey: Key.uploadReadingsToNightScout.rawValue)
        }
    }
    
    /// the nightscout url
    var nightScoutUrl:String? {
        get {
            return string(forKey: Key.nightScoutUrl.rawValue)
        }
        set {
            var value = newValue
            if let newValue = newValue {
                if !newValue.startsWith("http") {
                    value = "https://" + newValue
                }
            }
            set(value, forKey: Key.nightScoutUrl.rawValue)
        }
    }

    /// the nightscout api key
    var nightScoutAPIKey:String? {
        get {
            return string(forKey: Key.nightScoutAPIKey.rawValue)
        }
        set {
            set(newValue, forKey: Key.nightScoutAPIKey.rawValue)
        }
    }
    
    // MARK: Dexcom Share Settings
    
    /// should readings be uploaded to Dexcom share server, true or false
    var uploadReadingstoDexcomShare:Bool {
        get {
            return bool(forKey: Key.uploadReadingstoDexcomShare.rawValue)
        }
        set {
            set(newValue, forKey: Key.uploadReadingstoDexcomShare.rawValue)
        }
    }
    
    /// dexcom share account name
    var dexcomShareAccountName:String? {
        get {
            return string(forKey: Key.dexcomShareAccountName.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareAccountName.rawValue)
        }
    }
    
    /// dexcom share password
    var dexcomSharePassword:String? {
        get {
            return string(forKey: Key.dexcomSharePassword.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomSharePassword.rawValue)
        }
    }
    
    /// use US dexcomshare url true or false
    var useUSDexcomShareurl:Bool {
        get {
            return bool(forKey: Key.useUSDexcomShareurl.rawValue)
        }
        set {
            set(newValue, forKey: Key.useUSDexcomShareurl.rawValue)
        }
    }

    /// dexcom share serial number
    var dexcomShareSerialNumber:String? {
        get {
            return string(forKey: Key.dexcomShareSerialNumber.rawValue)
        }
        set {
            set(newValue, forKey: Key.dexcomShareSerialNumber.rawValue)
        }
    }

    // MARK: Healthkit Settings

    /// should readings be stored in healthkit ? true or false
    var storeReadingsInHealthkit: Bool {
        get {
            return bool(forKey: Key.storeReadingsInHealthkit.rawValue)
        }
        set {
            set(newValue, forKey: Key.storeReadingsInHealthkit.rawValue)
        }
    }
    
    // MARK: Speak Settings
    
    /// should readings be spoken or not
    var speakReadings: Bool {
        get {
            return bool(forKey: Key.speakReadings.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakReadings.rawValue)
        }
    }

    /// should trend be spoken or not
    var speakTrend: Bool {
        get {
            return bool(forKey: Key.speakTrend.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakTrend.rawValue)
        }
    }
    
    /// should trend be spoken or not
    var speakDelta: Bool {
        get {
            return bool(forKey: Key.speakDelta.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakDelta.rawValue)
        }
    }
    
    /// should trend be spoken or not
    var speakInterval: Int {
        get {
            return integer(forKey: Key.speakInterval.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakInterval.rawValue)
        }
    }    
}


