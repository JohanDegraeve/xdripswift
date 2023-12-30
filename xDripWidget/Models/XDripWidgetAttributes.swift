//
//  XDripWidgetAttributes.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 30/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct XDripWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        
        enum EventType: Float, Codable, Hashable {
            case urgentLowDropping
            case urgentLow
            case urgentLowRising
            case lowDropping
            case low
            case lowRising
            case inRangeDropping
            case inRange
            case inRangeRising
            case highDropping
            case high
            case highRising
            case urgentHighDropping
            case urgentHigh
            case urgentHighRising
            
            var title: String {
                switch self {
                    
                case .high, .highDropping, .highRising:
                    return "HIGH"
                case .inRange, .inRangeDropping, .inRangeRising:
                    return "IN RANGE"
                case .low, .lowDropping, .lowRising:
                    return "LOW"
                case .urgentHigh, .urgentHighDropping, .urgentHighRising:
                    return "VERY HIGH"
                case .urgentLow, .urgentLowDropping, .urgentLowRising:
                    return "VERY LOW"
                }
            }
            
            var explanation: String {
                switch self {
                    
                case .high:
                    return "You're not rising anymore"
                case .highDropping:
                    return "You're starting to drop down to range"
                case .highRising:
                    return "⚠️ You're still rising"
                case .inRange:
                    return "Everything's looking good"
                case .inRangeDropping:
                    return "All good, but dropping"
                case .inRangeRising:
                    return "All good, but rising"
                case .low:
                    return "You're not dropping anymore"
                case .lowDropping:
                    return "⚠️ You're still dropping"
                case .lowRising:
                    return "You're starting to rise back up"
                case .urgentHigh:
                    return "You're not rising anymore but still very high"
                case .urgentHighDropping:
                    return "You're starting to drop down to range"
                case .urgentHighRising:
                    return "‼️ You're still rising"
                case .urgentLow:
                    return "‼️ You are still too low"
                case .urgentLowDropping:
                    return "‼️ You're low and still dropping"
                case .urgentLowRising:
                    return "You're starting to come up to range"
                }
            }
        }
        
        
        // Dynamic stateful properties about your activity go here!
        var eventType: EventType
        var trendArrow: String
        var bgValueString: String
        
        init(eventType: EventType = .lowDropping, trendArrow: String = "↘", bgValueString: String = "64") {
            self.eventType = eventType
            self.trendArrow = trendArrow
            self.bgValueString = bgValueString
        }
    }

    // Fixed non-changing properties about your activity go here!
    var bgValueUnitString: String
    var eventStartDate: Date
}
