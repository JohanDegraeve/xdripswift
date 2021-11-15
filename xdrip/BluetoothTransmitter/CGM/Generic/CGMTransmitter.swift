import Foundation
import CoreBluetooth

/// defines functions that every cgm transmitter should conform to
protocol CGMTransmitter:AnyObject {
    
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
    
    /// - is the CGMTransmitter web oop enabled or not
    /// - default implementation returns false
    func isWebOOPEnabled() -> Bool
    
    /// get cgmTransmitterType
    func cgmTransmitterType() -> CGMTransmitterType
    
    /// only applicable for Libre transmitters. To request a new reading.
    func requestNewReading()
    
    /// - maximum sensor age in days, nil if no maximum
    /// - default implementation returns nil
    func maxSensorAgeInDays() -> Int?
    
    /// - to send a start sensor command to the transmitter
    /// - only useful for Dexcom - firefly type of transmitters, other transmitter types will have an empty implementation
    /// - parameters:
    ///     - sensorCode : only to be filled in if code known, only applicable for Dexcom firefly
    ///     - startDate : sensor start timeStamp
    func startSensor(sensorCode: String?, startDate: Date)
    
    /// - to send a stop sensor command to the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func stopSensor(stopDate: Date)
    
    /// - to send a calibration toe the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func calibrate(calibration: Calibration)
    
}

/// cgm transmitter types
enum CGMTransmitterType:String, CaseIterable {
    
    /// dexcom G4 using xdrip, xbridge, ...
    case dexcomG4 = "Dexcom G4"
    
    /// dexcom G5
    case dexcomG5 = "Dexcom G5"
    
    /// - dexcom G6 - for non Firefly - although it can also be used for firefly
    /// - only difference with firefly, is that sensorCode will not be asked (which is needed for firefly), and user will be asked to set a sensor start time (in case of firefly it's always the actual time that is used as start time)
    case dexcomG6 = "Dexcom G6"
    
    /// dexcom G6 firefly
    case dexcomG6Firefly = "Dexcom G6 Firefly"
    
    /// miaomiao
    case miaomiao = "MiaoMiao"
    
    /// GNSentry
    case GNSentry = "GNSentry"
    
    /// Blucon
    case Blucon = "Blucon"
    
    /// Bubble
    case Bubble = "Bubble"
    
    /// Droplet
    case Droplet1 = "Droplet-1"
    
    /// BlueReader
    case blueReader = "BlueReader"
    
    /// Atom
    case Atom = "Atom"
    
    /// watlaa
    case watlaa = "Watlaa"
    
    /// Libre2
    case Libre2 = "Libre2"
    
    /// what sensorType does this CGMTransmitter type support
    func sensorType() -> CGMSensorType {
        
        switch self {
            
        case .dexcomG4, .dexcomG5, .dexcomG6, .dexcomG6Firefly :
            return .Dexcom
            
        case .miaomiao, .Bubble, .GNSentry, .Droplet1, .blueReader, .watlaa, .Blucon, .Libre2, .Atom:
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
            
        case .dexcomG4:
            return false
            
        case .dexcomG5, .dexcomG6:
            return false
            
        case .dexcomG6Firefly:
            // for firefly, we receive the sensorStart time from the transmitter, this will be used to determine if a new sensor is received
            return true
            
        case .miaomiao, .Bubble:
            return true
            
        case .GNSentry:
            return false
            
        case .Blucon:
            return true
            
        case .Droplet1:
            return false
            
        case .blueReader:
            return false
            
        case .watlaa:
            return false
            
        case .Libre2:
            return true
            
        case .Atom:
            return true
            
        }
    }
    
    /// this function says if the user should be able to manually start the sensor.
    ///
    /// Would normally not be required, because if canDetectNewSensor returns true, then manual start shouldn't e necessary. However blucon automatic sensor start does not always work. So for this reason, this function is used.
    func allowManualSensorStart() -> Bool {
        
        switch self {
            
        case .dexcomG4, .dexcomG5, .dexcomG6, .GNSentry, .Droplet1, .blueReader, .watlaa:
            return true
            
        case .dexcomG6Firefly:
            return true
            
        case .miaomiao, .Bubble, .Blucon, .Libre2, .Atom:
            return true
        
        
        }
    }
        
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcomG4:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG4
            
        case .dexcomG5, .dexcomG6, .dexcomG6Firefly:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
            
        case .miaomiao:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            
        case .Bubble:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelBubble
            
        case .GNSentry:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelGNSEntry
            
        case .Blucon:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelBlucon
            
        case .Droplet1:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDroplet
            
        case .blueReader:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelBlueReader
            
        case .watlaa:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelWatlaa
            
        case .Libre2:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelLibre2
            
        case .Atom:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelAtom
            
        }
    }
    
    /// what unit to use for battery level, like '%', Volt, or nothing at all
    ///
    /// to be used for UI stuff
    func batteryUnit() -> String {
        
        switch self {
            
        case .dexcomG4:
            return ""
            
        case .dexcomG5, .dexcomG6, .dexcomG6Firefly:
            return "voltA"
            
        case .miaomiao, .Bubble, .Droplet1:
            return "%"
            
        case .GNSentry:
            return ""
            
        case .Blucon:
            return "%"
            
        case .blueReader:
            return "%"
            
        case .watlaa:
            return "%"
            
        case .Libre2:
            return "%"
            
        case .Atom:
            return "%"
            
        }
    }
    
    /// - if user starts, sensor, does it require a code?
    /// - only true for Dexcom G6  firefly type of transmitters
    func needsSensorStartCode() -> Bool {
        
        switch self {
           
        case .dexcomG6Firefly:
            return true
            
        default:
            return false
        }
        
    }

    /// - if user starts, sensor, does it require to give the start time?
    /// - only false for Dexcom G6 type of transmitters - all other true
    func needsSensorStartTime() -> Bool {
        
        switch self {
            
        case .dexcomG6Firefly:
            return false
            
        default:
            return true
            
        }
        
    }
    
}

extension CGMTransmitter {
    
    // empty implementation for transmitter types that don't need this
    func setNonFixedSlopeEnabled(enabled: Bool) {}

    // default implementation, false
    func isNonFixedSlopeEnabled() -> Bool {return false}
    
    // empty implementation for transmitter types that don't need this
    func setWebOOPEnabled(enabled:Bool) {}
    
    // default implementation, false
    func isWebOOPEnabled() -> Bool {return false}
    
    // empty implementation for transmitter types that don't need this
    func requestNewReading() {}

    // default implementation, nil
    func maxSensorAgeInDays() -> Int? {return nil}
    
    // default implementation, does nothing
    func startSensor(sensorCode: String?, startDate: Date) {}
    
    // default implementation, does nothing
    func stopSensor(stopDate: Date) {}
    
    // default implementation, does nothing
    func calibrate(calibration: Calibration) {}
    
}
