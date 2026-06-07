import Foundation

extension Libre2HeartBeat: BluetoothPeripheral {
        
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .Libre3HeartBeatType
        
    }
    
}
