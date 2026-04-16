import Foundation
import CoreBluetooth

/// defines functions that every cgm transmitter should conform to
protocol CGMTransmitter: AnyObject {
    
    /// to set nonFixedSlopeEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support non fixed slopes, there's no need to implemented this function<br>
    /// ---  for transmitters who support non fixed (all Libre transmitters) this should be implemented
    func setNonFixedSlopeEnabled(enabled:Bool)
    
    /// - is the CGMTransmitter nonFixed enabled or not
    /// - default implementation returns false
    func isNonFixedSlopeEnabled() -> Bool

    /// to set webOOPEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support webOOP, there's no need to implemented this function<br>
    /// ---  for transmitters who support webOOP (Bubble, MiaoMiao, ..) this should be implemented
    func setWebOOPEnabled(enabled:Bool)
    
    /// is the CGMTransmitter web oop enabled or not
    /// - webOOPEnabled means actually the transmitter sends calibrated data (which is the case also for Dexcom G6 firefly for example, and Libre 2 using Libre algorithm)
    /// - default implementation returns false
    func isWebOOPEnabled() -> Bool
    
    /// if true then the calibration is possible, even though the transmitter sends calibrated values (which is the case for Dexcom G6 firefly)
    /// - default false
    func overruleIsWebOOPEnabled() -> Bool
    
    /// is it allowed to set webOOPenabled to false
    /// - typicall for firefly, where webOOPEnabled false is not possible
    /// - default true
    func nonWebOOPAllowed() -> Bool
    
    /// is the transmitter a G6 Anubis with a 180 day expiry?
    /// - default false
    func isAnubisG6() -> Bool // append G6 to the protocol function name to avoid conflicts with the isAnubis public var of CGMG5Transmitter
    
    /// get cgmTransmitterType
    func cgmTransmitterType() -> CGMTransmitterType
    
    /// only applicable for Libre transmitters. To request a new reading.
    func requestNewReading()
    
    /// maximum sensor age in days, nil if no maximum
    /// - default implementation returns nil
    func maxSensorAgeInDays() -> Double?
    
    /// to send a start sensor command to the transmitter
    /// - only useful for Dexcom - firefly type of transmitters, other transmitter types will have an empty implementation
    /// - parameters:
    ///     - sensorCode : only to be filled in if code known, only applicable for Dexcom firefly
    ///     - startDate : sensor start timeStamp
    func startSensor(sensorCode: String?, startDate: Date)
    
    /// to send a stop sensor command to the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func stopSensor(stopDate: Date)
    
    /// - to send a calibration toe the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func calibrate(calibration: Calibration)
    
    /// - should user give sensor start time when starting a sensor
    /// - default true
    func needsSensorStartTime() -> Bool
    
    /// - should user give sensor start code when starting a sensor
    /// - default false
    func needsSensorStartCode() -> Bool
    
    /// returns the service CBUUID
    func getCBUUID_Service() -> String
    
    /// returns the receive characteristic CBUUID
    func getCBUUID_Receive() -> String
    
}

/// cgm transmitter types
enum CGMTransmitterType:String, CaseIterable {
    
    /// dexcom G5, G6
    case dexcom = "Dexcom G5/G6/ONE"
    
    /// dexcom G7
    case dexcomG7 = "Dexcom G7/ONE+/Stelo"
    
    /// miaomiao
    case miaomiao = "MiaoMiao"
    
    /// Bubble
    case Bubble = "Bubble"
    
    /// Libre2
    case Libre2 = "Libre2"
    
    /// what sensorType does this CGMTransmitter type support
    func sensorType() -> CGMSensorType {
        
        switch self {
            
        case .dexcom, .dexcomG7:
            return .Dexcom
            
        case .miaomiao, .Bubble, .Libre2:
            return .Libre
            
        }
        
    }
    
    /// if true, then a class conforming to the protocol CGMTransmitterDelegate will call newSensorDetected if it detects a new sensor is placed. Means there's no need to let the user start and stop a sensor
    ///
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    ///
    /// if true, then transmitterType must also be able to give the sensor age, ie sensorAge
    func canDetectNewSensor() -> Bool {
        
        switch self {
            
        case .dexcom:
            // for dexcom in native algorithm mode, we receive the sensorStart time from the transmitter, this will be used to determine if a new sensor is received
            // the others will not send sensorStart and will also not send sensorAge
            return true
            
        case .miaomiao, .Bubble:
            return true
            
        case .Libre2:
            return true
            
        case .dexcomG7:
            return true
            
        }
    }
    
