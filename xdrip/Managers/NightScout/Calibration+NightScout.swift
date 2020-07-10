//
//  Calibration+NightScout.swift
//  xdrip
//
//  Created by Tudor-Andrei Vrabie on 27/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

extension Calibration {
    
    /// dictionary representation for cal record upload to NightScout
    public var dictionaryRepresentationForCalRecordNightScoutUpload: [String: Any] {
        
        return  [
            "_id": id,
            "device": deviceName ?? "",
            "date": timeStamp.toMillisecondsAsInt64(),
            "dateString": timeStamp.ISOStringFromDate(),
            "type": "cal",
            "sysTime": timeStamp.ISOStringFromDate(),
            // adjusted slope and intercept values for Nightscout
            "slope": 1000 / slope,
            "intercept": -(intercept * 1000) / slope,
            "scale": 1
        ]
        
    }
    
    /// dictionary representation for mbg record upload to NightScout
    public var dictionaryRepresentationForMbgRecordNightScoutUpload: [String: Any] {
        
        return  [
            // the mbg record cannot have the same Id as the cal record
            "_id": UniqueId.createEventId(),
            "device": deviceName ?? "",
            "date": timeStamp.toMillisecondsAsInt64(),
            "dateString": timeStamp.ISOStringFromDate(),
            "type": "mbg",
            "mbg": bg,
            "sysTime": timeStamp.ISOStringFromDate()
        ]
        
    }
}

