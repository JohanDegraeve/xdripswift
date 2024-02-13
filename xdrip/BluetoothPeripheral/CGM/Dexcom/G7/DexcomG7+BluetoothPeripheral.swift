import Foundation
import xDrip4iOS_Widget

extension DexcomG7: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {

        return .DexcomG7Type
        
    }
    
}
