//
//  XDripWatchComplication+Entry.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 28/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI

extension XDripWatchComplication {
    struct Entry: TimelineEntry {
        var date: Date = .now
        var widgetState: WidgetState
    }
}

// MARK: - WidgetState

extension XDripWatchComplication.Entry {
    
    /// struct to hold the currect values that the widget/complication should show
    struct WidgetState {
        var bgReadingValues: [Double]?
        var bgReadingDates: [Date]?
        var isMgDl: Bool
        var slopeOrdinal: Int
        var deltaChangeInMgDl: Double?
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        var keepAliveIsDisabled: Bool
        var liveDataIsEnabled: Bool
        
        var bgUnitString: String
        var bgValueInMgDl: Double?
        var bgReadingDate: Date?
        var bgValueStringInUserChosenUnit: String
                
        init(bgReadingValues: [Double]? = nil, bgReadingDates: [Date]? = nil, isMgDl: Bool? = true, slopeOrdinal: Int? = 0, deltaChangeInMgDl: Double? = nil, urgentLowLimitInMgDl: Double? = 60, lowLimitInMgDl: Double? = 80, highLimitInMgDl: Double? = 180, urgentHighLimitInMgDl: Double? = 250, keepAliveIsDisabled: Bool? = false, remainingComplicationUserInfoTransfers: Int? = 99, liveDataIsEnabled: Bool? = false) {
            self.bgReadingValues = bgReadingValues
            self.bgReadingDates = bgReadingDates
            self.isMgDl = isMgDl ?? true
            self.slopeOrdinal = slopeOrdinal ?? 0
            self.deltaChangeInMgDl = deltaChangeInMgDl
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl ?? 60
            self.lowLimitInMgDl = lowLimitInMgDl ?? 80
            self.highLimitInMgDl = highLimitInMgDl ?? 180
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl ?? 250
            self.keepAliveIsDisabled = keepAliveIsDisabled ?? false
            self.liveDataIsEnabled = liveDataIsEnabled ?? false
            
            self.bgValueInMgDl = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0] : nil
            self.bgReadingDate = (bgReadingDates?.count ?? 0) > 0 ? bgReadingDates?[0] : nil
            self.bgUnitString = self.isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
            self.bgValueStringInUserChosenUnit = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0].mgdlToMmolAndToString(mgdl: self.isMgDl) ?? "" : ""
        }
        
        /// Blood glucose color dependant on the user defined limit values
        /// - Returns: a Color either red, yellow or green
        func bgTextColor() -> Color {
            if let bgValueInMgDl = bgValueInMgDl {
                if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                    return .red
                } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                    return .yellow
                } else {
                    return .green
                }
            } else {
                // this would never usually be returned in real use but it keeps the compiler happy
                return .colorSecondary
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
            }
            return ""
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
        
        /// used to return values and colors used by a SwiftUI gauge view
        /// - Returns: minValue/maxValue - used to define the limits of the gauge. gaugeColor/gaugeGradient - the gauge view will use one or the other
        func gaugeModel() -> (minValue: Double, maxValue: Double, gaugeColor: Color, gaugeGradient: Gradient) {
            
            var minValue: Double = lowLimitInMgDl
            var maxValue: Double = highLimitInMgDl
            var gaugeColor: Color = .green
            var gaugeGradient: Gradient = Gradient(colors: [.yellow, .green, .green, .green, .green, .green, .green, .green, .green, .yellow])
            
            if let bgValueInMgDl = bgValueInMgDl {
                if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                    minValue = 39
                    maxValue = 400
                    gaugeColor = .red
                    gaugeGradient = Gradient(colors: [.red, .red, .red, .yellow, .yellow, .green, .yellow, .yellow, .red, .red, .red,])
                } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                    minValue = urgentLowLimitInMgDl
                    maxValue = urgentHighLimitInMgDl
                    gaugeColor = .yellow
                    gaugeGradient = Gradient(colors: [.red, .yellow, .green, .green, .green, .green, .yellow, .red])
                }
            }
            return (minValue, maxValue, gaugeColor, gaugeGradient)
        }
        
        func isSmallScreen() -> Bool {
            return (WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen) ? true : false
        }
        
        func overrideChartHeight() -> Double {
            var height = isSmallScreen() ? ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangular
            
            height += keepAliveIsDisabled ? -15 : 0
            
            return height
        }
        
        func overrideChartWidth() -> Double {
            return isSmallScreen() ? ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangular
        }
        
    }
}

// MARK: - Data

extension XDripWatchComplication.Entry {
    static var placeholder: Self {
        .init(date: .now, widgetState: WidgetState(bgReadingValues: ConstantsWatchComplication.bgReadingValuesPlaceholderData, bgReadingDates: ConstantsWatchComplication.bgReadingDatesPlaceholderData(), isMgDl: true, slopeOrdinal: 4, deltaChangeInMgDl: 0, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 90, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, keepAliveIsDisabled: false, liveDataIsEnabled: true))
    }
}
