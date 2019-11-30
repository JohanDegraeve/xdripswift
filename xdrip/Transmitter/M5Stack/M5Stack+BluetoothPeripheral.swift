import Foundation

extension M5Stack: BluetoothPeripheral {
    
    func getAddress() -> String {
        <#code#>
    }
    
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        <#code#>
    }
    
    func dontTryToConnectToThisBluetoothPeripheral() {
        <#code#>
    }
    
    func alwaysTryToConnectToThisBluetoothPeripheral() {
        <#code#>
    }
    
    func xdripShouldTryToConnectToThisBluetoothPeripheral() -> Bool {
        <#code#>
    }
    
    func parameterUpdateNotNeededAtNextConnect() {
        <#code#>
    }
    
    func parameterUpdateNeededAtNextConnect() {
        <#code#>
    }
    
    func isParameterUpdateNeededAtNextConnect() -> Bool {
        <#code#>
    }
    
    
}
