//
//  ConstantsLibreLinkUp.swift
//  xdrip
//
//  Created by Paul Plant on 26/9/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsLibreLinkUp {
    
    /// string to hold the default LibreLinkUp version number. This will replace the user's current version if necessary when the app is run after a change.
    /// updated on 2 October 2025 to "4.16.0"
    static let libreLinkUpVersionDefault: String = "4.16.0"
    
    /// double to hold maximum sensor days for Libre sensors that upload to LibreLinkUp
    /// this is needed because we don't have a CGM transmitter class to pull the data from when in follower mode
    static let libreLinkUpMaxSensorAgeInDays: Double = 14.0
    
    /// double to hold maximum sensor days for Libre Plus sensors that upload to LibreLinkUp
    /// this is needed because we don't have a CGM transmitter class to pull the data from when in follower mode
    static let libreLinkUpMaxSensorAgeInDaysLibrePlus: Double = 15.0
    
    /// warm-up time considered for all libre sensors in LibreLinkUp follower mode
    static let sensorWarmUpRequiredInMinutesForLibre: Double = 60.0
    
    /// http header array - need to append "version" key before making request
    /// https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#headers
    static let libreLinkUpRequestHeaders = [
        "accept-encoding": "gzip",
        "cache-control": "no-cache",
        "connection": "keep-alive",
        "content-type": "application/json",
        "product": "llu.ios",
    ]
    
}
