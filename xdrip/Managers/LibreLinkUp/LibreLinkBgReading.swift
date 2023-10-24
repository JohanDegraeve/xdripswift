//
//  LibreLinkBgReading.swift
//  xdrip
//
//  Created by Paul Plant on 26/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// structure for bg reading data downloaded from LibreLink
struct LibreLinkBgReading {
    
    var timeStamp:Date
    var sgv:Double
    
    init(timeStamp:Date, sgv:Double) {

        self.timeStamp = timeStamp
        self.sgv = sgv
        
    }
    
    /// creates an instance with parameter a json array as received from LibreLinkFollowerManager
    init?(entry: RequestGraphResponseGlucoseMeasurement) {
        
        guard let timeStamp = entry.Timestamp as? Date, let sgv = entry.ValueInMgPerDl.value as? Double else {return nil}
        
        self.sgv = sgv
        self.timeStamp = timeStamp // Date(timeIntervalSince1970: date/1000)
        
    }

}

