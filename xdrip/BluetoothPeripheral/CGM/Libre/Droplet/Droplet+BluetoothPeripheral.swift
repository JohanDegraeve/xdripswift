import Foundation


extension Droplet: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .DropletType
        
    }
    
    func overrideNeedsOOPWeb() -> Bool {
        return false
    }
    
}
