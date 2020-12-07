import Foundation

class TextsLibreNFC {
    
    static private let filename = "LibreNFC"
    
    static let scanComplete: String = {
        return NSLocalizedString("scanComplete", tableName: filename, bundle: Bundle.main, value: "Scan Complete", comment: "after scanning NFC, scan complete message")
    }()

    static let holdTopOfIphoneNearSensor: String = {
        return NSLocalizedString("scanComplete", tableName: filename, bundle: Bundle.main, value: "Hold the top of your iOS device near the sensor", comment: "when NFC scanning is started, this message will appear")
    }()
    
}
