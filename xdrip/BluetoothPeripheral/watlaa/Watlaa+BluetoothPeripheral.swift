import Foundation

extension Watlaa: BluetoothPeripheral {
    
    func getDeviceName() -> String {
        return name
    }
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .watlaaMaster
    }
    
    func getAddress() -> String {
        return address
    }
    
    func getAlias() -> String? {
        return alias
    }
    
    func setAlias(_ value: String?) {
        alias = value
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
