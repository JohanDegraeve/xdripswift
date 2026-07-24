//
//  RootHomeChartRange.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Main chart width options shown on the home screen.
///
/// The raw value is the visible width in hours. The negative time interval mirrors the previous
/// UIKit chart manager contract, where the start date is calculated by subtracting the selected
/// range from the chart end date.
enum RootHomeChartRange: Double, CaseIterable, Identifiable {
    case threeHours = 3
    case fiveHours = 5
    case eightHours = 8
    case twelveHours = 12

    var id: Double {
        rawValue
    }

    var title: String {
        "\(Int(rawValue))\(Texts_Common.hourshort)"
    }

    var timeInterval: TimeInterval {
        .hours(-rawValue)
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
        }
    }

    static func closest(to hours: Double) -> RootHomeChartRange {
        RootHomeChartRange.allCases.min { abs($0.rawValue - hours) < abs($1.rawValue - hours) } ?? .fiveHours
    }
}
