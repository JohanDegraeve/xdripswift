import Foundation
import CoreBluetooth
import os

class CGMMiaoMiaoTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_MiaoMiao: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_MiaoMiao: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_MiaoMiao: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameMiaoMiao:String = "MiaoMiao"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?

    /// CGMMiaoMiaoTransmitterDelegate
    public weak var cGMMiaoMiaoTransmitterDelegate: CGMMiaoMiaoTransmitterDelegate?

    // maximum times resend request due to crc error
    let maxPacketResendRequests = 3;
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMMiaoMiao)
    
    /// timestamp of last received reading. When a new packet is received, then only the more recent readings will be treated
    private var timeStampLastBgReading:Date
    
    /// counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing MiaoMiao data packet
    private var timestampLastPacketReception:Date
    
    /// receive buffer for miaomiao packets
    private var rxBuffer:Data
    
    /// how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 3.0
    
    /// length of header added by MiaoMiao in front of data dat is received from Libre sensor
    private let miaoMiaoHeaderLength = 18
    
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
        
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?

    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - timeStampLastBgReading : timestamp of last bgReading
    ///     - webOOPEnabled : enabled or not
    ///     - oopWebSite : oop web site url to use, only used in case webOOPEnabled = true
    ///     - oopWebToken : oop web token to use, only used in case webOOPEnabled = true
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMMiaoMiaoTransmitterDelegate : a CGMMiaoMiaoTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMMiaoMiaoTransmitterDelegate : CGMMiaoMiaoTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, timeStampLastBgReading: Date?, sensorSerialNumber:String?, webOOPEnabled: Bool?, oopWebSite: String?, oopWebToken: String?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }

        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMMiaoMiaoTransmitterDelegate
        self.cGMMiaoMiaoTransmitterDelegate = cGMMiaoMiaoTransmitterDelegate
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // initialize rxbuffer
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        
        // initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading ?? Date(timeIntervalSince1970: 0)

        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken ?? ConstantsLibre.token
        self.oopWebSite = oopWebSite ?? ConstantsLibre.site
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MiaoMiao)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommand() -> Bool {
        if writeDataToPeripheral(data: Data.init([0xF0]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommand, write failed", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
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
            if (Date() > timestampLastPacketReception.addingTimeInterval(CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds)) {
                trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds.description)
                resetRxBuffer()
            }
            
            // set timestampLastPacketReception to now, this gives the MM again maxWaitForpacketInSeconds seconds to send the next packet
            timestampLastPacketReception = Date()
            
            //add new packet to buffer
            rxBuffer.append(value)
            
            //check type of message and process according to type
            if let firstByte = rxBuffer.first {
                if let miaoMiaoResponseState = MiaoMiaoResponseType(rawValue: firstByte) {
                    switch miaoMiaoResponseState {
                        
                    case .dataPacket:
                        //if buffer complete, then start processing
                        if rxBuffer.count >= 363  {
                            trace("in peripheral didUpdateValueFor, Buffer complete", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                            
                            /// gives information about type of sensor (Libre1, Libre2, etc..) - if transmitter doesn't offer patchInfo, then use nil value, which corresponds to Libre 1
                            var patchInfo: String?

                            // first off all see if the buffer contains patchInfo, and if yes send to delegate
                            if rxBuffer.count >= 369 {
                                
                                patchInfo = Data(rxBuffer[363...368]).hexEncodedString().uppercased()
                                
                                if let patchInfo = patchInfo {
                                    trace("    received patchInfo %{public}@", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, patchInfo)
                                }
                                
                            }
                            
                            var dataIsDecryptedToLibre1Format = false

                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                                // note that we should always have a libreSensorType
                                
                                cGMMiaoMiaoTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)

                                // decrypt of libre2 or libreUS
                                dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: log, patchInfo: patchInfo)
                                
                                // now except libreProH, all libres' 344 data is libre1 format
                                // should crc check
                                guard libreSensorType.crcIsOk(rxBuffer: &self.rxBuffer, headerLength: miaoMiaoHeaderLength, log: log) else {

                                    let temp = resendPacketCounter
                                    resetRxBuffer()
                                    resendPacketCounter = temp + 1
                                    if resendPacketCounter < maxPacketResendRequests {
                                        trace("in peripheral didUpdateValueFor, crc error encountered. New attempt launched", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                        _ = sendStartReadingCommand()
                                    } else {
                                        trace("in peripheral didUpdateValueFor, crc error encountered. Maximum nr of attempts reached", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                        resendPacketCounter = 0
                                    }

                                    return
                                    
                                }

                            }
                                
                            //get MiaoMiao info from MiaoMiao header
                            let firmware = String(describing: rxBuffer[14...15].hexEncodedString())
                            let hardware = String(describing: rxBuffer[16...17].hexEncodedString())
                            let batteryPercentage = Int(rxBuffer[13])
                            
                            // send firmware, hardware, battery level to delegate
                            cGMMiaoMiaoTransmitterDelegate?.received(firmware: firmware, from: self)
                            cGMMiaoMiaoTransmitterDelegate?.received(hardware: hardware, from: self)
                            cGMMiaoMiaoTransmitterDelegate?.received(batteryLevel: batteryPercentage, from: self)
                            
                            // send batteryPercentage to delegate
                            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorTimeInMinutes: nil)

                            // get sensor serialNumber and if changed inform delegate
                            if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))) {
                                
                                // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                    
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform delegate about new sensor detected
                                    cgmTransmitterDelegate?.newSensorDetected()
                                    
                                    cGMMiaoMiaoTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    
                                    // also reset timestamp last reading, to be sure that if new sensor is started, we get historic data
                                    timeStampLastBgReading = Date(timeIntervalSince1970: 0)
                                    
                                }
                                
                            }
                            
                            LibreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))), patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: timeStampLastBgReading, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, completionHandler: { (timeStampLastBgReading: Date?, sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                if let timeStampLastBgReading = timeStampLastBgReading {
                                    self.timeStampLastBgReading = timeStampLastBgReading
                                }
                                
                                if let sensorState = sensorState {
                                    self.cGMMiaoMiaoTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                                
                                // TODO : xDripError could be used to show latest errors in bluetoothPeripheralView
                                
                            })
                            
                            //reset the buffer
                            resetRxBuffer()

                        }
                        
                    case .frequencyChangedResponse:
                        trace("in peripheral didUpdateValueFor, frequencyChangedResponse received, shound't happen ?", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                        
                    case .newSensor:
                        trace("in peripheral didUpdateValueFor, new sensor detected", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                        cgmTransmitterDelegate?.newSensorDetected()
                        
                        // send 0xD3 and 0x01 to confirm sensor change as defined in MiaoMiao protocol documentation
                        // after that send start reading command, each with delay of 500 milliseconds
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                            if self.writeDataToPeripheral(data: Data.init([0xD3, 0x01]), type: .withoutResponse) {
                                trace("in peripheralDidUpdateValueFor, successfully sent 0xD3 and 0x01, confirm sensor change to MiaoMiao", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                                    if !self.sendStartReadingCommand() {
                                        trace("in peripheralDidUpdateValueFor, sendStartReadingCommand failed", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                                    } else {
                                        trace("in peripheralDidUpdateValueFor, successfully sent startReadingCommand to MiaoMiao", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                    }
                                }
                            } else {
                                trace("in peripheralDidUpdateValueFor, write D301 failed", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                            }
                        }
                        
                    case .noSensor:
                        trace("in peripheral didUpdateValueFor, sensor not detected", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                        // call to delegate
                        cgmTransmitterDelegate?.sensorNotDetected()
                        
                    }
                } else {
                    //rxbuffer doesn't start with a known miaomiaoresponse
                    //reset the buffer and send start reading command
                    trace("in peripheral didUpdateValueFor, rx buffer doesn't start with a known miaomiaoresponse, reset the buffer", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                    resetRxBuffer()
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
        }
        
        
    }
    
    // MARK: CGMTransmitter protocol functions
    
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
    
    func setWebOOPSite(oopWebSite: String) {
        self.oopWebSite = oopWebSite
    }
    
    func setWebOOPToken(oopWebToken: String) {
        self.oopWebToken = oopWebToken
    }
    
    func requestNewReading() {
        _ = sendStartReadingCommand()
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .miaomiao
    }
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        resendPacketCounter = 0
    }
    
}



