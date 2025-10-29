import Foundation
import os
import CoreBluetooth

@objcMembers
class CGMBlueReaderTransmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_BlueReader: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_BlueReader: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_BlueReader: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
  
    /// CGMBlueReaderTransmitterDelegate - not used used as there's no specific settings saved nor displayed for BlueReader
    public weak var cGMBlueReaderTransmitterDelegate: CGMBlueReaderTransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMBlueReader)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMBlueReaderTransmitterDelegate : a CGMBlueReaderTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMBlueReaderTransmitterDelegate : CGMBlueReaderTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "blueReader")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMBlueReaderTransmitterDelegate
        self.cGMBlueReaderTransmitterDelegate = cGMBlueReaderTransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_BlueReader)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_BlueReader, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_BlueReader, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
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
            
            // send to delegate (UI/Core Data) on main thread
            let glucoseDataArray = [GlucoseData(timeStamp: Date(), glucoseLevelRaw: rawDataAsDouble)]
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var copy = glucoseDataArray
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: transMitterBatteryInfo, sensorAge: nil)
            }
            
        } else {
            trace("    value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMBlueReader, type: .error)
        }
        
    }

    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // BlueReader-specific: clear state synchronously
        let tearDown = {
            self.emptyArray.removeAll()
            self.nonFixedSlopeEnabled = false
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    deinit {
        // Defensive: clear delegates already handled in base, just ensure emptyArray is cleared
        emptyArray.removeAll()
    }
    
    // MARK: CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
    }

    func cgmTransmitterType() -> CGMTransmitterType {
        return .blueReader
    }

    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_Service_BlueReader
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_BlueReader
    }

}
