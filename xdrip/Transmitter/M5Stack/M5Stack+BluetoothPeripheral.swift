import Foundation

extension M5Stack: BluetoothPeripheral {
   
    func getViewModel() -> BluetoothPeripheralViewModel {
        return M5StackBluetoothPeripheralViewModel()
    }
    
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
