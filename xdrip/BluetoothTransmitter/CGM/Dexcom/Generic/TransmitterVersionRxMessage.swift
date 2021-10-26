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
    
    init?(data: Data) {
        guard data.count == 19 && data.isCRCValid else {
            return nil
        }

        guard data.starts(with: .transmitterVersionRx) else {
            return nil
        }

        status = data[1]
        firmwareVersionAsData = data[2..<6]

    }

    /// firmware version in readable format
    func firmwareVersionFormatted() -> String  {
        return firmwareVersionAsData.map { "\(Int($0))" }.joined(separator: ".")
    }

}
