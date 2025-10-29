//
//  OmniPodHeartBeatTransmitter.swift
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
class OmniPodHeartBeatTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    private let CBUUID_Service_OmniPod: String = "1A7E4024-E3ED-4464-8B7E-751E03D0DC5F"
    
    /// advertisement
    private let CBUUID_Advertisement_OmniPod: String? = "00004024-0000-1000-8000-00805f9b34fb"
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic_OmniPod: String = "1A7E2442-E3ED-4464-8B7E-751E03D0DC5F"
    
    /// write characteristic - we will not write, but the parent class needs a write characteristic, use the same as the one used for Libre
    private let CBUUID_WriteCharacteristic_OmniPod: String = "F001"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatOmnipod)
    
    /// when was the last heartbeat
    private var timeStampOfLastHeartBeat: Date
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        // then device name of each omnipod contains "TWI BOARD"
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "BOARD")
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        // initially last heartbeat was never (ie 1 1 1970)
        self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_OmniPod, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_OmniPod)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_OmniPod, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_OmniPod, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        super.centralManager(central, didConnect: peripheral)
        
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
    
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
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
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // OmniPod-specific cleanup: reset heartbeat timestamp
        let tearDown = {
            self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    deinit {
        // Defensive cleanup beyond base class
        timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
    }
}
