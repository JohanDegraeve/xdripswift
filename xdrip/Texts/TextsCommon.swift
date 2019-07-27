import Foundation

// all common texts 
class Texts_Common {
    static private let filename = "Common"
    
    static let Ok = {
        return NSLocalizedString("common_Ok", tableName: filename, bundle: Bundle.main, value: "Ok", comment: "literally 'Ok'")
    }()
    
    //common_cancel
    static let Cancel = {
        return NSLocalizedString("common_cancel", tableName: filename, bundle: Bundle.main, value: "Cancel", comment: "literally 'Cancel'")
    }()
    
    static let mgdl: String = {
        return NSLocalizedString("common_mgdl", tableName: filename, bundle: Bundle.main, value: "mgdl", comment: "mgdl")
    }()

    static let mmol: String = {
        return NSLocalizedString("common_mmol", tableName: filename, bundle: Bundle.main, value: "mmol", comment: "mmol")
    }()

    static let bloodGLucoseUnit: String = {
        return NSLocalizedString("common_bloodglucoseunit", tableName: filename, bundle: Bundle.main, value: "Bloodglucose unit", comment: "can be used in several screens, just the words Bloodglucose unit")
    }()
    
    static let bloodGlucoxeUnitShort:String = {
        return NSLocalizedString("common_bloodglucoseunit_short", tableName: filename, bundle: Bundle.main, value: "Bg Unit", comment: "blood glucose unit in short, for text field title")
    }()
    
    static let password = {
        return NSLocalizedString("common_password", tableName: filename, bundle: Bundle.main, value: "Password", comment: "literally password")
    }()
    
    static let default0 = {
        return NSLocalizedString("common_default", tableName: filename, bundle: Bundle.main, value: "Default", comment: "literally default, will be the name of default alerttypes that will be created during initial app launch")
    }()

    static let HIGH = {
        return NSLocalizedString("common_high", tableName: filename, bundle: Bundle.main, value: "HIGH", comment: "the word HIGH, in capitals")
    }()
    
    static let LOW = {
        return NSLocalizedString("common_low", tableName: filename, bundle: Bundle.main, value: "LOW", comment: "the word LOW, in capitals")
    }()
    
    static let hour = {
        return NSLocalizedString("common_hour", tableName: filename, bundle: Bundle.main, value: "hour", comment: "literal translation needed")
    }()
    
    static let hours = {
        return NSLocalizedString("common_hours", tableName: filename, bundle: Bundle.main, value: "hours", comment: "literal translation needed")
    }()
    
    static let minutes = {
        return NSLocalizedString("common_minutes", tableName: filename, bundle: Bundle.main, value: "minutes", comment: "literal translation needed")
    }()
    
    static let minute = {
        return NSLocalizedString("common_minute", tableName: filename, bundle: Bundle.main, value: "minute", comment: "literal translation needed")
    }()
    
    static let day = {
        return NSLocalizedString("common_day", tableName: filename, bundle: Bundle.main, value: "day", comment: "literal translation needed")
    }()
    
    static let week = {
        return NSLocalizedString("common_week", tableName: filename, bundle: Bundle.main, value: "week", comment: "literal translation needed")
    }()
    
    static let warning = {
        return NSLocalizedString("warning", tableName: filename, bundle: Bundle.main, value: "Warning !", comment: "literally warning")
    }()
 
    static let update = {
        return NSLocalizedString("update", tableName: filename, bundle: Bundle.main, value: "Update", comment: "literally update")
    }()

    static let add = {
        return NSLocalizedString("add", tableName: filename, bundle: Bundle.main, value: "Add", comment: "literally add")
    }()
    
    static let yes = {
        return NSLocalizedString("yes", tableName: filename, bundle: Bundle.main, value: "yes", comment: "literally yes, without capital")
    }()
    
    static let no = {
        return NSLocalizedString("no", tableName: filename, bundle: Bundle.main, value: "no", comment: "literally no, without capital")
    }()
    
}
