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

        // Store values with a 16 bit precision to save payload bytes
        private var bgReadingFloats: [Float16]
        // Expose those conveniently as Doubles
        var bgReadingValues: [Double] {
            bgReadingFloats.map(Double.init)
        }

        // To save those precious payload bytes, store only the earliest date as Date
        private var firstDate: Date
        // ...and all other as seconds from that moment.
        // No need for floating points, a second is precise enough for the graph
        // UInt16 maximum value is 65535 so that means 18.2 hours.
        // This would need to be changed if wishing to present a 24 hour chart.
        private var secondsSinceFirstDate: [UInt16]
        // Expose the dates conveniently
        var bgReadingDates: [Date] {
            secondsSinceFirstDate.map { Date(timeInterval: Double($0), since: firstDate) }
        }

        var isMgDl: Bool
        var slopeOrdinal: Int
        var deltaChangeInMgDl: Double?
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        var eventStartDate: Date = Date()
        var warnUserToOpenApp: Bool = true
        var liveActivitySize: LiveActivitySize
        var dataSourceDescription: String

        var bgUnitString: String {
            isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        }
        /// the latest bg reading
        var bgValueInMgDl: Double? {
            bgReadingValues[0]
        }
        /// the latest bg reading date
        var bgReadingDate: Date? {
            bgReadingDates[0]
        }

        var bgValueStringInUserChosenUnit: String {
            bgReadingValues[0].mgdlToMmolAndToString(mgdl: isMgDl)
        }

        init(bgReadingValues: [Double], bgReadingDates: [Date], isMgDl: Bool, slopeOrdinal: Int, deltaChangeInMgDl: Double?, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivitySize: LiveActivitySize, dataSourceDescription: String? = "") {
        
            self.bgReadingFloats = bgReadingValues.map(Float16.init)

            let firstDate = bgReadingDates.last ?? .now
            self.firstDate = firstDate
            self.secondsSinceFirstDate = bgReadingDates.map { UInt16(truncatingIfNeeded: Int($0.timeIntervalSince(firstDate))) }
            
            self.isMgDl = isMgDl
            self.slopeOrdinal = slopeOrdinal
            self.deltaChangeInMgDl = deltaChangeInMgDl
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
            self.lowLimitInMgDl = lowLimitInMgDl
            self.highLimitInMgDl = highLimitInMgDl
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl            
            self.liveActivitySize = liveActivitySize
            self.dataSourceDescription = dataSourceDescription ?? ""
        }
        
        /// Blood glucose color dependant on the user defined limit values and based upon the time since the last reading
        /// - Returns: a Color object either red, yellow or green
        func bgTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, let bgValueInMgDl = bgValueInMgDl {
                if bgReadingDate > Date().addingTimeInterval(-60 * 7) {
                    if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                        return Color(.red)
                    } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                        return Color(.yellow)
                    } else {
                        return Color(.green)
                    }
                } else {
                    return Color.gray
                }
            } else {
                return Color.gray
            }
        }
        
        /// Delta text color dependant on the time since the last reading
        /// - Returns: a Color either red, yellow or green
        func deltaChangeTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-60 * 7) {
                return Color(white: 0.8)
            } else {
                return Color(.gray)
            }
        }
        
        /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
        /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
        func deltaChangeStringInUserChosenUnit() -> String {
            if let deltaChangeInMgDl = deltaChangeInMgDl {
                let deltaSign: String = deltaChangeInMgDl > 0 ? "+" : ""
                let valueAsString = deltaChangeInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
                
                // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
                // show unitized zero deltas as +0 or +0.0 as per Nightscout format
                if (isMgDl) {
                    return (deltaChangeInMgDl > -1 && deltaChangeInMgDl < 1) ?  "+0" : (deltaSign + valueAsString)
                } else {
                    return (deltaChangeInMgDl > -0.1 && deltaChangeInMgDl < 0.1) ? "+0.0" : (deltaSign + valueAsString)
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
                return ""
            }
        }
    }
}
