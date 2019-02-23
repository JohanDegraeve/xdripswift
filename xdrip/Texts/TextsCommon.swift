import Foundation

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

}
