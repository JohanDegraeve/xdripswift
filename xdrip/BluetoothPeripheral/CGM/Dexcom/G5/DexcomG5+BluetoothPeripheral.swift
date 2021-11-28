import Foundation
import xDrip4iOS_Widget

extension DexcomG5: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {

        if isDexcomG6 {return .DexcomG6Type}
        
        if isFirefly {return .DexcomG6FireflyType}
        
        return .DexcomG5Type
        
    }
    
}
