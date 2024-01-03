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
        
        // store the activity id here to enable us to remove it in case it is stale
        //var previousActivityID: String
        //var activityID: String
        
        // Dynamic stateful properties about your activity go here!
        var bgValueInMgDl: Double
        var isMgDl: Bool
//        var trendArrow: String
        var slopeOrdinal: Int
        var deltaChangeInMgDl: Double?
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        var bgReadingDate: Date
        var updatedDate: Date
        
        var bgValueStringInUserChosenUnit: String
        var bgUnitString: String
//        var deltaChangeStringInUserChosenUnit: String
        
        init(bgValueInMgDl: Double, isMgDl: Bool, slopeOrdinal: Int, deltaChangeInMgDl: Double?, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, bgReadingDate: Date, updatedDate: Date) {
            
            // these are the "passed in" stateful values used to initialize
            self.bgValueInMgDl = bgValueInMgDl
            self.isMgDl = isMgDl
//            self.trendArrow = trendArrow
            self.slopeOrdinal = slopeOrdinal
            self.deltaChangeInMgDl = deltaChangeInMgDl// ?? nil
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
            self.lowLimitInMgDl = lowLimitInMgDl
            self.highLimitInMgDl = highLimitInMgDl
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
            self.bgReadingDate = bgReadingDate
            self.updatedDate = updatedDate
            
            // these are dynamically initialized based on the above
            //self.bgValueInUserChosenUnit = bgValueInMgDl.mgdlToMmol(mgdl: isMgDl)
            self.bgUnitString = isMgDl ? Texts_Widget.mgdl : Texts_Widget.mmol
            self.bgValueStringInUserChosenUnit = bgValueInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
            //self.deltaChangeStringInUserChosenUnit = deltaChangeInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
            
            
        }
        
        /// Blood glucose color dependant on the user defined limit values
        /// - Returns: a Color object either red, yellow or green
        func getBgColor() -> Color {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        }
        
        /// Show the bg event title if relevant
        /// - Returns: a localized string such as "HIGH" or "LOW" as required
        func getBgTitle() -> String {
            
            if bgValueInMgDl >= urgentHighLimitInMgDl {
                return Texts_Widget.urgentHigh
            } else if bgValueInMgDl >= highLimitInMgDl {
                return Texts_Widget.high
            } else if bgValueInMgDl <= lowLimitInMgDl {
                return Texts_Widget.low
            } else if bgValueInMgDl <= urgentLowLimitInMgDl {
                return Texts_Widget.urgentLow
            } else {
                return ""
            }
        }
        
        /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
        /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
        func getDeltaChangeStringInUserChosenUnit() -> String {
            
            if let deltaChangeInMgDl = deltaChangeInMgDl {
                
                let valueAsString = deltaChangeInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
                
                var deltaSign: String = ""
                if (deltaChangeInMgDl > 0) { deltaSign = "+"; }
                
                // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
                // show unitized zero deltas as +0 or +0.0 as per Nightscout format
                if (isMgDl) {
                    if (deltaChangeInMgDl > -1) && (deltaChangeInMgDl < 1) {
                        return "+0"
                    } else {
                        return deltaSign + valueAsString
                    }
                } else {
                    if (deltaChangeInMgDl > -0.1) && (deltaChangeInMgDl < 0.1) {
                        return "+0.0"
                    } else {
                        return deltaSign + valueAsString
                    }
                }
            } else {
                return ""
            }
        }
        
        ///  returns a string holding the trend arrow
        /// - Returns: trend arrow string (i.e.  "↑")
        func trendArrow() -> String {
            
            switch slopeOrdinal {
            case 7:
                return "\u{2193}\u{2193}" // ↓↓
            case 6:
                return "\u{2193}" // ↓
            case 5:
                return "\u{2198}" // ↘
            case 4:
                return "\u{2192}" // →
            case 3:
                return "\u{2197}" // ↗
            case 2:
                return "\u{2191}" // ↑
            case 1:
                return "\u{2191}\u{2191}" // ↑↑
            default:
                return "n/a"
                
            }
            
        }
        
    }

    // when was the live activity event started? We check this on each update cycle and dismiss/recreate it before the 8-hour limit.
    var eventStartDate: Date
}
