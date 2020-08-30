import Foundation

extension MiaoMiao: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .MiaoMiaoType
        
    }
 
    func overrideNeedsOOPWeb() -> Bool {
        
        // mm does decryption for libre2 and libreus
        if let libreSensorType = blePeripheral.libreSensorType {
            
            if libreSensorType == .libre2 || libreSensorType == .libreUS {
                
                return true
                
            }
            
        }
        
        return false
        
    }
    
}
