import Foundation

class TextsLibreNFC {
    
    static private let filename = "LibreNFC"
    
    static let scanComplete: String = {
        return NSLocalizedString("scanComplete", tableName: filename, bundle: Bundle.main, value: "Scan Complete", comment: "after scanning NFC, scan complete message")
    }()

    static let holdTopOfIphoneNearSensor: String = {
        return NSLocalizedString("holdTopOfIphoneNearSensor", tableName: filename, bundle: Bundle.main, value: "Hold the top of your iOS device near the sensor", comment: "when NFC scanning is started, this message will appear")
    }()
    
    static let deviceMustSupportNFC: String = {
        return NSLocalizedString("deviceMustSupportNFC", tableName: filename, bundle: Bundle.main, value: "Device must support NFC", comment: "Device must support NFC")
    }()
    
    static let deviceMustSupportIOS14: String = {
        return NSLocalizedString("deviceMustSupportIOS14", tableName: filename, bundle: Bundle.main, value: "Device must support at least iOS 14.0", comment: "Device must support at least iOS 14.0")
    }()
    
    static let donotusethelibrelinkapp: String = {
        return NSLocalizedString("donotusethelibrelinkapp", tableName: filename, bundle: Bundle.main, value: "Connected to Libre 2.\r\n\r\nIf you still want to scan the Libre sensor with the official Libre app, then disallow bluetooth permission for the Libre app. Otherwise, scanning the NFC with the Libre app and with bluetooth permission allowed will disallow xDrip4iOS to connect to the Libre 2", comment: "After Libre NFC scanning, and after successful bluetooth connection, this message will be shown to explain that he or she should not allow bluetooth permission on the Libre app")
    }()
    
}
