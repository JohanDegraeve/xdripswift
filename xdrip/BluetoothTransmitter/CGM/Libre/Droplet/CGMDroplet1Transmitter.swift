import Foundation
import os
import CoreBluetooth

@objcMembers
class CGMDroplet1Transmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Droplet: String = "C97433F0-BE8F-4DC8-B6F0-5343E6100EB4"
    
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Droplet: String = "c97433f1-be8f-4dc8-b6f0-5343e6100eb4"
    
    /// write characteristic
    let CBUUID_WriteCharacteristic_Droplet: String = "c97433f2-be8f-4dc8-b6f0-5343e6100eb4"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMDropletTransmitterDelegate
    public weak var cGMDropletTransmitterDelegate: CGMDropletTransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMDroplet1)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMDropletTransmitterDelegate : CGMDropletTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "limitter")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMDropletTransmitterDelegate
        self.cGMDropletTransmitterDelegate = cGMDropletTransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Droplet)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Droplet, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Droplet, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        trace("in peripheral didUpdateValueFor", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .info)
        
        if let value = characteristic.value {
            
            guard let valueAsString = String(bytes: value, encoding: .utf8)  else {
                trace("    failed to convert value to string", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
                return
            }
            
            //find indexes of " "
            let indexesOfSplitter = valueAsString.indexes(of: " ")
            
            // length of indexesOfSplitter should be minimum 3 (there should be minimum 3 spaces)
            guard indexesOfSplitter.count >= 3 else {
                trace("    there's less than 3 spaces", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
                return
            }
            
            // get first field
            let firstField = String(valueAsString[valueAsString.startIndex..<indexesOfSplitter[0]])
            
            // if firstfield equals "000000" or "000999" then sensor detection failure - inform delegate and return
            guard firstField != "000000" && firstField != "000999" else {
                DispatchQueue.main.async { [weak self] in
                    self?.cgmTransmitterDelegate?.sensorNotDetected()
                }
                return
            }
            
            // first field : first digits are rawvalue, to be multiplied with 100, last two digits are sensor type indicator, 10=L1, 20=L2, 30=US 14 day, 40=Lpro/h
            let rawValueAsString = firstField[0..<(firstField.count - 2)] + "00"
            let sensorTypeIndicator = firstField[(firstField.count - 2)..<firstField.count]
            trace("    sensor type indicator = %{public}@", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .info, rawValueAsString, sensorTypeIndicator)
            
            // convert rawValueAsString to double and stop if this fails
            guard let rawValueAsDouble = rawValueAsString.toDouble() else {
                trace("    failed to convert rawValueAsString to double", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
                return
            }
            
            // third field is battery percentage, stop if convert to Int fails
            guard let batteryPercentage = Int(String(valueAsString[valueAsString.index(after: indexesOfSplitter[1])..<indexesOfSplitter[2]])) else {
                trace("    failed to convert batteryPercentage field to Int", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
                return
            }
            
            // fourth field is sensor time in minutes, stop if convert to Int fails
            guard let sensorAgeInMinutes = Int(String(valueAsString[valueAsString.index(after: indexesOfSplitter[2])..<valueAsString.endIndex])) else {
                trace("    failed to convert sensorAge field  to Int", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
                return
            }
            
            // send glucoseDataArray, transmitterBatteryInfo and sensorAge to cgmTransmitterDelegate (main thread)
            let glucoseDataArray = [GlucoseData(timeStamp: Date(), glucoseLevelRaw: rawValueAsDouble)]
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var copy = glucoseDataArray
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorAge: TimeInterval(minutes: Double(sensorAgeInMinutes * 10)))
                self.cGMDropletTransmitterDelegate?.received(batteryLevel: batteryPercentage, from: self)
            }

        } else {
            trace("    value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMDroplet1, type: .error)
        }
        
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Droplet-specific: clear transient state synchronously on main
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
        // Defensive cleanup beyond base class
        emptyArray.removeAll()
    }
    
    // MARK: CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
    }

    func cgmTransmitterType() -> CGMTransmitterType {
        return .Droplet1
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }

    func getCBUUID_Service() -> String {
        return CBUUID_Service_Droplet
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Droplet
    }

}
