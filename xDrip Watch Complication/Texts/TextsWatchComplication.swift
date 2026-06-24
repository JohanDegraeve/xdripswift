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
}
