//
//  ConstantsAppColors.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shared semantic colour palette for the application interface.
enum ConstantsAppColors {

    // MARK: - Base

    static let background = Color.black
    static let groupedBackground = Color(white: 0.11)
    static let primaryText = Color("colorPrimary")
    static let secondaryText = Color("colorSecondary")
    static let tertiaryText = Color("colorTertiary")
    static let disabledText = Color.gray

    // MARK: - Conventional rows

    /// Default text hierarchy for ordinary title/detail rows. Semantic status and indicator
    /// colours remain owned by their individual presentations.
    static let rowTitleText = primaryText
    static let rowDetailText = secondaryText

    // MARK: - Status

    static let normal = Color.green
    static let warning = Color.yellow
    static let caution = Color.orange
    static let urgent = Color.red
    static let accent = Color.blue

    // MARK: - Home

    static let homePanelBackground = Color(white: 0.15)
    static let toolbarIcon = Color.white
    static let toolbarLockedIcon = urgent
    static let toolbarAction = warning
    static let toolbarDestructiveAction = urgent
    static let toolbarNeutralAction = primaryText
    static let navigationTint = accent
    static let selectedTab = navigationTint
    static let clockText = Color.gray
    static let dataSourceText = secondaryText

    // MARK: - Sensor

    static let sensorText = Color(white: 0.67)
    static let sensorProgress = Color.gray
    static let sensorWarning = warning
    static let sensorUrgent = caution
    static let sensorExpired = urgent

    // MARK: - Statistics

    /// SwiftUI-native statistics colours used by pie charts and TIR value labels.
    static let statisticsLow = Color.red
    static let statisticsInRange = Color.green
    static let statisticsHigh = Color.yellow

    // MARK: - AGP

    /// Shared on-screen AGP palette. Printable reports retain their separate print-optimised colours.
    static let agpTargetFill = statisticsInRange.opacity(0.12)
    static let agpTargetRule = statisticsInRange.opacity(0.28)
    static let agpOuterBand = Color.cyan.opacity(0.18)
    static let agpInnerBand = Color.cyan.opacity(0.36)
    static let agpMedian = Color.cyan.opacity(0.85)
    static let agpXAxisGridLine = Color(white: 0.4).opacity(0.42)
    static let agpYAxisGridLine = Color(white: 0.3).opacity(0.42)
    static let agpObjectiveGridLine = Color(white: 0.7).opacity(0.5)
    static let agpPlotBorder = Color(.separator).opacity(0.45)

}
