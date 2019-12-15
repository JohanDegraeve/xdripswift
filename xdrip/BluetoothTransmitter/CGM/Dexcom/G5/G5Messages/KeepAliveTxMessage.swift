//
//  KeepAliveTxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/23/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct KeepAliveTxMessage: TransmitterTxMessage {
    let time: UInt8

    var data: Data {
        var data = Data(for: .keepAliveTx)
        data.append(time)
        return data
    }
}
