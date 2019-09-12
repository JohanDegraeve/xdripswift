import Foundation

protocol M5StackDelegate: AnyObject {
    
    /// if a new ble password is received from M5Stack
    func newBlePassWord(newBlePassword: String)
    
    /// did the app successfully authenticate towards M5Stack
    ///
    /// in case of failure, then user should set the correct password in the M5Stack ini file, or, in case there's no password set in the ini file, switch off and on the M5Stack
    func authentication(success: Bool)
    
    /// there's no ble password set, user should set it in the settings
    func blePasswordMissingInSettings()
    
    /// it's an M5Stack without password configired in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset
    func m5StackResetRequired()
    
}
