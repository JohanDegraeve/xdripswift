import Foundation
import CoreBluetooth
import os

class CGMBubbleTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Bubble: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Bubble: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_Bubble: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameBubble:String = "Bubble"
    
    /// CGMBubbleTransmitterDelegate
    public weak var cGMBubbleTransmitterDelegate: CGMBubbleTransmitterDelegate?

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMBubble)
    
    /// timestamp of last received reading. When a new packet is received, then only the more recent readings will be treated
    private var timeStampLastBgReading:Date
    
    /// used when processing Bubble data packet
    private var startDate:Date
    // receive buffer for bubble packets
    private var rxBuffer:Data
    // how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 60.0
    // length of header added by Bubble in front of data dat is received from Libre sensor
    private let bubbleHeaderLength = 8
   
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool

    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    /// current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// gives information about type of sensor (Libre1, Libre2, etc..)
    private var patchInfo: String?
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
    
    // MARK: - Initialization
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - delegate : CGMTransmitterDelegate intance
    ///     - timeStampLastBgReading : timestamp of last bgReading, if nil then 1 1 1970 is used
    ///     - webOOPEnabled : enabled or not, if nil then default false
    ///     - oopWebSite : oop web site url to use, only used in case webOOPEnabled = true, if nil then default value is used (see Constants)
    ///     - oopWebToken : oop web token to use, only used in case webOOPEnabled = true, if nil then default value is used (see Constants)
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMBubbleTransmitterDelegate : a CGMBubbleTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMBubbleTransmitterDelegate: CGMBubbleTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, timeStampLastBgReading:Date?, sensorSerialNumber:String?, webOOPEnabled: Bool?, oopWebSite: String?, oopWebToken: String?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameBubble)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign CGMBubbleTransmitterDelegate
        self.cGMBubbleTransmitterDelegate = cGMBubbleTransmitterDelegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        // initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading ?? Date(timeIntervalSince1970: 0)
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken ?? ConstantsLibre.token
        self.oopWebSite = oopWebSite ?? ConstantsLibre.site
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Bubble)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Bubble, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Bubble, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data([0x00, 0x00, 0x05]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommmand, write failed", log: log, category: ConstantsLog.categoryCGMBubble, type: .error)
            return false
        }
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        if error == nil && characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        if let value = characteristic.value {
            
            //check if buffer needs to be reset
            if (Date() > startDate.addingTimeInterval(CGMBubbleTransmitter.maxWaitForpacketInSeconds - 1)) {
                trace("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, CGMBubbleTransmitter.maxWaitForpacketInSeconds)
                resetRxBuffer()
            }
            
            if let firstByte = value.first {
                if let bubbleResponseState = BubbleResponseType(rawValue: firstByte) {
                    switch bubbleResponseState {
                        
                    case .dataInfo:
                        
                        // get hardware, firmware and batteryPercentage
                        let hardware = value[value.count-2].description + "." + value[value.count-1].description
                        let firmware = value[2].description + "." + value[3].description
                        let batteryPercentage = Int(value[4])
                        
                        // send firmware, hardware and battery to delegeate
                        cGMBubbleTransmitterDelegate?.received(firmware: firmware, from: self)
                        cGMBubbleTransmitterDelegate?.received(hardware: hardware, from: self)
                        cGMBubbleTransmitterDelegate?.received(batteryLevel: batteryPercentage, from: self)
                        
                        // send hardware, firmware and batteryPercentage to delegate
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorTimeInMinutes: nil)
                        
                        // confirm receipt
                        _ = writeDataToPeripheral(data: Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                        
                    case .serialNumber:
                        
                        guard value.count >= 10 else { return }
                        
                        // this is actually the sensor serial number, adding it to rxBuffer, although it could as wel be calculated here.
                        rxBuffer.append(value.subdata(in: 2..<10))
                        
                    case .dataPacket:
                        
                        
                        rxBuffer.append(value.suffix(from: 4))
                        
                        if rxBuffer.count >= 352 {
                            
                            // libreSensorSerialNumber has been added to rxBuffer when receving .serialNumber (0xC0), it's the first 8 bytes
                            guard let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 0..<8))) else {
                                trace("    could not create libreSensorSerialNumber", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                                return
                            }
                            
                            // verify serial number and if changed inform delegate
                            if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                
                                
                                sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                
                                trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, libreSensorSerialNumber.serialNumber)
                                
                                // inform delegate about new sensor detected
                                cgmTransmitterDelegate?.newSensorDetected()
                                
                                cGMBubbleTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                
                                // also reset timestamp last reading, to be sure that if new sensor is started, we get historic data
                                timeStampLastBgReading = Date(timeIntervalSince1970: 0)
                                
                            }

                            // get sensortype, and dependent on sensortype get crc
                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                                
                                // crc check only for Libre 1 (is this the right thing to do ?)
                                if libreSensorType == .libre1 {
                                    
                                    guard Crc.LibreCrc(data: &self.rxBuffer, headerOffset: self.bubbleHeaderLength) else {
                                        trace("    Libre 1 sensor, CRC check failed, no further processing", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                                        return
                                    }
                                    
                                }
                                
                                // do this for tracing only, not processing will continue if crc check fails
                                if libreSensorType == .libreProH {
                                    
                                    if !Crc.LibreCrc(data: &self.rxBuffer, headerOffset: self.bubbleHeaderLength) {
                                        trace("    libreProH sensor, CRC check failed - will continue processing anyway", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                                    }
                                    
                                }
                                
                            }

                            LibreDataParser.libreDataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: bubbleHeaderLength..<(344 + bubbleHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: timeStampLastBgReading, completionHandler: { (timeStampLastBgReading: Date?, sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                if let timeStampLastBgReading = timeStampLastBgReading {
                                    self.timeStampLastBgReading = timeStampLastBgReading
                                }
                                
                                if let sensorState = sensorState {
                                    self.cGMBubbleTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                                
                                // TODO : xDripError could be used to show latest errors in bluetoothPeripheralView
                                
                            })
                            
                            //reset the buffer
                            resetRxBuffer()
                        }
                        
                    case .noSensor:
                        cgmTransmitterDelegate?.sensorNotDetected()
                        
                    case .patchInfo:
                        if value.count >= 10 {
                            patchInfo = value.subdata(in: 5 ..< 11).hexEncodedString().uppercased()
                        }
                        
                        // send libreSensorType to delegate
                        if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                            cGMBubbleTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)
                        }
                        
                    }
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMBubble, type: .error)
        }
        
    }
        
    // MARK: CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        if nonFixedSlopeEnabled != enabled {
            
            nonFixedSlopeEnabled = enabled
            
            // nonFixed value changed, reset timeStampLastBgReading so that all glucose values will be sent to delegate. This is simply to ensure at least one reading will be sent to the delegate immediately.
            timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        
        if webOOPEnabled != enabled {
            
            webOOPEnabled = enabled
            
            // weboop value changed, reset timeStampLastBgReading so that all glucose values will be sent to delegate. This is simply to ensure at least one reading will be sent to the delegate immediately.
            timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            
        }
        
    }
    
    func setWebOOPSite(oopWebSite: String) {
        self.oopWebSite = oopWebSite
    }
    
    func setWebOOPToken(oopWebToken: String) {
        self.oopWebToken = oopWebToken
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Bubble
    }

    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }

    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
    }

    func requestNewReading() {
        
        _ = sendStartReadingCommmand()
        
    }

    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
    }
    
}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130 //0x82
    case dataInfo = 128 //0x80
    case noSensor = 191 //0xBF
    case serialNumber = 192 //0xC0
    case patchInfo = 193 //0xC1
}

extension BubbleResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket:
            return "Data packet received"
        case .noSensor:
            return "No sensor detected"
        case .dataInfo:
            return "Data info received"
        case .serialNumber:
            return "Serial number received"
        case .patchInfo:
            return "Patch info received"
        }
    }
}
