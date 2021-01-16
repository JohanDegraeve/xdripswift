import Foundation
import CoreBluetooth

/// defines functions that every cgm transmitter should conform to
protocol CGMTransmitter:AnyObject {
    
    /// to set nonFixedSlopeEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support non fixed slopes, there's no need to implemented this function<br>
    /// ---  for transmitters who support non fixed (all Libre transmitters) this should be implemented
    func setNonFixedSlopeEnabled(enabled:Bool)
    
    /// is the CGMTransmitter nonFixed enabled or not
    func isNonFixedSlopeEnabled() -> Bool

    /// to set webOOPEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support webOOP, there's no need to implemented this function<br>
    /// ---  for transmitters who support webOOP (Bubble, MiaoMiao, ..) this should be implemented
    func setWebOOPEnabled(enabled:Bool)
    
    /// is the CGMTransmitter web oop enabled or not
    func isWebOOPEnabled() -> Bool
    
    /// get cgmTransmitterType
    func cgmTransmitterType() -> CGMTransmitterType
    
    /// only applicable for Libre transmitters. To request a new reading.
    func requestNewReading()
    
}

/// cgm transmitter types
enum CGMTransmitterType:String, CaseIterable {
    
    /// dexcom G4 using xdrip, xbridge, ...
    case dexcomG4 = "Dexcom G4"
    
    /// dexcom G5
    case dexcomG5 = "Dexcom G5"
    
    /// dexcom G6
    case dexcomG6 = "Dexcom G6"
    
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
    
    /// watlaa
    case watlaa = "Watlaa"
    
    /// Libre2
    case Libre2 = "Libre2"
    
    /// what sensorType does this CGMTransmitter type support
    func sensorType() -> CGMSensorType {
        
        switch self {
            
        case .dexcomG4, .dexcomG5, .dexcomG6 :
            return .Dexcom
            
        case .miaomiao, .Bubble, .GNSentry, .Droplet1, .blueReader, .watlaa, .Blucon, .Libre2:
            return .Libre
            
        }
        
    }
    
    /// if true, then a class conforming to the protocol CGMTransmitterDelegate will call newSensorDetected if it detects a new sensor is placed. Means there's no need to let the user start and stop a sensor
    ///
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    ///
    /// if true, then transmitterType must also be able to give the sensor age, ie sensorTimeInMinutes
    func canDetectNewSensor() -> Bool {
        
        switch self {
            
        case .dexcomG4:
            return false
            
        case .dexcomG5, .dexcomG6:
            return false
            
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
            
        }
    }
    
    /// this function says if the user should be able to manually start the sensor.
    ///
    /// Would normally not be required, because if canDetectNewSensor returns true, then manual start shouldn't e necessary. However blucon automatic sensor start does not always work. So for this reason, this function is used.
    func allowManualSensorStart() -> Bool {
        
        switch self {
            
        case .dexcomG4, .dexcomG5, .dexcomG6, .GNSentry, .Droplet1, .blueReader, .watlaa:
            return true
            
        case .miaomiao, .Bubble, .Blucon, .Libre2:
            return true
        
        
        }
    }
        
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcomG4:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG4
            
        case .dexcomG5, .dexcomG6:
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
            
        }
    }
    
    /// what unit to use for battery level, like '%', Volt, or nothing at all
    ///
    /// to be used for UI stuff
    func batteryUnit() -> String {
        
        switch self {
            
        case .dexcomG4:
            return ""
            
        case .dexcomG5, .dexcomG6:
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
            
        }
    }
    
}
