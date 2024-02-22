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

    case liveActivityNotification = 0
    case dynamicIsland = 1
//    case mainChart = 2
//    case miniChart = 3
    
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
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityNotificationLarge, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityNotificationLarge)
            default:
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityNotificationNormal, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityNotificationNormal)
            }
        case .dynamicIsland:
            return (ConstantsGlucoseChartSwiftUI.viewWidthDynamicIsland, ConstantsGlucoseChartSwiftUI.viewHeightDynamicIsland)
        }
    }
    
    func hoursToShow(liveActivityNotificationSizeType: LiveActivityNotificationSizeType) -> Double {
        switch self {
        case .liveActivityNotification:
            switch liveActivityNotificationSizeType {
            case .large:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationLarge
            default:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationNormal
            }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.hoursToShowDynamicIsland
        }
    }
    
    func intervalBetweenAxisValues(liveActivityNotificationSizeType: LiveActivityNotificationSizeType) -> Int {
        switch self {
        case .liveActivityNotification:
            switch liveActivityNotificationSizeType {
            case .large:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityNotificationLarge
            default:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityNotificationNormal
        }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesDynamicIsland
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.viewBackgroundColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.viewBackgroundColorDynamicIsland
        }
    }
    
    var glucoseCircleDiameter: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterDynamicIsland
        }
    }
    
    var lowHighLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorDynamicIsland
        }
    }
    
    var urgentLowHighLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorDynamicIsland
        }
    }
    
    var relativeYAxisLineSize: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeDynamicIsland
        }
    }
    
    var xAxisLabelOffset: Double {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetDynamicIsland
        }
    }
    
    var xAxisGridLineColor: Color {
        switch self {
        case .liveActivityNotification:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorDynamicIsland
        }
    }
    
}
