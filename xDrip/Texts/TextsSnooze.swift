import Foundation

class TextsSnooze {
    
    static private let filename = "Snooze"
    
    static let not_snoozed: String = {
        return NSLocalizedString("not_snoozed", tableName: filename, bundle: Bundle.main, value: "Not snoozed", comment: "row text for overview snooze. Not snoozed alarm")
    }()
    
    static let snoozed_until: String = {
        return NSLocalizedString("snoozed_until", tableName: filename, bundle: Bundle.main, value: "Not snoozed", comment: "row text for overview snooze. Snoozed alarm, until .. followed by timestamp")
    }()
    
}
