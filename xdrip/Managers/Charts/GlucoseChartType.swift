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
    case liveActivity = 0
    case dynamicIsland = 1
    case watchApp = 2
    case watchAccessoryRectangular = 3
    case widgetSystemSmall = 4
    case widgetSystemSmallStandBy = 5
    case widgetSystemMedium = 6
    case widgetSystemLarge = 7
    case widgetAccessoryRectangular = 8
    case siriGlucoseIntent = 9
    case notificationImageThumbnail = 10
    case notificationExpanded = 11
    case notificationWatch = 12
    
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
        case .widgetSystemSmallStandBy:
            return "Widget Chart .systemSmall for StandBy mode"
        case .widgetSystemMedium:
            return "Widget Chart .systemMedium"
        case .widgetSystemLarge:
            return "Widget Chart .systemLarge"
        case .widgetAccessoryRectangular:
            return "Widget Chart .accessoryRectangular"
        case .siriGlucoseIntent:
            return "Siri Glucose Intent Chart"
        case .notificationImageThumbnail:
            return "Notification Thumbnail Image Chart"
        case .notificationExpanded:
            return "Notification Expanded Image Chart"
        case .notificationWatch:
            return "Notification Watch Image Chart"
        }
    }
    
    // MARK: - general chart properties
    
    func viewSize(liveActivityType: LiveActivityType) -> (width: CGFloat, height: CGFloat) {
        switch self {
        case .liveActivity:
            switch liveActivityType {
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
        case .widgetSystemSmallStandBy:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemSmallStandBy, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemSmallStandBy)
        case .widgetSystemMedium:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemMedium, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemMedium)
        case .widgetSystemLarge:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSystemLarge, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSystemLarge)
        case .widgetAccessoryRectangular:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetAccessoryRectangular, ConstantsGlucoseChartSwiftUI.viewHeightWidgetAccessoryRectangular)
        case .siriGlucoseIntent:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWidgetSiriGlucoseIntent, ConstantsGlucoseChartSwiftUI.viewHeightWidgetSiriGlucoseIntent)
        case .notificationImageThumbnail:
            return (ConstantsGlucoseChartSwiftUI.viewWidthNotificationThumbnailImage, ConstantsGlucoseChartSwiftUI.viewHeightNotificationThumbnailImage)
        case .notificationExpanded:
            return (ConstantsGlucoseChartSwiftUI.viewWidthNotificationExpanded, ConstantsGlucoseChartSwiftUI.viewHeightNotificationExpanded)
        case .notificationWatch:
            return (ConstantsGlucoseChartSwiftUI.viewWidthNotificationWatch, ConstantsGlucoseChartSwiftUI.viewHeightNotificationWatch)
        }
    }
    
    func hoursToShow(liveActivityType: LiveActivityType) -> Double {
        switch self {
        case .liveActivity:
            switch liveActivityType {
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
        case .widgetSystemSmall, .widgetSystemSmallStandBy:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemSmall
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetAccessoryRectangular
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWidgetSiriGlucoseIntent
        case .notificationImageThumbnail:
            return ConstantsGlucoseChartSwiftUI.hoursToShowNotificationThumbnailImage
        case .notificationExpanded:
            return ConstantsGlucoseChartSwiftUI.hoursToShowNotificationExpanded
        case .notificationWatch:
            return ConstantsGlucoseChartSwiftUI.hoursToShowNotificationWatch
        }
    }
    
    func intervalBetweenAxisValues(liveActivityType: LiveActivityType) -> Int {
        return ConstantsGlucoseChartSwiftUI.xAxisIntervalBetweenValues
    }
    
    func glucoseCircleDiameter(liveActivityType: LiveActivityType) -> Double {
        switch self {
        case .liveActivity:
            switch liveActivityType {
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
        case .widgetSystemSmallStandBy:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemSmallStandBy
        case .widgetSystemMedium:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemMedium
        case .widgetSystemLarge:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetSystemLarge
        case .widgetAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWidgetAccessoryRectangular
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterSiriGlucoseIntent
        case .notificationImageThumbnail:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterNotificationThumbnailImage
        case .notificationExpanded:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterNotificationExpanded
        case .notificationWatch:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterNotificationWatch
        }
    }
    
    func backgroundColor() -> Color {
        switch self {
        case .siriGlucoseIntent:
            return ConstantsGlucoseChartSwiftUI.backgroundColorSiriGlucoseIntent
        case .watchAccessoryRectangular:
            return ConstantsGlucoseChartSwiftUI.backgroundColorWatchAccessoryRectangular
        case .notificationWatch:
            return ConstantsGlucoseChartSwiftUI.backgroundColorNotificationWatch
        default:
            return ConstantsGlucoseChartSwiftUI.backgroundColor
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
        case .siriGlucoseIntent, .widgetSystemLarge, .notificationExpanded:
            return .automatic
        default:
            return .hidden
        }
    }
    
    func yAxisLabelOffsetX() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge, .notificationExpanded:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelOffsetX
        default:
            return 0
        }
    }
    
    func yAxisLabelOffsetY() -> CGFloat {
        switch self {
        case .siriGlucoseIntent, .widgetSystemLarge, .notificationExpanded:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelOffsetY
        default:
            return 0
        }
    }
    
    func yAxisLineSize() -> Double {
        switch self {
        case .widgetSystemSmallStandBy:
            return ConstantsGlucoseChartSwiftUI.yAxisLineSizeSystemSmallStandBy
        default:
            return ConstantsGlucoseChartSwiftUI.yAxisLineSize
        }
    }
    
    func yAxisLowHighLineColor() -> Color {
        switch self {
        case .widgetSystemSmallStandBy:
            return ConstantsGlucoseChartSwiftUI.yAxisLowHighLineColorSystemSmallStandBy
        default:
            return ConstantsGlucoseChartSwiftUI.yAxisLowHighLineColor
        }
    }
    
    func yAxisUrgentLowHighLineColor() -> Color {
        switch self {
        case .widgetSystemSmallStandBy:
            return ConstantsGlucoseChartSwiftUI.yAxisUrgentLowHighLineColorSystemSmallStandBy
        default:
            return ConstantsGlucoseChartSwiftUI.yAxisUrgentLowHighLineColor
        }
    }
    
    
    // MARK: - filename properties if generating an image of the chart/view
    
    func filename() -> String {
        switch self {
        case .notificationImageThumbnail:
            return ConstantsGlucoseChartSwiftUI.filenameNotificationThumbnailImage
        default:
            return ""
        }
    }
}
