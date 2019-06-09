import Foundation
import CoreBluetooth
import os

class CGMG5Transmitter:BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitter {
    // MARK: - properties
    
    /// UUID's
    // advertisement
    let CBUUID_Advertisement_G5 = "0000FEBC-0000-1000-8000-00805F9B34FB"
    // service
    let CBUUID_Service_G5 = "F8083532-849E-531C-C594-30F1F86A4EA5"
    // characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    private enum CBUUID_Characteristic_UUID:String, CustomStringConvertible  {
        // Read/Notify characteristic
        case CBUUID_Communication = "F8083533-849E-531C-C594-30F1F86A4EA5"
        // Write/Indicate - write characteristic
        case CBUUID_Write_Control = "F8083534-849E-531C-C594-30F1F86A4EA5"
        // Read/Write/Indicate - Read Characteristic
        case CBUUID_Receive_Authentication = "F8083535-849E-531C-C594-30F1F86A4EA5"
        // Read/Write/Notify
        case CBUUID_Backfill = "F8083536-849E-531C-C594-30F1F86A4EA5"

        var description: String {return self.rawValue}
    }

    // stored characteristics
    /// the write and control Characteristic
    private var writeControlCharacteristic:CBCharacteristic?
    /// the receive and authentication Characteristic
    private var receiveAuthenticationCharacteristic:CBCharacteristic?
    /// the communication Characteristic
    private var communicationCharacteristic:CBCharacteristic?
    /// the backfill Characteristic
    private var backfillCharacteristic:CBCharacteristic?


    //timestamp of last reading
    private var timeStampOfLastG5Reading:Date
    
    //timestamp of last battery read
    private var timeStampOfLastBatteryReading:Date
    
    //timestamp of transmitterReset
    private var timeStampTransmitterReset:Date
    
    /// transmitterId
    private let transmitterId:String

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMG5)
    
    /// is G5 reset necessary or not
    private var G5ResetRequested:Bool
    
    // G5 transmitter firmware version - only used internally, if nil then it was  never received
    private var transmitterVersion:String?
    
    // actual device address
    private var actualDeviceAddress:String?
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [RawGlucoseData] = []
    
    // for creating testreadings
    private var testAmount:Double = 150000.0
    
    // MARK: - functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    init?(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate) {
        //verify if transmitterid is 6 chars and allowed chars
        guard transmitterID.count == 6 else {
            os_log("transmitterID length not 6, init CGMG5Transmitter fails", log: log, type: .error)
            return nil
        }
        
        //verify allowed chars
        let regex = try! NSRegularExpression(pattern: "[a-zA-Z0-9]", options: .caseInsensitive)
        guard transmitterID.validate(withRegex: regex) else {
            os_log("transmitterID has non-allowed characters a-zA-Z0-9", log: log, type: .error)
            return nil
        }
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "DEXCOM" + transmitterID[transmitterID.index(transmitterID.startIndex, offsetBy: 4)..<transmitterID.endIndex])
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
            actualDeviceAddress = address
        }
        
        // set timestampoflastg5reading to 0
        self.timeStampOfLastG5Reading = Date(timeIntervalSince1970: 0)
        
        //set timeStampOfLastBatteryReading to 0
        self.timeStampOfLastBatteryReading = Date(timeIntervalSince1970: 0)
        
        //set timeStampTransmitterReset to 0
        self.timeStampTransmitterReset = Date(timeIntervalSince1970: 0)

        //assign transmitterId
        self.transmitterId = transmitterID
        
        // initialize G5ResetRequested
        self.G5ResetRequested = false

        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will probably not be used in the superclass
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G5, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G5)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue, startScanningAfterInit: CGMTransmitterType.dexcomG5.startScanningAfterInit())

        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self
        
        // start scanning
        _ = startScanning()
    }
    
    /// for testing , make the function public and call it after having activate a sensor in rootviewcontroller
    ///
    /// amount is rawvalue for testreading, should be number like 150000
    private func temptesting(amount:Double) {
        testAmount = amount
        Timer.scheduledTimer(timeInterval: 60 * 5, target: self, selector: #selector(self.createTestReading), userInfo: nil, repeats: true)
    }
    
    /// for testing, used by temptesting
    @objc private func createTestReading() {
        let testdata = RawGlucoseData(timeStamp: Date(), glucoseLevelRaw: testAmount, glucoseLevelFiltered: testAmount)
        debuglogging("timestamp testdata = " + testdata.timeStamp.description + ", with amount = " + testAmount.description)
        var testdataasarray = [testdata]
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &testdataasarray, transmitterBatteryInfo: nil, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, serialNumber: nil, bootloader: nil)
        testAmount = testAmount + 1
    }
    
    // MARK: public functions
    
    func doG5Reset() {
        G5ResetRequested = true
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if Date() < Date(timeInterval: 60, since: timeStampOfLastG5Reading) {
            // will probably never come here because reconnect doesn't happen with scanning, hence diddiscover will never be called excep the very first time that an app tries to connect to a G5
            os_log("diddiscover peripheral, but last reading was less than 1 minute ago, will ignore", log: log, type: .info)
        } else {
            super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if Date() < Date(timeInterval: 60, since: timeStampOfLastG5Reading) {
            os_log("connected, but last reading was less than 1 minute ago, disconnecting", log: log, type: .info)
            //TODO: is it not better to keep connection open till it times out ? should be tested with new device, see if battery drains, if it does, try with removing the disconnect - Spike also disconnects
            disconnect()
        } else {
            super.centralManager(central, didConnect: peripheral)
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        os_log("didDiscoverCharacteristicsFor", log: log, type: .info)
        
        // log error if any
        if let error = error {
            os_log("    error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                let ASCIIstring = characteristic.uuid.uuidString
                os_log("characteristic uuid: %{public}@", log: log, type: .info, ASCIIstring)
                if let characteristicValue = CBUUID_Characteristic_UUID(rawValue: ASCIIstring) {
                    switch characteristicValue {
                    case .CBUUID_Backfill:
                        backfillCharacteristic = characteristic
                    case .CBUUID_Write_Control:
                        writeControlCharacteristic = characteristic
                    case .CBUUID_Communication:
                        communicationCharacteristic = characteristic
                    case .CBUUID_Receive_Authentication:
                        receiveAuthenticationCharacteristic = characteristic
                        os_log("    calling setNotifyValue true", log: log, type: .info)
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                } else {
                    os_log("    characteristic UUID unknown", log: log, type: .error)
                }
            }
        } else {
            os_log("characteristics is nil. There must be some error.", log: log, type: .error)
        }
    }
    
    // MARK: BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address:String?, name:String?) {
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        // if status changed to poweredon, and if address = nil then superclass will not start the scanning
        // but for DexcomG5 we can start scanning
        if state == .poweredOn {
            if (actualDeviceAddress == nil) {
                    _ = startScanning()
            }
        }

        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheralDidUpdateNotificationStateFor", log: log, type: .info)
        if let error = error {
            os_log("    error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        let ASCIIstring = characteristic.uuid.uuidString
        os_log("    characteristic uuid: %{public}@", log: log, type: .info, ASCIIstring)
        if let characteristicValue = CBUUID_Characteristic_UUID(rawValue: ASCIIstring) {
            switch characteristicValue {
            case .CBUUID_Write_Control:
                if (G5ResetRequested) {
                    // send ResetTxMessage
                    sendG5Reset()
                } else {
                    // send SensorTxMessage to transmitter
                    getSensorData()
                }
            case .CBUUID_Receive_Authentication:
                //send AuthRequestTxMessage
                sendAuthRequestTxMessage()
            default:
                break
            }
        } else {
            os_log("    characteristicValue is nil", log: log, type: .error)
        }
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheralDidUpdateValueFor", log: log, type: .info)
        if let error = error {
            os_log("error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let value = characteristic.value {
            
            //only for logging
            let data = value.hexEncodedString()
            os_log("    data = %{public}@", log: log, type: .debug, data)
            
            //check type of message and process according to type
            if let firstByte = value.first {
                if let opCode = Opcode(rawValue: firstByte) {
                    os_log("    opcode = %{public}@", log: log, type: .info, opCode.description)
                    switch opCode {
                    case .authChallengeRx:
                        if let authChallengeRxMessage = AuthChallengeRxMessage(data: value) {
                            if !authChallengeRxMessage.bonded {
                                cgmTransmitterDelegate?.cgmTransmitterNeedsPairing()
                                os_log("    transmitter needs paring", log: log, type: .info)
                            } else {
                                if let writeControlCharacteristic = writeControlCharacteristic {
                                    setNotifyValue(true, for: writeControlCharacteristic)
                                } else {
                                    os_log("    writeControlCharacteristic is nil, can not set notifyValue", log: log, type: .error)
                                }
                            }
                        } else {
                            os_log("    failed to create authChallengeRxMessage", log: log, type: .info)
                        }
                    case .authRequestRx:
                        if let authRequestRxMessage = AuthRequestRxMessage(data: value), let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {
                            
                            guard let challengeHash = CGMG5Transmitter.computeHash(transmitterId, of: authRequestRxMessage.challenge) else {
                                os_log("    failed to calculate challengeHash, no further processing", log: log, type: .error)
                                return
                            }
                            
                            let authChallengeTxMessage = AuthChallengeTxMessage(challengeHash: challengeHash)
                            _ = writeDataToPeripheral(data: authChallengeTxMessage.data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)
                        } else {
                            os_log("    writeControlCharacteristic is nil or authRequestRxMessage is nil", log: log, type: .error)
                        }
                    case .sensorDataRx:
                        if let sensorDataRxMessage = SensorDataRxMessage(data: value) {
                            if transmitterVersion != nil {
                                // transmitterversion was already recceived, let's see if we need to get the batterystatus
                                if Date() > Date(timeInterval: Constants.DexcomG5.batteryReadPeriodInHours * 60 * 60, since: timeStampOfLastBatteryReading) {
                                    os_log("    last battery reading was long time, ago requesting now", log: log, type: .info)
                                    if let writeControlCharacteristic = writeControlCharacteristic {
                                        _ = writeDataToPeripheral(data: BatteryStatusTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
                                        timeStampOfLastBatteryReading = Date()
                                    } else {
                                        os_log("    writeControlCharacteristic is nil, can not send BatteryStatusTxMessage", log: log, type: .error)
                                    }
                                    //TODO: strictly speaking a disconnect should be done after having written the data
                                } else {
                                    disconnect()
                                }
                            } else {
                                if let writeControlCharacteristic = writeControlCharacteristic {
                                    _ = writeDataToPeripheral(data: TransmitterVersionTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
                                } else {
                                    os_log("    writeControlCharacteristic is nil, can not send TransmitterVersionTxMessage", log: log, type: .error)
                                }
                                //TODO: strictly speaking a disconnect should be done after having written the data
                            }
                            //if reset was done recently, less than 5 minutes ago, then ignore the reading
                            if Date() < Date(timeInterval: 5 * 60, since: timeStampTransmitterReset) {
                                os_log("    last transmitterreset was less than 5 minutes ago, ignoring this reading", log: log, type: .info)
                            } else {
                                if Date() < Date(timeInterval: 60, since: timeStampOfLastG5Reading) {
                                    os_log("    last reading was less than 1 minute ago, disconnecting", log: log, type: .info)
                                } else {
                                    timeStampOfLastG5Reading = Date()
                                    let glucoseData = RawGlucoseData(timeStamp: sensorDataRxMessage.timestamp, glucoseLevelRaw: sensorDataRxMessage.unfiltered, glucoseLevelFiltered: sensorDataRxMessage.filtered)
                                    var glucoseDataArray = [glucoseData]
                                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: nil, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, serialNumber: nil, bootloader: nil)
                                }
                            }
                            //start processing now the sensorDataRxMessage
                            
                        } else {
                            os_log("    sensorDataRxMessagee is nil", log: log, type: .error)
                        }
                    case .resetRx:
                        processResetRxMessage(value: value)
                    case .batteryStatusRx:
                        processBatteryStatusRxMessage(value: value)
                    case .transmitterVersionRx:
                        processTransmitterVersionRxMessage(value: value)
                    default:
                        os_log("    unknown opcode received ", log: log, type: .error)
                        break
                    }
                } else {
                    os_log("    value doesn't start with a known opcode = %{public}d", log: log, type: .error, firstByte)
                }
            } else {
                os_log("    characteristic.value is nil", log: log, type: .error)
            }
        }
    }

    // MARK: helper functions
    
    /// sends SensorTxMessage to transmitter
    private func getSensorData() {
        os_log("sending getsensordata", log: log, type: .info)
        if let writeControlCharacteristic = writeControlCharacteristic {
            _ = writeDataToPeripheral(data: SensorDataTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
        } else {
            os_log("    writeControlCharacteristic is nil, not getsensordata", log: log, type: .error)
        }
    }
    
    /// sends G5 reset to transmitter
    private func sendG5Reset() {
        os_log("sending G5Reset", log: log, type: .info)
        if let writeControlCharacteristic = writeControlCharacteristic {
            _ = writeDataToPeripheral(data: ResetTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            G5ResetRequested = false
        } else {
            os_log("    writeControlCharacteristic is nil, not sending G5 reset", log: log, type: .error)
        }
    }
    
    /// sends AuthRequestTxMessage to transmitter
    private func sendAuthRequestTxMessage() {
        let authMessage = AuthRequestTxMessage()
        if let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {
            _ = writeDataToPeripheral(data: authMessage.data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)
        } else {
            os_log("receiveAuthenticationCharacteristic is nil", log: log, type: .error)
        }
    }
    
    private func processResetRxMessage(value:Data) {
        if let resetRxMessage = ResetRxMessage(data: value) {
            os_log("resetRxMessage status is %{public}d", log: log, type: .info, resetRxMessage.status)
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorState: SensorState.G5Reset, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, serialNumber: nil, bootloader: nil)
        } else {
            os_log("resetRxMessage is nil", log: log, type: .error)
        }
    }
    
    private func processBatteryStatusRxMessage(value:Data) {
        if let batteryStatusRxMessage = BatteryStatusRxMessage(data: value) {
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.DexcomG5(voltageA: batteryStatusRxMessage.voltageA, voltageB: batteryStatusRxMessage.voltageB, resist: batteryStatusRxMessage.resist, runtime: batteryStatusRxMessage.runtime, temperature: batteryStatusRxMessage.temperature), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, serialNumber: nil, bootloader: nil)
        } else {
            os_log("batteryStatusRxMessage is nil", log: log, type: .error)
        }
    }
    
    private func processTransmitterVersionRxMessage(value:Data) {
        if let transmitterVersionRxMessage = TransmitterVersionRxMessage(data: value) {
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorState: nil, sensorTimeInMinutes: nil, firmware: transmitterVersionRxMessage.firmwareVersion.hexEncodedString(), hardware: nil, serialNumber: nil, bootloader: nil)
            // assign transmitterVersion
            transmitterVersion = transmitterVersionRxMessage.firmwareVersion.hexEncodedString()
        } else {
            os_log("transmitterVersionRxMessage is nil", log: log, type: .error)
        }
    }

    /// calculates encryptionkey
    private static func cryptKey(_ id:String) -> Data? {
        return "00\(id)00\(id)".data(using: .utf8)
    }
    
    /// compute hash
    private static func computeHash(_ id:String, of data: Data) -> Data? {
        guard data.count == 8 else {
            return nil
        }
        
        var doubleData = Data(capacity: data.count * 2)
        doubleData.append(data)
        doubleData.append(data)
        
        if let cryptKey = cryptKey(id) {
            if let outData = try? AESCrypt.encryptData(doubleData, usingKey: cryptKey) {
                return outData[0..<8]
            }
        }
        return nil
    }

}
