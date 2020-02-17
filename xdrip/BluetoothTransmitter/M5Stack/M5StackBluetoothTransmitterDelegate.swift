import Foundation

protocol M5StackBluetoothTransmitterDelegate: AnyObject {
    
    /// will be called if M5StackBluetoothTransmitter is connected and ready to receive data
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// M5StackBluetoothTransmitter wants to receive all parameters
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// if a new ble password is received from M5StackBluetoothTransmitter
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// did the app successfully authenticate towards M5Stack
    ///
    /// in case of failure, then user should set the correct password in the M5Stack ini file, or, in case there's no password set in the ini file, switch off and on the M5Stack
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// there's no ble password set during M5Stack init, user should set it in the settings
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// it's an M5Stack without password configired in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
    /// M5Stack is sending batteryLevel
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter)
    
}
