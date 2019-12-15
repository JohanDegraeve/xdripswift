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
    
}
