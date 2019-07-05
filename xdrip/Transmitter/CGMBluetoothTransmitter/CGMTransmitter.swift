import Foundation
import CoreBluetooth

/// defines functions that every transmitter should implement, mainly used by rootviewcontroller to get transmitter address, name, deterine status etc.
///
/// Most of the functions are already defined by BlueToothTransmitter.swift - so most of these functions don't need re-implementation in CGMTransmitter classes that conform to this protocol.
///
/// An exception is for example initiatePairing, which is implemented in CGMG5Transmitter.swift, because that transmitter needs to send a message to the transmitter that will cause the app to request the user to accept the pairing
protocol CGMTransmitter {
    
    /// get device address, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func address() -> String?
    
    /// get device name, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func name() -> String?
    
    /// start scanning, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    /// - returns:
    ///     the scanning result
    func startScanning() -> BluetoothTransmitter.startScanningResult
    
    /// get connection status, nil if peripheral not yet known, ie never connected or discovered the transmitter
    func getConnectionStatus() -> CBPeripheralState?
    
    /// to ask transmitter that it initiates pairing
    ///
    /// for transmitter types that don't need pairing, or that don't need pairing initiated by user/view controller, this will be an empty function. Only G5 (and in future maybe G6) will use it. The others can define an empty body
    func initiatePairing()
}

/// cgm transmitter types
enum CGMTransmitterType:String, CaseIterable {
    
    /// dexcom G4 using xdrip, xbridge, ...
    case dexcomG4 = "Dexcom G4"
    /// dexcom G5
    case dexcomG5 = "Dexcom G5"
    /// miaomiao
    case miaomiao = "MiaoMiao"
    /// GNSentry
    case GNSentry = "GNSentry"
    
    func needsTransmitterId() -> Bool {
        switch self {
        case .dexcomG4:
            return true
        case .dexcomG5:
            return true
        case .miaomiao:
            return false
        case .GNSentry:
            return false
        }
    }
    
    /// if true, then a class conforming to the protocol CGMTransmitterDelegate will call newSensorDetected if it detects a new sensor is placed. Means there's no need to let the user start and stop a sensor
    ///
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    func canDetectNewSensor() -> Bool {
        switch self {
        case .dexcomG4:
            return false
        case .dexcomG5:
            return false
        case .miaomiao:
            return true
        case .GNSentry:
            return false
        }
    }
    
    /// returns nil if idtovalidate has expected length and type of characters etc.
    func validateTransimtterId(idtovalidate:String) -> String? {
        switch self {
        case .dexcomG5:
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
        }
    }
    
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcomG4:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelDexcomG4
        case .dexcomG5:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
        case .miaomiao:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
        case .GNSentry:
            return Constants.DefaultAlertLevels.defaultBatteryAlertLevelGNSEntry
        }
    }
    
    /// if true, then scanning can start automatically as soon as an instance of the CGM transmitter is created. This is typical for eg Dexcom G5, where an individual transitter can be idenfied via the transmitter id. Also the case for Blucon. For MiaoMiao and G4 xdrip this is different.
    ///
    /// for this type of devices, there's no need to give an option in the UI to manually start scanning.
    func startScanningAfterInit() -> Bool {
        switch self {
            
        case .dexcomG4:
            return false
        case .dexcomG5:
            return true
        case .miaomiao:
            return false
        case .GNSentry:
            return false
        }
    }
    
    /// what unit to use for battery level, like '%', Volt, or nothing at all
    ///
    /// to be used for UI stuff
    func batteryUnit() -> String {
        switch self {
            
        case .dexcomG4:
            return ""
        case .dexcomG5:
            return "voltA"
        case .miaomiao:
            return "%"
        case .GNSentry:
            // TODO:- check if GNSentry is indeed percentage
            return ""
        }
    }
}
