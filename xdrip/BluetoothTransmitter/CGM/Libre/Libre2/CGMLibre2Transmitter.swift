import Foundation
import os
import CoreBluetooth

class CGMLibre2Transmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Libre2: String = "FDE3"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Libre2: String = "F002"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_Libre2: String = "F001"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMLibre2TransmitterDelegate
    public weak var cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []
    
    private var unlockCount: UInt16 = 0
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    ///     - cGMLibre2TransmitterDelegate : a CGMLibre2TransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMLibre2TransmitterDelegate : CGMLibre2TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "abbott")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMLibre2TransmitterDelegate
        self.cGMLibre2TransmitterDelegate = cGMLibre2TransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        trace("in peripheral didUpdateValueFor", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
        
        /*if let value = characteristic.value {
            
            if let valueAsString = String(bytes: value, encoding: .utf8)   {
                trace("    failed to convert value to string", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
                return
            }
            
        } else {
            trace("    value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
        }*/
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        // !!! DIABLE IS DOING THIS AFTER HAVING RECEIVED dataServiceUUID !!!
        
        if error == nil && characteristic.isNotifying {
            
            //app.device.macAddress = settings.activeSensorAddress
            
            unlockCount += 1
            
            trace("in peripheral didUpdateNotificationStateFor, writing streaming unlock payload: ", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
           // main.debugLog("Bluetooth: writing streaming unlock payload: \(Data(Libre2.streamingUnlockPayload(id: sensor.uid, info: sensor.patchInfo, enableTime: sensor.unlockCode, unlockCount: sensor.unlockCount)).hex) (unlock code: \(sensor.unlockCode), unlock count: \(sensor.unlockCount))")
            
        //   app.device.write([UInt8](Data(Libre2.streamingUnlockPayload(id: sensor.uid, info: sensor.patchInfo, enableTime: sensor.unlockCode, unlockCount: sensor.unlockCount))), .withResponse)
            
            
        }
        
    }
    
    // MARK: - CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
    }
    
    /// this transmitter does not support oopWeb
    func setWebOOPEnabled(enabled: Bool) {
    }
    
    func setWebOOPSite(oopWebSite: String) {}
    
    func setWebOOPToken(oopWebToken: String) {}
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Libre2
    }
    
    func isWebOOPEnabled() -> Bool {
        return false
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func requestNewReading() {
        // not supported for blucon
    }
    
}
