import Foundation

/// Every class that represents a bluetooth peripheral type needs to conform to this protocol. Classes being core data classes, ie NSManagedObject classes. Example M5Stack conforms to this protocol.
protocol BluetoothPeripheral {
    
    // MARK:- functions related to generic parameters like address, alias, devicename,..

    /// what type of peripheral is this
    func bluetoothPeripheralType() -> BluetoothPeripheralType
        
    /// to be used when transmitter is created
    /// - instance of BluetoothTransmitter is created only when user cliks the "start scanning" or "connect" button in the bluetooth screen (depending on status of the transmitter)
    /// - user may change settings which are required by the BluetoothTransmitter object (like useOtherApp for Dexcom). If user change any of  those settings in the bluetooth screen at a moment the BluetoothTransmitter object is not yet created, they will need to be send at the moment the BluetoothTransmitter object is created. BluetoothPeripheralManager manages this, it will call this function when the transmitter is created
    func sendSettings(to bluetoothTransmitter: BluetoothTransmitter)
    
    /// a blePeripheral
    var blePeripheral: BLEPeripheral {get}

}

extension BluetoothPeripheral {
    
    // default implementation, empty
    func sendSettings(to bluetoothTransmitter: BluetoothTransmitter) {}
    
}

