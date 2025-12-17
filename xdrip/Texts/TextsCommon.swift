import Foundation

// all common texts 
class Texts_Common {
    static private let filename = "Common"
    
    static let Ok = {
        return NSLocalizedString("common_Ok", tableName: filename, bundle: Bundle.main, value: "OK", comment: "literally 'OK'")
    }()
    
    //common_cancel
    static let Cancel = {
        return NSLocalizedString("common_cancel", tableName: filename, bundle: Bundle.main, value: "Cancel", comment: "literally 'Cancel'")
    }()
    
    static let mgdl: String = {
        return NSLocalizedString("common_mgdl", tableName: filename, bundle: Bundle.main, value: "mg/dL", comment: "mg/dL")
    }()

    static let mmol: String = {
        return NSLocalizedString("common_mmol", tableName: filename, bundle: Bundle.main, value: "mmol/L", comment: "mmol/L")
    }()

    static let bloodGlucoseUnit: String = {
        return NSLocalizedString("common_bloodglucoseunit", tableName: filename, bundle: Bundle.main, value: "Blood Glucose Unit", comment: "can be used in several screens, just the words Bloodglucose unit")
    }()
    
    static let bloodGlucoseUnitShort:String = {
        return NSLocalizedString("common_bloodglucoseunit_short", tableName: filename, bundle: Bundle.main, value: "BG Unit", comment: "blood glucose unit in short, for text field title")
    }()
    
    static let password = {
        return NSLocalizedString("common_password", tableName: filename, bundle: Bundle.main, value: "Password", comment: "literally password")
    }()
    
