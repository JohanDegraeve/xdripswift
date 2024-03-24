import Foundation

enum ConstantsWatch {
    
    /// text to add as notes in glucose events
    static let textInCreatedEvent = "created by xDrip4iOS"
    
    /// text to use as the visual indicator in the calendar title when bg is "Urgent"
    static let visualIndicatorUrgent = "🔴"
    
    /// text to use as the visual indicator in the calendar title when bg is "Not Urgent"
    static let visualIndicatorNotUrgent = "🟡"
    
    /// text to use as the visual indicator in the calendar title when bg is "In Range"
    static let visualIndicatorInRange = "🟢"
}

// MARK: - Used in the AGP

// Indentifiers for blood glucose range descriptions
public enum BgRangeDescription: Int {
    
    /// Specific case for very hgh
    case urgentHigh = 4
    
    /// Specific case for high
    case high = 3
    
    /// bg range is "in range"
    case inRange = 2
    
    /// Specific case for low
    case low = 1
    
    /// Specific case for very low
    case urgentLow = 0
    
    /// bg range is "not urgent" (either high or low)
    case notUrgent = 6
    
    // ---------------------------
    
    /// Case for when we need to display a special message
    case special = -1
    
    /// bg range is "urgent" (either high or low)
    case urgent = -2
    
    /// TBC
    case rangeNR = -3
    
    var descriptions: String {
        switch self {
        case .urgentHigh:
            return "Urgent High"
        case .high:
            return "High"
        case .inRange:
            return "In Range"
        case .low:
            return "Low"
        case .urgentLow:
            return "Urgent Low"
        case .notUrgent:
            return "Not Urgent"
        case .special:
            return "Special"
        case .urgent:
            return "Urgent"
        case .rangeNR:
            return "RangeNR TBC"
        }
    }
}
