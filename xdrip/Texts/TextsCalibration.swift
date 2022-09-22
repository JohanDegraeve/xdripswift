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
    
    static let calibrateButtonTitle:String = {
        return NSLocalizedString("calibrateButtonTitle", tableName: filename, bundle: Bundle.main, value: "Calibrate", comment: "the calibrate button title")
    }()
    
    static let calibrateAnywayButtonTitle:String = {
        return NSLocalizedString("calibrateAnywayButtonTitle", tableName: filename, bundle: Bundle.main, value: "Calibrate Anyway!", comment: "the calibrate anyway button title")
    }()
    
    static let okToCalibrate:String = {
        return NSLocalizedString("okToCalibrate", tableName: filename, bundle: Bundle.main, value: "Conditions are OK to calibrate", comment: "a message to inform that the BG values are OK to calibrate")
    }()
    
    static let waitToCalibrate:String = {
        return NSLocalizedString("waitToCalibrate", tableName: filename, bundle: Bundle.main, value: "You may calibrate, but it would be better to wait", comment: "a message to inform that the user whould wait before calibrate")
    }()
    
    static let doNotCalibrate:String = {
        return NSLocalizedString("doNotCalibrate", tableName: filename, bundle: Bundle.main, value: "You should not calibrate now. Wait for a better time", comment: "a message to inform that the user should not calibrate")
    }()
    
    static let bgValuesRising:String = {
        return NSLocalizedString("bgValuesRising", tableName: filename, bundle: Bundle.main, value: "BG values have been rising", comment: "a message to inform that the BG values have been rising too much to calibrate")
    }()
    
    static let bgValuesDropping:String = {
        return NSLocalizedString("bgValuesDropping", tableName: filename, bundle: Bundle.main, value: "BG values have been dropping", comment: "a message to inform that the BG values have been dropping too much to calibrate")
    }()
    
    static let bgValuesNotStable:String = {
        return NSLocalizedString("bgValuesNotStable", tableName: filename, bundle: Bundle.main, value: "BG values are not stable enough", comment: "a message to inform that the BG values are not stable enough to calibrate")
    }()
    
    static let bgValueTooHigh:String = {
        return NSLocalizedString("bgValueTooHigh", tableName: filename, bundle: Bundle.main, value: "Current BG value is too high", comment: "a message to inform that the current BG value is too high to calibrate")
    }()
    
    static let bgValuesSlightlyHigh:String = {
        return NSLocalizedString("bgValuesSlightlyHigh", tableName: filename, bundle: Bundle.main, value: "Current BG value is slightly high", comment: "a message to inform that the current BG value is slightly high to calibrate")
    }()
    
    static let bgValueTooLow:String = {
        return NSLocalizedString("bgValueTooLow", tableName: filename, bundle: Bundle.main, value: "Current BG value is too low", comment: "a message to inform that the current BG value is too low to calibrate")
    }()
    
    static let bgValuesSlightlyLow:String = {
        return NSLocalizedString("bgValuesSlightlyLow", tableName: filename, bundle: Bundle.main, value: "Current BG value is slightly low", comment: "a message to inform that the current BG value is slightly low to calibrate")
    }()
    
    
}


