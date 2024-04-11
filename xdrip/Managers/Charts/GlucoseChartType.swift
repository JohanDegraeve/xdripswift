//
//  GlucoseChartType.swift
//  xdrip
//
//  Created by Paul Plant on 5/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// holds and returns the different parameters used for creating the newer (2024) SwiftUI glucose charts
public enum GlucoseChartType: Int, CaseIterable {
    
    // when adding GlucoseChartType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case liveActivity = 0
    case dynamicIsland = 1
    case watchApp = 2
    case watchAccessoryRectangular = 3
    case widgetSystemSmall = 4
    case widgetSystemMedium = 5
    case widgetSystemLarge = 6
    case widgetAccessoryRectangular = 7
    
    var description: String {
        switch self {
        case .liveActivity:
            return "Live Activity Notification Chart"
        case .dynamicIsland:
            return "Dynamic Island (Expanded) Chart"
        case .watchApp:
            return "Apple Watch Chart"
        case .watchAccessoryRectangular:
            return "Watch Chart .accessoryRectangular"
        case .widgetSystemSmall:
            return "Widget Chart .systemSmall"
        case .widgetSystemMedium:
            return "Widget Chart .systemMedium"
        case .widgetSystemLarge:
            return "Widget Chart .systemLarge"
        case .widgetAccessoryRectangular:
            return "Widget Chart .accessoryRectangular"
        }
    }
    
    
    func viewSize(liveActivitySize: LiveActivitySize) -> (width: CGFloat, height: CGFloat) {
        switch self {
        case .liveActivity:
            switch liveActivitySize {
            case .large:
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityLarge, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityLarge)
            default:
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityNormal, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityNormal)
            }
        case .dynamicIsland:
            return (ConstantsGlucoseChartSwiftUI.viewWidthDynamicIsland, ConstantsGlucoseChartSwiftUI.viewHeightDynamicIsland)
        case .watchApp:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWatchApp, ConstantsGlucoseChartSwiftUI.viewHeightWatchApp)
        case .watchAccessoryRectangular:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangular, ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangular)
        case .widgetSystemSmall:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemSmall, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemSmall)
        case .widgetSystemMedium:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemMedium, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemMedium)
        case .widgetSystemLarge:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemMedium, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemLarge)
        case .widgetAccessoryRectangular:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetAccessoryRectangular, ConstantsGlucoseChartSwiftUI.viewHeightWidgetAccessoryRectangular)
        }
    }
    
    func hoursToShow(liveActivitySize: LiveActivitySize) -> Double {
        switch self {
        case .liveActivity:
            switch liveActivitySize {
            case .large:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityLarge
            default:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNormal
            }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.hoursToShowDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetAccessoryRectangular
        }
    }
    
    func intervalBetweenAxisValues(liveActivitySize: LiveActivitySize) -> Int {
        switch self {
        case .liveActivity:
            switch liveActivitySize {
            case .large:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityLarge
            default:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityNormal
        }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWidgetAccessoryRectangular
        }
    }
    
    func glucoseCircleDiameter(liveActivitySize: LiveActivitySize) -> Double {
        switch self {
        case .liveActivity:
            switch liveActivitySize {
            case .large:
                return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityLarge
            default:
                return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNormal
        }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetAccessoryRectangular
        }
    }
    
    var lowHighLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorLiveActivity
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWidgetAccessoryRectangular
        }
    }
    
    var urgentLowHighLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineLiveActivity
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWidgetAccessoryRectangular
        }
    }
    
    var relativeYAxisLineSize: Double {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivity
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWidgetAccessoryRectangular
        }
    }
    
    var xAxisLabelOffset: Double {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetLiveActivity
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWidgetAccessoryRectangular
        }
    }
    
    var xAxisGridLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorLiveActivity
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorDynamicIsland
        case .watchApp:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWatchApp
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWatchAccessoryRectangular
        case .widgetSystemSmall:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWidgetAccessoryRectangular
        }
    }
    
}
