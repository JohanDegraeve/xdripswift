import Foundation
import os
import CoreBluetooth

class CGMBlueReaderTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_BlueReader: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_BlueReader: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_BlueReader: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMBlueReader)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    init(address:String?, name: String?, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "blueReader")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_BlueReader)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_BlueReader, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_BlueReader, startScanningAfterInit: CGMTransmitterType.blueReader.startScanningAfterInit(), bluetoothTransmitterDelegate: nil)
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        super.centralManager(central, didConnect: peripheral)
        
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: deviceAddress, name: deviceName)
        
    }
    
    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        super.centralManagerDidUpdateState(central)
        
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: central.state)
        
    }
    
    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        trace("in peripheral didUpdateValueFor", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .info)
        
        if let value = characteristic.value {
            
            guard let valueAsString = String(bytes: value, encoding: .utf8)  else {
                trace("    failed to convert value to string", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .error)
                return
            }
            
            trace("    value = %{public}@", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .info, valueAsString)
            
            //find indexes of " "
            let indexesOfSplitter = valueAsString.indexes(of: " ")
            
            // second field is the battery level, there should be at least one space
            guard indexesOfSplitter.count >= 1 else {
                trace("    there's less than 1 space", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .error)
                return
            }
            
            // get first field, this is rawdata
            let rawDataAsString = String(valueAsString[valueAsString.startIndex..<indexesOfSplitter[0]])
            
            // convert rawDataAsString to double and stop if this fails
            guard let rawDataAsDouble = rawDataAsString.toDouble() else {
                trace("    failed to convert rawDataAsString to double", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .error)
                return
            }
            
            // if there's more than one field, then the second field is battery level
            // there could be 2 fields or more
            //var batteryLevelAsString:String? = nil
            
            //if indexesOfSplitter.count == 1 {// there's two fields
            //    batteryLevelAsString = String(valueAsString[valueAsString.index(after: indexesOfSplitter[0])..<valueAsString.endIndex])
            //} else {// there's more than 2 fields
            //    batteryLevelAsString = String(valueAsString[valueAsString.index(after: indexesOfSplitter[0])..<indexesOfSplitter[1]])
            //}
            
            let transMitterBatteryInfo:TransmitterBatteryInfo? = nil
            //if let batteryLevelAsString = batteryLevelAsString, let batteryLevelAsInt = Int(batteryLevelAsString) {
            //    transMitterBatteryInfo = TransmitterBatteryInfo.percentage(percentage: batteryLevelAsInt)
            //}
            
            // send to delegate
            var glucoseDataArray = [GlucoseData(timeStamp: Date(), glucoseLevelRaw: rawDataAsDouble)]
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: transMitterBatteryInfo, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)
            
        } else {
            trace("    value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .error)
        }
        
    }
    
    // MARK: CGMTransmitter protocol functions
    
    /// to ask pairing - empty function because Bubble doesn't need pairing
    ///
    /// this function is not implemented in BluetoothTransmitter.swift, otherwise it might be forgotten to look at in future CGMTransmitter developments
    func initiatePairing() {}
    
    /// to ask transmitter reset - empty function because Bubble doesn't support reset
    ///
    /// this function is not implemented in BluetoothTransmitter.swift, otherwise it might be forgotten to look at in future CGMTransmitter developments
    func reset(requested:Bool) {}
    
    /// this transmitter does not support oopWeb
    func setWebOOPEnabled(enabled: Bool) {}
    
    /// this transmitter does not support oop web
    func setWebOOPSiteAndToken(oopWebSite: String, oopWebToken: String) {}
    
    func cgmTransmitterType() -> CGMTransmitterType? {
        return .blueReader
    }
    
}
