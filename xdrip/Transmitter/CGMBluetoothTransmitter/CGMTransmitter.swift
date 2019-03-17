import Foundation

protocol CGMTransmitter {
    /// get device address, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func address() -> String?
    
    /// get device name, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func name() -> String?
    
    /// start scanning, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    /// - returns:
    ///     the scanning result
    func startScanning() -> BluetoothTransmitter.startScanningResult
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
            print("in canDetectNewSensor, to do for gnsentry")
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
}
