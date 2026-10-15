//
//  BluetoothPeripheralManager+CGMLibre3TransmitterDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

extension BluetoothPeripheralManager: CGMLibre3TransmitterDelegate {
    func libre3Transmitter(_ transmitter: CGMLibre3Transmitter, updated record: Libre3PairingRecord) {
        guard let peripheral = getBluetoothPeripheral(for: transmitter) as? Libre3 else { return }
        peripheral.blePeripheral.sensorSerialNumber = record.serial
        peripheral.firmware = record.firmware
        peripheral.status = record.status
        peripheral.warmupMinutes = Int32(record.warmupMinutes)
        peripheral.wearMinutes = Int32(record.wearMinutes)
        peripheral.startedAt = record.startedAt
        coreDataManager.saveChanges()
    }
}
