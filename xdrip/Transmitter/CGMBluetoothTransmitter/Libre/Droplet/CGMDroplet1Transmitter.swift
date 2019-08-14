import Foundation
import os
import CoreBluetooth

class CGMDroplet1Transmitter:BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Droplet: String = "C97433F0-BE8F-4DC8-B6F0-5343E6100EB4"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Droplet: String = "c97433f1-be8f-4dc8-b6f0-5343e6100eb4"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_Droplet: String = "c97433f2-be8f-4dc8-b6f0-5343e6100eb4"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMDroplet1)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    init(address:String?, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "limitter")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Droplet)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Droplet, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Droplet, startScanningAfterInit: CGMTransmitterType.Droplet1.startScanningAfterInit())
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self
        
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address:String?, name:String?) {
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        
        trace("in peripheral didUpdateValueFor", log: log, type: .info)
        
        if let value = characteristic.value {
            
            guard let valueAsString = String(bytes: value, encoding: .utf8)  else {
                trace("    failed to convert value to string", log: log, type: .error)
                return
            }
            
            trace("    value = %{public}@", log: log, type: .info, valueAsString)
            
            //find indexes of " "
            var indexesOfSplitter = valueAsString.indexes(of: " ")
            
            // length of indexesOfSplitter should be minimum 3 (there should be minimum 3 spaces)
            guard indexesOfSplitter.count >= 3 else {
                trace("    there's less than 3 spaces", log: log, type: .error)
                return
            }

            // get first field
            let firstField = String(valueAsString[valueAsString.startIndex..<indexesOfSplitter[0]])
            
            // if firstfield equals "000000" or "000999" then sensor detection failure - inform delegate and return
            guard firstField != "000000" && firstField != "000999" else {
                cgmTransmitterDelegate?.sensorNotDetected()
                return
            }

            // first field : first digits are rawvalue, to be multiplied with 100, last two digits are sensor type indicator, 10=L1, 20=L2, 30=US 14 day, 40=Lpro/h
            let rawValueAsString = firstField[0..<(firstField.count - 2)] + "00"
            let sensorTypeIndicator = firstField[(firstField.count - 2)..<firstField.count]
            trace("    sensor type indicator = %{public}@", log: log, type: .info, rawValueAsString, sensorTypeIndicator)
            
            // convert rawValueAsString to double and stop if this fails
            guard let rawValueAsDouble = rawValueAsString.toDouble() else {
                trace("    failed to convert rawValueAsString to double", log: log, type: .error)
                return
            }

            // third field is battery percentage, stop if convert to Int fails
            guard let batteryPercentage = Int(String(valueAsString[valueAsString.index(after: indexesOfSplitter[1])..<indexesOfSplitter[2]])) else {
                trace("    failed to convert batteryPercentage field to Int", log: log, type: .error)
                return
            }
            
            // fourth field is sensor time in minutes, stop if convert to Int fails
            guard let sensorTimeInMinutes = Int(String(valueAsString[valueAsString.index(after: indexesOfSplitter[2])..<valueAsString.endIndex])) else {
                trace("    failed to convert sensorTimeInMinutes field  to Int", log: log, type: .error)
                return
            }

            // send to delegate
            var glucoseDataArray = [GlucoseData(timeStamp: Date(), glucoseLevelRaw: rawValueAsDouble)]
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorState: nil, sensorTimeInMinutes: sensorTimeInMinutes * 10, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)
            
        } else {
            trace("    value is nil, no further processing", log: log, type: .error)
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
    func setWebOOPEnabled(enabled: Bool) {
    }

}
