import Foundation

extension UserDefaults {
    /// keys for settings and user defaults. For reading and writing settings, the keys should not be used, the specific functions kan be used.
    func setDefalutValue() {
        if !defaultValueInit {
            bloodGlucoseUnitIsMgDl = false
            
            defaultValueInit = true
        }
    }
    
    public enum Key: String {
        // User configurable Settings
        
        // General
        
        /// set userDefault default value at app first launch
        case defaultValueInit = "defaultValueInit"
        /// bloodglucose  unit
        case bloodGlucoseUnitIsMgDl = "bloodGlucoseUnit"
        /// low value
        case lowMarkValue = "lowMarkValue"
        /// high value
        case highMarkValue = "highMarkValue"
        /// master or follower
        case isMaster = "isMaster"
        
        // Transmitter
        
        /// transmitter type
        case transmitterTypeAsString = "transmitterTypeAsString"
        /// transmitterid
        case transmitterId = "transmitterId"
        
        // Nightscout
        
        /// should readings be uploaded to nightscout
        case nightScoutEnabled = "nightScoutEnabled"
        /// nightscout url
        case nightScoutUrl = "nightScoutUrl"
        /// nightscout api key
        case nightScoutAPIKey = "nightScoutAPIKey"
        /// should readings be uploaded to Dexcom share
        
        // Dexcom Share
        
        case uploadReadingstoDexcomShare = "uploadReadingstoDexcomShare"
        /// dexcom share account name
        case dexcomShareAccountName = "dexcomShareAccountName"
        /// dexcom share password
        case dexcomSharePassword = "dexcomSharePassword"
        /// use US dexcomshare url true or false
        case useUSDexcomShareurl = "useUSDexcomShareurl"
        /// dexcom share serial number
        case dexcomShareSerialNumber = "dexcomShareSerialNumber"
        
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
        /// speak rate
        case speakRate = "speakRate"
        
        // Settings that Keep track of alert and info messages shown to the user ======
        
        /// message shown when user starts a sensor, which tells that timing should be exact, was it already shown or not
        case startSensorTimeInfoGiven = "startSensorTimeInfoGiven"
        
        /// license info accepted by user yes or no
        case licenseInfoAccepted = "licenseInfoAccepted"
        
        // Other Settings (not user configurable)
        
        // Bluetooth
        /// active BluetoothTransmitter address
        case bluetoothDeviceAddress = "bluetoothDeviceAddress"
        /// active BluetoothTransmitter name
        case bluetoothDeviceName = "bluetoothDeviceName"
        /// timestamp of last bluetooth disconnect
        case lastdisConnectTimestamp = "lastdisConnectTimestamp"
        
        // Nightscout
        /// timestamp lastest reading uploaded to NightScout
        case timeStampLatestNSUploadedBgReadingToNightScout = "timeStampLatestUploadedBgReading"
        
        // Transmitter
        /// Transmitter Battery Level
        case transmitterBatteryInfo = "transmitterbatteryinfo"
        /// Dexcom transmitter reset required
        case transmitterResetRequired = "transmitterResetRequired"
        
        // HealthKit
        /// did user authorize the storage of readings in healthkit or not
        case storeReadingsInHealthkitAuthorized = "storeReadingsInHealthkitAuthorized"
        
        /// timestamp of last bgreading that was stored in healthkit
        case timeStampLatestHealthKitStoreBgReading = "timeStampLatestHealthKitStoreBgReading"
        
        // Dexcom Share
        /// timestamp of latest reading uploaded to Dexcom Share
        case timeStampLatestDexcomShareUploadedBgReading = "timeStampLatestDexcomShareUploadedBgReading"
        
        // Sensor
        /// sensor Serial Number, for now only applicable to Libre
        case sensorSerialNumber = "sensorSerialNumber"
        
        // development settings to test G6 scaling
        /// G6 factor1 - for testing G6 scaling
        case G6v2ScalingFactor1 = "G6v2ScalingFactor1"

        /// G6 factor2 - for testing G6 scaling
        case G6v2ScalingFactor2 = "G6v2ScalingFactor2"
        
        /// Bubble web oop
        case webOOPEnabled = "webOOPEnabled"
        
        /// for test
        case lastDate = "lastDate"
        
        /// for test
        case lastIndex = "lastIndex"
    }
    
    var lastDate: Date {
        get {
            if let date = value(forKey: Key.lastDate.rawValue) as? Date {
                return date
            }
            let date = Date()
            self.lastDate = date
            return date
        }
        set {
            set(newValue, forKey: Key.lastDate.rawValue)
        }
    }
    
