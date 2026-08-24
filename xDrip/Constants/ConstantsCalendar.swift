//
//  ConstantsCalendar.swift
//  xdrip
//
//  Created by Paul Plant on 24/10/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsCalendar {
    
    /// prefix before the encoded calendar share payload in event notes
    static let calendarSharePayloadPrefix = "xdripswift:"

    /// minimum cadence for Calendar Share readings, to avoid sharing one-minute source values downstream.
    static let minimumTimeBetweenTwoSharedReadingsInMinutes = 4.75
    
    /// text to use as the visual indicator in the calendar title when bg is "Urgent"
    static let visualIndicatorUrgent = "🔴"
    
    /// text to use as the visual indicator in the calendar title when bg is "Not Urgent"
    static let visualIndicatorNotUrgent = "🟡"
    
    /// text to use as the visual indicator in the calendar title when bg is "In Range"
    static let visualIndicatorInRange = "🟢"

}

enum CalendarShareStatus: String {
    case notConfigured
    case active
    case waiting
    case noData
    case stale
    case error

    var description: String {
        switch self {
        case .notConfigured:
            return "Setup Needed"
        case .active:
            return "Active"
        case .waiting:
            return "Waiting"
        case .noData:
            return "No Data"
        case .stale:
            return "Stale"
        case .error:
            return "Error"
        }
    }
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
