//
//  TransmitterVersionRxMessage.swift
//  xDripG5
//
//  Created by Nate Racklyeft on 9/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct TransmitterVersionRxMessage: TransmitterRxMessage {
    let status: UInt8
    let firmwareVersionAsData: Data
    var transmitterExpiryInDays: UInt8
    
    init?(data: Data) {
        guard data.count == 19 && data.isCRCValid else {
            return nil
        }

        guard data.starts(with: .transmitterVersionRx) else {
            return nil
        }

        status = data[1]
        firmwareVersionAsData = data[2..<6]
        transmitterExpiryInDays = (data[14] << 8) + data[13]
    }

    /// firmware version in readable format
    func firmwareVersionFormatted() -> String  {
        return firmwareVersionAsData.map { "\(Int($0))" }.joined(separator: ".")
    }
    
    /// if the transmitter is showing a 180 day expiry, then it's an Anubis so return true
    func isAnubis() -> Bool  {
        if transmitterExpiryInDays == 180 {
            return true
        }
        
        return false
    }
}
