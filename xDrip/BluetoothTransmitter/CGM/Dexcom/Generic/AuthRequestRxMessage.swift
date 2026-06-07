//
//  AuthRequestRxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/22/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct AuthRequestRxMessage: TransmitterRxMessage {
    let tokenHash: Data
    let challenge: Data

    init?(data: Data) {
        guard data.count >= 17 else {
            return nil
        }

        guard data.starts(with: .authRequestRx) else {
            return nil
        }

        tokenHash = data.subdata(in: 1..<9)
        challenge = data.subdata(in: 9..<17)
    }
}
