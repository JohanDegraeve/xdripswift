//
//  FollowerBgReading.swift
//  xdrip
//
//  Created by Paul Plant on 7/10/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// structure for bg reading data downloaded from one of the follower managers
/// this could be Nightscout for example
struct FollowerBgReading {
    
    var timeStamp: Date
    var sgv: Double
    
    init(timeStamp:Date, sgv:Double) {

        self.timeStamp = timeStamp
        self.sgv = sgv
        
    }
    
    /// creates an instance with parameter a json array as received from Nightscout
    init?(json:[String:Any]) {
        
        guard let sgv = json["sgv"] as? Double, let date = json["date"] as? Double else {return nil}
        
        self.sgv = sgv
        self.timeStamp = Date(timeIntervalSince1970: date/1000)
        
    }
    
    /// creates an instance with parameter a json array as received from LibreLinkUpFollowerManager
    init?(entry: RequestGraphResponseGlucoseMeasurement) {

        self.sgv = entry.ValueInMgPerDl.value
        self.timeStamp =  entry.FactoryTimestamp // Date(timeIntervalSince1970: date/1000)

    }

}
