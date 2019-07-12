//
//  BondRequestTxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/23/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// Initiates a bond with the central
struct PairRequestTxMessage: TransmitterTxMessage {
    var data: Data {
        return Data(for: .bondRequestTx)
    }
}
