import Foundation

/// 
///
/// BluetoothPeripheral vs BluetoothTransmitter ? What's in a name. . I created BluetoothPeripheral so I can extend every core data type (eg M5Stack) with this functionality.
protocol BluetoothPeripheral {
    
    /// mac address of the peripheral
    func address() -> String
    
}

enum BluetoothPeripheralType: String, CaseIterable {
    
    /// M5Stack
    case M5Stack = "M5Stack"
    
}
