import Foundation

extension Blucon: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .BluconType
        
    }
    
    func overrideNeedsOOPWeb() -> Bool {
        return false
    }
    
}
