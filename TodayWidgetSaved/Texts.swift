import Foundation

// all common texts 
class Texts {
    static private let filename = "Common"
    
    static let minutes = {
        return NSLocalizedString("common_minutes", tableName: filename, bundle: Bundle.main, value: "mins", comment: "literal translation needed")
    }()
    
    static let minute = {
        return NSLocalizedString("common_minute", tableName: filename, bundle: Bundle.main, value: "min", comment: "literal translation needed")
    }()
    
    static let HIGH = {
        return NSLocalizedString("common_high", tableName: filename, bundle: Bundle.main, value: "HIGH", comment: "the word HIGH, in capitals")
    }()
    
    static let LOW = {
        return NSLocalizedString("common_low", tableName: filename, bundle: Bundle.main, value: "LOW", comment: "the word LOW, in capitals")
    }()
        
    static let mgdl: String = {
        return NSLocalizedString("common_mgdl", tableName: filename, bundle: Bundle.main, value: "mg/dL", comment: "mg/dL")
    }()

    static let mmol: String = {
        return NSLocalizedString("common_mmol", tableName: filename, bundle: Bundle.main, value: "mmol/L", comment: "mmol/L")
    }()

    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()

}
