//
//  CGMMedtrumTouchCareNanoTransmitterDelegate.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Callbacks specific to the Medtrum TouchCare Nano transmitter, used by the settings UI
/// (and BluetoothPeripheralManager) to surface device metadata as it's discovered.
protocol CGMMedtrumTouchCareNanoTransmitterDelegate: AnyObject {

    /// firmware string, if it becomes available
    func received(firmware: String, from cGMMedtrumTouchCareNanoTransmitter: CGMMedtrumTouchCareNanoTransmitter)

}
