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
    
    var deviceStatusCreatedAt: Date?
    var deviceStatusLastLoopDate: Date?
    
    var allowStandByHighContrast: Bool
    var forceStandByBigNumbers: Bool
}
