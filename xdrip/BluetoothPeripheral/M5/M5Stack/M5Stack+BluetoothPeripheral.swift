import Foundation

extension M5Stack: BluetoothPeripheral {
   
    func getDeviceName() -> String {
        return name
    }
    
    func setAlias(_ value: String?) {
        alias = value
    }
   
    func getAlias() -> String? {
        return alias
    }
    
    // get the mac address
    func getAddress() -> String {
        return address
    }
    
    // get the type of BluetoothPeripheral: "M5Stack", ...
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        if isM5StickC {
            return .M5StickCType
        }
        return .M5StackType
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
