//
//  LibreRawGlucoseOOPA2Data.swift
//  xdrip
//
//  Created by Johan Degraeve on 08/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

// source https://github.com/JohanDegraeve/xdripswift/blob/bd5b3060f3a7d4c68dce767b5c86306239d06d14/xdrip/BluetoothTransmitter/CGM/Libre/Utilities/GlucoseData.swift#L208

import Foundation

public class LibreRawGlucoseOOPA2Data: NSObject, LibreRawGlucoseWeb, LibreOOPWebServerResponseData {
    
    // if received from server, probably always nil ?
    var msg: String?
    
    var errcode: Int?
    
    var list: [LibreRawGlucoseOOPA2List]?
    
    /// - time when instance of LibreRawGlucoseOOPData was created
    /// - this can be created to calculate the timestamp of realtimeGlucoseData
    var creationTimeStamp = Date()

    /// server parse value
    var content: LibreRawGlucoseOOPA2Cotent? {
        return list?.first?.content
    }
    
    /// if the server value is error return true
    var isError: Bool {
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return list?.first?.content?.historicBg?.isEmpty ?? true
    }
    
    /// sensor state
    var sensorState: LibreSensorState {
        if let id = content?.currentTime {
            if id < 60 { // if sensor time < 60, the sensor is starting
                return LibreSensorState.starting
            } else if id >= 20880 { // if sensor time >= 20880, the sensor expired
                return LibreSensorState.expired
            }
        }
        
        let state = LibreSensorState.ready
        return state
    }
    
    func glucoseData() -> (libreRawGlucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?) {
        
        // initialize returnvalue, empty glucoseData array, sensorState, and nil as sensorTimeInMinutes
        var returnValue: ([GlucoseData], LibreSensorState, Int?) = ([GlucoseData](), sensorState, nil)

        // if isError function returns true, then return empty array
        guard !isError else { return returnValue }
        
        // if sensorState is not .ready, then return empty array
        if sensorState != .ready { return returnValue }

        // content should be non nil, content.currentBg not nil and currentBg != 0, content.currentTime (sensorTimeInMinutes) not nil
        guard let content = content, let currentBg = content.currentBg, currentBg != 0, let sensorTimeInMinutes = content.currentTime else { return returnValue }
        
        // set senorTimeInMinutes in returnValue
        returnValue.2 = sensorTimeInMinutes
        
        // create realtimeGlucoseData, which is the current glucose data
        let realtimeGlucoseData = GlucoseData(timeStamp: creationTimeStamp, glucoseLevelRaw: currentBg)

        // add first element
        returnValue.0.append(realtimeGlucoseData)

        // history should be non nil, otherwise return only the first value
        guard var history = content.historicBg else { return returnValue }
        
        // check the order, first should be the highest value, time is sensor time in minutes, means first should be the most recent or the highest sensor time
        // if not, reverse it
        if (history.first?.time ?? 0) < (history.last?.time ?? 0) {
            history = history.reversed()
        }
        
        // iterate through history
        for libreHistoricGlucoseA2 in history {
            
            // if quality != 0, the value is error, don't add it
            if libreHistoricGlucoseA2.quality != 0 {continue}
            
            // if time is nil, (which is sensorTimeInMinutes at the moment this reading was created), then we can't calculate the timestamp, don't add it
            if libreHistoricGlucoseA2.time == nil {continue}
            
            // create timestamp of the reading
            let readingTimeStamp = creationTimeStamp.addingTimeInterval(-60 * Double(sensorTimeInMinutes - libreHistoricGlucoseA2.time!))
            
            //  only add readings that are at least 5 minutes away from each other, same approach as in LibreDataParser.parse
            if let lastElement = returnValue.0.last {
                
                if lastElement.timeStamp.toMillisecondsAsDouble() - readingTimeStamp.toMillisecondsAsDouble() < (5 * 60 * 1000 - 10000) {continue}
                
            }
            
            // bg value should be non nil and > 0.0
            if libreHistoricGlucoseA2.bg == nil {continue}
            if libreHistoricGlucoseA2.bg! == 0.0 {continue}
            
            let libreRawGlucoseData = GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: libreHistoricGlucoseA2.bg!)
            
            returnValue.0.append(libreRawGlucoseData)
            
        }
        
        return (returnValue)
        
    }
    
    override public var description: String {
            
        var returnValue = "LibreRawGlucoseOOPA2Data =\n"
        
        // a description created by LibreRawGlucoseWeb
        returnValue = returnValue + (self as LibreRawGlucoseWeb).description
        
        if let errcode = errcode {
            returnValue = returnValue + "   errcode = " + errcode.description + "\n"
        }
        
        return returnValue
        
    }
    
}
