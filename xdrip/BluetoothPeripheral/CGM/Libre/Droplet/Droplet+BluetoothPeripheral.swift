import Foundation


extension Droplet: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .DropletType
        
    }
    
}
