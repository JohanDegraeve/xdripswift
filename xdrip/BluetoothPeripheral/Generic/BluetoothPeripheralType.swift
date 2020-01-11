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
    
    /// - returns: the BluetoothPeripheralViewModel
    func viewModel() -> BluetoothPeripheralViewModel {
        
        switch self {
            
        case .M5StackType:
            return M5StackBluetoothPeripheralViewModel()
            
        case .M5StickCType:
            return M5StickCBluetoothPeripheralViewModel()
            
        case .watlaaMaster:
            return WatlaaMasterBluetoothPeripheralViewModel()
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
            
            let newM5StickC = M5StickC(address: address, name: name, textColor: UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor, backGroundColor: ConstantsM5Stack.defaultBackGroundColor, rotation: ConstantsM5Stack.defaultRotation, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

            return newM5StickC
            
        case .watlaaMaster:
            
            let newWatlaa = Watlaa(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
            
            return newWatlaa
            
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
            
        }
    }
    
}
