//
//  ConstantsBgAdjustment.swift
//  xdrip
//
//  Created by Paul Plant on 3/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

enum BgAdjustmentShapeType: Int16, CaseIterable {
    case softerLows = 0
    case neutral = 1
    case softerHighs = 2
    
    var description: String {
        switch self {
        case .softerLows:
            return Texts_HomeView.postProcessingSofterHighs
        case .neutral:
            return Texts_HomeView.postProcessingNeutral
        case .softerHighs:
            return Texts_HomeView.postProcessingSofterLows
        }
    }
    
    var scaleCenterInMgDl: Double {
        // This is the pivot used when applying the scale factor.
        // Values near the pivot move the least and values further away move more.
        switch self {
        case .softerLows:
            return 80.0
        case .neutral:
            return 100.0
        case .softerHighs:
            return 120.0
        }
    }
}

enum ConstantsBgAdjustment {
    static let minimumSlopeValue: Double = 0.25
    static let maximumSlopeValue: Double = 1.75
    static let slopeNudgeValue: Double = 0.05
    static let interceptNudgeValueInMgDl: Double = 1.0
    static let interceptNudgeValueInMmol: Double = 0.1
    static let defaultShapeType: BgAdjustmentShapeType = .neutral
    static let defaultPreviewChartHoursToShow = 5
    static let previewChartHoursToShowOptions = [5, 8, 12, 24]

    /// Set this to true if the preview chart should only show readings from the
    /// current sensor or follower source context.
    static let showOnlyLatestDataSourceInPreviewChart = false
}
