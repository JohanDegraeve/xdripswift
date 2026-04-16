//
//  DexcomG6BackfillTxMessage.swift
//  xDrip
//
//  Created by Artem Kalmykov on 24.10.2020.
//  Copyright © 2020 Faifly. All rights reserved.
//

import Foundation

struct DexcomBackfillTxMessage: TransmitterTxMessage {
    
    let data: Data
    
    init(startTime: Date, endTime: Date, transmitterStartDate: Date) {
        
        let earliestTimestamp = startTime.timeIntervalSince1970
        
        let latestTimestamp = endTime.timeIntervalSince1970
        
        let transmitterTimestamp = transmitterStartDate.timeIntervalSince1970
        
        let startTimeAsInt = Int(earliestTimestamp - TimeInterval(minutes: 5) - transmitterTimestamp)
        
        let endTimeAsInt = Int(latestTimestamp + TimeInterval(minutes: 5) - transmitterTimestamp)
        
        var array = [Int8]()
        
        array.append(contentsOf: [Int8(DexcomTransmitterOpCode.glucoseBackfillTx.rawValue), 0x5, 0x2, 0x0])
        
        withUnsafeBytes(of: startTimeAsInt) {
            array.append(contentsOf: Array($0.prefix(4 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
        }
        
        withUnsafeBytes(of: endTimeAsInt) {
            array.append(contentsOf: Array($0.prefix(4 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
        }
        
        array.append(contentsOf: [Int8](repeating: 0, count: 6))
        
        let data = array.withUnsafeBufferPointer { Data(buffer: $0) }
        
        self.data = data.appendingCRC()
    }
    
}
