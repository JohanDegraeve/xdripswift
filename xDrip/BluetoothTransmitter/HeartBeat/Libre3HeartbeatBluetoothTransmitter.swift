//
//  Libre3HeartBeat+BluetoothPeripheral.swift
//  xdrip
//
//  Created by Johan Degraeve on 06/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

@objcMembers
class Libre3HeartBeatBluetoothTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// advertisement UUID unknown
    private let CBUUID_Advertisement_Libre3: String? = nil

    /// receive characteristic - this is the characteristic for the one minute reading
    private let CBUUID_ReceiveCharacteristic_Libre3: String = "0898177A-EF89-11E9-81B4-2A2AE2DBCCE4"
    
    /// write characteristic - we will not write, but the parent class needs a write characteristic, use the same as the one used for Libre 3
    private let CBUUID_WriteCharacteristic_Libre3: String = "F001"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatLibre3)
    
    /// when was the last heartbeat
    private var timeStampOfLastHeartBeat: Date

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: should be the name of the libre 3 transmitter as seen in the iOS settings, doesn't need to be the full name, 3-5 characters should be ok
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {

        // if it's a new device being scanned for, then use name ABBOTT. It will connect to anything that starts with name ABBOTT
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: transmitterID)
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        // initially last heartbeat was never (ie 1 1 1970)
        self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)

        // using nil as servicesCBUUIDs, that works.
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_Libre3, servicesCBUUIDs: nil, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre3, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre3, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        super.centralManager(central, didConnect: peripheral)
        
        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            timeStampOfLastHeartBeat = Date()

            let timeStamp = timeStampOfLastHeartBeat
            if Thread.isMainThread {
                UserDefaults.standard.timeStampOfLastHeartBeat = timeStamp
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.timeStampOfLastHeartBeat = timeStamp
                }
            }

            // wait for a second to allow the official app to upload to LibreView before triggering the heartbeat announcement to the delegate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.bluetoothTransmitterDelegate?.heartBeat()
            }
        }

    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        // trace the received value and uuid
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid), value.hexEncodedString())
        }

        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            timeStampOfLastHeartBeat = Date()

            let ts = timeStampOfLastHeartBeat
            if Thread.isMainThread {
                UserDefaults.standard.timeStampOfLastHeartBeat = ts
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.timeStampOfLastHeartBeat = ts
                }
            }

            // wait for a second to allow the official app to upload to LibreView before triggering the heartbeat announcement to the delegate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.bluetoothTransmitterDelegate?.heartBeat()
            }
        }
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, deviceName ?? "'unknown'", String(describing:service.uuid))
        
        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .error)
        }
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Libre3-specific transient state cleanup
        let tearDown = {
            self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }
}
