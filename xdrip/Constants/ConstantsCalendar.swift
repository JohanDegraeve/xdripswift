import Foundation

enum ConstantsCalendar {
    
    /// text to add as notes in glucose events
    static let textInCreatedEvent = "created by xDrip4iOS"
    
    /// text to use as the visual indicator in the calendar title when bg is "Urgent"
    static let visualIndicatorUrgent = "🔴"
    
    /// text to use as the visual indicator in the calendar title when bg is "Not Urgent"
    static let visualIndicatorNotUrgent = "🟡"
    
    /// text to use as the visual indicator in the calendar title when bg is "In Range"
    static let visualIndicatorInRange = "🟢"
}


// Indentifiers for blood glucose range descriptions
enum BgRangeDescription {
    
    /// bg range is "urgent" (either high or low)
    case urgent
    
    /// bg range is "not urgent" (either high or low)
    case notUrgent
    
    /// bg range is "in range"
    case inRange
}
