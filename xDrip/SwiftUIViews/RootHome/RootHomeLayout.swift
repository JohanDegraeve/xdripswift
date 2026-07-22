//
//  RootHomeLayout.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Native SwiftUI layout contract for the home screen.
///
/// Compact rows keep stable heights because they contain fixed-format status information.
/// The main chart is the flexible row and expands to consume the remaining vertical space.
enum RootHomeLayout {
    static let sectionSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 9
    static let screenHorizontalMargin: CGFloat = 12
    static let horizontalMargin: CGFloat = 8
    static let toolbarMinimumHeight: CGFloat = 44
    static let glucoseRowHeight: CGFloat = 120
    static let glucoseInfoRowHeight: CGFloat = 24
    static let pumpWidth: CGFloat = 158
    static let loopHeight: CGFloat = 35
    static let sensorNoiseWarningHeight: CGFloat = 40
    static let loopTopPadding: CGFloat = 2
    static let loopBottomPadding: CGFloat = 2
    static let loopStatusSymbolSize: CGFloat = 18
    static let miniChartHeight: CGFloat = 60
    static let selectorHeight: CGFloat = 30
    static let statisticsHeight: CGFloat = 90
    static let sensorProgressHeight: CGFloat = 10
    static let dataSourceHeight: CGFloat = 30
    static let bottomStatusSpacing: CGFloat = 2
    static let clockHeight: CGFloat = 140
}
