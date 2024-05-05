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
    case siriGlucoseIntent = 8
    
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
        case .siriGlucoseIntent:
            return "Siri Glucose Intent Chart"
        }
    }
    
    // MARK: - general chart properties
    
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
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemLarge, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemLarge)
        case .widgetAccessoryRectangular:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetAccessoryRectangular, ConstantsGlucoseChartSwiftUI.viewHeightWidgetAccessoryRectangular)
        case .siriGlucoseIntent:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSiriGlucoseIntent, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSiriGlucoseIntent)
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
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSiriGlucoseIntent
        }
    }
    
    func intervalBetweenAxisValues(liveActivitySize: LiveActivitySize) -> Int {
        return ConstantsGlucoseChartSwiftUI.xAxisIntervalBetweenValues
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
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterSiriGlucoseIntent
        }
    }
    
    func backgroundColor() -> Color {
        switch self {
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.backgroundColorSiriGlucoseIntent
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.backgroundColorWatchAccessoryRectangular
        default:
            return .black
        }
    }
    
    func frame() -> Bool {
        switch self {
        case .siriGlucoseIntent:
            return false
        default:
            return true
        }
    }
    
    func aspectRatio() -> (enable: Bool, aspectRatio: CGFloat, contentMode: ContentMode) {
        switch self {
        case .siriGlucoseIntent:
            return (true, 1.5, .fit)
        default:
            return (false, 1, .fill) // use anything here after false as it won't be used
        }
    }
    
    func cornerRadius() -> Double {
        switch self {
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.cornerRadiusSiriGlucoseIntent
        default:
            return ConstantsGlucoseChartSwiftUI.cornerRadius
        }
    }
    
    func padding() -> (enable: Bool, padding: CGFloat) {
        switch self {
        case .siriGlucoseIntent:
            return (true, ConstantsGlucoseChartSwiftUI.paddingSiriGlucoseIntent)
        default:
            return (false, 0)
        }
    }
    
    
    // MARK: - x axis properties
    
    func xAxisShowLabels() -> Bool {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return true
        default:
            return false
        }
    }
    
    func xAxisLabelEveryHours() -> Int {
        switch self {
        default:
            return 1
        }
    }
    
    func xAxisLabelOffsetX() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetX
        default:
            return 0
        }
    }
    
    func xAxisLabelOffsetY() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetY
        default:
            return 0
        }
    }
    
    
    // MARK: - y axis properties
    
    func yAxisShowLabels() -> Visibility {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return .automatic
        default:
            return .hidden
        }
    }
    
    func yAxisLabelOffsetX() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelOffsetX
        default:
            return 0
        }
    }
    
    func yAxisLabelOffsetY() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelOffsetY
        default:
            return 0
        }
    }
}
