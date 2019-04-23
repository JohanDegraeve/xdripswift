import Foundation

class Texts_Alerts {
    static private let filename = "alerts"
    
    // MARK:- Body Text in the alerts
    static let highAlertBody: String = {
        return NSLocalizedString("alerts_highalertbody", tableName: filename, bundle: Bundle.main, value: "High Alert", comment: "When high alert rises, this is the start of the text shown in the body of the notification")
    }()
    
    static let veryHighAlertBody: String = {
        return NSLocalizedString("alerts_veryhighalertbody", tableName: filename, bundle: Bundle.main, value: "Very High Alert", comment: "When very high alert rises, this is the start of the text shown in the body of the notification")
    }()
    
    static let lowAlertBody: String = {
        return NSLocalizedString("alerts_lowalertbody", tableName: filename, bundle: Bundle.main, value: "Low Alert", comment: "When very low alert rises, this is the start of the text shown in the body of the notification")
    }()
    
    static let veryLowAlertBody: String = {
        return NSLocalizedString("alerts_verylowalertbody", tableName: filename, bundle: Bundle.main, value: "Very Low Alert", comment: "When very low alert rises, this is the start of the text shown in the body of the notification")
    }()
    
    static let snooze: String = {
        return NSLocalizedString("alerts_snooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Action text for alerts. This is the button that allows to snooze the alert")
    }()
    

}
