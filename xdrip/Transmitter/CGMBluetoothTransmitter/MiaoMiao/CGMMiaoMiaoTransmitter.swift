import Foundation
import CoreBluetooth
import os

class CGMMiaoMiaoTransmitter:BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitter {
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
    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMMiaoMiao)
    
    // used in parsing packet
    private var timeStampLastBgReading:Date
    
    // counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing MiaoMiao data packet
    private var startDate:Date
    // receive buffer for miaomiao packets
    private var rxBuffer:Data
    // how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 60.0
    // length of header added by MiaoMiao in front of data dat is received from Libre sensor
    private let miaoMiaoHeaderLength = 18
    
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    init(address:String?, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date) {
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
        }

        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MiaoMiao)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao)
        
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data.init(bytes: [0xF0]), type: .withoutResponse) {
            return true
        } else {
            os_log("in sendStartReadingCommmand, write failed", log: log, type: .error)
            return false
        }
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
        if characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        //os_log("in peripheral didUpdateValueFor", log: log, type: .debug)
        if let value = characteristic.value {
            //only for logging
            //let data = value.hexEncodedString()
            //os_log("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .debug, data)
            
            //check if buffer needs to be reset
            if (Date() > startDate.addingTimeInterval(CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds - 1)) {
                os_log("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, type: .info, CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds)
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
                            os_log("in peripheral didUpdateValueFor, Buffer complete", log: log, type: .info)
                            
                            if (Crc.LibreCrc(data: &rxBuffer, headerOffset: miaoMiaoHeaderLength)) {
                                //get MiaoMiao info from MiaoMiao header
                                let firmware = String(describing: rxBuffer[14...15].hexEncodedString())
                                let hardware = String(describing: rxBuffer[16...17].hexEncodedString())
                                let batteryPercentage = Int(rxBuffer[13])
                                
                                //get readings from buffer and send to delegate
                                var result = parseLibreData(data: &rxBuffer, timeStampLastBgReadingStoredInDatabase: timeStampLastBgReading, headerOffset: miaoMiaoHeaderLength)
                                //TODO: sort glucosedata before calling newReadingsReceived
                                cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorState: result.sensorState, sensorTimeInMinutes: result.sensorTimeInMinutes, firmware: firmware, hardware: hardware)
                                
                                //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
                                if result.glucoseData.count > 0 {
                                    timeStampLastBgReading = result.glucoseData[0].timeStamp
                                }
                                
                                //reset the buffer
                                resetRxBuffer()
                            } else {
                                let temp = resendPacketCounter
                                resetRxBuffer()
                                resendPacketCounter = temp + 1
                                if resendPacketCounter < maxPacketResendRequests {
                                    os_log("in peripheral didUpdateValueFor, crc error encountered. New attempt launched", log: log, type: .info)
                                    _ = sendStartReadingCommmand()
                                } else {
                                    os_log("in peripheral didUpdateValueFor, crc error encountered. Maximum nr of attempts reached", log: log, type: .info)
                                    resendPacketCounter = 0
                                }
                            }
                        }
                        
                    case .frequencyChangedResponse:
                        os_log("in peripheral didUpdateValueFor, frequencyChangedResponse received, shound't happen ?", log: log, type: .error)
                    case .newSensor:
                        os_log("in peripheral didUpdateValueFor, new sensor detected", log: log, type: .info)
                        cgmTransmitterDelegate?.newSensorDetected()
                    case .noSensor:
                        os_log("in peripheral didUpdateValueFor, sensor not detected", log: log, type: .info)
                        cgmTransmitterDelegate?.sensorNotDetected()
                    }
                } else {
                    //rxbuffer doesn't start with a known miaomiaoresponse
                    //reset the buffer and send start reading command
                    os_log("in peripheral didUpdateValueFor, rx buffer doesn't start with a known miaomiaoresponse, reset the buffer", log: log, type: .error)
                    resetRxBuffer()
                }
            }
        } else {
            os_log("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, type: .error)
        }
    }
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
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

