import Foundation

extension Watlaa: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .WatlaaType
    }
    
}
