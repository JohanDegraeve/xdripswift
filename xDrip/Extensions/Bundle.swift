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

    /// Build-time override to remove outward OS-AID shared app group writes.
    var disableLoopShare: Bool {
        guard let rawValue = object(forInfoDictionaryKey: "DisableLoopShare") as? String else {
            return false
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "YES", "TRUE", "1":
            return true
        default:
            return false
        }
    }
}
