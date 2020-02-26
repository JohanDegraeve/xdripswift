import Foundation

class Texts_BluetoothPeripheralsView {
    
    static private let filename = "BluetoothPeripheralsView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "Bluetooth Devices", comment: "when Bluetooth Peripheral list is shown, title of the view")
    }()
    
    static let selectCategory: String = {
        return NSLocalizedString("selectCategory", tableName: filename, bundle: Bundle.main, value: "Select Category", comment: "when clicking add button in screen with list of bluetoothperipherals, title of pop up where user  needs to select bluetooth peripheral category")
    }()
    
    static let selectType: String = {
        return NSLocalizedString("selectType", tableName: filename, bundle: Bundle.main, value: "Select Type", comment: "when clicking add button in screen with list of bluetoothperipherals, after having selected the category, a new pop up appears, this is the title of pop up where user  needs to select bluetooth peripheral type")
    }()
    
    static let batteryLevel: String = {
        return NSLocalizedString("batteryLevel", tableName: filename, bundle: Bundle.main, value: "Battery Level", comment: "title of the cell where transmitter battery level is shown in detailed screen")
    }()
    
    static let noMultipleActiveCGMsAllowed: String = {
        return NSLocalizedString("noMultipleActiveCGMsAllowed", tableName: filename, bundle: Bundle.main, value: "You can not have more than one CGM Transmitter which is connected or trying to connect.\nVerify your other CGM Transmitters and either click 'Don't connect' or delete it.", comment: "When adding a new cgm transmitter, but the user has another one already which is either connected or trying to connect")
    }()
}
