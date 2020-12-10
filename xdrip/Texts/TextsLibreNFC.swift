import Foundation

class TextsLibreNFC {
    
    static private let filename = "LibreNFC"
    
    static let scanComplete: String = {
        return NSLocalizedString("scanComplete", tableName: filename, bundle: Bundle.main, value: "Scan Complete", comment: "after scanning NFC, scan complete message")
    }()

    static let holdTopOfIphoneNearSensor: String = {
        return NSLocalizedString("holdTopOfIphoneNearSensor", tableName: filename, bundle: Bundle.main, value: "Hold the top of your iOS device near the sensor", comment: "when NFC scanning is started, this message will appear")
    }()
    
    static let deviceMustSupportNFCAndIOS14: String = {
        return NSLocalizedString("deviceMustSupportNFCAndIOS14", tableName: filename, bundle: Bundle.main, value: "Hold the top of your iOS device near the sensor", comment: "Device must support NFC and must run at least iOS 14.0")
    }()
    
}
