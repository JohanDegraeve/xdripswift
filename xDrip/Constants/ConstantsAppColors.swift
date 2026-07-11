//
//  ConstantsAppColors.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shared SwiftUI colour palette for app-native views.
///
/// Older screens still use their historical constants. New SwiftUI migration work should use
/// these semantic colours instead so that the app gradually moves towards one common visual
/// language without making SwiftUI views depend on view-controller-era formatting constants.
enum ConstantsAppColors {

    // MARK: - Base

    static let background = Color.black
    static let primaryText = Color(.colorPrimary)
    static let secondaryText = Color(.colorSecondary)
    static let tertiaryText = Color(.colorTertiary)
    static let disabledText = Color.gray

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
    static let clockText = Color.gray
    static let dataSourceText = secondaryText

    // MARK: - Sensor

    static let sensorText = Color(white: 0.67)
    static let sensorProgress = Color.gray
    static let sensorWarning = warning
    static let sensorUrgent = caution
    static let sensorExpired = urgent

    // MARK: - Statistics

    static let statisticsLow = urgent
    static let statisticsInRange = Color(red: 0.0, green: 0.6, blue: 0.0)
    static let statisticsHigh = warning

}
