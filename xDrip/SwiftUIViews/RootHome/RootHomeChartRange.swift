//
//  RootHomeChartRange.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Available visible widths for the main Home chart.
///
/// The raw value is the visible width in hours. The negative time interval mirrors the previous
/// UIKit chart manager contract, where the start date is calculated by subtracting the selected
/// range from the chart end date.
enum RootHomeChartRange: Double, CaseIterable {
    case threeHours = 3
    case fiveHours = 5
    case eightHours = 8
    case twelveHours = 12
    case twentyFourHours = 24

    var timeInterval: TimeInterval {
        .hours(-rawValue)
    }

    /// Localized label shared by the Settings menus that expose the same ranges as pinch zoom.
    var settingsTitle: String {
        rawValue.formatted(.number.precision(.fractionLength(0))) + " " + Texts_Common.hours
    }

    /// Baseline used by `GlucoseChartView` to keep glucose points readable as the visible range widens.
    var glucoseCircleDiameterScalingHours: Double {
        switch self {
        case .threeHours:
            return 3.0
        case .fiveHours:
            return 4.5
        case .eightHours:
            return 6.0
        case .twelveHours:
            return 7.2
        case .twentyFourHours:
            return 10.0
        }
    }

    var nextShorterRange: RootHomeChartRange? {
        switch self {
        case .threeHours:
            return nil
        case .fiveHours:
            return .threeHours
        case .eightHours:
            return .fiveHours
        case .twelveHours:
            return .eightHours
        case .twentyFourHours:
            return .twelveHours
        }
    }

    var nextLongerRange: RootHomeChartRange? {
        switch self {
        case .threeHours:
            return .fiveHours
        case .fiveHours:
            return .eightHours
        case .eightHours:
            return .twelveHours
        case .twelveHours:
            return .twentyFourHours
        case .twentyFourHours:
            return nil
        }
    }

    static func closest(to hours: Double) -> RootHomeChartRange {
        RootHomeChartRange.allCases.min { abs($0.rawValue - hours) < abs($1.rawValue - hours) } ?? .fiveHours
    }
}
