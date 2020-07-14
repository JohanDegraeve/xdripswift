import Foundation

class TextsLibreStates {
    
    static private let filename = "LibreStates"
    
    static let notYetStarted: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "not yet started", comment: "Possible Libre Sensor states")
    }()
    
    static let starting: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "starting", comment: "Possible Libre Sensor states")
    }()
    
    static let ready: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "ready", comment: "Possible Libre Sensor states")
    }()
    
    static let expired: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "expired", comment: "Possible Libre Sensor states")
    }()
    
    static let shutdown: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "shut down", comment: "Possible Libre Sensor states")
    }()
    
    static let failure: String = {
        return NSLocalizedString("notYetStarted", tableName: filename, bundle: Bundle.main, value: "failed", comment: "Possible Libre Sensor states")
    }()
    
    static let unknown: String = {
        return NSLocalizedString("unknown", tableName: filename, bundle: Bundle.main, value: "unknown", comment: "Possible Libre Sensor states")
    }()
    

}
