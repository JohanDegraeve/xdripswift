import Foundation

/// Every class that represents a bluetooth peripheral type needs to conform to this protocol. Classes being core data classes, ie NSManagedObject classes. Example M5Stack conforms to this protocol.
protocol BluetoothPeripheral {
    
    // MARK:- functions related to generic parameters like address, alias, devicename,..

    /// what type of peripheral is this
    func bluetoothPeripheralType() -> BluetoothPeripheralType
        
    /// a blePeripheral
    var blePeripheral: BLEPeripheral {get}
    
    /// for libre sensor. LibreSensortype may require oop web (ie needsWebOOP returns true), but if transmitter supports decryption (to Libre 1 format), then user could still decide not to use oop web and do self calibration. So if the transmitter type (which matches a bluetooth peripheral type) supports decryption, then this value will return true in which case user should be able to enable/disable oopweb himself, meaning this overrides "needsOopWeb", it's the user that decides
    ///
    /// in the end  maybe the funcions needsWebOOP and overrideNeedsWebOOP can be completely removed
    func overrideNeedsOOPWeb() -> Bool
    
}

