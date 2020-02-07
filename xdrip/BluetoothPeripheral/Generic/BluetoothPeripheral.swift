import Foundation

/// Every class that represents a bluetooth peripheral type needs to conform to this protocol. Classes being core data classes, ie NSManagedObject classes. Example M5Stack conforms to this protocol.
protocol BluetoothPeripheral {
    
    // MARK:- functions related to generic parameters like address, alias, devicename,..

    /// what type of peripheral is this
    func bluetoothPeripheralType() -> BluetoothPeripheralType
        
    /// a blePeripheral
    var blePeripheral: BLEPeripheral {get}
    
}

