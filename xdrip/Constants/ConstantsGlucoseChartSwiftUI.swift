//
//  ConstantsGlucoseChartSwiftUI.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 31/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import SwiftUI

enum ConstantsGlucoseChartSwiftUI {
    
    static let mmollToMgdl = 18.01801801801802
    static let mgDlToMmoll = 0.0555
    
    /// application name, appears in licenseInfo as title
    static let applicationName: String = {

        guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
        
        guard let version = dictionary["CFBundleDisplayName"] as? String else {return "unknown"}
        
        return version
        
    }()
     
    
    // live activity
    static let viewWidthLiveActivityNormal: CGFloat = 180
    static let viewHeightLiveActivityNormal: CGFloat = 90
    static let hoursToShowLiveActivityNormal: Double = 3
    static let intervalBetweenXAxisValuesLiveActivityNormal: Int = 1
    
    static let viewWidthLiveActivityLarge: CGFloat = 360
    static let viewHeightLiveActivityLarge: CGFloat = 160 // 150 seems to be max size without clipping
    static let hoursToShowLiveActivityLarge: Double = 6
    static let intervalBetweenXAxisValuesLiveActivityLarge: Int = 1
    
    static let viewBackgroundColorLiveActivityNotification = Color.black
    static let lowHighLineColorLiveActivityNotification = Color(white: 0.6)
    static let urgentLowHighLineLiveActivityNotification = Color(white: 0.4)
    static let xAxisGridLineColorLiveActivityNotification = Color(white: 0.4)
    static let glucoseCircleDiameterLiveActivityNotification: Double = 36
    static let relativeYAxisLineSizeLiveActivityNotification: Double = 1
    static let xAxisLabelOffsetLiveActivityNotification: Double = -10
    
    // dynamic island bottom (expanded)
    static let viewWidthDynamicIsland: CGFloat = 330
    static let viewHeightDynamicIsland: CGFloat = 70
    
    static let viewBackgroundColorDynamicIsland = Color.black
    static let lowHighLineColorDynamicIsland = Color(white: 0.6)
    static let urgentLowHighLineColorDynamicIsland = Color(white: 0.4)
    static let xAxisGridLineColorDynamicIsland = Color(white: 0.4)
    static let hoursToShowDynamicIsland: Double = 12
    static let intervalBetweenXAxisValuesDynamicIsland: Int = 2
    static let glucoseCircleDiameterDynamicIsland: Double = 14
    static let relativeYAxisLineSizeDynamicIsland: Double = 0.8
    static let xAxisLabelOffsetDynamicIsland: Double = -10
    
    // watch chart
    static let viewWidthWatch: CGFloat = 200
    static let viewHeightWatch: CGFloat = 90
    
    static let viewBackgroundColorWatch = Color.black
    static let lowHighLineColorWatch = Color(white: 0.6)
    static let urgentLowHighLineColorWatch = Color(white: 0.4)
    static let xAxisGridLineColorWatch = Color(white: 0.3)
    static let hoursToShowWatch: Double = 4
    static let intervalBetweenXAxisValuesWatch: Int = 1
    static let glucoseCircleDiameterWatch: Double = 20
    static let relativeYAxisLineSizeWatch: Double = 0.8
    static let xAxisLabelOffsetWatch: Double = -10
    
}
