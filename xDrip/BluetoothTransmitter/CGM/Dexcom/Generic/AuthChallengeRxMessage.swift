//
//  AuthChallengeRxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/22/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct AuthChallengeRxMessage: TransmitterRxMessage {
    let authenticated: Bool
    let paired: Bool

    init?(data: Data) {
        guard data.count >= 3 else {
            return nil
        }

        guard data.starts(with: .authChallengeRx) else {
            return nil
        }

        authenticated = data[1] == 0x1
        paired = data[2] != 2
    }
}
