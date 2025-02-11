import Foundation

/// all texts related to calibration
enum Texts_Calibrations {
    static private let filename = "CalibrationRequest"

    static let calibrationNotificationRequestTitle:String = {
        return NSLocalizedString("calibration_notification_title", tableName: filename, bundle: Bundle.main, value: "Calibration", comment: "If user must calibrate, this is the title of the notification")
    }()

    static let calibrationNotificationRequestBody:String = {
        return NSLocalizedString("calibration_notification_body", tableName: filename, bundle: Bundle.main, value: "Click the notification to calibrate", comment: "If user must calibrate, this is the body of the notification")
    }()

    static let enterCalibrationValue:String = {
        return NSLocalizedString("enter_calibration_value", tableName: filename, bundle: Bundle.main, value: "Enter Calibration Value", comment: "When calibration alert goess off, user clicks the notification, app opens, dialog pops up, this is the text in the dialog")
    }()
    
    static let singlePointCalibration:String = {
        return NSLocalizedString("singlePointCalibration", tableName: filename, bundle: Bundle.main, value: "Standard", comment: "text for standard/single-point calibration")
    }()
    
    static let multiPointCalibration:String = {
        return NSLocalizedString("multiPointCalibration", tableName: filename, bundle: Bundle.main, value: "Multi-point", comment: "text for multi-point/non-fixed slope calibration")
    }()
    
}


