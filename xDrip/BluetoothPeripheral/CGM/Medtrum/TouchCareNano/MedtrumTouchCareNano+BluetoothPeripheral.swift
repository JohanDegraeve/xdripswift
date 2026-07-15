//
//  MedtrumTouchCareNano+BluetoothPeripheral.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

extension MedtrumTouchCareNano: BluetoothPeripheral {

    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .MedtrumTouchCareNanoType
    }

}
