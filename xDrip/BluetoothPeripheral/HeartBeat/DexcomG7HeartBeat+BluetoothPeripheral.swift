import Foundation

extension DexcomG7HeartBeat: BluetoothPeripheral {
        
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .DexcomG7HeartBeatType
        
    }
    
}
