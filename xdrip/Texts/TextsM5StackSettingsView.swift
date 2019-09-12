import Foundation

class Texts_M5Stack_SettingsView {
    
    static private let filename = "M5StackSettingsView"
    
    static let screenTitle: String = {
        return NSLocalizedString("m5stack_settingsviews_settingstitle", tableName: filename, bundle: Bundle.main, value: "M5 Stack Settings", comment: "shown on top of the first settings screen")
    }()
    
    static let textColor: String = {
        return NSLocalizedString("m5stack_settingsviews_textColor", tableName: filename, bundle: Bundle.main, value: "Text Color", comment: "name of setting for text color")
    }()
    
    static let sectionTitleBluetooth: String = {
        return NSLocalizedString("m5stack_settingsviews_sectiontitlebluetooth", tableName: filename, bundle: Bundle.main, value: "Bluetooth", comment: "bluetooth settings, section title")
    }()
    
    static let giveBlueToothPassword: String = {
        return NSLocalizedString("m5stack_settingsviews_giveBluetoothPassword", tableName: filename, bundle: Bundle.main, value: "Enter Bluetooth password", comment: "M5 stack bluetooth  settings, pop up that asks user to enter the password")
    }()

    
}
