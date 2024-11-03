//
//  NightscoutSyncDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 2/11/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// to be implemented for anyone who needs to receive information from the nightscout sync manager
protocol NightscoutSyncDelegate: AnyObject {
    /// to inform on new nightscout device status data
    func newNightscoutDeviceStatusReceived()
}
