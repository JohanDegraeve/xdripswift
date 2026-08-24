//
//  WidgetSharedUserDefaultsModel.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// model of the data we'll store in the shared app group to pass from the watch app to the widgets
struct WidgetSharedUserDefaultsModel: Codable {
    private static let widgetDataKeyPrefix = "widgetSharedUserDefaults"
    private static let keepAliveDisabledMessageKeyPrefix = "widgetKeepAliveDisabledMessage"

    static func widgetDataKey(for bundleIdentifier: String) -> String {
        "\(widgetDataKeyPrefix).\(bundleIdentifier)"
    }

    static func keepAliveDisabledMessageKey(for bundleIdentifier: String) -> String {
        "\(keepAliveDisabledMessageKeyPrefix).\(bundleIdentifier)"
    }

    var bgReadingValues: [Double]
    var bgReadingDatesAsDouble: [Double]
    var isMgDl: Bool
    var slopeOrdinal: Int
    var deltaValueInUserUnit: Double
    var urgentLowLimitInMgDl: Double
    var lowLimitInMgDl: Double
    var highLimitInMgDl: Double
    var urgentHighLimitInMgDl: Double
    var dataSourceDescription: String
    var followerPatientName: String?
    
    var aidStatus: AIDStatus?
    
    var allowStandByHighContrast: Bool
    var forceStandByBigNumbers: Bool
}
