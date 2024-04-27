//
//  ConstantsWidgetExtension.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 27/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsWidgetExtension {
    /// the time in minutes until the last BG value is considered stale
    static let bgReadingDateStaleInMinutes = TimeInterval(minutes: 7.0)
    
    /// the time in minutes until the last BG value is considered too old to show
    static let bgReadingDateVeryStaleInMinutes = TimeInterval(minutes: 20.0)
}
