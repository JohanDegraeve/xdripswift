//
//  DexcomG6SessionStartTxMessage.swift
//  xDrip
//
//  Created by Dmitry on 08.01.2021.
//  Copyright © 2021 Faifly. All rights reserved.
//

import Foundation

struct DexcomSessionStartTxMessage: TransmitterTxMessage {
    
    let data: Data
    
    init(startDate: Date, transmitterStartDate: Date, dexcomCalibrationParameters: DexcomCalibrationParameters) {
        
        var array = [Int8]()
        
        array.append(Int8(DexcomTransmitterOpCode.sessionStartTx.rawValue))
        
        withUnsafeBytes(of: Int(startDate.timeIntervalSince1970 - transmitterStartDate.timeIntervalSince1970)) {
            array.append(contentsOf: Array($0.prefix(4 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
        }
        
        withUnsafeBytes(of: Int(startDate.timeIntervalSince1970)) {
            array.append(contentsOf: Array($0.prefix(4 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
        }
        
        if dexcomCalibrationParameters.parameter1 != 0 {
            
            withUnsafeBytes(of: dexcomCalibrationParameters.parameter1) {
                array.append(contentsOf: Array($0.prefix(2 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
            }

            withUnsafeBytes(of: dexcomCalibrationParameters.parameter2) {
                array.append(contentsOf: Array($0.prefix(2 * MemoryLayout<Int8>.size)).map { Int8(bitPattern: $0) })
            }
            
        }
        
        let data = array.withUnsafeBufferPointer { Data(buffer: $0) }
        
        self.data = data.appendingCRC()
        
    }
    
}
