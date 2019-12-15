import Foundation


enum BluetoothPeripheralType: String, CaseIterable {
    
    /// M5Stack
    case M5Stack = "M5Stack"
    
    func getViewModel() -> BluetoothPeripheralViewModel {
        
        switch self {
            
        case .M5Stack:
            return M5StackBluetoothPeripheralViewModel()
            
        }
        
    }

}
