import Foundation
import CoreBluetooth
import os

class CGMBluconTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// Blucon Service
    let CBUUID_BluconService = "436A62C0-082E-4CE8-A08B-01D81F195B24"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Blucon: String = "436A0C82-082E-4CE8-A08B-01D81F195B24"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_Blucon: String = "436AA6E9-082E-4CE8-A08B-01D81F195B24"
    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryBlucon)
    
    // actual device address
    private var actualDeviceAddress:String?
    
    // used in parsing packet
    private var timeStampLastBgReading:Date
    
    // waiting successful pairing yes or not
    private var waitingSuccessfulPairing:Bool = false
    
    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID
    init?(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date) {
        
        // assign addressname and name or expected devicename
        // start by using expected device name
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: CGMBluconTransmitter.createExpectedDeviceName(transmitterIdSetByUser: transmitterID))
        if let address = address {
            // address not nil, means it already connected before, use that address
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
            actualDeviceAddress = address
        }
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading

        // initialize
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_BluconService)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Blucon, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Blucon, startScanningAfterInit: CGMTransmitterType.Blucon.startScanningAfterInit())

        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self

    }
    
    // MARK: - private helper functions
    
    /// will check if the transmitter id as set by the user is complete, and if not complete it
    ///
    /// user may just add the digits in which case this function will add BLU... with a number of 0's
    private static func createExpectedDeviceName(transmitterIdSetByUser: String) -> String {
        
        var returnValue = transmitterIdSetByUser
        
        if !returnValue.uppercased().startsWith("BLU") {
            while returnValue.count < 5 {
                returnValue = "0" + returnValue;
            }
            returnValue = "BLU" + returnValue;
        }

        return returnValue
    }
    
}

extension CGMBluconTransmitter: CGMTransmitter {
    
    func initiatePairing() {
        // nothing to do, Blucon keeps on reconnecting, resulting in continous pairing request
        return
    }
    
    func reset(requested: Bool) {
        // no reset supported for blucon
        return
    }
    
}

extension CGMBluconTransmitter: BluetoothTransmitterDelegate {
    
    func centralManagerDidConnect(address: String?, name: String?) {
        os_log("in centralManagerDidConnect", log: log, type: .info)
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
        os_log("in centralManagerDidFailToConnect", log: log, type: .error)
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        os_log("in centralManagerDidDisconnectPeripheral", log: log, type: .info)
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheralDidUpdateNotificationStateFor", log: log, type: .info)
        
        // check if error occurred
        if let error = error {

            // no need to log the error, it's already logged in BluetoothTransmitter
            
            // check if it's an encryption error, if so call delegate
            if error.localizedDescription.uppercased().contains(find: "ENCRYPTION IS INSUFFICIENT") {
                
                cgmTransmitterDelegate?.cgmTransmitterNeedsPairing()
                
                waitingSuccessfulPairing = true
            }
        } else {
            if waitingSuccessfulPairing {
                cgmTransmitterDelegate?.successfullyPaired()
                waitingSuccessfulPairing = false
            }
        }
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        
        // log the received characteristic value
        os_log("in peripheralDidUpdateValueFor with characteristic UUID = %{public}@", log: log, type: .info, characteristic.uuid.uuidString)

        // this is only applicable the very first time that blucon connects and pairing is done
        if waitingSuccessfulPairing {
            cgmTransmitterDelegate?.successfullyPaired()
            waitingSuccessfulPairing = false
        }

        // check if error occured
        if let error = error {
            os_log("   error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let value = characteristic.value {
            let data = value.hexEncodedString()
            os_log("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .debug, data)

        } else {
            os_log("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, type: .error)
        }
        
    }
    
}