    static let username = {
        return NSLocalizedString("common_username", tableName: filename, bundle: Bundle.main, value: "Username", comment: "literally username")
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
    
    static let hourshort = {
        return NSLocalizedString("common_hourshort", tableName: filename, bundle: Bundle.main, value: "h", comment: "literal translation needed")
    }()
    
    static let hour = {
        return NSLocalizedString("common_hour", tableName: filename, bundle: Bundle.main, value: "hour", comment: "literal translation needed")
    }()
    
    static let hours = {
        return NSLocalizedString("common_hours", tableName: filename, bundle: Bundle.main, value: "hours", comment: "literal translation needed")
    }()
    
    static let minuteshort = {
        return NSLocalizedString("common_minuteshort", tableName: filename, bundle: Bundle.main, value: "m", comment: "literal translation needed")
    }()
    
    static let minutes = {
        return NSLocalizedString("common_minutes", tableName: filename, bundle: Bundle.main, value: "mins", comment: "literal translation needed")
    }()
    
    static let minute = {
        return NSLocalizedString("common_minute", tableName: filename, bundle: Bundle.main, value: "min", comment: "literal translation needed")
    }()
    
    static let dayshort = {
        return NSLocalizedString("common_dayshort", tableName: filename, bundle: Bundle.main, value: "d", comment: "literal translation needed")
    }()
    
    static let day = {
        return NSLocalizedString("common_day", tableName: filename, bundle: Bundle.main, value: "day", comment: "literal translation needed")
    }()
    
    static let days = {
        return NSLocalizedString("common_days", tableName: filename, bundle: Bundle.main, value: "days", comment: "literal translation needed")
    }()
    
    static let today = {
        return NSLocalizedString("common_today", tableName: filename, bundle: Bundle.main, value: "Today", comment: "the word today")
    }()
    
    static let todayshort = {
        return NSLocalizedString("common_todayshort", tableName: filename, bundle: Bundle.main, value: "Today", comment: "the word today")
    }()
    
    static let week = {
        return NSLocalizedString("common_week", tableName: filename, bundle: Bundle.main, value: "week", comment: "literal translation needed")
    }()
    
    static let warning = {
        return NSLocalizedString("warning", tableName: filename, bundle: Bundle.main, value: "Warning!", comment: "literally warning")
    }()
 
    static let update = {
        return NSLocalizedString("update", tableName: filename, bundle: Bundle.main, value: "Edit", comment: "literally update")
    }()

    static let add = {
        return NSLocalizedString("add", tableName: filename, bundle: Bundle.main, value: "Add", comment: "literally add")
    }()
    
    static let yes = {
        return NSLocalizedString("yes", tableName: filename, bundle: Bundle.main, value: "Yes", comment: "literally yes, without capital")
    }()
    
    static let no = {
        return NSLocalizedString("no", tableName: filename, bundle: Bundle.main, value: "No", comment: "literally no, without capital")
    }()
    
    static let red = {
        return NSLocalizedString("red", tableName: filename, bundle: Bundle.main, value: "red", comment: "red")
    }()
    
    static let green = {
        return NSLocalizedString("green", tableName: filename, bundle: Bundle.main, value: "green", comment: "green")
    }()
    
    static let white = {
        return NSLocalizedString("white", tableName: filename, bundle: Bundle.main, value: "white", comment: "white")
    }()
    
    static let yellow = {
        return NSLocalizedString("yellow", tableName: filename, bundle: Bundle.main, value: "yellow", comment: "yellow")
    }()
    
    static let black = {
        return NSLocalizedString("black", tableName: filename, bundle: Bundle.main, value: "black", comment: "black")
    }()
    
    static let name = {
        return NSLocalizedString("name", tableName: filename, bundle: Bundle.main, value: "Name:", comment: "name")
    }()
    
    static let WiFi = {
        return NSLocalizedString("WiFi", tableName: filename, bundle: Bundle.main, value: "WiFi", comment: "WiFi")
    }()
    
    static let on = {
        return NSLocalizedString("on", tableName: filename, bundle: Bundle.main, value: "On", comment: "on")
    }()

    static let off = {
        return NSLocalizedString("Off", tableName: filename, bundle: Bundle.main, value: "off", comment: "off")
    }()

    static let delete = {
        return NSLocalizedString("Delete", tableName: filename, bundle: Bundle.main, value: "Delete", comment: "Delete")
    }()
    
    static let invalidValue = {
        return NSLocalizedString("invalidValue", tableName: filename, bundle: Bundle.main, value: "Invalid Value", comment: "whenever invalid value is given by user somewhere in a field")
    }()
    
    static let firmware = {
        return NSLocalizedString("firmware", tableName: filename, bundle: Bundle.main, value: "Firmware", comment: "for settings row, literally firmware")
    }()
    
    static let hardware = {
        return NSLocalizedString("hardware", tableName: filename, bundle: Bundle.main, value: "Hardware", comment: "for settings row, literally hardware")
    }()
    
    static let unknown = {
        return NSLocalizedString("unknown", tableName: filename, bundle: Bundle.main, value: "Unknown", comment: "general usage")
    }()
    
    static let sensorStatus = {
        return NSLocalizedString("sensorStatus", tableName: filename, bundle: Bundle.main, value: "Sensor Status", comment: "to show the sensor status")
    }()
    
    static let invalidAccountOrPassword = {
        return NSLocalizedString("invalidAccountOrPassword", tableName: filename, bundle: Bundle.main, value: "Invalid account or password", comment: "Where credentials need to be given, if either account or password is invalid (for the moment only applicable to Dexcom Share")
    }()
    

    static let lowStatistics = {
        return NSLocalizedString("common_statistics_low", tableName: filename, bundle: Bundle.main, value: "Low", comment: "the word low")
    }()
    
    static let inRangeStatistics = {
        return NSLocalizedString("common_statistics_inRange", tableName: filename, bundle: Bundle.main, value: "In Range", comment: "the words in range")
    }()
    
    static let inTightRangeStatistics = {
        return NSLocalizedString("common_statistics_inTightRange", tableName: filename, bundle: Bundle.main, value: "Tight Range", comment: "the words in tight range")
    }()
    
    static let userRangeStatistics = {
        return NSLocalizedString("common_statistics_userRange", tableName: filename, bundle: Bundle.main, value: "User Range", comment: "the words in user range")
    }()
    
    static let highStatistics = {
        return NSLocalizedString("common_statistics_high", tableName: filename, bundle: Bundle.main, value: "High", comment: "the word high")
    }()
    
    static let averageStatistics = {
        return NSLocalizedString("common_statistics_average", tableName: filename, bundle: Bundle.main, value: "Average", comment: "the word average")
    }()
    
    static let a1cStatistics = {
        return NSLocalizedString("common_statistics_a1c", tableName: filename, bundle: Bundle.main, value: "HbA1c", comment: "phrase HbA1c")
    }()
    
    static let cvStatistics = {
        return NSLocalizedString("common_statistics_cv", tableName: filename, bundle: Bundle.main, value: "CV", comment: "coefficient of variation")
    }()
    
    static let dontShowAgain = {
        return NSLocalizedString("common_dontshowagain", tableName: filename, bundle: Bundle.main, value: "Don't Show Again", comment: "don't show again")
    }()
    
    static let enabled = {
        return NSLocalizedString("common_enabled", tableName: filename, bundle: Bundle.main, value: "Enabled", comment: "enabled")
    }()
    
    static let disabled = {
        return NSLocalizedString("common_disabled", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "disabled")
    }()
    
    static let notRequired = {
        return NSLocalizedString("common_notRequired", tableName: filename, bundle: Bundle.main, value: "Not required", comment: "not required")
    }()
    
    static let next = {
        return NSLocalizedString("common_next", tableName: filename, bundle: Bundle.main, value: "Next", comment: "next")
    }()
    
    static let checking = {
        return NSLocalizedString("common_checking", tableName: filename, bundle: Bundle.main, value: "Checking...", comment: "checking")
    }()
}
