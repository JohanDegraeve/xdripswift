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


// Indentifiers for blood glucose range descriptions
public enum BgRangeDescription {
    
    /// bg range is "urgent" (either high or low)
    case urgent
    
    /// bg range is "not urgent" (either high or low)
    case notUrgent
    
    /// bg range is "in range"
    case inRange
    
    /// bg range is very high
    case urgentHigh
    
    /// bg range is very low
    case urgentLow
    
    /// bg is low but not urgent
    case low
    
    /// bg is high but not urgent
    case high
    
    /// bg is does not require a range description.
    ///
    /// Typically, this is when the user has panned the chart
    /// so the value won't need a specific colour at that point
    case rangeNR
    
    /// This is for mg/dL < 12
    case special
}
