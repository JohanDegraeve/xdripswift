import Foundation

class Texts_BluetoothPeripheralsView {
    
    static private let filename = "BluetoothPeripheralsView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "Bluetooth Devices", comment: "when Bluetooth Peripheral list is shown, title of the view")
    }()
    
}
