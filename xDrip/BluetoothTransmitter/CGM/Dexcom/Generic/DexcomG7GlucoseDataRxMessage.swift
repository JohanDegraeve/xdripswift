//
//  DexcomG7GlucoseDataRxMessage.swift
//  xdrip
//
//  Created by Johan Degraeve on 19/02/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/**
  at creation, check if glucoseIsDisplayOnly is false
 */
public struct G7GlucoseMessage {
    
    let timeStamp: Date
    
    let calculatedValue: Double
    
    let algorithmStatus: DexcomAlgorithmState
    
    let sensorAge: TimeInterval

    private let glucose: UInt16?
    private let predicted: UInt16?
    private let messageTimestamp: UInt32 // timestamp of the message, in seconds since sensor start
    private let sequence: UInt16
    private let trend: Double?
    private let glucoseIsDisplayOnly: Bool

    init?(data: Data) {
        //    0  1  2 3 4 5  6 7  8  9 10 11 1213 14 15 1617 18
        //         TTTTTTTT SQSQ       AG    BGBG SS TR PRPR C
        // 0x4e 00 d5070000 0900 00 01 05 00 6100 06 01 ffff 0e
        // TTTTTTTT = timestamp
        //     SQSQ = sequence
        //       AG = age Amount of time elapsed (seconds) from sensor reading to BLE comms
        //     BGBG = glucose
        //       SS = algorithm state
        //       TR = trend
        //     PRPR = predicted
        //        C = calibration

        guard data.count >= 19 else {
            return nil
        }

        guard data[1] == 00 else {
            return nil
        }

        // not used?
        sequence = data[6..<8].to(UInt16.self)

        // time between sensor start and reading, in seconds
        messageTimestamp = data[2..<6].toInt()

        // time between reading and the actual receipt of the ble message (something like 7 seconds)
        let messageAge = data[10]

        // we assume reading is now, so sensorage = messageTimestamp + messageAge
        sensorAge = TimeInterval(messageTimestamp) + TimeInterval(messageAge)

        // timestamp of the glucose reading is now - age of the message
        timeStamp = Date().addingTimeInterval(-TimeInterval(messageAge))

        let glucoseData = data[12..<14].to(UInt16.self)
        if glucoseData != 0xffff {
            glucose = glucoseData & 0xfff
            glucoseIsDisplayOnly = (data[18] & 0x10) > 0
            calculatedValue = Double(glucose!)
        } else {
            glucose = nil
            glucoseIsDisplayOnly = false
            calculatedValue = 0.0
        }

        let predictionData = data[16..<18].to(UInt16.self)
        if predictionData != 0xffff {
            predicted = predictionData & 0xfff
        } else {
            predicted = nil
        }

        if let receivedState = DexcomAlgorithmState(rawValue: data[14]) {
            
            algorithmStatus = receivedState
            
        } else {
            
            algorithmStatus = DexcomAlgorithmState.None
            
        }
        
        if data[15] == 0x7f {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[15])) / 10
        }

    }

}
