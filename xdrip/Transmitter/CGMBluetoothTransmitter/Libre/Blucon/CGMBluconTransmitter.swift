import Foundation
import CoreBluetooth
import os

class CGMBluconTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// Blucon Service
    private let CBUUID_BluconService = "436A62C0-082E-4CE8-A08B-01D81F195B24"
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic_Blucon: String = "436A0C82-082E-4CE8-A08B-01D81F195B24"
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic_Blucon: String = "436AA6E9-082E-4CE8-A08B-01D81F195B24"
    
    /// if value starts with this string, then it's assume that a battery low indication is sent by the Blucon
    private let unknownCommand2BatteryLowIndicator = "8bda02"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBlucon)
    
    // actual device address
    private var actualDeviceAddress:String?
    
    // used in parsing packet
    private var timeStampLastBgReading:Date
    
    // waiting successful pairing yes or not
    private var waitingSuccessfulPairing:Bool = false
    
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []
    
    /// timestamp when wakeUpResponse was sent to Blucon
    private var timeStampLastWakeUpResponse:Date?
    
    /// BluconACKResponse will come in two different situations
    /// - after we have sent an ackwakeup command
    /// - after we have a sleep command
    /// shouldSendUnknown1CommandAfterReceivingWakeUpResponse and timeStampLastWakeUpResponsetime work together to determine the case
    private var shouldSendUnknown1CommandAfterReceivingBluconAckResponse = true
    
    /// used when processing Blucon data packet
    private var timestampFirstPacketReception:Date?
    
    // how long to wait for next packet before considering the session as failed
    private let maxWaitForHistoricDataInSeconds = 5.0

    // receive buffer for Blucon packets
    private var rxBuffer:Data
    
    // used in Blucon protocol
    private var nowGlucoseOffset:UInt8 = 0
    
    // used in Blucon protocol - corresponds to m_getNowGlucoseDataCommand
    private var waitingForGlucoseData = false
    
    // timestamp of sending singleBlockInfoPrefix command, if time of receiving singleBlockInfoResponsePrefix is too late, then reading will be ignored
    private var timeStampOfSendingSingleBlockInfoPrefix:Date?
    
    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID
    ///     - delegate : CGMTransmitterDelegate
    ///     - sensorSerialNumber : is needed to allow detection of a new sensor.
    init?(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date, sensorSerialNumber:String?) {
        
        // assign addressname and name or expected devicename
        // start by using expected device name
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: CGMBluconTransmitter.createExpectedDeviceName(transmitterIdSetByUser: transmitterID))
        if let address = address {
            // address not nil, means it already connected before, use that address
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
            actualDeviceAddress = address
        }
        
        // initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber
        
        // initialize rxbuffer
        rxBuffer = Data()

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
                returnValue = "0" + returnValue
            }
            returnValue = "BLU" + returnValue
        }

        return returnValue
    }
    
    /// writes command to blucon, withResponse, and also logs the command
    private func sendCommandToBlucon(opcode:BluconTransmitterOpCode) {

        trace("    send opcode %{public}@ to Blucon", log: log, type: .info, opcode.description)
        _ = writeDataToPeripheral(data: Data(hexadecimalString: opcode.rawValue)!, type: .withResponse)

    }
    
    /// reset rxBuffer, reset timestampFirstPacketReception, stop packetRxMonitorTimer
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampFirstPacketReception = Date()
    }
    
    /// process new historic data block received from Blucon, one block is the contents when receiving multipleBlockResponseIndex, inclusive the opcode - this is used if we ask all Libre data from the transmitter, which includes sensorTime and sensorStatus
    /// - returns:
    ///     - did receive all data yes or no, if yes, then blucon can go to sleep
    /// also calls delegate with result of new readings
    private func handleNewHistoricData(block: Data) -> Bool {
        
        //check if buffer needs to be reset
        if let timestampFirstPacketReception = timestampFirstPacketReception {
            if (Date() > timestampFirstPacketReception.addingTimeInterval(maxWaitForHistoricDataInSeconds - 1)) {
                trace("in handleNewHistoricData, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, type: .info,maxWaitForHistoricDataInSeconds)
                resetRxBuffer()
            }
        }

        //add new packet to buffer, ignoring the opcode (2 bytes), the number of the next block (1 byte), and the number of blocks in the data (1 byte)
        rxBuffer.append(block[4..<block.count])
        
        // if rxBuffer has reached minimum lenght, then start processing
        if rxBuffer.count >= 344 {
            
            trace("in handleNewHistoricData, reached minimum length, processing data", log: log, type: .info)
            
            // crc check
            guard Crc.LibreCrc(data: &rxBuffer, headerOffset: 0) else {
                
                trace("    crc check failed, no further processing", log: log, type: .error)
                
                // transmitter can go to sleep
                return true
                
            }

            //get readings from buffer and send to delegate
            var result = LibreDataParser.parse(libreData: rxBuffer, timeStampLastBgReading: timeStampLastBgReading)
            
            //TODO: sort glucosedata before calling newReadingsReceived
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: nil, sensorState: result.sensorState, sensorTimeInMinutes: result.sensorTimeInMinutes, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)
            
            //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
            if result.glucoseData.count > 0 {
                timeStampLastBgReading = result.glucoseData[0].timeStamp
            }
            
            //reset the buffer
            resetRxBuffer()
            
            // transmitter can go to sleep
            return true
            
        }

        // transmitter should send more data
        return false
    }
    
    private func blockNumberForNowGlucoseData(input:Data) -> String {
        
        // caculate byte position in sensor body, decrement index to get the index where the last valid BG reading is stored
        var nowGlucoseIndex2 = input[5] * 6 + 4 - 6
        
        // adjust round robin
        if nowGlucoseIndex2 < 4 {
            nowGlucoseIndex2 = nowGlucoseIndex2 + 96
        }
        
        // calculate the absolute block number which correspond to trend index
        let nowGlucoseIndex3 = 3 + (nowGlucoseIndex2/8)
        
        // calculate offset of the 2 bytes in the block
        nowGlucoseOffset = nowGlucoseIndex2 % 8
        
        
        let nowGlucoseDataAsHexString = nowGlucoseIndex3.description

        return nowGlucoseDataAsHexString
    }
    
    private func nowGetGlucoseValue(input:Data) -> Double {
        
        // example 8BDE07DB010F04C868DB01
        // value 1 = 0F
        // value 2 = 04
        //rawGlucose = (input[3 + nowGlucoseOffset + 1] & 0x0F) * 256 + input[3 + nowGlucoseOffset] = 1039
        let value1 = input[3 + Int(nowGlucoseOffset)]
        let value2 = input[3 + Int(nowGlucoseOffset) + 1]
        
        let rawGlucose = Double((UInt16(value2 & 0x0F)<<8) | UInt16(value1 & 0xFF))
        
        // rescale for Libre
        let curGluc = rawGlucose * ConstantsBloodGlucose.libreMultiplier
        
        return(curGluc)
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
    
    /// this transmitter does not support oopWeb
    func setWebOOPEnabled(enabled: Bool) {
    }

}

