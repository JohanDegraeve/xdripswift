import Foundation
import xDrip4iOS_Widget

extension DexcomG5: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {

        return .DexcomType
        
    }
    
}
