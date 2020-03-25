import Foundation
import CoreData

/// defines the types of bluetooth peripherals
/// - bubble, dexcom G5, dexcom G4, ... which are all of category CGM
/// - M5Stack, M5StickC which are both of category M5Stack
/// - possibily more in the future, like watlaa
enum BluetoothPeripheralType: String, CaseIterable {
    
    /// M5Stack
    case M5StackType = "M5Stack"
    
    /// M5StickC
    case M5StickCType = "M5StickC"
    
    /// watlaa master
    case watlaaMaster = "Watlaa master"
    
    /// DexcomG5
    case DexcomG5Type = "Dexcom G5"
    
    /// bubble
    case BubbleType = "Bubble"
    
    /// MiaoMiao
    case MiaoMiaoType = "MiaoMiao"
    
    /// - returns: the BluetoothPeripheralViewModel
    func viewModel() -> BluetoothPeripheralViewModel {
        
        switch self {
            
        case .M5StackType:
            return M5StackBluetoothPeripheralViewModel()
            
        case .M5StickCType:
            return M5StickCBluetoothPeripheralViewModel()
            
        case .watlaaMaster:
            return WatlaaMasterBluetoothPeripheralViewModel()
            
        case .DexcomG5Type:
            return DexcomG5BluetoothPeripheralViewModel()
            
        case .BubbleType:
            return BubbleBluetoothPeripheralViewModel()
            
        case .MiaoMiaoType:
            return MiaoMiaoBluetoothPeripheralViewModel()
        }
        
    }
    
    func createNewBluetoothPeripheral(withAddress address: String, withName name: String, nsManagedObjectContext: NSManagedObjectContext) -> BluetoothPeripheral {
    
        switch self {
            
        case .M5StackType:
            
           let newM5Stack = M5Stack(address: address, name: name, textColor: UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor, backGroundColor: ConstantsM5Stack.defaultBackGroundColor, rotation: ConstantsM5Stack.defaultRotation, brightness: 100, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
            // assign password stored in UserDefaults (might be nil)
            newM5Stack.blepassword = UserDefaults.standard.m5StackBlePassword
    
            return newM5Stack

        case .M5StickCType:
            
            return M5StickC(address: address, name: name, textColor: UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor, backGroundColor: ConstantsM5Stack.defaultBackGroundColor, rotation: ConstantsM5Stack.defaultRotation, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .watlaaMaster:
            
            return Watlaa(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .DexcomG5Type:
            
            return DexcomG5(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .BubbleType:
            
            return Bubble(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .MiaoMiaoType:
            
            return MiaoMiao(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        }
        
    }

    /// to which category of bluetoothperipherals does this type belong (M5Stack, CGM, ...)
    func category() -> BluetoothPeripheralCategory {
        
        switch self {
            
        case .M5StackType:
            return .M5Stack
            
        case .M5StickCType:
            return .M5Stack
            
        case .watlaaMaster:
            return .watlaa
            
        case .DexcomG5Type, .BubbleType, .MiaoMiaoType:
            return .CGM
            
        }
    }
    
    /// does the device need a transmitterID (currently only Dexcom and Blucon)
    func needsTransmitterId() -> Bool {
        
        switch self {
            
        case .M5StackType, .M5StickCType, .watlaaMaster, .BubbleType, .MiaoMiaoType:
            return false
            
        case .DexcomG5Type:
            return true

        }
    }
    
    /// - returns nil if id to validate has expected length and type of characters etc.
    /// - returns error text if transmitterId is not ok
    func validateTransmitterId(transmitterId:String) -> String? {
        
        switch self {
            
        case .DexcomG5Type: //.dexcomG6:
            
            // length for G5 is 6
            if transmitterId.count != 6 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveLength6
            }
            
            //verify allowed chars
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !transmitterId.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            
            // reject transmitters with id in range 8G or higher. These are Firefly's
            // convert to upper
            let transmitterIdUpper = transmitterId.uppercased()
            if transmitterIdUpper.compare("8G") == .orderedDescending {
                return Texts_SettingsView.transmitterId8OrHigherNotSupported
            }

            // validation successful
            return nil
            
        /*case .dexcomG4:
            //verify allowed chars
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !transmitterId.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            if transmitterId.count != 5 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveLength5
            }
            return nil
            
        case .miaomiao, .GNSentry, .Bubble, .Droplet1:
            return nil
            
        case .Blucon:
            // todo: validate transmitter id for blucon
            return nil
            
        case .blueReader:
            return nil
            
        case .watlaa:
            return nil*/
            
        case .M5StackType, .M5StickCType, .watlaaMaster, .BubbleType, .MiaoMiaoType:
            // no transmitter id means no validation to do
            return nil
            
        }
        
    }

    /// can a transmitter be reset ? For example Dexcom G5 (and G6) can be reset
    ///
    /// can be used in UI stuff, if reset not possible then there's no need to show that option in the settings UI
    func resetPossible() -> Bool {
        
        switch self {

        case .M5StackType, .M5StickCType, .watlaaMaster, .BubbleType, .MiaoMiaoType:
            return false
            
        case .DexcomG5Type:
            return true

        }
        
    }
    
}
