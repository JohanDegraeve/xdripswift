//
//  XDripWidget+Entry.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import WidgetKit
import SwiftUI

extension XDripWidget {
    struct Entry: TimelineEntry {
        var date: Date = .now
        var widgetState: WidgetState
        
    }
}

// MARK: - WidgetState

extension XDripWidget.Entry {
    
    /// struct to hold the values that the widgets/complications should show
    struct WidgetState {
        var bgReadingValues: [Double]?
        var bgReadingDates: [Date]?
        var isMgDl: Bool
        var slopeOrdinal: Int
        var deltaValueInUserUnit: Double?
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        var dataSourceDescription: String
        var allowStandByHighContrast: Bool
        var forceStandByBigNumbers: Bool
        var followerPatientName: String?
        
        var deviceStatusCreatedAt: Date?
        var deviceStatusLastLoopDate: Date?
        
        var bgUnitString: String
        var bgValueInMgDl: Double?
        var bgReadingDate: Date?
                
        init(bgReadingValues: [Double]? = nil, bgReadingDates: [Date]? = nil, isMgDl: Bool? = true, slopeOrdinal: Int? = 0, deltaValueInUserUnit: Double? = nil, urgentLowLimitInMgDl: Double? = 60, lowLimitInMgDl: Double? = 80, highLimitInMgDl: Double? = 180, urgentHighLimitInMgDl: Double? = 250, dataSourceDescription: String? = "", followerPatientName: String?, deviceStatusCreatedAt: Date?, deviceStatusLastLoopDate: Date?, allowStandByHighContrast: Bool? = true, forceStandByBigNumbers: Bool? = false) {
            self.bgReadingValues = bgReadingValues
            self.bgReadingDates = bgReadingDates
            self.isMgDl = isMgDl ?? true
            self.slopeOrdinal = slopeOrdinal ?? 0
            self.deltaValueInUserUnit = deltaValueInUserUnit
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl ?? 60
            self.lowLimitInMgDl = lowLimitInMgDl ?? 80
            self.highLimitInMgDl = highLimitInMgDl ?? 180
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl ?? 250
            self.dataSourceDescription = dataSourceDescription ?? ""
            self.allowStandByHighContrast = allowStandByHighContrast ?? true
            self.forceStandByBigNumbers = forceStandByBigNumbers ?? false
            self.followerPatientName = followerPatientName
            
            self.deviceStatusCreatedAt = deviceStatusCreatedAt
            self.deviceStatusLastLoopDate = deviceStatusLastLoopDate            
            
            self.bgValueInMgDl = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0] : nil
            self.bgReadingDate = (bgReadingDates?.count ?? 0) > 0 ? bgReadingDates?[0] : nil
            self.bgUnitString = self.isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
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
        /// - Returns: a Color either red, yellow or green
        func bgTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateStaleInMinutes), let bgValueInMgDl = bgValueInMgDl {
                if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                    return .red
                } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                    return .yellow
                } else {
                    return .green
                }
            } else {
                return .colorTertiary
            }
        }
        
        /// Delta text color dependant on the time since the last reading
        /// - Returns: a Color either red, yellow or green
        func deltaChangeTextColor() -> Color {
            if let bgReadingDate = bgReadingDate, bgReadingDate > Date().addingTimeInterval(-ConstantsWidgetExtension.bgReadingDateStaleInMinutes) {
                return .colorPrimary
            } else {
                return .colorTertiary
            }
        }
        
        /// used to return values and colors used by a SwiftUI gauge view
        /// - Returns: minValue/maxValue - used to define the limits of the gauge. nilValue - used if there is currently no data present (basically puts the gauge at the 50% mark). gaugeGradient - the color ranges used
        func gaugeModel() -> (minValue: Double, maxValue: Double, nilValue: Double, gaugeColor: Color, gaugeGradient: Gradient) {
            
            var minValue: Double = lowLimitInMgDl
            var maxValue: Double = highLimitInMgDl
            var gaugeColor: Color = .green
            var colorArray = [Color]()
                    
            if let bgValueInMgDl = bgValueInMgDl {
                if bgValueInMgDl >= urgentHighLimitInMgDl {
                    maxValue = ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
                    gaugeColor = .red
                } else if bgValueInMgDl >= highLimitInMgDl {
                    maxValue = urgentHighLimitInMgDl
                    gaugeColor = .red
                }
                
                if bgValueInMgDl <= urgentLowLimitInMgDl {
                    minValue = ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
                    gaugeColor = .yellow
                } else if bgValueInMgDl <= lowLimitInMgDl {
                    minValue = urgentLowLimitInMgDl
                    gaugeColor = .yellow
                }
            }
            
            // let's round the min value down to nearest 10 and the max up to nearest 10
            // this is to start creating the gradient ranges
            let minValueRoundedDown = Double(10 * Int(minValue/10))
            let maxValueRoundedUp = Double(10 * Int(maxValue/10)) + 10
            
            // the prevent the gradient changes from being too sharp, we'll reduce the granularity if trying to show a big range
            // step through the range and append the colors as necessary
            for currentValue in stride(from: minValueRoundedDown, through: maxValueRoundedUp, by: (maxValueRoundedUp - minValueRoundedDown) > 200 ? 20 : 10) {
                if currentValue > urgentHighLimitInMgDl || currentValue <= urgentLowLimitInMgDl {
                    colorArray.append(Color.red)
                } else if currentValue > highLimitInMgDl || currentValue <= lowLimitInMgDl {
                    colorArray.append(Color.yellow)
                } else {
                    colorArray.append(Color.green)
                }
            }
            
            // calculate a nil value to show on the gauge (as it can't display nil). This should basically just peg the gauge indicator in the middle of the current range
            let nilValue =  minValue + ((maxValue - minValue) / 2)
            
            return (minValue, maxValue, nilValue, gaugeColor, Gradient(colors: colorArray))
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

// MARK: - Data

extension XDripWidget.Entry {
    static var placeholder: Self {
        .init(date: .now, widgetState: WidgetState(bgReadingValues: ConstantsWidgetExtension.bgReadingValuesPlaceholderData, bgReadingDates: ConstantsWidgetExtension.bgReadingDatesPlaceholderData(), isMgDl: true, slopeOrdinal: 4, deltaValueInUserUnit: 0, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 90, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, dataSourceDescription: "Dexcom G6", followerPatientName: nil, deviceStatusCreatedAt: Date().addingTimeInterval(-200), deviceStatusLastLoopDate: Date().addingTimeInterval(-120)))
    }
}
