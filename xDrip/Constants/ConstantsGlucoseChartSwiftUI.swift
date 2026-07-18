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
    // shared chart defaults
    static let yAxisLineSize: Double = 0.8
    static let yAxisAbsoluteMinimumChartValueInMgDl: Double = 38
    static let yAxisDomainPaddingInMgDl: Double = 6
    static let yAxisBasalDomainPaddingInMgDl: Double = 0
    static let yAxisLabelOffsetX: CGFloat = 0
    static let yAxisLabelOffsetY: CGFloat = 0
    static let yAxisLabelWidth: CGFloat = 38
    static let yAxisLabelPrimaryColor = Color(.colorPrimary)
    static let yAxisLabelSecondaryColor = Color(.colorSecondary)
    static let yAxisContextGridLineColor = Color(white: 0.3)
    static let yAxisLowHighLineColor = Color(white: 0.7)
    static let yAxisUrgentLowHighLineColor = Color(white: 0.6)
    
    static let xAxisGridLineColor = Color(white: 0.4)
    static let xAxisLabelColor = Color(.colorSecondary)
    // separate midnight styling keeps day-boundary markers visible without changing normal gridlines
    static let xAxisMidnightGridLineColor = Color(white: 0.35)
    static let xAxisMidnightGridLineSize: Double = 1.25
    static let chartPlotBorderColor = Color(white: 0.5)
    static let chartPlotBorderLineWidth: Double = 1.0
    // x-axis labels use a fixed width, so the negative offset visually centers the hour over its gridline
    static let xAxisLabelOffsetX: CGFloat = -25
    static let xAxisLabelOffsetY: CGFloat = -2
    static let xAxisLabelWidth: CGFloat = 44
    static let xAxisIntervalBetweenValues: Int = 1
    static let xAxisLabelFirstClippingInMinutes: Double = 8 * 60
    static let xAxisLabelLastClippingInMinutes: Double = 12 * 60
    
    static let cornerRadius: CGFloat = 0
    static let backgroundColor: Color = .black
    
    // Swift Charts `symbolSize` is area-based, so small changes here make a visible but controlled
    // difference to point diameter without changing every chart type's base size.
    static let glucosePointSymbolSizeMultiplier: Double = 1.2
    static let carbTreatmentSymbolSizeMultiplier: Double = 2.0
    
    
    // ------------------------------------------
    // ----- Main Chart Context -----------------
    // ------------------------------------------
    // main chart y-axis context values
    //
    // The main Home chart always keeps fixed vertical context, even when visible glucose and
    // treatment values are clustered into a smaller range. Compact charts remain data-driven.
    static let yAxisLowContextGridLineInMgDl: Double = 40
    static let yAxisLowContextMinimumUrgentLowInMgDl: Double = 50
    static let yAxisMainChartContextTopPaddingInMgDl: Double = 8
    static let yAxisUpperContextGridLinesInMgDl = [150.0, 200.0, 250.0, 300.0, 350.0, 400.0]
    static let yAxisMainChartObjectiveLabelFontSize: CGFloat = 15
    static let yAxisMainChartSecondaryLabelFontSize: CGFloat = 14
    // the main y-axis keeps a fixed trailing lane for each unit; mmol/L needs room for
    // four-character labels such as "10.0", while mg/dL normally uses three digits
    static let yAxisMainChartLabelWidthInMgDl: CGFloat = 30
    static let yAxisMainChartLabelWidthInMmol: CGFloat = 38
    static let yAxisMainChartLabelOffsetX: CGFloat = 0
    static let yAxisMainChartObjectiveLabelColor = Color.white
    static let yAxisMainChartDimmedLabelColor = Color.gray


    // ------------------------------------------
    // ----- Mini Chart -------------------------
    // ------------------------------------------
    static let miniChartViewWidth: CGFloat = 300
    static let miniChartViewHeight: CGFloat = 48
    static let miniChartHoursToShow: Double = 24
    static let miniChartGlucoseCircleDiameter: Double = 3
    static let miniChartBackgroundColor: Color = .black
    static let miniChartYAxisLineSize: Double = 0.5
    static let miniChartXAxisMidnightLineColor = Color(white: 0.3)
    static let miniChartXAxisMidnightLineSize: Double = 1.25

    // optional overview window, used by the home mini-chart to provide
    // a Nightscout style overview context when scrolling the main chart
    //
    // If a chart state supplies overlay start/end dates, the renderer dims the plot area outside
    // that window and draws visible edge bars. Normal charts will never render this unless the
    // optional state values are present.
    static let overlayWindowShadeColor = Color.black.opacity(0.4)
    static let overlayWindowTintColor = Color(white: 0.3).opacity(0.4)
    static let overlayWindowEdgeColor = Color.blue.opacity(0.6)
    static let overlayWindowEdgeLineWidth: CGFloat = 2.0
    static let overlayWindowCurrentTimeEdgeTolerance: TimeInterval = 5 * 60

    // muted enough to stay behind glucose points, but visible enough during chart scrolling
    static let sensorNoiseWarningBandColor = Color.yellow.opacity(0.22)
    static let sensorNoiseUrgentBandColor = Color.red.opacity(0.27)

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
    // ----- Notification Charts ----------------
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
