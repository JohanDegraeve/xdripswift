//
//  TransmitterReadSuccessResult.swift
//  xdrip
//
//  Created by Paul Plant on 23/9/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

/// model to return the transmitter read success results
public struct TransmitterReadSuccessResult {
    public let earliestTimestamp: Date?
    public let latestTimestamp: Date?
    public let distinctTimestampsCount: Int
}
