import Foundation

extension DexcomG4: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .DexcomG4Type
        
    }
   
}
