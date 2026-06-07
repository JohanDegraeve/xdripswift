//
//  DexcomG6SessionStopRxMessage.swift
//  xDrip
//
//  Created by Dmitry on 22.03.2021.
//  Copyright © 2021 Faifly. All rights reserved.
//
// adapted by Johan Degraeve

import Foundation

struct DexcomSessionStopRxMessage {
    
    let status: UInt8
    
    let sessionStopResponse: DexcomSessionStopResponse
    
    /// timeinterval since transmitterStartDate
    let sessionStopTime: Double
    
    /// transmitterStartDAte =timeinterval since now, negative
    let transmitterTime: Double
    
    /// transmitter Start Date
    let transmitterStartDate: Date
    
    /// session stopDate
    let sessionStopDate: Date
    
    init?(data: Data) {
        
        guard data.count >= 15 else { return nil }
        
        guard data.starts(with: .sessionStopRx) else {return nil}
        
        status = data[1]
        
        guard let sessionStopResponseReceived = DexcomSessionStopResponse(rawValue: data[2]) else {return nil}

        sessionStopResponse = sessionStopResponseReceived
        
        sessionStopTime = Double(Data(data[3..<7]).to(UInt32.self))
        
        transmitterTime = Double(Data(data[11..<15]).to(UInt32.self))
        
        transmitterStartDate = Date(timeIntervalSinceNow: -transmitterTime)
        
        sessionStopDate = Date(timeInterval: sessionStopTime, since: transmitterStartDate)
        
    }
    
    var isOkay: Bool {
        return status == 0
    }
    
}
