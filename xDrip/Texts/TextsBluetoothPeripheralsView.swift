import Foundation

class Texts_BluetoothPeripheralsView {
    
    static private let filename = "BluetoothPeripheralsView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "Devices", comment: "when the devices list is shown, title of the view")
    }()
    
    static let selectCategory: String = {
        return NSLocalizedString("selectCategory", tableName: filename, bundle: Bundle.main, value: "Select Type", comment: "when clicking add button in screen with list of bluetoothperipherals, title of pop up where user  needs to select bluetooth peripheral category")
    }()
 
    static let selectType: String = {
        return NSLocalizedString("selectType", tableName: filename, bundle: Bundle.main, value: "Select Transmitter Type", comment: "when clicking add button in screen with list of bluetoothperipherals, after having selected the category, a new pop up appears, this is the title of pop up where user  needs to select bluetooth peripheral type")
    }()

    static let noBluetoothPeripheralsConfigured: String = {
        return NSLocalizedString("noBluetoothPeripheralsConfigured", tableName: filename, bundle: Bundle.main, value: "No Bluetooth peripherals configured", comment: "Shown when the Bluetooth peripherals list is empty")
    }()

    static let heartbeatDeviceFooter: String = {
        return NSLocalizedString("heartbeatDeviceFooter", tableName: filename, bundle: Bundle.main, value: "A heartbeat device does not provide glucose readings. It uses Bluetooth activity to wake the app in the background so follower updates, alarms, badges and notifications can keep running.", comment: "Follower HeartBeat bluetooth list footer. Explains that the device wakes the app in the background but does not provide glucose readings.")
    }()

    static let m5StackDeviceFooter: String = {
        return NSLocalizedString("m5StackDeviceFooter", tableName: filename, bundle: Bundle.main, value: "M5Stack devices are small ESP32-based external displays. They can show glucose values sent from xDrip4iOS over Bluetooth.", comment: "M5Stack bluetooth type selection footer. Explains what M5Stack devices do.")
    }()
    
    static let batteryLevel: String = {
        return NSLocalizedString("batteryLevel", tableName: filename, bundle: Bundle.main, value: "Battery Level", comment: "title of the cell where transmitter battery level is shown in detailed screen")
    }()
    
    static let noMultipleActiveCGMsAllowed: String = {
        return NSLocalizedString("noMultipleActiveCGMsAllowed", tableName: filename, bundle: Bundle.main, value: "You already have one CGM transmitter connected.\n\nVerify your other CGM transmitters and click 'Stop Scanning', 'Disconnect' or just delete them if needed.", comment: "When adding a new cgm transmitter, but the user has another one already which is either connected or trying to connect")
    }()

    static let noMultipleActiveCGMsAllowedFooter: String = {
        return NSLocalizedString("noMultipleActiveCGMsAllowedFooter", tableName: filename, bundle: Bundle.main, value: "You already have one CGM connected.", comment: "Short footer shown in Bluetooth CGM detail when another CGM is already active")
    }()
}