    /// this function says if the user should be able to manually start the sensor.
    ///
    /// Would normally not be required, because if canDetectNewSensor returns true, then manual start shouldn't e necessary.
    func allowManualSensorStart() -> Bool {
        
        switch self {
            
        case .dexcom:
            return true
            
        case .miaomiao, .Bubble, .Libre2:
            return true
            
        case .dexcomG7:
            return false
        
        }
    }
        
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcom:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
            
        case .miaomiao:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            
        case .Bubble:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelBubble
            
        case .Libre2:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelLibre2
            
        case .dexcomG7:
            // we don't use this
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
            
        }
    }
    
    /// what unit to use for battery level, like '%', Volt, or nothing at all
    ///
    /// to be used for UI stuff
    func batteryUnit() -> String {
        
        switch self {
            
        case .dexcom:
            return "voltB"
            
        case .miaomiao, .Bubble:
            return "%"
            
        case .Libre2:
            return "%"
            
        case .dexcomG7:
            // we don't use this
            return ""
            
        }
    }
    
    func detailedDescription() -> String {
        
        switch self {
            /// dexcom G5, G6
        case .dexcom:
            
            if let transmitterIdString = UserDefaults.standard.activeSensorTransmitterId {
                
                if transmitterIdString.startsWith("4") {
                    
                    return "Dexcom G5"
                    
                } else if transmitterIdString.startsWith("8") {
                    
                    return "Dexcom G6"
                    
                } else if transmitterIdString.startsWith("5") {
                    
                    return "Dexcom ONE"
                    
                } else if transmitterIdString.startsWith("C") {
                    
                    return "Dexcom ONE"
                    
                }
                
            }
            
            return "Dexcom"
            
        case .dexcomG7:
            if let transmitterIdString = UserDefaults.standard.activeSensorTransmitterId {
                if transmitterIdString.startsWith("DX01") {
                    return "Dexcom Stelo"
                } else if transmitterIdString.startsWith("DX02") {
                    return "Dexcom ONE+"
                } else {
                    return "Dexcom G7"
                }
            }
            return "Dexcom - please wait..."
            
        case .Libre2:
            if let activeSensorMaxSensorAgeInDays = UserDefaults.standard.activeSensorMaxSensorAgeInDays, activeSensorMaxSensorAgeInDays >= 15 {
                return "Libre 2 Plus EU"
            } else {
                return "Libre 2 EU"
            }
            
        default:
            return self.rawValue
            
        }
        
    }
    
}

extension CGMTransmitter {
    
    // empty implementation for transmitter types that don't need this
    func setNonFixedSlopeEnabled(enabled: Bool) {}

    // default implementation, false
    func isNonFixedSlopeEnabled() -> Bool { return false }
    
    // empty implementation for transmitter types that don't need this
    func setWebOOPEnabled(enabled:Bool) {}
    
    // default implementation, false
    func isWebOOPEnabled() -> Bool { return false }
    
    // default implementation, false
    func overruleIsWebOOPEnabled() -> Bool { return false }
    
    // default implementation, false
    func isAnubisG6() -> Bool { return false }
    
    // empty implementation for transmitter types that don't need this
    func requestNewReading() {}

    // default implementation, nil
    func maxSensorAgeInDays() -> Double? { return nil }
    
    // default implementation, does nothing
    func startSensor(sensorCode: String?, startDate: Date) {}
    
    // default implementation, does nothing
    func stopSensor(stopDate: Date) {}
    
    // default implementation, does nothing
    func calibrate(calibration: Calibration) {}
    
    // default implementation, returns true
    func needsSensorStartTime() -> Bool { return true }
    
    // default implementation, returns false
    func needsSensorStartCode() -> Bool { return false }
    
    // default implementation, returns true
    func nonWebOOPAllowed() -> Bool { return true }
    
}
