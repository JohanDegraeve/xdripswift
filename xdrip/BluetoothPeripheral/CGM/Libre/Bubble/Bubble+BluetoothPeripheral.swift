import Foundation

extension Bubble: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .BubbleType
        
    }
    
    func overrideNeedsOOPWeb() -> Bool {
        
        // bubble does decryption for libre2 and libreus
        if let libreSensorType = blePeripheral.libreSensorType {
            
            if libreSensorType == .libre2 || libreSensorType == .libreUS {
                
                return true
                
            }
            
        }
        
        return false
        
    }
    
}
