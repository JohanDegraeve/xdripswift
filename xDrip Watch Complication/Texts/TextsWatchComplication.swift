//
//  TextsWatchComplication.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 26/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// all Nightscout related texts
class Texts_WatchComplication {
    static private let filename = "WatchComplication"
    
    static let keepAliveDisabled: String = {
        return NSLocalizedString("keepAliveDisabled", tableName: filename, bundle: Bundle.main, value: "Keep-alive disabled", comment: "watch complication - keep alive disabled")
    }()
    
    static let liveDataDisabled: String = {
        return NSLocalizedString("liveDataDisabled", tableName: filename, bundle: Bundle.main, value: "Live data disabled", comment: "watch complication - live data disabled")
    }()
    
    static let goTo: String = {
        return NSLocalizedString("goTo", tableName: filename, bundle: Bundle.main, value: "Go to", comment: "watch complication - text for go to")
    }()
    
    static let appleWatch: String = {
        return NSLocalizedString("appleWatch", tableName: filename, bundle: Bundle.main, value: "Apple Watch", comment: "watch complication - text for apple watch")
    }()
    
    static let settings: String = {
        return NSLocalizedString("settings", tableName: filename, bundle: Bundle.main, value: "Settings", comment: "Watch complication - text for apple watch settings")
    }()
    
    static let toEnable: String = {
        return NSLocalizedString("toEnable", tableName: filename, bundle: Bundle.main, value: "to enable", comment: "Watch complication - text for to enable")
    }()
}
