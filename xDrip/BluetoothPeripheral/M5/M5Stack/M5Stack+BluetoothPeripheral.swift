import Foundation

extension M5Stack: BluetoothPeripheral {
    
    // get the type of BluetoothPeripheral: "M5Stack", ...
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        if isM5StickC {
            return .M5StickCType
        }
        return .M5StackType
    }
    
}
