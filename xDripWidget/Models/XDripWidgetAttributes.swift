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
        
        // Dynamic stateful properties about your activity go here!
        var bgValueInMgDl: Double
        var isMgDl: Bool
        var trendArrow: String
        var deltaChangeInMgDl: Double
        var urgentLowLimitInMgDl: Double
        var lowLimitInMgDl: Double
        var highLimitInMgDl: Double
        var urgentHighLimitInMgDl: Double
        
        var bgValueStringInUserChosenUnit: String
        var bgUnitString: String
        
        init(bgValueInMgDl: Double, isMgDl: Bool, trendArrow: String, deltaChangeInMgDl: Double, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double) {
            
            // these are the "passed in" stateful values used to initialize
            self.bgValueInMgDl = bgValueInMgDl
            self.isMgDl = isMgDl
            self.trendArrow = trendArrow
            self.deltaChangeInMgDl = deltaChangeInMgDl
            self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
            self.lowLimitInMgDl = lowLimitInMgDl
            self.highLimitInMgDl = highLimitInMgDl
            self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
            
            // these are dynamically initialized based on the above
            //self.bgValueInUserChosenUnit = bgValueInMgDl.mgdlToMmol(mgdl: isMgDl)
            self.bgUnitString = isMgDl ? Texts_Widget.mgdl : Texts_Widget.mmol
            self.bgValueStringInUserChosenUnit = bgValueInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
            
        }
        
        func getBgColor() -> Color {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        }
        
        func getBgTitle() -> String {
            
            if bgValueInMgDl >= highLimitInMgDl {
                return Texts_Widget.HIGH
            } else if bgValueInMgDl <= lowLimitInMgDl {
                return Texts_Widget.LOW
            } else {
                return ""
            }
        }
        
    }

    // Fixed non-changing properties about your activity go here!
    var eventStartDate: Date
}
