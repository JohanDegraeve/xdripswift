import Foundation

class Texts_Alerts {
    static private let filename = "alerts"
    
    // MARK:- Body Text in the alerts
    static let highAlertTitle: String = {
        return NSLocalizedString("alerts_highalerttitle", tableName: filename, bundle: Bundle.main, value: "High Alert", comment: "When high alert rises, this is the start of the text shown in the title of the alert notification")
    }()
    
    static let veryHighAlertTitle: String = {
        return NSLocalizedString("alerts_veryhighalerttitle", tableName: filename, bundle: Bundle.main, value: "Very High Alert", comment: "When very high alert rises, this is the start of the text shown in the title of the alert notification")
    }()
    
    static let lowAlertTitle: String = {
        return NSLocalizedString("alerts_lowalerttitle", tableName: filename, bundle: Bundle.main, value: "Low Alert", comment: "When very low alert rises, this is the start of the text shown in the title of the alert notification")
    }()
    
    static let veryLowAlertTitle: String = {
        return NSLocalizedString("alerts_verylowalerttitle", tableName: filename, bundle: Bundle.main, value: "Very Low Alert", comment: "When very low alert rises, this is the start of the text shown in the title of the alert notification")
    }()
    
    static let missedReadingAlertTitle: String = {
        return NSLocalizedString("alerts_missedreadingalerttitle", tableName: filename, bundle: Bundle.main, value: "Missed Reading", comment: "When Missed reading alert happens, this is the title of the alert notification")
    }()
    
    static let calibrationNeededAlertTitle: String = {
        return NSLocalizedString("alerts_calibrationneeded", tableName: filename, bundle: Bundle.main, value: "Calibration Needed", comment: "when calibration is needed, this is the title of the alert notification")
    }()
    
    static let batteryLowAlertTitle: String = {
        return NSLocalizedString("alerts_batterylow", tableName: filename, bundle: Bundle.main, value: "Battery Low", comment: "transmitter battery low, this is the title of the alert notification")
    }()
    
    static let snooze: String = {
        return NSLocalizedString("alerts_snooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Action text for alerts. This is the button that allows to snooze the alert")
    }()
    
    static let selectSnoozeTime: String = {
        return NSLocalizedString("alerts_select_snooze_time", tableName: filename, bundle: Bundle.main, value: "Select Snooze Time", comment: "When pop up is shown to let user pick the snooze time, this is the title of this pop up")
    }()
    
}
