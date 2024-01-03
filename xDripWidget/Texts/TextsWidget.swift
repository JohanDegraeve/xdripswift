import Foundation

// all common texts 
class Texts_Widget {
    static private let filename = "TextsWidget"
    
    static let minutes = {
        return NSLocalizedString("widget_minutes", tableName: filename, bundle: Bundle.main, value: "mins", comment: "literal translation needed")
    }()
    
    static let minute = {
        return NSLocalizedString("widget_minute", tableName: filename, bundle: Bundle.main, value: "min", comment: "literal translation needed")
    }()
    
    static let high = {
        return NSLocalizedString("widget_high", tableName: filename, bundle: Bundle.main, value: "High", comment: "the word HIGH, in capitals")
    }()
    
    static let low = {
        return NSLocalizedString("widget_low", tableName: filename, bundle: Bundle.main, value: "Low", comment: "the word LOW, in capitals")
    }()
    
    static let urgentHigh = {
        return NSLocalizedString("widget_urgentHigh", tableName: filename, bundle: Bundle.main, value: "Urgent High", comment: "the words urgent HIGH, in capitals")
    }()
    
    static let urgentLow = {
        return NSLocalizedString("widget_urgentLow", tableName: filename, bundle: Bundle.main, value: "Urgent Low", comment: "the words urgent LOW, in capitals")
    }()
        
    static let mgdl: String = {
        return NSLocalizedString("widget_mgdl", tableName: filename, bundle: Bundle.main, value: "mg/dL", comment: "mg/dL")
    }()

    static let mmol: String = {
        return NSLocalizedString("widget_mmol", tableName: filename, bundle: Bundle.main, value: "mmol/L", comment: "mmol/L")
    }()

    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()

}