    var lastIndex: Int {
        get {
            return integer(forKey: Key.lastIndex.rawValue)
        }
        set {
            set(newValue, forKey: Key.lastIndex.rawValue)
        }
    }
    
    /// true is setted defalut value
    var defaultValueInit: Bool {
        get {
            return bool(forKey: Key.defaultValueInit.rawValue)
        }
        set {
            set(newValue, forKey: Key.defaultValueInit.rawValue)
        }
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
        }
    }
    
    /// the highmarkvalue in unit selected by user ie, mgdl or mmol
    @objc dynamic var highMarkValueInUserChosenUnit:Double {
        get {
            //read currentvalue in mgdl
            var returnValue = double(forKey: Key.highMarkValue.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsBGGraphBuilder.defaultHighMmarkInMgdl
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
        }
    }
    
    // MARK: Transmitter Settings
    
    /// setting a new transmittertype will also set the transmitterid to nil
    var transmitterType:CGMTransmitterType? {
        get {
            if let transmitterTypeAsString = transmitterTypeAsString {
                return CGMTransmitterType(rawValue: transmitterTypeAsString)
            } else {
                return nil
            }
        }
    }
    
    /// transmittertype as String, just to be able to define dynamic dispatch and obj-c visibility
    @objc dynamic var transmitterTypeAsString:String? {
        get {
            return string(forKey: Key.transmitterTypeAsString.rawValue)
        }
        set {
            // if transmittertype has changed then also reset the transmitter id to nil
            // this is also a check to see if transmitterTypeAsString has really changed, because just calling a set without a new value may cause a transmittertype reset in other parts of the call (inclusive stopping sensor etc.)
            if newValue != string(forKey: Key.transmitterTypeAsString.rawValue) {
                set(nil, forKey: Key.transmitterId.rawValue)
                set(newValue, forKey: Key.transmitterTypeAsString.rawValue)
            }
        }
    }
    
    /// transmitter id
    @objc dynamic var transmitterId:String? {
        get {
            return string(forKey: Key.transmitterId.rawValue)
        }
        set {
            set(newValue, forKey: Key.transmitterId.rawValue)
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
    
    /// the nightscout url - starts with http
    ///
    /// when assigning a new value, it will be checked if it starts with http, if not then automatically https:// will be added
    @objc dynamic var nightScoutUrl:String? {
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
    
    /// speak readings interval in minutes, if nil then default value to be used
    @objc dynamic var speakRate: Double {
        get {
            return double(forKey: Key.speakRate.rawValue)
        }
        set {
            set(newValue, forKey: Key.speakRate.rawValue)
        }
    }
    
    // MARK: - =====  Keep track of alert and info messages shown to the user ======
    
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
    
    // MARK: - =====  Other Settings ======
    
    var bluetoothDeviceAddress: String? {
        get {
            return string(forKey: Key.bluetoothDeviceAddress.rawValue)
        }
        set {
            set(newValue, forKey: Key.bluetoothDeviceAddress.rawValue)
        }
    }
    
    var bluetoothDeviceName: String? {
        get {
            return string(forKey: Key.bluetoothDeviceName.rawValue)
        }
        set {
            set(newValue, forKey: Key.bluetoothDeviceName.rawValue)
        }
    }

    var lastdisConnectTimestamp:Date? {
        get {
            return object(forKey: Key.lastdisConnectTimestamp.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.lastdisConnectTimestamp.rawValue)
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
    
    /// transmitterBatteryInfo
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
        }
    }
    
    /// is transmitter reset required or not
    @objc dynamic var transmitterResetRequired: Bool {
        get {
            return bool(forKey: Key.transmitterResetRequired.rawValue)
        }
        set {
            set(newValue, forKey: Key.transmitterResetRequired.rawValue)
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
    
    /// sensor serial number, for now only useful for Libre sensor
    var sensorSerialNumber:String? {
        get {
            return string(forKey: Key.sensorSerialNumber.rawValue)
        }
        set {
            set(newValue, forKey: Key.sensorSerialNumber.rawValue)
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
    
    
    /// web oop enabled
    @objc dynamic var webOOPEnabled: Bool {
        get {
            return bool(forKey: Key.webOOPEnabled.rawValue)
        }
        set {
            set(newValue, forKey: Key.webOOPEnabled.rawValue)
        }
    }
}


