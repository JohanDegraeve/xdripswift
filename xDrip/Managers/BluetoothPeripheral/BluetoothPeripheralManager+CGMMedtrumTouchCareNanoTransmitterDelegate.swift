//
//  BluetoothPeripheralManager+CGMMedtrumTouchCareNanoTransmitterDelegate.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

extension BluetoothPeripheralManager: CGMMedtrumTouchCareNanoTransmitterDelegate {

    func received(firmware: String, from cGMMedtrumTouchCareNanoTransmitter: CGMMedtrumTouchCareNanoTransmitter) {
        guard let medtrumNano = findTransmitter(cGMMedtrumTouchCareNanoTransmitter: cGMMedtrumTouchCareNanoTransmitter) else { return }
        medtrumNano.firmware = firmware
        coreDataManager.saveChanges()
    }

    private func findTransmitter(cGMMedtrumTouchCareNanoTransmitter: CGMMedtrumTouchCareNanoTransmitter) -> MedtrumTouchCareNano? {
        guard let index = bluetoothTransmitters.firstIndex(of: cGMMedtrumTouchCareNanoTransmitter),
              let medtrumNano = bluetoothPeripherals[index] as? MedtrumTouchCareNano else { return nil }
        return medtrumNano
    }
}
