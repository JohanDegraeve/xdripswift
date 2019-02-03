//
//  AuthRequestTxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/22/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct AuthRequestTxMessage: TransmitterTxMessage {
    let singleUseToken: Data
    let endByte: UInt8 = 0x2

    init() {
        let uuid = UUID().uuid

        singleUseToken = Data(bytes: [uuid.0, uuid.1, uuid.2, uuid.3,
                                      uuid.4, uuid.5, uuid.6, uuid.7])
    }

    var data: Data {
        var data = Data(for: .authRequestTx)
        data.append(singleUseToken)
        data.append(endByte)
        return data
    }
}
