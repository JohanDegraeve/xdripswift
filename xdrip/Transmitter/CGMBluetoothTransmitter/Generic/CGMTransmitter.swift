import Foundation
import CoreBluetooth

/// defines functions that every cgm transmitter should conform to, mainly used by rootviewcontroller to get transmitter address, name, deterine status etc.
///
/// Most of the functions are already defined by BlueToothTransmitter.swift - so most of these functions don't need re-implementation in CGMTransmitter classes that conform to this protocol.
///
/// An exception is for example initiatePairing, which is implemented in CGMG5Transmitter.swift, because that transmitter needs to send a message to the transmitter that will cause the app to request the user to accept the pairing
protocol CGMTransmitter {
    
    /// get device address, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    ///
    /// this function is implemented in class BluetoothTransmitter.swift, it's not necessary for transmitter types to implement this function (as new transmitterType class conform to protocol CGMTransmitter but also extend the BluetoothTransmitter class
    func address() -> String?
    
    /// get device name, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    ///
    /// this function is implemented in class BluetoothTransmitter.swift, it's not necessary for transmitter types to implement this function (as new transmitterType class conform to protocol CGMTransmitter but also extend the BluetoothTransmitter class
    func name() -> String?
    
    /// start scanning, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    /// - returns:
    ///     the scanning result
    ///
    /// this function is implemented in class BluetoothTransmitter.swift, it's not necessary for transmitter types to implement this function (as new transmitterType class conform to protocol CGMTransmitter but also extend the BluetoothTransmitter class
    func startScanning() -> BluetoothTransmitter.startScanningResult
    
    /// get connection status, nil if peripheral not yet known, ie never connected or discovered the transmitter
    ///
    /// this function is implemented in class BluetoothTransmitter.swift, it's not necessary for transmitter types to implement this function (as new transmitterType class conform to protocol CGMTransmitter but also extend the BluetoothTransmitter class
    func getConnectionStatus() -> CBPeripheralState?
    
    /// to ask transmitter that it initiates pairing
    ///
    /// for transmitter types that don't need pairing, or that don't need pairing initiated by user/view controller, this will be an empty function. Only G5 (and in future maybe G6) will use it. The others can define an empty body
    func initiatePairing()
    
    /// to reset the transmitter
    /// - parameters:
    ///     - requested : if true then transmitter must be reset
    /// for transmitter types that don't support resetting, this will be an empty function. Only G5 (and in future maybe G6) will use it. The others can define an empty body
    func reset(requested:Bool)
    
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
    case Blucon = "Blucon NOT READY !"
    
    /// does the transmitter need a transmitter id ?
    ///
    /// can be used in UI stuff, if reset not possible then there's no need to show that option in the settings UI
    func needsTransmitterId() -> Bool {
        switch self {
            
        case .dexcomG4:
            return true
            
        case .dexcomG5, .dexcomG6:
            return true
            
        case .miaomiao:
            return false
            
        case .GNSentry:
            return false
            
        case .Blucon:
            return true
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
            
        case .miaomiao:
            return true
            
        case .GNSentry:
            return false
            
        case .Blucon:
            return true
        }
    }
    
    /// returns nil if id to validate has expected length and type of characters etc.
    func validateTransimtterId(idtovalidate:String) -> String? {
        switch self {
            
        case .dexcomG5, .dexcomG6:
            //verify allowed chars
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !idtovalidate.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            if idtovalidate.count != 6 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveLength6
            }
            return nil
            
        case .dexcomG4:
            //verify allowed chars
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !idtovalidate.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            if idtovalidate.count != 5 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveLength5
            }
            return nil
            
        case .miaomiao, .GNSentry:
            return nil
            
        case .Blucon:
            // todo: validate transmitter id for blucon
            return nil
        }
    }
    
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcomG4:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelDexcomG4
            
        case .dexcomG5, .dexcomG6:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
            
        case .miaomiao:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            
        case .GNSentry:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelGNSEntry
            
        case .Blucon:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelBlucon
            
        }
    }
    
    /// if true, then scanning can start automatically as soon as an instance of the CGM transmitter is created. This is typical for eg Dexcom G5, where an individual transitter can be idenfied via the transmitter id. Also the case for Blucon. For MiaoMiao and G4 xdrip this is different.
    ///
    /// for this type of devices, there's no need to give an option in the UI to manually start scanning.
    func startScanningAfterInit() -> Bool {
        switch self {
            
        case .dexcomG4:
            return false
            
        case .dexcomG5, .dexcomG6:
            return true
            
        case .miaomiao:
            return false
            
        case .GNSentry:
            return false
            
        case .Blucon:
            return true
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
            
        case .miaomiao:
            return "%"
            
        case .GNSentry:
            return ""
            
        case .Blucon:
            return "%"
        }
    }
    
    /// can a transmitter be reset ? For example Dexcom G5 (and G6) can be reset
    ///
    /// can be used in UI stuff, if reset not possible then there's no need to show that option in the settings UI
    func resetPossible() -> Bool {
        switch self {
            
        case .dexcomG4:
            return false
            
        case .dexcomG5, .dexcomG6:
            return true
            
        case .miaomiao:
            return false
            
        case .GNSentry:
            return false
            
        case .Blucon:
            return false
        }
    }
}
