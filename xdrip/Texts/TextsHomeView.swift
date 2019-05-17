import Foundation

/// all texts related to calibration
enum Texts_HomeView {
    static private let filename = "HomeView"
    
    static let snoozeButton:String = {
        return NSLocalizedString("presnooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Text in button on home screen")
    }()
    
    static let transmitterButton:String = {
        return NSLocalizedString("transmitter", tableName: filename, bundle: Bundle.main, value: "Transmitter", comment: "Text in button on home screen")
    }()
    
    static let calibrationButton:String = {
        return NSLocalizedString("calibrate", tableName: filename, bundle: Bundle.main, value: "Calibrate", comment: "Text in button on home screen")
    }()
    
}
