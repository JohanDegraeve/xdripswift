import Foundation

extension OmniPodHeartBeat: BluetoothPeripheral {
        
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .OmniPodHeartBeatType
        
    }
    
}
