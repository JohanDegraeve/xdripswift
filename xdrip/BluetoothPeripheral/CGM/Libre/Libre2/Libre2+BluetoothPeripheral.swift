import Foundation

extension Libre2: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .BluconType
        //return .Libre2Type
    }
    
    func overrideNeedsOOPWeb() -> Bool {
        // for Libre 2 we decrypt the data, so the data will be processed as Libre 1, means user can choose to use oop web or not for defining slope parameters
        return true
    }
    
    
}
