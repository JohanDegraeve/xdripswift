//
//  DexcomG6SessionStartRxMessage.swift
//  xDrip
//
//  Created by Dmitry on 08.01.2021.
//  Copyright © 2021 Faifly. All rights reserved.
//
// adapted by Johan Degraeve

import Foundation

struct DexcomSessionStartRxMessage {
    
    let status: UInt8
    let info: UInt8
    let requestedStartTime: Double
    let sessionStartTime: Double
    let transmitterTime: Double
    
    init?(data: Data) {
        
        guard data.count >= 15 else { return nil }
        
        guard data.starts(with: .sessionStartTx) else {return nil}

        status = data[1]
        info = data[2]
        requestedStartTime = Double(Data(data[3..<7]).to(UInt32.self))
        sessionStartTime = Double(Data(data[7..<11]).to(UInt32.self))
        transmitterTime = Double(Data(data[11..<15]).to(UInt32.self))
        
    }
}
