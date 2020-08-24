import Foundation

import Foundation

extension BlueReader: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .GNSentryType
        
    }
  
    func overrideNeedsOOPWeb() -> Bool {
        return false
    }
    
}
