import Foundation

/// Every class that represents a bluetooth peripheral needs to conform to this protocol. Classes being core data classes, ie NSManagedObject classes. Example M5Stack conforms to this protocol.
///
/// - implementation of the functions in this protocol will usually be the same for all implementations. As Swift doesn't support abstract classes, and as at the same time the classes (like M5Stack) extens NSManagedObject, I see no other way
protocol BluetoothPeripheral {
    
    /// mac address of the peripheral
    ///
    /// implmentation will always be the same, ie return the address
    func getAddress() -> String
    
    /// what type of peripheral is this
    func bluetoothPeripheralType() -> BluetoothPeripheralType
    
    /// tells the app that it should always try to connect to this bluetoothperipheral
    ///
    /// it's just an internal boolean value that is stored
    func alwaysTryToConnectToThisBluetoothPeripheral()
    
    /// should xdrip try to connect yes or no ?
    ///
    /// it's just an internal boolean value that is stored
    func shouldXdripTryToConnectToThisBluetoothPeripheral() -> Bool

    /// when peripheral reconnects, app should not send list of parameters
    ///
    /// - For example in case of M5Stack, user may change rotation or background color while it's not connected.
    /// - In that case parameterUpdateNeededAtNextConnect will be called.
    /// - Then later, when reconnecting isParameterUpdateNeededAtNextConnect tells us that app should send all parameters to the M5Stack.
    /// - After that a call is made to parameterUpdateNotNeededAtNextConnect
    func parameterUpdateNotNeededAtNextConnect()
    
    /// when peripheral reconnects, app should not send list of parameters
    ///
    /// - For example in case of M5Stack, user may change rotation or background color while it's not connected.
    /// - In that case parameterUpdateNeededAtNextConnect will be called.
    /// - Then later, when reconnecting isParameterUpdateNeededAtNextConnect tells us that app should send all parameters to the M5Stack.
    /// - After that a call is made to parameterUpdateNotNeededAtNextConnect
    func parameterUpdateNeededAtNextConnect()
    
    /// when peripheral reconnects, should app send a list of parameters ?
    ///
    /// - For example in case of M5Stack, user may change rotation or background color while it's not connected.
    /// - In that case parameterUpdateNeededAtNextConnect will be called.
    /// - Then later, when reconnecting isParameterUpdateNeededAtNextConnect tells us that app should send all parameters to the M5Stack.
    /// - After that a call is made to parameterUpdateNotNeededAtNextConnect
    func isParameterUpdateNeededAtNextConnect() -> Bool
    
}

