import Foundation

extension DexcomG7: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {

        return .DexcomG7Type
        
    }
    
}
