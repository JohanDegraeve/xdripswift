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
            
            var bgColorInt: Int {
                switch self {
                case .inRange, .inRangeDropping, .inRangeRising:
                    return 1
                case .urgentHigh, .urgentHighDropping, .urgentHighRising, .urgentLow, .urgentLowDropping, .urgentLowRising:
                    return 2
                case .high, .highDropping, .highRising, .low, .lowDropping, .lowRising:
                    return 3
                }
            }
        }
        
        
        // Dynamic stateful properties about your activity go here!
        var eventType: EventType
        var trendArrow: String
        var bgValueString: String
        var bgValueColorInt: Int
        
        init(eventType: EventType , trendArrow: String, bgValueString: String, bgValueColorInt: Int) {
            self.eventType = eventType
            self.trendArrow = trendArrow
            self.bgValueString = bgValueString
            self.bgValueColorInt = bgValueColorInt
            
            self.bgValueColorInt = getBgValueColor(bgValueString: bgValueString)
        }
        
        func getBgValueColor(bgValueString: String) -> Int {
            
            let bgValue: Float = Float(bgValueString) ?? 1
            
            switch bgValue {
            case 0..<70:
                return 1
            case 71..<80:
                return 3
            case 81..<140:
                return 2
            case 141...:
                return 3
            default:
                return 2
            }
            
        }
    }

    // Fixed non-changing properties about your activity go here!
    var bgValueUnitString: String
    var eventStartDate: Date
}
