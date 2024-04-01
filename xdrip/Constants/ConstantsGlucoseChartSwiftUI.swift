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
    static let viewHeightLiveActivityNormal: CGFloat = 70
    static let hoursToShowLiveActivityNormal: Double = 3
    static let intervalBetweenXAxisValuesLiveActivityNormal: Int = 1
    static let glucoseCircleDiameterLiveActivityNormal: Double = 36
    
    static let viewWidthLiveActivityLarge: CGFloat = 340
    static let viewHeightLiveActivityLarge: CGFloat = 90
    static let hoursToShowLiveActivityLarge: Double = 8
    static let intervalBetweenXAxisValuesLiveActivityLarge: Int = 1
    static let glucoseCircleDiameterLiveActivityLarge: Double = 24
    
    static let lowHighLineColorLiveActivity = Color(white: 0.6)
    static let urgentLowHighLineLiveActivity = Color(white: 0.4)
    static let xAxisGridLineColorLiveActivity = Color(white: 0.4)
    static let relativeYAxisLineSizeLiveActivity: Double = 1
    static let xAxisLabelOffsetLiveActivity: Double = -10
    
    // dynamic island bottom (expanded)
    static let viewWidthDynamicIsland: CGFloat = 330
    static let viewHeightDynamicIsland: CGFloat = 70
    
    static let lowHighLineColorDynamicIsland = Color(white: 0.6)
    static let urgentLowHighLineColorDynamicIsland = Color(white: 0.4)
    static let xAxisGridLineColorDynamicIsland = Color(white: 0.4)
    static let hoursToShowDynamicIsland: Double = 12
    static let intervalBetweenXAxisValuesDynamicIsland: Int = 2
    static let glucoseCircleDiameterDynamicIsland: Double = 14
    static let relativeYAxisLineSizeDynamicIsland: Double = 0.8
    static let xAxisLabelOffsetDynamicIsland: Double = -10
    
    // watch chart
    static let viewWidthWatchApp: CGFloat = 190
    static let viewHeightWatchApp: CGFloat = 90
    
    // watch chart sizes for smaller watches
    static let viewWidthWatchAppSmall: CGFloat = 155
    static let viewHeightWatchAppSmall: CGFloat = 75
    
    static let lowHighLineColorWatchApp = Color(white: 0.6)
    static let urgentLowHighLineColorWatchApp = Color(white: 0.4)
    static let xAxisGridLineColorWatchApp = Color(white: 0.3)
    static let hoursToShowWatchApp: Double = 4
    static let intervalBetweenXAxisValuesWatchApp: Int = 1
    static let glucoseCircleDiameterWatchApp: Double = 20
    static let relativeYAxisLineSizeWatchApp: Double = 0.8
    static let xAxisLabelOffsetWatchApp: Double = -10
    
    // watch complication .accessoryRectangular chart
    static let viewWidthWatchAccessoryRectangular: CGFloat = 180
    static let viewHeightWatchAccessoryRectangular: CGFloat = 55
    
    // watch complication sizes for smaller watches
    static let viewWidthWatchAccessoryRectangularSmall: CGFloat = 160
    static let viewHeightWatchAccessoryRectangularSmall: CGFloat = 45
    
    static let lowHighLineColorWatchAccessoryRectangular = Color(white: 0.7)
    static let urgentLowHighLineColorWatchAccessoryRectangular = Color(white: 0.5)
    static let xAxisGridLineColorWatchAccessoryRectangular = Color(white: 0.4)
    static let hoursToShowWatchAccessoryRectangular: Double = 5
    static let intervalBetweenXAxisValuesWatchAccessoryRectangular: Int = 1
    static let glucoseCircleDiameterWatchAccessoryRectangular: Double = 14
    static let relativeYAxisLineSizeWatchAccessoryRectangular: Double = 0.8
    static let xAxisLabelOffsetWatchAccessoryRectangular: Double = -10
    
    // widget systemSmall chart
    static let viewWidthWidgetSystemSmall: CGFloat = 120
    static let viewHeightWidgetSystemSmall: CGFloat = 80
    
    static let lowHighLineColorWidgetSystemSmall = Color(white: 0.6)
    static let urgentLowHighLineColorWidgetSystemSmall = Color(white: 0.4)
    static let xAxisGridLineColorWidgetSystemSmall = Color(white: 0.3)
    static let hoursToShowWidgetSystemSmall: Double = 3
    static let intervalBetweenXAxisValuesWidgetSystemSmall: Int = 1
    static let glucoseCircleDiameterWidgetSystemSmall: Double = 20
    static let relativeYAxisLineSizeWidgetSystemSmall: Double = 0.8
    static let xAxisLabelOffsetWidgetSystemSmall: Double = -10
    
    // widget systemMedium chart
    static let viewWidthWidgetSystemMedium: CGFloat = 300
    static let viewHeightWidgetSystemMedium: CGFloat = 80
    
    static let lowHighLineColorWidgetSystemMedium = Color(white: 0.6)
    static let urgentLowHighLineColorWidgetSystemMedium = Color(white: 0.4)
    static let xAxisGridLineColorWidgetSystemMedium = Color(white: 0.3)
    static let hoursToShowWidgetSystemMedium: Double = 8
    static let intervalBetweenXAxisValuesWidgetSystemMedium: Int = 1
    static let glucoseCircleDiameterWidgetSystemMedium: Double = 14
    static let relativeYAxisLineSizeWidgetSystemMedium: Double = 0.8
    static let xAxisLabelOffsetWidgetSystemMedium: Double = -10
    
    // widget systemLarge chart
    static let viewWidthWidgetSystemLarge: CGFloat = 300
    static let viewHeightWidgetSystemLarge: CGFloat = 260
    
    static let lowHighLineColorWidgetSystemLarge = Color(white: 0.6)
    static let urgentLowHighLineColorWidgetSystemLarge = Color(white: 0.4)
    static let xAxisGridLineColorWidgetSystemLarge = Color(white: 0.3)
    static let hoursToShowWidgetSystemLarge: Double = 4
    static let intervalBetweenXAxisValuesWidgetSystemLarge: Int = 1
    static let glucoseCircleDiameterWidgetSystemLarge: Double = 30
    static let relativeYAxisLineSizeWidgetSystemLarge: Double = 0.8
    static let xAxisLabelOffsetWidgetSystemLarge: Double = -10
    
    // widget (lock screen) .accessoryRectangular chart
    static let viewWidthWidgetAccessoryRectangular: CGFloat = 130
    static let viewHeightWidgetAccessoryRectangular: CGFloat = 40
    
    static let lowHighLineColorWidgetAccessoryRectangular = Color(white: 0.7)
    static let urgentLowHighLineColorWidgetAccessoryRectangular = Color(white: 0.5)
    static let xAxisGridLineColorWidgetAccessoryRectangular = Color(white: 0.4)
    static let hoursToShowWidgetAccessoryRectangular: Double = 4
    static let intervalBetweenXAxisValuesWidgetAccessoryRectangular: Int = 1
    static let glucoseCircleDiameterWidgetAccessoryRectangular: Double = 14
    static let relativeYAxisLineSizeWidgetAccessoryRectangular: Double = 0.8
    static let xAxisLabelOffsetWidgetAccessoryRectangular: Double = -10
}
