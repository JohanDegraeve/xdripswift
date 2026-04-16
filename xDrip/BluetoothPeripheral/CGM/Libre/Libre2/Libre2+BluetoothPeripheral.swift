import Foundation

extension Libre2: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .Libre2Type
    }
    
}
