import Foundation

extension Bundle {
    var appGroupSuiteName: String {
        return object(forInfoDictionaryKey: "AppGroupIdentifier") as! String
    }
    
    var appGroupSuiteNameTrio: String {
        return object(forInfoDictionaryKey: "AppGroupIdentifierTrio") as! String
    }
    
    var mainAppBundleIdentifier: String {
        return object(forInfoDictionaryKey: "MainAppBundleIdentifier") as! String
    }
}