extension CGMBluconTransmitter: BluetoothTransmitterDelegate {
    
    func centralManagerDidConnect(address: String?, name: String?) {
        trace("in centralManagerDidConnect", log: log, type: .info)
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
        trace("in centralManagerDidFailToConnect", log: log, type: .error)
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        trace("in centralManagerDidDisconnectPeripheral", log: log, type: .info)
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        trace("in peripheralDidUpdateNotificationStateFor", log: log, type: .info)
        
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
        trace("in peripheralDidUpdateValueFor with characteristic UUID = %{public}@", log: log, type: .info, characteristic.uuid.uuidString)

        // this is only applicable the very first time that blucon connects and pairing is done
        if waitingSuccessfulPairing {
            cgmTransmitterDelegate?.successfullyPaired()
            waitingSuccessfulPairing = false
        }

        // check if error occured
        if let error = error {
            trace("   error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let value = characteristic.value {
            
            // convert to string and log the value
            let valueAsString = value.hexEncodedString()
            
            trace("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .info, valueAsString)
            
            // get Opcode
            if let opCode = BluconTransmitterOpCode(withOpCodeValue: valueAsString) {
                
                trace("    received opcode = %{public}@ from Blucon", log: log, type: .info, opCode.description)
                
                switch opCode {
                    
                case .getPatchInfoRequest, .wakeUpResponse, .sleep, .unknown1Command, .unknown2Command, .getHistoricDataAllBlocksCommand, .getNowDataIndex, .singleBlockInfoPrefix:
                    // these are commands that app sends to Blucon, shouldn't receive any of them
                    break
                    
                case .wakeUpRequest:
                    
                        // start by setting waitingForGlucoseData to false, it might still have value true due to protocol error
                        waitingForGlucoseData = false
                        
                        // send getPatchInfoRequest
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.getPatchInfoRequest)
                    
                        // by default set battery level to 100
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 100), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)

                
                case .error14:
                    
                    // Blucon didn't receive the next command it was waiting for, need to wait 5 minutes
                    trace("    Timeout received, need to  wait 5 minutes or push button to restart!", log: log, type: .error)

                    // and send Blucon to sleep
                    sendCommandToBlucon(opcode: .sleep)

                case .sensorNotDetected:
                    
                    // Blucon didn't detect sensor, call delegate
                    cgmTransmitterDelegate?.sensorNotDetected()
                    
                    // and send Blucon to sleep
                    sendCommandToBlucon(opcode: .sleep)
                    
                case .getPatchInfoResponse:
                    
                    // get serial number
                    let newSerialNumber = BluconUtilities.decodeSerialNumber(input: value)
                    
                    // verify serial number and if changed inform delegate
                    if newSerialNumber != sensorSerialNumber {
                        
                        trace("    new sensor detected :  %{public}@", log: log, type: .info, newSerialNumber)
                        
                        sensorSerialNumber = newSerialNumber
                        
                        // inform delegate about new sensor detected
                        cgmTransmitterDelegate?.newSensorDetected()
                        
                        // also reset timestamp last reading, to be sure that if new sensor is started, we get historic data
                        timeStampLastBgReading = Date(timeIntervalSince1970: 0)
                        
                    }
                    
                    // read sensorState
                    let sensorState = LibreSensorState(stateByte: value[17])
                    
                    // if sensor is ready then send Ack, otherwise send sleep
                    if sensorState == LibreSensorState.ready {
                        
                        timeStampLastWakeUpResponse = Date()
                        shouldSendUnknown1CommandAfterReceivingBluconAckResponse = true
                        
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.wakeUpResponse)
                        
                    } else {
                        
                        trace("    sensorState =  %{public}@", log: log, type: .info, sensorState.description)

                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.sleep)

                    }

                    // inform delegate about sensorSerialNumber and sensorState
                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorState: sensorState, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: sensorSerialNumber)

