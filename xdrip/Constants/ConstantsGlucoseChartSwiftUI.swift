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
    
    static let xAxisGridLineColor = Color(white: 0.45)
    static let xAxisLabelOffsetX: CGFloat = -12
    static let xAxisLabelOffsetY: CGFloat = -2
    static let xAxisIntervalBetweenValues: Int = 1
    static let xAxisLabelFirstClippingInMinutes: Double = 8 * 60
    static let xAxisLabelLastClippingInMinutes: Double = 12 * 60
    
    static let cornerRadius: CGFloat = 2
    
    
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
    static let hoursToShowWatchApp: Double = 4
    static let glucoseCircleDiameterWatchApp: Double = 20
    
    // watch chart sizes for smaller watches
    static let viewWidthWatchAppSmall: CGFloat = 155
    static let viewHeightWatchAppSmall: CGFloat = 75
    
    
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
    // siri glucose intent response chart
    static let viewWidthWidgetSiriGlucoseIntent: CGFloat = 320
    static let viewHeightWidgetSiriGlucoseIntent: CGFloat = 150
    static let hoursToShowWidgetSiriGlucoseIntent: Double = 4
    static let glucoseCircleDiameterSiriGlucoseIntent: Double = 20
    static let cornerRadiusSiriGlucoseIntent: Double = 0
    static let paddingSiriGlucoseIntent: Double = 10
    static let backgroundColorSiriGlucoseIntent: Color = .black // Color(red: 0.18, green: 0.18, blue: 0.18) originally from gshaviv
}
