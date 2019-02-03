//
//  AuthChallengeTxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/22/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


struct AuthChallengeTxMessage: TransmitterTxMessage {
    let challengeHash: Data

    var data: Data {
        var data = Data(for: .authChallengeTx)
        data.append(challengeHash)
        return data
    }
}
