//
//  GlucoseChartWidgetType.swift
//  xdrip
//
//  Created by Paul Plant on 5/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// holds and returns the different parameters used for creating the images for different widget types
public enum GlucoseChartWidgetType: Int, CaseIterable {
    
    // when adding GlucoseChartWidgetType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case liveActivityNotification = 0
    case dynamicIsland = 1
    
    var description: String {
        switch self {
        case .liveActivityNotification:
            return "Live Activity Notification Widget"
        case .dynamicIsland:
            return "Dynamic Island (Expanded) Widget"
        }
    }
    
    
    func viewSize(liveActivityNotificationSizeType: LiveActivityNotificationSizeType) -> (width: CGFloat, height: CGFloat) {
        switch self {
        case .liveActivityNotification:
            switch liveActivityNotificationSizeType {
            case .large:
                return (ConstantsWidget.viewWidthLiveActivityNotificationLarge, ConstantsWidget.viewHeightLiveActivityNotificationLarge)
            default:
                return (ConstantsWidget.viewWidthLiveActivityNotificationNormal, ConstantsWidget.viewHeightLiveActivityNotificationNormal)
            }
        case .dynamicIsland:
            return (ConstantsWidget.viewWidthDynamicIsland, ConstantsWidget.viewHeightDynamicIsland)
        }
    }
    
    func hoursToShow(liveActivityNotificationSizeType: LiveActivityNotificationSizeType) -> Double {
        switch self {
        case .liveActivityNotification:
            switch liveActivityNotificationSizeType {
            case .large:
                return ConstantsWidget.hoursToShowLiveActivityNotificationLarge
            default:
                return ConstantsWidget.hoursToShowLiveActivityNotificationNormal
            }
        case .dynamicIsland:
            return ConstantsWidget.hoursToShowDynamicIsland
        }
    }
    
    func intervalBetweenAxisValues(liveActivityNotificationSizeType: LiveActivityNotificationSizeType) -> Int {
        switch self {
        case .liveActivityNotification:
            switch liveActivityNotificationSizeType {
            case .large:
                return ConstantsWidget.intervalBetweenXAxisValuesLiveActivityNotificationLarge
            default:
                return ConstantsWidget.intervalBetweenXAxisValuesLiveActivityNotificationNormal
        }
        case .dynamicIsland:
            return ConstantsWidget.intervalBetweenXAxisValuesDynamicIsland
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.viewBackgroundColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.viewBackgroundColorDynamicIsland
        }
    }
    
    var glucoseCircleDiameter: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.glucoseCircleDiameterLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.glucoseCircleDiameterDynamicIsland
        }
    }
    
    var lowHighLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.lowHighLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.lowHighLineColorDynamicIsland
        }
    }
    
    var urgentLowHighLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.urgentLowHighLineLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.urgentLowHighLineColorDynamicIsland
        }
    }
    
    var relativeYAxisLineSize: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.relativeYAxisLineSizeLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.relativeYAxisLineSizeDynamicIsland
        }
    }
    
    var xAxisLabelOffset: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.xAxisLabelOffsetLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.xAxisLabelOffsetDynamicIsland
        }
    }
    
    var xAxisGridLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsWidget.xAxisGridLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsWidget.xAxisGridLineColorDynamicIsland
        }
    }
    
}
