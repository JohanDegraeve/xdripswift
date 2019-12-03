import Foundation

extension M5Stack: BluetoothPeripheral {
    
    // get the mac address
    func getAddress() -> String {
        return address
    }
    
    // get the type of BluetoothPeripheral: "M5Strack", ...
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .M5Stack
    }
    
    func dontTryToConnectToThisBluetoothPeripheral() {
        shouldconnect = false
    }
    
    func alwaysTryToConnectToThisBluetoothPeripheral() {
        shouldconnect = true
    }
    
    func shouldXdripTryToConnectToThisBluetoothPeripheral() -> Bool {
        return shouldconnect
    }
    
    func parameterUpdateNotNeededAtNextConnect() {
        parameterUpdateNeeded = false
    }
    
    func parameterUpdateNeededAtNextConnect() {
        parameterUpdateNeeded = true
    }
    
    func isParameterUpdateNeededAtNextConnect() -> Bool {
        return parameterUpdateNeeded
    }
    
    
}
