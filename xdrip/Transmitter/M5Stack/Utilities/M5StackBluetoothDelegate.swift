import Foundation
import CoreBluetooth

protocol M5StackBluetoothDelegate: AnyObject {
    
    /// if a new ble password is received from M5Stack
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack:M5Stack)
    
    /// did the app successfully authenticate towards M5Stack
    ///
    /// in case of failure, then user should set the correct password in the M5Stack ini file, or, in case there's no password set in the ini file, switch off and on the M5Stack
    func authentication(success: Bool, forM5Stack m5Stack:M5Stack)
    
    /// there's no ble password set during M5Stack init, user should set it in the settings
    func blePasswordMissing(forM5Stack m5Stack:M5Stack)
    
    /// it's an M5Stack without password configired in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset
    func m5StackResetRequired(forM5Stack m5Stack:M5Stack)
    
    /// did connect to M5Stack
    /// - parameters:
    ///     - forM5Stack : if nil then it's the first connection to a new M5Stack, time to create a new M5Stack instance with address and string which should now not be nil
    ///     - bluetoothTransmitter : is needed in case we want to disconnect from it
    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter : M5StackBluetoothTransmitter)
    
    /// did disconnect from M5Stack
    func didDisconnect(forM5Stack m5Stack:M5Stack)
    
    /// the ios device did change bluetooth status
    func deviceDidUpdateBluetoothState(state: CBManagerState, forM5Stack m5Stack:M5Stack)
    
    /// to pass some text error message, delegate can decide to show to user, log, ...
    func error(message: String)
    
}
