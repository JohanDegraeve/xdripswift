import Foundation
import CoreData

/// defines the types of bluetooth peripherals
/// - bubble, dexcom G5, dexcom G4, ... which are all of category CGM
/// - M5Stack, M5StickC which are both of category M5Stack
/// - possibily more in the future...
enum BluetoothPeripheralType: String, CaseIterable {
    
    /// M5Stack
    case M5StackType = "M5Stack"
    
    /// M5StickC
    case M5StickCType = "M5StickC"
    
    /// Libre 2
    case Libre2Type = "Libre 2/2+ EU"
    
    /// MiaoMiao
    case MiaoMiaoType = "MiaoMiao"
    
    /// bubble
    case BubbleType = "Nano/Bubble/Bubble Mini"
    
    /// Dexcom
    case DexcomType = "Dexcom G5/G6/ONE"
    
    /// Dexcom G7
    case DexcomG7Type = "Dexcom G7/ONE+/Stelo"
    
    /// to use a Libre (such as L2 US/CA/AUS or Libre 3/Libre 3 Plus) or just any generic heartbeat device as heartbeat
    case Libre3HeartBeatType = "Libre/Generic HeartBeat"
    
    /// DexcomG7 heartbeat
    case DexcomG7HeartBeatType = "Dexcom G7/ONE+/Stelo HeartBeat"
    
    /// omnipod heartbeat
    case OmniPodHeartBeatType = "OmniPod HeartBeat"

    /// - returns: the BluetoothPeripheralViewModel. If nil then there's no specific settings for the tpe of bluetoothPeripheral
    func viewModel() -> BluetoothPeripheralViewModel? {
        
        switch self {
            
        case .M5StackType:
            return M5StackBluetoothPeripheralViewModel()
            
        case .M5StickCType:
            return M5StickCBluetoothPeripheralViewModel()
            
        case .DexcomType:
            return DexcomG5BluetoothPeripheralViewModel()
            
        case .BubbleType:
            return BubbleBluetoothPeripheralViewModel()
            
        case .MiaoMiaoType:
            return MiaoMiaoBluetoothPeripheralViewModel()
            
        case .Libre2Type:
            return Libre2BluetoothPeripheralViewModel()
            
        case .Libre3HeartBeatType:
            return Libre3HeartBeatBluetoothPeripheralViewModel()
            
        case .DexcomG7HeartBeatType:
            return DexcomG7HeartBeatBluetoothPeripheralViewModel()
            
        case .OmniPodHeartBeatType:
            return OmniPodHeartBeatBluetoothPeripheralViewModel()

        case .DexcomG7Type:
            return DexcomG7BluetoothPeripheralViewModel()
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
            
        case .DexcomType:
            return DexcomG5(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .BubbleType:
            return Bubble(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .MiaoMiaoType:
            return MiaoMiao(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .Libre2Type:
            return Libre2(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .Libre3HeartBeatType:
            return Libre2HeartBeat(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .DexcomG7HeartBeatType:
            return DexcomG7HeartBeat(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
        case .OmniPodHeartBeatType:
            return OmniPodHeartBeat(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

        case .DexcomG7Type:
            return DexcomG7(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

        }

    }
    
    /// to which category of bluetoothperipherals does this type belong (M5Stack, CGM, ...)
    func category() -> BluetoothPeripheralCategory {
        
        switch self {
            
        case .M5StackType, .M5StickCType:
            return .M5Stack
            
        case .DexcomType, .BubbleType, .MiaoMiaoType, .Libre2Type, .DexcomG7Type:
            return .CGM

        case .Libre3HeartBeatType, .DexcomG7HeartBeatType, .OmniPodHeartBeatType:
            return .HeartBeat
            
        }
        
    }
    
    /// does the device need a transmitterID (currently only Dexcom)
    func needsTransmitterId() -> Bool {
        
        switch self {
            
        case .DexcomType, .Libre3HeartBeatType, .DexcomG7Type, .DexcomG7HeartBeatType:
            return true

        default:
            return false
        }
        
    }
    
    /// - returns nil if id to validate has expected length and type of characters etc.
    /// - returns error text if transmitterId is not ok
    func validateTransmitterId(transmitterId:String) -> String? {
        
        switch self {
            
        case .DexcomType:
            // length for G5 and G6 is 6
            if transmitterId.count != 6 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveLength6
            }
            
            //verify allowed chars
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !transmitterId.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            
            // validation successful
            return nil
            
        case .DexcomG7Type:
            // if nothing entered, then that's fine, we'll scan as normal
            if transmitterId.isEmpty { return nil }
            
            if !transmitterId.uppercased().hasPrefix("DX") {
                return Texts_ErrorMessages.DexcomG7TypeTransmitterIDWrongPattern
            }
            
            // max length for G7 type is 6, but we will allow partial matches to be used
            if transmitterId.count > 6 {
                return Texts_ErrorMessages.TransmitterIDShouldHaveMaximumLength6
            }
            
            let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
            if !transmitterId.validate(withRegex: regex) {
                return Texts_ErrorMessages.DexcomTransmitterIDInvalidCharacters
            }
            
            return nil
            
        default:
            return nil
        }
        
    }
        
    /// is it web oop supported or not.
    func canWebOOP() -> Bool {
        
        switch self {
            
        case .BubbleType, .MiaoMiaoType: //, .DexcomType:
            return true
            
        case .Libre2Type:
            // oop web can still be used for Libre2 because in the end the data received is Libre 1 format, we can use oop web to get slope parameters
            return true
            
        default:
            return false
            
        }
        
    }
    
    /// can use non fixed slopes or not
    func canUseNonFixedSlope() -> Bool {
        
        switch self {
            
        case .Libre2Type, .BubbleType, .MiaoMiaoType:
            return true
            
        default:
            return false
            
        }
        
    }
    
    /// needs an NFC scan before connecting via BLE, or not
    func needsNFCScanToConnect() -> Bool {
        
        switch self {
            
        case .Libre2Type:
            return true
            
        default:
            return false
            
        }
        
    }
    
    /// can we show the transmitter read sucess row?
    /// basically only show it for CGM transmitters and hide for heartbeat and M5Stack types
    func canShowTransmitterReadSuccess() -> Bool {
        switch self.category() {
        case .CGM:
            return true
        default:
            return false
        }
    }
}


