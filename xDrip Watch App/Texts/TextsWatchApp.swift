//
//  TextsWatchApp.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 27/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// all Nightscout related texts
class Texts_WatchApp {
    static private let filename = "WatchApp"
    
    static let requestingData: String = {
        return NSLocalizedString("requestingData", tableName: filename, bundle: Bundle.main, value: "Requesting data...", comment: "watch app - text for requesting data")
    }()
    
    static let lastReading: String = {
        return NSLocalizedString("lastReading", tableName: filename, bundle: Bundle.main, value: "Last reading", comment: "watch app - text for last reading")
    }()
    
    static let noSensorData: String = {
        return NSLocalizedString("noSensorData", tableName: filename, bundle: Bundle.main, value: "No sensor data", comment: "watch app - text for no sensor data")
    }()
}

