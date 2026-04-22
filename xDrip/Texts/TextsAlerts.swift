import Foundation

/// all texts for Alerts related texts (texts in notifications, etc.) and Alert Settings Views related texts
class Texts_Alerts {
    static private let filename = "Alerts"
    
    // MARK:- Body Text in the alerts
    static let highAlertTitle: String = {
        return NSLocalizedString("alerts_highalerttitle", tableName: filename, bundle: Bundle.main, value: "High Alarm", comment: "When high alarm rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alarm")
    }()
    
    static let veryHighAlertTitle: String = {
        return NSLocalizedString("alerts_veryhighalerttitle", tableName: filename, bundle: Bundle.main, value: "Very High Alarm", comment: "When very high alert rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let lowAlertTitle: String = {
        return NSLocalizedString("alerts_lowalerttitle", tableName: filename, bundle: Bundle.main, value: "Low Alarm", comment: "When very low alert rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let veryLowAlertTitle: String = {
        return NSLocalizedString("alerts_verylowalerttitle", tableName: filename, bundle: Bundle.main, value: "Very Low Alarm", comment: "When very low alert rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let missedReadingAlertTitle: String = {
        return NSLocalizedString("alerts_missedreadingalerttitle", tableName: filename, bundle: Bundle.main, value: "Missed Readings", comment: "When Missed reading alert happens, this is the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let calibrationNeededAlertTitle: String = {
        return NSLocalizedString("alerts_calibrationneeded", tableName: filename, bundle: Bundle.main, value: "Calibration Reminder", comment: "when calibration is needed, this is the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let batteryLowAlertTitle: String = {
        return NSLocalizedString("alerts_batterylow", tableName: filename, bundle: Bundle.main, value: "Transmitter Battery Low", comment: "transmitter battery low, this is the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let phoneBatteryLowAlertTitle: String = {
        return NSLocalizedString("alerts_phonebatterylow", tableName: filename, bundle: Bundle.main, value: "Phone Battery Low", comment: "phone battery low, this is the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let fastDropTitle: String = {
        return NSLocalizedString("alerts_fastdrop", tableName: filename, bundle: Bundle.main, value: "Fast Drop Alarm", comment: "When fast drop alert rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alert")
    }()

    static let fastRiseTitle: String = {
        return NSLocalizedString("alerts_fastrise", tableName: filename, bundle: Bundle.main, value: "Fast Rise Alarm", comment: "When fast drop alert rises, this is the start of the text shown in the title of the alert notification, also in alert settings list, for the name of the alert")
    }()
    
    static let snooze: String = {
        return NSLocalizedString("alerts_snooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Action text for alerts. This is the button that allows to snooze the alert")
    }()
    
    static let selectSnoozeTime: String = {
        return NSLocalizedString("alerts_select_snooze_time", tableName: filename, bundle: Bundle.main, value: "Select Snooze Time", comment: "When pop up is shown to let user pick the snooze time, this is the title of this pop up")
    }()
    
    static let alertsScreenTitle: String = {
        return NSLocalizedString("alertssettingsview_screentitle", tableName: filename, bundle: Bundle.main, value: "Alarms", comment: "shown on top of the screen that allows user to view all the alerts in one table")
    }()
    
    static let editAlertScreenTitle: String = {
        return NSLocalizedString("alertsettingsview_screentitle", tableName: filename, bundle: Bundle.main, value: "Edit Alarm", comment: "shown on top of the screen that allows user to edit an alert")
    }()

    static let alertStart: String = {
        return NSLocalizedString("alertstart", tableName: filename, bundle: Bundle.main, value: "Apply from:", comment: "an alert is applicable as of a certain timestamp in the day, this is the text in the field in the settings screen that allows to modify this timestamp")
    }()
    
    static let alertValue: String = {
        return NSLocalizedString("alertvalue", tableName: filename, bundle: Bundle.main, value: "Value", comment: "an alert is applicable as of a certain value (eg low alert as of 70 mg/dl), this is the name of the field in the settings screen that allows to modify this valule")
    }()
    
    static let alertWhenBelowValue: String = {
        return NSLocalizedString("alertWhenBelowValue", tableName: filename, bundle: Bundle.main, value: "Only When Below", comment: "an alert is only triggered when below a certain value")
    }()
    
    static let alertWhenAboveValue: String = {
        return NSLocalizedString("alertWhenAboveValue", tableName: filename, bundle: Bundle.main, value: "Only When Above", comment: "an alert is only triggered when above a certain value")
    }()
    
    static let alerttype: String = {
        return NSLocalizedString("alerttype", tableName: filename, bundle: Bundle.main, value: "Alarm Type", comment: "an alert is applicable as of a certain value (eg low alert as of 70 mg/dl), this is the name of the field in the settings screen that allows to modify this valule")
    }()
    
    static let changeAlertValue: String = {
        return NSLocalizedString("changealertvalue", tableName: filename, bundle: Bundle.main, value: "Change Alarm Value", comment: "when editing an alert value, a pop is shown, this is the explanation message in the pop up")
    }()
    
    static let changeAlertTriggerValue: String = {
        return NSLocalizedString("changeAlertTriggerValue", tableName: filename, bundle: Bundle.main, value: "Change Alarm Trigger Value", comment: "when editing an alert trigger value, a pop is shown, this is the explanation message in the pop up")
    }()
    
    static let confirmDeletionAlert: String = {
        return NSLocalizedString("confirmdeletionalert", tableName: filename, bundle: Bundle.main, value: "Delete Alarm?", comment: "when trying to delete an alert, user needs to confirm first, this is the message")
    }()
    
    static let alertTypeUrgent: String = {
        return NSLocalizedString("alertTypeUrgent", tableName: filename, bundle: Bundle.main, value: "Urgent", comment: "text to show an urgent alarm type")
    }()
    
    static let alertTypeWarning: String = {
        return NSLocalizedString("alertTypeWarning", tableName: filename, bundle: Bundle.main, value: "Warning", comment: "text to show a warning alarm type")
    }()
    
}
