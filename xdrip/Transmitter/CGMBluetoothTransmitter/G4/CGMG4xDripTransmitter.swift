import Foundation
import CoreBluetooth

final class CGMG4xDripTransmitter: BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitterProtocol {
    // MARK: - properties
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    let CBUUID_Advertisement_G4: String = "0000FFE0-0000-1000-8000-00805F9B34FB"
    /// service to be discovered
    let CBUUID_Service_G4: String = "0000FFE0-0000-1000-8000-00805F9B34FB"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_G4: String = "0000FFE1-0000-1000-8000-00805F9B34Fb"
    /// write characteristic
    let CBUUID_WriteCharacteristic_G4: String = "0000FFE1-0000-1000-8000-00805F9B34Fb"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    // MARK: - functions
    
    init(addressAndName: BluetoothTransmitter.DeviceAddressAndName, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName
        switch addressAndName {
        case .alreadyConnectedBefore(let newAddress, let newName):
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: newAddress, name: newName)
        case .notYetConnected:
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: nil)
        }
        
        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G4, CBUUID_Service: CBUUID_Service_G4, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G4, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_G4)
        
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: - functions
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect() {
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.didUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        //In Spike and iosxdripreader, a device connection completed is transmitted in this case
        cgmTransmitterDelegate?.cgmTransmitterDidConnect()
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        //TODO: xbridge protocol
    }
    
    //MARK: CGMTransmitterProtocol functions
    func canDetectNewSensor() -> Bool {
        return false
    }
}
