import Foundation

class Text_BluetoothPeripheralView {
    
    static private let filename = "BluetoothPeripheralView"
    
    static let address: String = {
        return NSLocalizedString("address", tableName: filename, bundle: Bundle.main, value: "Address", comment: "when M5Stack is shown, title of the cell with the address")
    }()

    static let status: String = {
        return NSLocalizedString("status", tableName: filename, bundle: Bundle.main, value: "Status", comment: "when Bluetooth Peripheral is shown, title of the cell with the status")
    }()
    
    static let connected: String = {
        return NSLocalizedString("connected", tableName: filename, bundle: Bundle.main, value: "connected", comment: "when Bluetooth Peripheral is shown, connection status, connected")
    }()
    
    static let notConnected: String = {
        return NSLocalizedString("notConnected", tableName: filename, bundle: Bundle.main, value: "Not Connected", comment: "when Bluetooth Peripheral is shown, connection status, not connected")
    }()
    
    static let alwaysConnect: String = {
        return NSLocalizedString("alwaysconnect", tableName: filename, bundle: Bundle.main, value: "Always Connect", comment: "text in button top right, by clicking, user says that device should always try to connect")
    }()
    
    static let donotconnect: String = {
        return NSLocalizedString("donotconnect", tableName: filename, bundle: Bundle.main, value: "Don't connect", comment: "text in button top right, this button will disable automatic connect")
    }()
    
    static let selectAliasText: String = {
        return NSLocalizedString("selectAliasText", tableName: filename, bundle: Bundle.main, value: "Choose an alias for this Bluetooth Peripheral, the name will be shown in the app and is easier for you to recognize", comment: "Bluetooth Peripheral view, when user clicks alias field")
    }()
    
    static let aliasAlreadyExists: String = {
        return NSLocalizedString("aliasAlreadyExists", tableName: filename, bundle: Bundle.main, value: "There is already a Bluetooth Peripheral with this alias", comment: "Bluetooth Peripheral view, when user clicks alias field")
    }()
    
    static let confirmDeletionBluetoothPeripheral: String = {
        return NSLocalizedString("confirmDeletionPeripheral", tableName: filename, bundle: Bundle.main, value: "Do you want to delete Bluetooth Peripheral with ", comment: "Bluetooth Peripheral view, when user clicks the trash button - this is not the complete sentence, it will be followed either by 'name' or 'alias', depending on the availability of an alias")
    }()
    
    static let bluetoothPeripheralAlias: String = {
        return NSLocalizedString("bluetoothPeripheralAlias", tableName: filename, bundle: Bundle.main, value: "Alias", comment: "BluetoothPeripheral view, this is a name of a BluetoothPeripheral assigned by the user, to recognize the device")
    }()

}
