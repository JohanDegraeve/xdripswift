//
//  ConstantsGlucoseChartSwiftUI.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 31/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import SwiftUI

enum ConstantsGlucoseChartSwiftUI {
    
    // ------------------------------------------
    // ----- SwiftUI Glucose Chart --------------
    // ------------------------------------------
    // default chart properties for all chart types
    static let yAxisLineSize: Double = 0.8
    static let yAxisLabelOffsetX: CGFloat = 0
    static let yAxisLabelOffsetY: CGFloat = 0
    
    static let yAxisLowHighLineColor = Color(white: 0.7)
    static let yAxisUrgentLowHighLineColor = Color(white: 0.6)
    
    static let xAxisGridLineColor = Color(white: 0.4)
    static let xAxisLabelOffsetX: CGFloat = -12
    static let xAxisLabelOffsetY: CGFloat = -2
    static let xAxisIntervalBetweenValues: Int = 1
    static let xAxisLabelFirstClippingInMinutes: Double = 8 * 60
    static let xAxisLabelLastClippingInMinutes: Double = 12 * 60
    
    static let cornerRadius: CGFloat = 0
    
    static let backgroundColor: Color = .black
    
    
    // ------------------------------------------
    // ----- Live Activities --------------------
    // ------------------------------------------
    // live activity (normal)
    static let viewWidthLiveActivityNormal: CGFloat = 180
    static let viewHeightLiveActivityNormal: CGFloat = 70
    static let hoursToShowLiveActivityNormal: Double = 3
    static let glucoseCircleDiameterLiveActivityNormal: Double = 36
    
    // live activity (large)
    static let viewWidthLiveActivityLarge: CGFloat = 340
    static let viewHeightLiveActivityLarge: CGFloat = 80
    static let hoursToShowLiveActivityLarge: Double = 8
    static let glucoseCircleDiameterLiveActivityLarge: Double = 24
    
    // dynamic island bottom (expanded)
    static let viewWidthDynamicIsland: CGFloat = 330
    static let viewHeightDynamicIsland: CGFloat = 70
    
    static let hoursToShowDynamicIsland: Double = 12
    static let glucoseCircleDiameterDynamicIsland: Double = 14
    
    
    // ------------------------------------------
    // ----- Watch app --------------------------
    // ------------------------------------------
    // watch chart
    static let viewWidthWatchApp: CGFloat = 190
    static let viewHeightWatchApp: CGFloat = 90
    static let viewHeightWatchAppWithAIDStatus: CGFloat = 60
    static let hoursToShowWatchApp: Double = 4
    static let glucoseCircleDiameterWatchApp: Double = 20
    
    // watch chart sizes for smaller watches
    static let viewWidthWatchAppSmall: CGFloat = 155
    static let viewHeightWatchAppSmall: CGFloat = 75
    static let viewWidthWatchAppSmallWithAIDStatus: CGFloat = 155
    static let viewHeightWatchAppSmallWithAIDStatus: CGFloat = 60
    
    
    // ------------------------------------------
    // ----- Watch Widgets/Complications --------
    // ------------------------------------------
    // watch complication .accessoryRectangular chart
    static let viewWidthWatchAccessoryRectangular: CGFloat = 180
    static let viewHeightWatchAccessoryRectangular: CGFloat = 55
    static let hoursToShowWatchAccessoryRectangular: Double = 5
    static let glucoseCircleDiameterWatchAccessoryRectangular: Double = 14
    static let backgroundColorWatchAccessoryRectangular: Color = .clear
    
    // watch complication sizes for smaller watches
    static let viewWidthWatchAccessoryRectangularSmall: CGFloat = 160
    static let viewHeightWatchAccessoryRectangularSmall: CGFloat = 45
    
    
    // ------------------------------------------
    // ----- iOS Widgets ------------------------
    // ------------------------------------------
    // widget systemSmall chart
    static let viewWidthWidgetSystemSmall: CGFloat = 120
    static let viewHeightWidgetSystemSmall: CGFloat = 80
    static let hoursToShowWidgetSystemSmall: Double = 3
    static let glucoseCircleDiameterWidgetSystemSmall: Double = 20
    
    // widget systemSmall StandBy chart
    static let viewWidthWidgetSystemSmallStandBy: CGFloat = 140
    static let viewHeightWidgetSystemSmallStandBy: CGFloat = 100
    static let hoursToShowWidgetSystemSmallStandBy: Double = 43
    static let glucoseCircleDiameterWidgetSystemSmallStandBy: Double = 20
    static let yAxisLineSizeSystemSmallStandBy: Double = 1.0
    static let yAxisLowHighLineColorSystemSmallStandBy = Color(white: 1.0)
    static let yAxisUrgentLowHighLineColorSystemSmallStandBy = Color(white: 0.8)
    
    // widget systemMedium chart
    static let viewWidthWidgetSystemMedium: CGFloat = 300
    static let viewHeightWidgetSystemMedium: CGFloat = 80
    static let hoursToShowWidgetSystemMedium: Double = 8
    static let glucoseCircleDiameterWidgetSystemMedium: Double = 14
    
    // widget systemLarge chart
    static let viewWidthWidgetSystemLarge: CGFloat = 300
    static let viewHeightWidgetSystemLarge: CGFloat = 250
    static let hoursToShowWidgetSystemLarge: Double = 4
    static let glucoseCircleDiameterWidgetSystemLarge: Double = 30
    
    // widget (lock screen) .accessoryRectangular chart
    static let viewWidthWidgetAccessoryRectangular: CGFloat = 130
    static let viewHeightWidgetAccessoryRectangular: CGFloat = 40
    static let hoursToShowWidgetAccessoryRectangular: Double = 4
    static let glucoseCircleDiameterWidgetAccessoryRectangular: Double = 14
    
    
    // ------------------------------------------
    // ----- Siri Intent Chart ------------------
    // ------------------------------------------
    static let viewWidthWidgetSiriGlucoseIntent: CGFloat = 320
    static let viewHeightWidgetSiriGlucoseIntent: CGFloat = 150
    static let hoursToShowWidgetSiriGlucoseIntent: Double = 4
    static let glucoseCircleDiameterSiriGlucoseIntent: Double = 20
    static let cornerRadiusSiriGlucoseIntent: Double = 0
    static let paddingSiriGlucoseIntent: Double = 10
    static let backgroundColorSiriGlucoseIntent: Color = .black
    
    
    // ------------------------------------------
    // ----- Notification Charts -----------
    // ------------------------------------------
    // iOS notification chart - thumbnail image
    static let viewWidthNotificationThumbnailImage: CGFloat = 80
    static let viewHeightNotificationThumbnailImage: CGFloat = 80
    static let hoursToShowNotificationThumbnailImage: Double = 0.5
    static let glucoseCircleDiameterNotificationThumbnailImage: Double = 100
    static let filenameNotificationThumbnailImage: String = "notificationThumbnailImage"
    
    // iOS notification chart
    static let viewWidthNotificationExpanded: CGFloat = 373
    static let viewHeightNotificationExpanded: CGFloat = 170
    static let hoursToShowNotificationExpanded: Double = 3
    static let glucoseCircleDiameterNotificationExpanded: Double = 40
    
    // watch notification image
    static let viewWidthNotificationWatch: CGFloat = 160
    static let viewHeightNotificationWatch: CGFloat = 60
    static let hoursToShowNotificationWatch: Double = 3
    static let glucoseCircleDiameterNotificationWatch: Double = 20
    static let backgroundColorNotificationWatch: Color = Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 1)
}
