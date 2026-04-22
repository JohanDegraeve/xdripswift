//
//  AlertSnoozeStatus.swift
//  xdrip
//
//  Created by Paul Plant on 15/5/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// defines if the snooze status is inactive, non-urgent are snoozed, or urgent alarms are snoozed
/// also used to udpate the UI to reflect the snooze status
public enum AlertSnoozeStatus: Int {
    case inactive = 0
    case urgent = 1
    case notUrgent = 2
    case allSnoozed = 3
    
    var description: String {
        switch self {
        case .inactive:
            return "inactive"
        case .urgent:
            return "urgent"
        case .notUrgent:
            return "non-urgent"
        case .allSnoozed:
            return "all snoozed"
        }
    }
}
