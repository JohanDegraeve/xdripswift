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
    case watch = 2
//    case mainChart = 2
//    case miniChart = 3
    
    var description: String {
        switch self {
        case .liveActivity:
            return "Live Activity Notification Chart"
        case .dynamicIsland:
            return "Dynamic Island (Expanded) Chart"
        case .watch:
            return "Apple Watch Chart"
        }
    }
    
    
    func viewSize(liveActivitySizeType: LiveActivitySizeType) -> (width: CGFloat, height: CGFloat) {
        switch self {
        case .liveActivity:
            switch liveActivitySizeType {
            case .large:
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityLarge, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityLarge)
            default:
                return (ConstantsGlucoseChartSwiftUI.viewWidthLiveActivityNormal, ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityNormal)
            }
        case .dynamicIsland:
            return (ConstantsGlucoseChartSwiftUI.viewWidthDynamicIsland, ConstantsGlucoseChartSwiftUI.viewHeightDynamicIsland)
        case .watch:
            return (ConstantsGlucoseChartSwiftUI.viewWidthWatch, ConstantsGlucoseChartSwiftUI.viewHeightWatch)
        }
    }
    
    func hoursToShow(liveActivitySizeType: LiveActivitySizeType) -> Double {
        switch self {
        case .liveActivity:
            switch liveActivitySizeType {
            case .large:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityLarge
            default:
                return ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNormal
            }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.hoursToShowDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.hoursToShowWatch
        }
    }
    
    func intervalBetweenAxisValues(liveActivitySizeType: LiveActivitySizeType) -> Int {
        switch self {
        case .liveActivity:
            switch liveActivitySizeType {
            case .large:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityLarge
            default:
                return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityNormal
        }
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesWatch
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.viewBackgroundColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.viewBackgroundColorDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.viewBackgroundColorWatch
        }
    }
    
    var glucoseCircleDiameter: Double {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterWatch
        }
    }
    
    var lowHighLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.lowHighLineColorWatch
        }
    }
    
    var urgentLowHighLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.urgentLowHighLineColorWatch
        }
    }
    
    var relativeYAxisLineSize: Double {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeWatch
        }
    }
    
    var xAxisLabelOffset: Double {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.xAxisLabelOffsetWatch
        }
    }
    
    var xAxisGridLineColor: Color {
        switch self {
        case .liveActivity:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorLiveActivityNotification
        case .dynamicIsland:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorDynamicIsland
        case .watch:
            return ConstantsGlucoseChartSwiftUI.xAxisGridLineColorWatch
        }
    }
    
}
