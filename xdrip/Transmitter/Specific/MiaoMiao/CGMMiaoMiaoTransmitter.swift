import Foundation
import CoreBluetooth
import os

class CGMGMiaoMiaoTransmitter:BluetoothTransmitter, BluetoothTransmitterDelegate {
    
    // MARK: - properties
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    let CBUUID_Advertisement_MiaoMiao: String = ""
    /// service to be discovered
    let CBUUID_Service_MiaoMiao: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_MiaoMiao: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_MiaoMiao: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameMiaoMiao:String = "MiaoMiao"
    
    /// will be used to pass back bluetooth and cgm related events
    var cgmTransmitterDelegate:CGMTransmitterDelegate?

    
    // for OS_log,
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMMiaoMiao)
    
    // MARK: - functions
    
    init(addressAndName: CGMGMiaoMiaoTransmitter.MiaoMiaoDeviceAddressAndName, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName
        switch addressAndName {
        case .alreadyConnectedBefore(let newAddress, let newName):
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: newAddress, name: newName)
        case .notYetConnected:
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_MiaoMiao, CBUUID_Service: CBUUID_Service_MiaoMiao, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao)
        
        blueToothTransmitterDelegate = self
    }
    
    // MARK: - functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data.init(bytes: [0xF0]), type: .withoutResponse) {
            return true
        } else {
            os_log("in sendStartReadingCommmand, write failed", log: log, type: .error)
            return false
        }
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func peripheralD(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
    }
    
    func peripheralD(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("hello miaomiao didUpdateValueFor")
    }
    
    func centralManagerDidUpdateStateD(_ central: CBCentralManager) {
        cgmTransmitterDelegate?.bluetooth(didUpdateState: central.state)
    }
    
    func centralManagerD(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cgmTransmitterDelegate?.cgmTransmitterdidConnect()
    }
    
    func peripheralD(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        //nothing to do for MiaoMiao
    }

    // MARK: - enum

    /// * if we never connected to a G4 bridge, then we don't know it's name and address as the Device itself is going to send.
    /// * If we already connected to a device before, then we know it's name and address
    enum MiaoMiaoDeviceAddressAndName {
        /// we already connected to the device so we should know the address and name as used by the device
        case alreadyConnectedBefore (address:String, name:String)
        /// * We never connected to the device, no need to send an expected device name
        case notYetConnected
    }

}
