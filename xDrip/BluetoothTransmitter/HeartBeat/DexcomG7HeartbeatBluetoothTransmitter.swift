//
//  DexcomG7HeartbeatBluetoothTransmitter.swift
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

/**
 DexcomG7HeartbeatBluetoothTransmitter is not a real CGMTransmitter but used as workaround to make clear in bluetoothperipheral manager that libreview is used as CGM
 */
@objcMembers
class DexcomG7HeartbeatBluetoothTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// service CBUUID
    private let CBUUID_Service_G7: String = "F8083532-849E-531C-C594-30F1F86A4EA5"
    
    /// advertisement CBUUID
    private let CBUUID_Advertisement_G7: String = "FEBC"

    /// receive characteristic - this is the characteristic for the one minute reading
    private let CBUUID_ReceiveCharacteristic_G7: String = "F8083535-849E-531C-C594-30F1F86A4EA5" // authentication characteristic
    
    /// not really useful
    private let CBUUID_WriteCharacteristic_G7: String = "F8083535-849E-531C-C594-30F1F86A4EA5"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatG7)
    
    /// when was the last heartbeat
    private var timeStampOfLastHeartBeat: Date

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: should be the name of the libre 3 transmitter as seen in the iOS settings, doesn't need to be the full name, 3-5 characters should be ok
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {

        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: transmitterID)
        
        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }
        
        // initially last heartbeat was never (ie 1 1 1970)
        self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G7, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G7)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G7, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_G7, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // No additional state to clear for heartbeat transmitter
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        //super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // trace the received value and uuid
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryHeartBeatG7, type: .info, String(describing: characteristic.uuid), value.hexEncodedString())
        }

        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            timeStampOfLastHeartBeat = Date()
            
            // bump the UserDefaults write onto the main thread so KVO/UI observers fire on main
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
    
    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        
        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            
            timeStampOfLastHeartBeat = Date()
            
            // bump the UserDefaults write onto the main thread so KVO/UI observers fire on main
            let ts = timeStampOfLastHeartBeat
            if Thread.isMainThread {
                UserDefaults.standard.timeStampOfLastHeartBeat = ts
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.timeStampOfLastHeartBeat = ts
                }
            }
            
            // no need to wait for a second, because the disconnect usually happens about 1' seconds after connect
            // this case is for when a follower would be using an expired Dexcom G7 as a heartbeat
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.heartBeat()
            }
        }
    }
            
}
