import Foundation

extension MiaoMiao: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        
        return .MiaoMiaoType
        
    }
 
}
