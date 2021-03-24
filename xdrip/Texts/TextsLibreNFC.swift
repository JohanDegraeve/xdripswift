import Foundation

class TextsLibreNFC {
    
    static private let filename = "LibreNFC"
    
    static let scanComplete: String = {
        return NSLocalizedString("scanComplete", tableName: filename, bundle: Bundle.main, value: "Scan Complete", comment: "after scanning NFC, scan complete message")
    }()

    static let holdTopOfIphoneNearSensor: String = {
        return NSLocalizedString("holdTopOfIphoneNearSensor", tableName: filename, bundle: Bundle.main, value: "Hold the top of your iOS device near the sensor to scan", comment: "when NFC scanning is started, this message will appear")
    }()
    
    static let deviceMustSupportNFC: String = {
        return NSLocalizedString("deviceMustSupportNFC", tableName: filename, bundle: Bundle.main, value: "This iPhone does not support NFC", comment: "Device must support NFC")
    }()
    
    static let deviceMustSupportIOS14: String = {
        return NSLocalizedString("deviceMustSupportIOS14", tableName: filename, bundle: Bundle.main, value: "To connect to Libre 2, this iPhone needs upgrading to iOS14", comment: "Device must support at least iOS 14.0")
    }()
    
    static let donotusethelibrelinkapp: String = {
        return String(format: NSLocalizedString("donotusethelibrelinkapp", tableName: filename, bundle: Bundle.main, value: "Connected to Libre 2.\r\n\r\nIf you want to keeping scanning sometimes the Libre sensor with the official Libre app, then disallow bluetooth permission for the Libre app. \r\n\r\nOtherwise, scanning the NFC with the Libre app and with the bluetooth permission allowed will break the connection between %@ and the Libre 2.", comment: "After Libre NFC scanning, and after successful bluetooth connection, this message will be shown to explain that he or she should not allow bluetooth permission on the Libre app"), ConstantsHomeView.applicationName)
    }()
    
    static let connectedLibre2DoesNotMatchScannedLibre2: String = {
        return String(format: NSLocalizedString("connectedLibre2DoesNotMatchScannedLibre2", tableName: filename, bundle: Bundle.main, value: "You seem to have scanned a new sensor, but %@ is having the Bluetooth connection to the old sensor.\r\n\r\nTo solve this :\r\n- Click 'disconnect' or 'stop scanning'\r\n- Go back to previous screen and add a new CGM of type Libre 2 and scan again.\r\n\r\n%@ should now connect to the new sensor.", comment: "The user has connected to another (older?) Libre 2 with bluetooth than the one for which NFC scan was done, in that case, inform user that he/she should click 'disconnect', add a new CGM sensor and scan again."), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let nfcErrorRetryScan: String = {
        return NSLocalizedString("nfcErrorRetryScan", tableName: filename, bundle: Bundle.main, value: "Error occured while scanning the sensor. Click 'Scan' top left or click 'back' and add the Libre 2 again, and scan again.", comment: "Sometimes NFC scanning creates errors, retrying solves the problem. This is to explain this to the user")
    }()
    
}