                    return
                    
                case .bluconAckResponse:
                    
                    // BluconACKResponse will come in two different situations
                    // 1) after we have sent an ackwakeup command ==> need to send unknown1Command
                    // 2) after we have sent a sleep command ==> no command to send
                    // to verify in which case we are, timeStampLastWakeUpResponse is used
                    // assuming bluconAckResponse will arrive less than 5 seconds after having send wakeUpResponse
                    if let timeStampLastWakeUpResponse = timeStampLastWakeUpResponse, abs(timeStampLastWakeUpResponse.timeIntervalSinceNow) < 5 && shouldSendUnknown1CommandAfterReceivingBluconAckResponse {
                        
                            // set to false to be sure
                            shouldSendUnknown1CommandAfterReceivingBluconAckResponse = false

                            // send unknown1Command
                            sendCommandToBlucon(opcode: BluconTransmitterOpCode.unknown1Command)
                            
                    } else {
                        
                        trace("    no further processing, Blucon is sleeping now and should send a new reading in 5 minutes", log: log, type: .info)
                        
                    }
                    
                case .unknown1CommandResponse:
                    
                    sendCommandToBlucon(opcode: BluconTransmitterOpCode.unknown2Command)

                case .unknown2CommandResponse:
                    
                    // check if there's a battery low indication
                    if valueAsString.startsWith(unknownCommand2BatteryLowIndicator) {

                        // this is considered as battery level 5%
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 5), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)
                        
                    }

                    // if timeStampLastBgReading > 5 minutes ago, then we'll get historic data, otherwise just get the latest reading
                    if abs(timeStampLastBgReading.timeIntervalSinceNow) > 5 * 60 + 10 {

                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.getHistoricDataAllBlocksCommand)

                    } else {

                        // not asking for sensorAge as in Spike and xdripplus, we know the sensorAge because we started with getHistoricDataAllBlocksCommand
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.getNowDataIndex)
                        
                    }

                case .multipleBlockResponseIndex:
                    
                    if handleNewHistoricData(block: value) {

                        // when Blucon responds with bluconAckResponse, then there's no need to send unknown1Command
                        shouldSendUnknown1CommandAfterReceivingBluconAckResponse = false
                        
                        // send sleep command
                        sendCommandToBlucon(opcode: .sleep)
                        
                    }

                case .singleBlockInfoResponsePrefix:

                    if !waitingForGlucoseData {

                        // get blockNumber and compose command
                        let commandToSend = BluconTransmitterOpCode.singleBlockInfoPrefix.rawValue + blockNumberForNowGlucoseData(input: value)
                        
                        // convert command to hexstring, might fail if blockNumberForNowGlucoseData returned an invalid value
                        if let commandToSendAsData = Data(hexadecimalString: commandToSend) {
                            
                            trace("    send %{public}@ to Blucon", log: log, type: .info, commandToSend)
                            _ = writeDataToPeripheral(data: commandToSendAsData, type: .withResponse)
                            
                            waitingForGlucoseData = true
                            
                        } else {
                            
                            trace("    failed to convert commandToSend to Data", log: log, type: .error)
                        }

                    }  else {
                        
                        // reset waitingForGlucoseData to false as we will not wait for glucosedata, after having processed this reading
                        waitingForGlucoseData = false

                        // to be sure that waitingForGlucoseData is not having value true due to having broken protcol, verify when SingleBlockInfoPrefix was sent
                        if let timeStampOfSendingSingleBlockInfoPrefix = timeStampOfSendingSingleBlockInfoPrefix {
                            // should be a matter of milliseconds, so take 2 seconds
                            if abs(timeStampOfSendingSingleBlockInfoPrefix.timeIntervalSinceNow) > 2 {
                                
                                trace("    time since sending SingleBlockInfoPrefix is more than 2 seconds, ignoring this reading", log: log, type: .error)
                                
                                // send sleep command
                                sendCommandToBlucon(opcode: .sleep)
                                
                                return
                                
                            }
                        }
                        
                        // checking now timestamp of last reading, if less than 30 seconds old, then reading will be ignored, seems a bit late to do that check, but after a few tests it seems to be the best to continue up to here to make sure the Blucon stays in a consistent state.
                        if abs(timeStampLastBgReading.timeIntervalSinceNow) < 30 {
                            trace("    last reading less than 30 seconds old, ignoring this one", log: log, type: .info)
                        } else {

                            trace("    creating glucoseValue", log: log, type: .info)
                            
                            // create glucose reading with timestamp now
                            timeStampLastBgReading = Date()
                            
                            // get glucoseValue from value
                            let glucoseValue = nowGetGlucoseValue(input: value)
                            
                            let glucoseData = GlucoseData(timeStamp: timeStampLastBgReading, glucoseLevelRaw: glucoseValue, glucoseLevelFiltered: glucoseValue)
                            var glucoseDataArray = [glucoseData]
                            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: nil, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)

                        }
                        
                        sendCommandToBlucon(opcode: .sleep)
                        
                    }

                case .bluconBatteryLowIndication1:
                    
                    // this is considered as battery level 3%
                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 3), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)

                case .bluconBatteryLowIndication2:
                    
                    // this is considered as battery level 2%
                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 2), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)

                }
                
            }

        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, type: .error)
        }
        
    }
    
}
