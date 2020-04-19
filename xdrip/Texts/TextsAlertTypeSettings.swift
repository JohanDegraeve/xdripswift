import Foundation

/// all texts for Alert Type Settings Views related texts
class Texts_AlertTypeSettingsView {
    static private let filename = "AlertTypesSettingsView"
    
    // MARK: - Title of the screen
    
    static let alertTypesScreenTitle: String = {
        return NSLocalizedString("alerttypessettingsview_screentitle", tableName: filename, bundle: Bundle.main, value: "Alarm Types", comment: "shown on top of the screen that allows user to view all the alert types or add a new alert type")
    }()
    
    static let editAlertTypeScreenTitle: String = {
        return NSLocalizedString("alerttypesettingsview_screentitle", tableName: filename, bundle: Bundle.main, value: "Edit Alarm Type", comment: "shown on top of the screen that allows user to edit an alert type")
    }()
    
    static let alertTypeName: String = {
        return NSLocalizedString("alerttypesettingsview_name", tableName: filename, bundle: Bundle.main, value: "Name", comment: "when editing an alert type, field title for name")
    }()

    static let alertTypeEnabled: String = {
        return NSLocalizedString("alerttypesettingsview_enabled", tableName: filename, bundle: Bundle.main, value: "Enabled", comment: "when editing an alert type, field title for Enabled")
    }()
    
    static let alertTypeVibrate: String = {
        return NSLocalizedString("alerttypesettingsview_vibrate", tableName: filename, bundle: Bundle.main, value: "Vibrate", comment: "when editing an alert type, field title for Vibrate")
    }()
    
    static let alertTypeSnoozeViaNotification: String = {
        return NSLocalizedString("alerttypesettingsview_snoozevianotification", tableName: filename, bundle: Bundle.main, value: "Snooze Via Notification", comment: "when editing an alert type, field title for Snooze Via Notification")
    }()
    
    static let alertTypeDefaultSnoozePeriod: String = {
        return NSLocalizedString("alerttypesettingsview_defaultsnoozeperiod", tableName: filename, bundle: Bundle.main, value: "Default Snooze Time (mins)", comment: "when editing an alert type, field title for Snooze Period")
    }()
    
    static let alertTypeOverrideMute: String = {
        return NSLocalizedString("alerttypesettingsview_overridemute", tableName: filename, bundle: Bundle.main, value: "Override Mute", comment: "when editing an alert type, field title for Override Mute")
    }()
    
    static let alertTypeSound: String = {
        return NSLocalizedString("alerttypesettingsview_sound", tableName: filename, bundle: Bundle.main, value: "Sound", comment: "when editing an alert type, field title for Sound")
    }()
    
    static let alertTypeDefaultIOSSound: String = {
        return NSLocalizedString("alerttypesettingsview_defaultiossound", tableName: filename, bundle: Bundle.main, value: "iOS Sound", comment: "when editing an alert type, if alert type sound name is default iOS sound")
    }()
    
    static let alertTypeGiveAName: String = {
        return NSLocalizedString("alerttypesettingsview_givename", tableName: filename, bundle: Bundle.main, value: "Alarm Name", comment: "when editing the name of an alert type, ")
    }()

    static let alertTypeGiveSnoozePeriod: String = {
        return NSLocalizedString("alerttypesettingsview_givesnoozeperiod", tableName: filename, bundle: Bundle.main, value: "Snooze Time in Minutes", comment: "when editing the snoozeperiod of an alert type, ")
    }()
    
    static let alertTypePickSoundName: String = {
        return NSLocalizedString("alerttypesettingsview_picksoundname", tableName: filename, bundle: Bundle.main, value: "Sound Name", comment: "when selecting the sound of an alert type, ")
    }()
    
    static let alertTypeNoSound: String = {
        return NSLocalizedString("alerttypesettingsview_nosound", tableName: filename, bundle: Bundle.main, value: "No Sound", comment: "when selecting the sound of an alert type, this is for no sound")
    }()
    
    static let alertTypeNameAlreadyExistsMessage: String = {
        return NSLocalizedString("alerttypenamealreadyexistsmessages", tableName: filename, bundle: Bundle.main, value: "An Alarm Type with this name already exists. Use a different name", comment: "when adding a new alert type, but the name is already used for another alert type, this is the error messages")
    }()

    static let confirmDeletionAlertType: String = {
        return NSLocalizedString("confirmdeletionalerttype", tableName: filename, bundle: Bundle.main, value: "Delete Alarm Type: ", comment: "when trying to delete an alert type, user needs to confirm first, this is the message")
    }()
    


}
