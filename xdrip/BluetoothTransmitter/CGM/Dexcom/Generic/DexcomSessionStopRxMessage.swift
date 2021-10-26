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
    let received: UInt8
    let sessionStopTime: Double
    let sessionStartTime: Double
    let transmitterTime: Double
    
    init?(data: Data) {
        
        guard data.count >= 15 else { return nil }
        
        guard data.starts(with: .sessionStopRx) else {return nil}
        
        status = data[1]
        received = data[2]
        sessionStopTime = Double(Data(data[3..<7]).to(UInt32.self))
        sessionStartTime = Double(Data(data[7..<11]).to(UInt32.self))
        transmitterTime = Double(Data(data[11..<15]).to(UInt32.self))
        
    }
    
    var isOkay: Bool {
        return status == 0
    }
}
