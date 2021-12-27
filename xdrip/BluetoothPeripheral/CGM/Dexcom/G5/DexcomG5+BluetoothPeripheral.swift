import Foundation
import xDrip4iOS_Widget

extension DexcomG5: BluetoothPeripheral {
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {

        return .DexcomType
        
    }
    
    func sendSettings(to bluetoothTransmitter: BluetoothTransmitter) {
        
        if let cGMG5Transmitter = bluetoothTransmitter as? CGMG5Transmitter {
            
            cGMG5Transmitter.useOtherApp = useOtherApp
            
        }
        
    }
    
}
