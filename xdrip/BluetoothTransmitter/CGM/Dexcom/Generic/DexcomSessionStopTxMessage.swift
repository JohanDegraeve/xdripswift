
//
//  DexcomG6SessionStartTxMessage.swift
//  xDrip
//
//  Created by Dmitry on 08.01.2021.
//  Copyright © 2021 Faifly. All rights reserved.
//

import Foundation

struct DexcomSessionStopTxMessage: TransmitterTxMessage {
    
    let data: Data
    
    let stopDate: Date
    
    init(stopDate: Date, transmitterStartDate: Date) {
        
        self.stopDate = stopDate
        
        var array = [Int8]()
        
        array.append(Int8(DexcomTransmitterOpCode.sessionStopTx.rawValue))
        
        let stopTime = Int(stopDate.timeIntervalSince1970  - transmitterStartDate.timeIntervalSince1970)
        
        withUnsafeBytes(of: stopTime) {
            array.append(contentsOf: Array($0.prefix(4 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
        }
        
        let data = array.withUnsafeBufferPointer { Data(buffer: $0) }
        
        self.data = data.appendingCRC()
        
    }
    
}
