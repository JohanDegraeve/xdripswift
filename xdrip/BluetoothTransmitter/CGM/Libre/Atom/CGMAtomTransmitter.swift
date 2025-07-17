import Foundation
import CoreBluetooth
import os

class CGMAtomTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Atom: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Atom: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_Atom: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameAtom:String = "Atom"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// CGMAtomTransmitterDelegate
    public weak var cGMAtomTransmitterDelegate: CGMAtomTransmitterDelegate?
    
    // maximum times resend request due to crc error
    let maxPacketResendRequests = 3;
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMAtom)
    
    /// counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing Atom data packet
    private var timestampLastPacketReception:Date
    
    /// receive buffer for atom packets
    private var rxBuffer:Data
    
    /// how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 3.0
    
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// - current sensor serial number, if nil then it's not known yet
    /// - stored as data because serial number is recalculated when patchInfo is received
    private var sensorSerialNumberAsData: Data?
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    /// instance of libreDataParser
    private let libreDataParser: LibreDataParser
    
    // gives information about type of sensor (Libre1, Libre2, etc..)
    private var patchInfo: String?
    
    /// firmware, if received
    private var firmWare: String?
    
    /// current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// sensor type
    private var libreSensorType: LibreSensorType?
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - webOOPEnabled : enabled or not
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMAtomTransmitterDelegate : a CGMAtomTransmitterDelegate
    ///     - firmWare : firmWare if known
    ///     - sensorSerialNumber : sensor serial number, if nil then it's not yet known
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMAtomTransmitterDelegate : CGMAtomTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate,  sensorSerialNumber:String?, webOOPEnabled: Bool?, nonFixedSlopeEnabled: Bool?, firmWare: String?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameAtom)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber
        
        // assign firmWare
        self.firmWare = firmWare
        
        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMAtomTransmitterDelegate
        self.cGMAtomTransmitterDelegate = cGMAtomTransmitterDelegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initiliaze LibreDataParser
        self.libreDataParser = LibreDataParser()
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Atom)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Atom, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Atom, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommand() -> Bool {
        
        if writeDataToPeripheral(data: Data.init([0x00, 0x01, 0x05]), type: .withoutResponse) {
            
            return true
            
        } else {
            
            trace("in sendStartReadingCommand, write failed", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
            
            return false
            
        }
    }
    
    func sendAtomResponse() -> Bool {
        
        if writeDataToPeripheral(data: Data.init([0x02, 0x01, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse) {
            
            return true
            
        } else {
            
            trace("in sendAtomResponse, write failed", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
            
            return false
            
        }
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        if error == nil && characteristic.isNotifying {
            
            _ = sendStartReadingCommand()
            
        }
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        if let value = characteristic.value {
            
            //check if buffer needs to be reset
            if (Date() > timestampLastPacketReception.addingTimeInterval(CGMAtomTransmitter.maxWaitForpacketInSeconds)) {
                
                trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMAtom, type: .info, CGMAtomTransmitter.maxWaitForpacketInSeconds.description)
                
                resetRxBuffer()
                
            }
            
            // set timestampLastPacketReception to now, this gives the MM again maxWaitForpacketInSeconds seconds to send the next packet
            timestampLastPacketReception = Date()
            
            //check type of message and process according to type
            if let firstByte = value.first {
                
                if let atomResponseState = AtomResponseType(rawValue: firstByte) {
                    
                    switch atomResponseState {
                    
                    case .dataPacket:
                        
                        //add new packet to buffer, ignore the first 4 bytes
                        rxBuffer.append(value[4..<value.endIndex])
                        
                        //if buffer complete, then start processing
                        if rxBuffer.count >= 344  {
                            
                            trace("in peripheral didUpdateValueFor, Buffer complete", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                            
                            var dataIsDecryptedToLibre1Format = false
                            
                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo), let sensorSerialNumberAsData = sensorSerialNumberAsData {
                                // note that we should always have a libreSensorType
                                
                                self.libreSensorType = libreSensorType
                                
                                // decrypt of libre2 or libreUS
                                dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer[0..<344], headerLength: 0, log: log, patchInfo: patchInfo, uid: Array(sensorSerialNumberAsData))
                                
                                // now except libreProH, all libres' 344 data is libre1 format
                                // should crc check
                                guard libreSensorType.crcIsOk(rxBuffer: &self.rxBuffer[0..<344], headerLength: 0, log: log) else {
                                    
                                    let temp = resendPacketCounter
                                    resetRxBuffer()
                                    resendPacketCounter = temp + 1
                                    if resendPacketCounter < maxPacketResendRequests {
                                        
                                        trace("in peripheral didUpdateValueFor, crc error encountered. New attempt launched", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                                        
                                        _ = sendStartReadingCommand()
                                        
                                    } else {
                                        
                                        trace("in peripheral didUpdateValueFor, crc error encountered. Maximum nr of attempts reached", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                                        
                                        resendPacketCounter = 0
                                        
                                    }
                                    
                                    return
                                    
                                }
                                
                            }
                            
                            guard let sensorSerialNumberAsData = sensorSerialNumberAsData else {
                                
                                trace("in peripheral didUpdateValueFor, sensorSerialNumberAsData is nil, no further processing", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
                                
                                return
                                
                            }
                            
                            libreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: sensorSerialNumberAsData, with: LibreSensorType.type(patchInfo: patchInfo))?.serialNumber, patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, libreData: (rxBuffer[0..<344]), cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, testTimeStamp: nil, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                if let sensorState = sensorState {
                                    self.cGMAtomTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                                
                            })
                            
                            //reset the buffer
                            resetRxBuffer()
                            
                        }
                        
                    case .transmitterInfo:
                        
                        trace("in peripheral didUpdateValueFor, transmitterInfo received", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
                        
                        let transmitterBatteryPercentage = Int(value[4])
                        
                        // send transmitterBatteryInfo to cgmTransmitterDelegate
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: transmitterBatteryPercentage), sensorAge: nil)
                        
                        // send transmitter battery percentage to cGMAtomTransmitterDelegate
                        cGMAtomTransmitterDelegate?.received(batteryLevel: transmitterBatteryPercentage, from: self)
                        
                        // get firmware, byte 2 to hex + "." + byte 3 to hex
                        firmWare = String(describing: value[2..<3].hexEncodedString()) + "." + String(describing: value[3..<4].hexEncodedString())
                        
                        // send firmware to cGMAtomTransmitterDelegate
                        if let firmWare = firmWare {
                            cGMAtomTransmitterDelegate?.received(firmware: firmWare, from: self)
                        }
                        
                        // get hardware, last but one byte to hex + "." + last byte to hex
                        let hardWare = String(describing: value[(value.count - 2)..<(value.count - 1)].hexEncodedString()) + "." + String(describing: value[(value.count - 1)..<value.count].hexEncodedString())
                        
                        // send hardware to cGMAtomTransmitterDelegate
                        cGMAtomTransmitterDelegate?.received(hardware: hardWare, from: self)
                        
                        // send ack message
                        _ = sendAtomResponse()
                        
                    case .sensorNotDetected:
                        
                        trace("in peripheral didUpdateValueFor, received sensorNotDetected", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                        
                        // call cgmTransmitterDelegate sensorNotDetected
                        cgmTransmitterDelegate?.sensorNotDetected()
                        
                    case .sensorUID:
                        
                        trace("in peripheral didUpdateValueFor, received sensorUID", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                        
                        guard value.count >= 10 else {
                            
                            trace("in peripheral didUpdateValueFor, received sensorUID, not enough bytes received", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
                            
                            return
                            
                        }

                        // assign self.sensorSerialNumberAsData - not yet calculating the serialNumber, because the value depends on the patchInfo which we receive only in a second step
                        self.sensorSerialNumberAsData = value[2..<10]

                        
                    case .patchInfo:
                        
                        trace("in peripheral didUpdateValueFor, received patchInfo", log: log, category: ConstantsLog.categoryCGMAtom, type: .info)
                        
                        guard let firmWare = firmWare, let firmWareAsDouble = firmWare.toDouble() else {
                            
                            trace("in peripheral didUpdateValueFor, firmware nil or not convertible to double", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
                            
                            return
                            
                        }
                        
                        if firmWareAsDouble < 1.35 && value.count >= 9 {
                            
                            patchInfo = value[3..<9].hexEncodedString().uppercased()
                            
                        } else if value.count >= 11 {
                            
                            patchInfo = value[5..<11].hexEncodedString().uppercased()
                            
                        }
                        
                        if let patchInfo = patchInfo {
                            
                            trace("    received patchInfo %{public}@ ", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, patchInfo)
                            
                        }
                        
                        // send libreSensorType to delegate
                        if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                            
                            cGMAtomTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)
                            
                        }
                        
                        // recalculate serial number and send to delegate
                        if let sensorSerialNumberAsData = sensorSerialNumberAsData, let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: sensorSerialNumberAsData, with: LibreSensorType.type(patchInfo: patchInfo))  {
                            
                            // call to delegate, received sensor serialNumber
                            cGMAtomTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                            
                            if self.sensorSerialNumber != libreSensorSerialNumber.serialNumber {
                                
                                // assign self.sensorSerialNumber to libreSensorSerialNumber.serialNumber
                                self.sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                
                                // call delegate, to inform that a new sensor is detected
                                // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                                cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)

                            }

                        } else {
                            
                            trace("in peripheral didUpdateValueFor, could not create libreSensorSerialNumber", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                            
                            return
                            
                        }
                    
                        
                    }
                } else {
                    
                    //value doesn't start with a known atomresponse
                    
                    //reset the buffer
                    trace("in peripheral didUpdateValueFor, rx buffer doesn't start with a known atomresponse, reset the buffer", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
                    
                    resetRxBuffer()
                    
                }
            }
        } else {
            
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMAtom, type: .error)
            
        }
        
        
    }
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        resendPacketCounter = 0
    }

    // MARK: - CGMTransmitter protocol functions
    
    /// this transmitter supports oopWeb
    func setWebOOPEnabled(enabled: Bool) {
        
        webOOPEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
        
    }
    
    func isWebOOPEnabled() -> Bool {
        
        return webOOPEnabled
        
    }
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        
        nonFixedSlopeEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
        
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        
        return nonFixedSlopeEnabled
        
    }
    
    func requestNewReading() {
        
        _ = sendStartReadingCommand()
        
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        
        return .Atom
        
    }
    
    func maxSensorAgeInDays() -> Double? {
        
        return libreSensorType?.maxSensorAgeInDays()
        
    }

    func getCBUUID_Service() -> String {
        return CBUUID_Service_Atom
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Atom
    }

}




