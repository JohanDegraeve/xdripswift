import Foundation

extension GNSEntry: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .GNSentryType
        
    }
 
    func overrideNeedsOOPWeb() -> Bool {
        return false
    }
    
}
