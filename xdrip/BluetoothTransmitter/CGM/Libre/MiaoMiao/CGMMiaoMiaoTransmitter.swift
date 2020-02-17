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

    // maximum times resend request due to crc error
    let maxPacketResendRequests = 3;
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMMiaoMiao)
    
    // used in parsing packet
    private var timeStampLastBgReading:Date
    
    /// counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing MiaoMiao data packet
    private var timestampFirstPacketReception:Date
    
    /// receive buffer for miaomiao packets
    private var rxBuffer:Data
    
    /// how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 60.0
    
    /// length of header added by MiaoMiao in front of data dat is received from Libre sensor
    private let miaoMiaoHeaderLength = 18
    
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
        
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
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, timeStampLastBgReading:Date, webOOPEnabled: Bool, oopWebSite: String, oopWebToken: String) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }

        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        timestampFirstPacketReception = Date()
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled

        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken
        self.oopWebSite = oopWebSite

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MiaoMiao)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao, startScanningAfterInit: CGMTransmitterType.miaomiao.startScanningAfterInit(), bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
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
            if (Date() > timestampFirstPacketReception.addingTimeInterval(CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds - 1)) {
                trace("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds)
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
                            trace("in peripheral didUpdateValueFor, Buffer complete", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                            
                            if (Crc.LibreCrc(data: &rxBuffer, headerOffset: miaoMiaoHeaderLength)) {
                                //get MiaoMiao info from MiaoMiao header
                                let firmware = String(describing: rxBuffer[14...15].hexEncodedString())
                                let hardware = String(describing: rxBuffer[16...17].hexEncodedString())
                                let batteryPercentage = Int(rxBuffer[13])
                                
                                LibreDataParser.libreDataProcessor(sensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)))?.serialNumber, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), firmware: firmware, hardware: hardware, hardwareSerialNumber: nil, bootloader: nil, timeStampLastBgReading: timeStampLastBgReading, completionHandler: {(timeStampLastBgReading:Date) in
                                    self.timeStampLastBgReading = timeStampLastBgReading
                                    
                                })
                                
                                //reset the buffer
                                resetRxBuffer()
                                
                            } else {
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
                            }
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
    
    /// to ask transmitter reset - empty function because MiaoMiao doesn't support reset
    ///
    /// this function is not implemented in BluetoothTransmitter.swift, otherwise it might be forgotten to look at in future CGMTransmitter developments
    func reset(requested:Bool) {}
 
    /// this transmitter supports oopWeb
    func setWebOOPEnabled(enabled: Bool) {
        webOOPEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
    }
    
    func setWebOOPSiteAndToken(oopWebSite: String, oopWebToken: String) {
        self.oopWebToken = oopWebToken
        self.oopWebSite = oopWebSite
    }

    func cgmTransmitterType() -> CGMTransmitterType? {
        return .miaomiao
    }
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampFirstPacketReception = Date()
        resendPacketCounter = 0
    }
    
}

fileprivate enum MiaoMiaoResponseType: UInt8 {
    case dataPacket = 0x28
    case newSensor = 0x32
    case noSensor = 0x34
    case frequencyChangedResponse = 0xD1
}

extension MiaoMiaoResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket:
            return "Data packet received"
        case .newSensor:
            return "New sensor detected"
        case .noSensor:
            return "No sensor detected"
        case .frequencyChangedResponse:
            return "Reading interval changed"
        }
    }
}

