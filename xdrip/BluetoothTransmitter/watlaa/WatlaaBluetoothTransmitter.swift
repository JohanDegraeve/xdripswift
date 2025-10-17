import Foundation
import os
import CoreBluetooth

final class WatlaaBluetoothTransmitter: BluetoothTransmitter {
    
    // MARK: - public properties
    
    public weak var watlaaBluetoothTransmitterDelegate: WatlaaBluetoothTransmitterDelegate?

    // MARK: - UUID's
    
    /// This service is identical to Tomato service (MiaoMiao), has the same UUID and data exchange protocol
    let CBUUID_Data_Service = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"

    /// Watlaa settings Service UUID
    let CBUUID_Watlaa_Settings_Service = "00001010-1212-EFDE-0137-875F45AC0113"
    
    /// Battery Service UUID
    let CBUUID_Battery_Service = "0000180F-0000-1000-8000-00805F9B34FB"
    
    /// characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    public enum CBUUID_Characteristic_UUID:String, CustomStringConvertible, CaseIterable {
        
        /// Bridge connection status characteristic
        case CBUUID_BridgeConnectionStatus_Characteristic = "00001012-1212-EFDE-0137-875F45AC0113"
        
        /// Calibration characteristic
        case CBUUID_Calibration_Characteristic = "00001014-1212-EFDE-0137-875F45AC0113"
        
        /// Glucose units characteristic
        case CBUUID_GlucoseUnit_Characteristic = "00001015-1212-EFDE-0137-875F45AC0113"
        
        /// Alerts settings characteristic
        case CBUUID_AlertSettings_Characteristic = "00001016-1212-EFDE-0137-875F45AC0113"
        
        /// Battery level characteristic
        case CBUUID_BatteryLevel_Characteristic = "00002A19-0000-1000-8000-00805F9B34FB"
        
        /// receive characteristic (see MiaoMiao)
        case CBUUID_ReceiveCharacteristic = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        
        /// write characteristic (see MiaoMiao)
        case CBUUID_WriteCharacteristic = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        

