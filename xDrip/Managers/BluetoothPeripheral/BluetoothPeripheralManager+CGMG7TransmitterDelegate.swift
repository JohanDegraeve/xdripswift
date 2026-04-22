//
//  BluetoothPeripheralManager+CGMG7TransmitterDelegate.swift
//  xdrip
//
//  Created by Johan Degraeve on 15/02/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

extension BluetoothPeripheralManager: CGMG7TransmitterDelegate {
    
    func received(sensorStartDate: Date?, cGMG7Transmitter: CGMG7Transmitter) {
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else {return}
        
        dexcomG7.sensorStartDate = sensorStartDate
        
        coreDataManager.saveChanges()
    }
    
    func received(sensorStatus: String?, cGMG7Transmitter: CGMG7Transmitter) {
        
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else {return}
        
        dexcomG7.sensorStatus = sensorStatus
        
        coreDataManager.saveChanges()
        
    }
    
    private func getDexcomG7(cGMG7Transmitter: CGMG7Transmitter) -> DexcomG7? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG7Transmitter), let dexcomG7 = bluetoothPeripherals[index] as? DexcomG7 else {return nil}
        
        return dexcomG7
        
    }
    
}
