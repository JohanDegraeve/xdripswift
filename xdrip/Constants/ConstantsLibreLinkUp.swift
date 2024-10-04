//
//  ConstantsLibreLinkUp.swift
//  xdrip
//
//  Created by Paul Plant on 26/9/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsLibreLinkUp {
    
    /// string to hold the default LibreLinkUp version number
    static let libreLinkUpVersionDefault: String = "4.12.0"
    
    /// double to hold maximum sensor days for Libre sensors that upload to LibreLinkUp
    /// currently easy as they are all the same at 14 days exactly (LibreLink doesn't upload the extra 12 hours)
    /// this is needed because we don't have a CGM transmitter class to pull the data from when in follower mode
    static let libreLinkUpMaxSensorAgeInDays: Double = 14.0
    
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