        /// for logging, returns a readable name for the characteristic
        var description: String {
            
            switch self {
                
            case .CBUUID_BridgeConnectionStatus_Characteristic:
                return "BridgeConnectionStatus"
                
            case .CBUUID_Calibration_Characteristic:
                return "Calibration"
                
            case .CBUUID_GlucoseUnit_Characteristic:
                return "GlucoseUnit"
                
            case .CBUUID_AlertSettings_Characteristic:
                return "AlertSettings"
                
            case .CBUUID_BatteryLevel_Characteristic:
                return "BatteryLevel"

            case .CBUUID_ReceiveCharacteristic:
                return "ReceiveCharacteristic"
                
            case .CBUUID_WriteCharacteristic:
                return "WriteCharacteristic"
                
            }
        }

    }
    
    /// is the transmitter oop web enabled or not
    public var webOOPEnabled: Bool
    
    /// is nonFixed enabled for the transmitter or not
    public var nonFixedSlopeEnabled: Bool
    
    // MARK: Other private properties
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatlaa)
    
    /// will be used to pass back bluetooth and cgm related events
    private weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    // maximum times resend request due to crc error (not sure if that works for Watlaa, this is copied from CGMMiaoMiaoTransmitter
    let maxPacketResendRequests = 3
    
    /// receive buffer for bubble packets
    private var rxBuffer:Data

    /// counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0

    /// used when processing data packet
    private var timestampFirstPacketReception:Date

    /// battery level Characteristic, needed to be able to read value
    private var batteryLevelCharacteric: CBCharacteristic?
    
    /// how long to wait for next packet before sending startreadingcommand
    private let maxWaitForpacketInSeconds = 60.0

    /// length of header added by MiaoMiao in front of data dat is received from Libre sensor  (copied from MiaoMiao code)
    private let miaoMiaoHeaderLength = 18

    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?

    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    /// instance of libreDataParser
    private let libreDataParser: LibreDataParser

    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - cgmTransmitterDelegate : CGMTransmitterDelegate
    ///     - watlaaBluetoothTransmitterDelegate : the WatlaaBluetoothTransmitterDelegate
    ///     - bluetoothTransmitterDelegate : BluetoothTransmitterDelegate
    init(address:String?, name: String?, cgmTransmitterDelegate:CGMTransmitterDelegate?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, watlaaBluetoothTransmitterDelegate: WatlaaBluetoothTransmitterDelegate, sensorSerialNumber:String?, webOOPEnabled: Bool?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "watlaa")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }

        // initialize rxbuffer
        rxBuffer = Data()
        timestampFirstPacketReception = Date()

        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cgmTransmitterDelegate
        
        // assign watlaaBluetoothTransmitterDelegate
        self.watlaaBluetoothTransmitterDelegate = watlaaBluetoothTransmitterDelegate
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false

        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // assign sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // initiliaze LibreDataParser
        self.libreDataParser = LibreDataParser()
        
        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will not be used in the superclass
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Data_Service), CBUUID(string: CBUUID_Battery_Service), CBUUID(string: CBUUID_Watlaa_Settings_Service)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_ReceiveCharacteristic.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_WriteCharacteristic.rawValue, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    /// read battery level
    public func readBatteryLevel() {

        if let batteryLevelCharacteric = batteryLevelCharacteric {
            readValueForCharacteristic(for: batteryLevelCharacteric)
        }
        
    }

    /// to ask for the first reading - SEEMS NOT WORKING FOR WATLAA
    func sendStartReadingCommand() -> Bool {
        if writeDataToPeripheral(data: Data.init([0xF0]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommand, write failed", log: log, category: ConstantsLog.categoryWatlaa, type: .error)
            return false
        }
    }

    // MARK: - private functions

    /// reset rxBuffer, reset startDate, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampFirstPacketReception = Date()
        resendPacketCounter = 0
    }

    /// creates CBUUID_Characteristic_UUID for the characteristicUUID
    private func receivedCharacteristicUUIDToCharacteristic(characteristicUUID:String) -> CBUUID_Characteristic_UUID? {
        
        // using enum to make sure  no new characteristics are forgotten in case new are added in the future
        for characteristic_UUID in CBUUID_Characteristic_UUID.allCases {
            
            switch characteristic_UUID {
                
            case .CBUUID_BridgeConnectionStatus_Characteristic:
                if CBUUID_Characteristic_UUID.CBUUID_BridgeConnectionStatus_Characteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_BridgeConnectionStatus_Characteristic
                }

            case .CBUUID_Calibration_Characteristic:
                if CBUUID_Characteristic_UUID.CBUUID_Calibration_Characteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_Calibration_Characteristic
                }

            case .CBUUID_GlucoseUnit_Characteristic:
                if CBUUID_Characteristic_UUID.CBUUID_GlucoseUnit_Characteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_GlucoseUnit_Characteristic
                }

            case .CBUUID_AlertSettings_Characteristic:
                if CBUUID_Characteristic_UUID.CBUUID_AlertSettings_Characteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_AlertSettings_Characteristic
                }

            case .CBUUID_BatteryLevel_Characteristic:
                if CBUUID_Characteristic_UUID.CBUUID_BatteryLevel_Characteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_BatteryLevel_Characteristic
                }

            case .CBUUID_ReceiveCharacteristic:
                if CBUUID_Characteristic_UUID.CBUUID_ReceiveCharacteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_ReceiveCharacteristic
                }
                
            case .CBUUID_WriteCharacteristic:
                if CBUUID_Characteristic_UUID.CBUUID_WriteCharacteristic.rawValue.containsIgnoringCase(find: characteristicUUID) {
                    return CBUUID_Characteristic_UUID.CBUUID_WriteCharacteristic
                }
                
            }
            
        }
        
        return nil
    }

    private func handleUpdateValueFor_BridgeConnectionStatus_Characteristic(value: Data) {}
    
    private func handleUpdateValueFor_Calibration_Characteristic(value: Data) {}
    
    private func handleUpdateValueFor_GlucoseUnit_Characteristic(value: Data) {}
    
    private func handleUpdateValueFor_AlertSettings_Characteristic(value: Data) {}
    
    private func handleUpdateValueFor_BatteryLevel_Characteristic(value: Data) {
        
        guard value.count >= 1 else {
            trace("   value length should be minimum 1", log: log, category: ConstantsLog.categoryWatlaa, type: .error)
            return
        }

        // Watlaa is sending batteryLevel, which is in the first byte
        let receivedBatteryLevel = Int(value[0])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.watlaaBluetoothTransmitterDelegate?.received(watlaaBatteryLevel: receivedBatteryLevel, watlaaBluetoothTransmitter: self)
        }

    }
    
    private func handleUpdateValueFor_CurrentTime_Characteristic(value: Data) {}
    
    private func handleUpdateValueFor_Receive_Characteristic(value: Data) {
        
        
        //check if buffer needs to be reset
        if (Date() > timestampFirstPacketReception.addingTimeInterval(maxWaitForpacketInSeconds - 1)) {
            trace("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryWatlaa, type: .info, maxWaitForpacketInSeconds)
            resetRxBuffer()
        }
        
        //add new packet to buffer
        rxBuffer.append(value)
        
        //check type of message and process according to type
        if let firstByte = rxBuffer.first {
            if let miaoMiaoResponseState = MiaoMiaoResponseType(rawValue: firstByte) {
                switch miaoMiaoResponseState {
                    
                case .dataPacket:
                    //if buffer complete, then start processing
                    if rxBuffer.count >= 363  {
                        trace("in peripheral didUpdateValueFor, Buffer complete", log: log, category: ConstantsLog.categoryWatlaa, type: .info)
                        
                        if (Crc.LibreCrc(data: &rxBuffer, headerOffset: miaoMiaoHeaderLength, libreSensorType: nil)) {

                            // get batteryPercentage
                            let batteryPercentage = Int(rxBuffer[13])
                            
                            // get sensor serialNumber and if changed inform delegate
                            if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: nil) {
                                
                                // verify serial number
                                // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                    
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryWatlaa, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform delegate about new sensor detected
                                    // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self = self else { return }
                                        self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)
                                        self.watlaaBluetoothTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    }
                                    
                                }
                                
                            }
                            
                            // send battery level to delegate and batteryPercentage to delegate on main thread
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                self.watlaaBluetoothTransmitterDelegate?.received(transmitterBatteryLevel: batteryPercentage, watlaaBluetoothTransmitter: self)
                                var emptyArrayCopy = self.emptyArray
                                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArrayCopy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorAge: nil)
                            }
                            
                            libreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: nil)?.serialNumber, patchInfo: nil, webOOPEnabled: webOOPEnabled, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: false, testTimeStamp: nil, completionHandler:  { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                // TODO : use sensorState as in MiaoMiao and Bubble : show the status on bluetoothPeripheralView
                                
                                // TODO : xDripError could be used to show latest errors in bluetoothPeripheralView
                                
                            }
                            )

                            //reset the buffer
                            resetRxBuffer()
                            
                        } else {
                            let temp = resendPacketCounter
                            resetRxBuffer()
                            resendPacketCounter = temp + 1
                            if resendPacketCounter < maxPacketResendRequests {
                                trace("in peripheral didUpdateValueFor, crc error encountered. New attempt launched", log: log, category: ConstantsLog.categoryWatlaa, type: .info)
                                _ = sendStartReadingCommand()
                            } else {
                                trace("in peripheral didUpdateValueFor, crc error encountered. Maximum nr of attempts reached", log: log, category: ConstantsLog.categoryWatlaa, type: .info)
                                resendPacketCounter = 0
                            }
                        }
                    }
                    
                case .frequencyChangedResponse:
                    trace("in peripheral didUpdateValueFor, frequencyChangedResponse received, shound't happen ?", log: log, category: ConstantsLog.categoryWatlaa, type: .error)
                    
                case .newSensor:
                    // not sure if watlaa will ever send this, and if so if it will handle the response correctly
                    // this is copied from MiaoMiao
                    trace("in peripheral didUpdateValueFor, new sensor detected", log: log, category: ConstantsLog.categoryWatlaa, type: .info)

                    // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)
                    }

                    // send 0xD3 and 0x01 to confirm sensor change as defined in MiaoMiao protocol documentation
                    // after that send start reading command, each with delay of 500 milliseconds
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                        if self.writeDataToPeripheral(data: Data.init([0xD3, 0x01]), type: .withoutResponse) {
                            trace("in peripheralDidUpdateValueFor, successfully sent 0xD3 and 0x01, confirm sensor change to MiaoMiao", log: self.log, category: ConstantsLog.categoryWatlaa, type: .info)
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                                if !self.sendStartReadingCommand() {
                                    trace("in peripheralDidUpdateValueFor, sendStartReadingCommand failed", log: self.log, category: ConstantsLog.categoryWatlaa, type: .error)
                                } else {
                                    trace("in peripheralDidUpdateValueFor, successfully sent startReadingCommand to MiaoMiao", log: self.log, category: ConstantsLog.categoryWatlaa, type: .info)
                                }
                            }
                        } else {
                            trace("in peripheralDidUpdateValueFor, write D301 failed", log: self.log, category: ConstantsLog.categoryWatlaa, type: .error)
                        }
                    }
                    
                case .noSensor:
                    trace("in peripheral didUpdateValueFor, sensor not detected - not sending this to delegate as I've seen this appearing while my bubble was correctly installed. Not sure if watlaa handles this correctly", log: log, category: ConstantsLog.categoryWatlaa, type: .info)
                    
                }
                
            } else {
                //rxbuffer doesn't start with a known miaomiaoresponse
                //reset the buffer and send start reading command
                trace("in peripheral didUpdateValueFor, rx buffer doesn't start with a known miaomiaoresponse, reset the buffer", log: log, category: ConstantsLog.categoryWatlaa, type: .error)
                resetRxBuffer()
            }
        }
        
    }
    
    private func handleUpdateValueFor_Write_Characteristic(value: Data) {}
    
    // MARK: - BluetoothTransmitter overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        if error == nil && characteristic.isNotifying {
            _ = sendStartReadingCommand()
        }
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        
        //need to store some of the characteristics to be able to write to them
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                
                if (characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_BatteryLevel_Characteristic.rawValue)) {
                    trace("    found batteryLevelCharacteristic", log: log, category: ConstantsLog.categoryWatlaa, type: .info)
                    batteryLevelCharacteric = characteristic
                    
                }
            }
        }
        
        // here all characteristics should be known, we can call isReadyToReceiveData
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.watlaaBluetoothTransmitterDelegate?.isReadyToReceiveData(watlaaBluetoothTransmitter: self)
        }
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        // find the CBUUID_Characteristic_UUID
        guard let receivedCharacteristic = receivedCharacteristicUUIDToCharacteristic(characteristicUUID: characteristic.uuid.uuidString) else {
            trace("in peripheralDidUpdateValueFor, unknown characteristic received with uuid = %{public}@", log: log, category: ConstantsLog.categoryWatlaa, type: .error, characteristic.uuid.uuidString)
            return
        }
        
        trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryWatlaa, type: .info, receivedCharacteristic.description)
        
        guard let value = characteristic.value else {return}
        
        switch receivedCharacteristic {
            
        case .CBUUID_BridgeConnectionStatus_Characteristic:
            handleUpdateValueFor_BridgeConnectionStatus_Characteristic(value: value)
            
        case .CBUUID_Calibration_Characteristic:
            handleUpdateValueFor_Calibration_Characteristic(value: value)
            
        case .CBUUID_GlucoseUnit_Characteristic:
            handleUpdateValueFor_GlucoseUnit_Characteristic(value: value)
            
        case .CBUUID_AlertSettings_Characteristic:
            handleUpdateValueFor_AlertSettings_Characteristic(value: value)
            
        case .CBUUID_BatteryLevel_Characteristic:
            handleUpdateValueFor_BatteryLevel_Characteristic(value: value)
            
        case .CBUUID_ReceiveCharacteristic:
            handleUpdateValueFor_Receive_Characteristic(value: value)
            
        case .CBUUID_WriteCharacteristic:
            // will probably never happen ?
            handleUpdateValueFor_Write_Characteristic(value: value)
            
        }
        
    }
    
}

