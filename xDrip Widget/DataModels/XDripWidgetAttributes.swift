//
//  XDripWidgetAttributes.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 30/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
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
        
        // For some reason, ActivityAttributes can't see the main target Assets folder
        // so we'll just duplicate the colors here for now
        // We have to store just the float value instead of the whole Color object to
        // keep the struct conforming to Codable
        private var colorPrimaryWhiteValue: Double = 0.9
        private var colorSecondaryWhiteValue: Double = 0.65
        private var colorTertiaryWhiteValue: Double = 0.45

        var isMgDl: Bool
        var slopeOrdinal: Int
        var deltaValueInUserUnit: Double?
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        var eventStartDate: Date = Date()
        var warnUserToOpenApp: Bool = true
        var liveActivityType: LiveActivityType
        var dataSourceDescription: String
        var followerPatientName: String?
        
        var deviceStatusCreatedAt: Date?
        var deviceStatusLastLoopDate: Date?

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

        init(bgReadingValues: [Double], bgReadingDates: [Date], isMgDl: Bool, slopeOrdinal: Int, deltaValueInUserUnit: Double?, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivityType: LiveActivityType, dataSourceDescription: String? = "", followerPatientName: String? = nil, deviceStatusCreatedAt: Date?, deviceStatusLastLoopDate: Date?) {
        
            self.bgReadingFloats = bgReadingValues.map(Float16.init)

            let firstDate = bgReadingDates.last ?? .now
            self.firstDate = firstDate
            self.secondsSinceFirstDate = bgReadingDates.map { UInt16(truncatingIfNeeded: Int($0.timeIntervalSince(firstDate))) }
            
            self.isMgDl = isMgDl
            self.slopeOrdinal = slopeOrdinal
            self.deltaValueInUserUnit = deltaValueInUserUnit
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
            self.lowLimitInMgDl = lowLimitInMgDl
            self.highLimitInMgDl = highLimitInMgDl
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl            
            self.liveActivityType = liveActivityType
            self.dataSourceDescription = dataSourceDescription ?? ""
            self.followerPatientName = followerPatientName
            
            self.deviceStatusCreatedAt = deviceStatusCreatedAt
            self.deviceStatusLastLoopDate = deviceStatusLastLoopDate
        }
        
        /// returns blood glucose value as a string in the user-defined measurement unit. Will check and display also high, low and error texts as required.
        /// - Returns: a String with the formatted value/unit or error text
        func bgValueStringInUserChosenUnit() -> String {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateVeryStaleInMinutes), let bgValueInMgDl = bgValueInMgDl {
                var returnValue: String
                
                if bgValueInMgDl >= 400 {
                    returnValue = Texts_Common.HIGH
                } else if bgValueInMgDl >= 40 {
                    returnValue = bgValueInMgDl.mgDlToMmolAndToString(mgDl: isMgDl)
                } else if bgValueInMgDl > 12 {
                    returnValue = Texts_Common.LOW
                } else {
                    switch bgValueInMgDl {
                    case 0:
                        returnValue = "??0"
                    case 1:
                        returnValue = "?SN"
                    case 2:
                        returnValue = "??2"
                    case 3:
                        returnValue = "?NA"
                    case 5:
                        returnValue = "?NC"
                    case 6:
                        returnValue = "?CD"
                    case 9:
                        returnValue = "?AD"
                    case 12:
                        returnValue = "?RF"
                    default:
                        returnValue = "???"
                    }
                }
                return returnValue
            } else {
                return isMgDl ? "---" : "-.-"
            }
        }
        
        /// Blood glucose color dependant on the user defined limit values and based upon the time since the last reading
        /// - Returns: a Color object either red, yellow or green
        func bgTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, let bgValueInMgDl = bgValueInMgDl {
                if bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateStaleInMinutes) {
                    if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                        return .red
                    } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                        return .yellow
                    } else {
                        return .green
                    }
                } else {
                    return Color(white: colorTertiaryWhiteValue)
                }
            } else {
                return Color(white: colorTertiaryWhiteValue)
            }
        }
        
        /// Delta text color dependant on the time since the last reading
        /// - Returns: a Color either white(ish) or gray
        func deltaChangeTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateStaleInMinutes) {
                return Color(white: colorPrimaryWhiteValue)
            } else {
                return Color(white: colorTertiaryWhiteValue)
            }
        }
        
        /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
        /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
        func deltaChangeStringInUserChosenUnit() -> String {
            if let deltaValueInUserUnit = deltaValueInUserUnit, let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateVeryStaleInMinutes) {
                let deltaSign: String = deltaValueInUserUnit > 0 ? "+" : ""
                let deltaValueAsString = isMgDl ? deltaValueInUserUnit.mgDlToMmolAndToString(mgDl: isMgDl) : deltaValueInUserUnit.mmolToString()
                
                // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
                // show unitized zero deltas as +0 or +0.0 as per Nightscout format
                return deltaValueInUserUnit == 0.0 ? (isMgDl ? "+0" : "+0.0") : (deltaSign + deltaValueAsString)
            } else {
                return isMgDl ? "-" : "-.-"
            }
        }
        
        ///  returns a string holding the trend arrow
        /// - Returns: trend arrow string (i.e.  "↑")
        func trendArrow() -> String {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateVeryStaleInMinutes) {
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
            } else {
                return ""
            }
        }
                
        func deviceStatusColor() -> Color? {
            if let lastLoopDate = deviceStatusLastLoopDate, let createdAt = deviceStatusCreatedAt {
                if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
                    return .green
                } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
                    return .green
                } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
                    return .yellow
                } else {
                    return .red
                }
            } else {
                return nil
            }
        }
        
        func deviceStatusIconImage() -> Image? {
            if let lastLoopDate = deviceStatusLastLoopDate, let createdAt = deviceStatusCreatedAt {
                if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
                    return Image(systemName: "checkmark.circle.fill")
                } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
                    return Image(systemName: "checkmark.circle")
                } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
                    return Image(systemName: "questionmark.circle")
                } else {
                    return Image(systemName: "exclamationmark.circle")
                }
            } else {
                return nil
            }
        }
    }
}
