//
//  ResetMessage.swift
//  xDripG5
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


struct ResetTxMessage: RespondableMessage {
    typealias Response = ResetRxMessage

    var data: Data {
        return Data(for: .resetTx).appendingCRC()
    }
}


struct ResetRxMessage: TransmitterRxMessage {
    let status: Int

    init?(data: Data) {
        guard data.count >= 2, data.starts(with: .resetRx) else {
            return nil
        }

        status = Int(data[1])
    }
}
