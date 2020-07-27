import Foundation

extension DexcomG5: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .DexcomG5Type
        
    }
    
}
