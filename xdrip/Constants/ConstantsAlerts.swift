import Foundation

enum ConstantsAlerts {
    
    /// - to avoid that a specific alert gets raised for instance every minute, this is the default delay used
    /// - the actual delay used is first read from UserDefaults (settings), if not present then this value here is used
    static let defaultDelayBetweenAlertsOfSameKindInMinutes = 5
    
}
