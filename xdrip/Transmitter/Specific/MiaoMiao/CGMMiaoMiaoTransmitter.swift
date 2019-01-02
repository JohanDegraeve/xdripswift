import Foundation
import CoreBluetooth
import os

class CGMGMiaoMiaoTransmitter:BluetoothTransmitter {
    
    // MARK: - properties
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    let CBUUID_Advertisement_MiaoMiao: String = ""
    /// service to be discovered
    let CBUUID_Service_MiaoMiao: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_MiaoMiao: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_MiaoMiao: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    // maximum times resend request due to crc error
    let maxPacketResendRequests = 3;
    
    /// expected device name
    let expectedDeviceNameMiaoMiao:String = "MiaoMiao"
    
    /// will be used to pass back bluetooth and cgm related events
    var cgmTransmitterDelegate:CGMTransmitterDelegate?

    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMMiaoMiao)
    
    // used in parsing packet, older readings will not be added in response to delegate
    private var timeStampLastBgReading:Date
    
    // counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing MiaoMiao data packet
    private var startDate:Date
    // receive buffer for miaomiao packets
    private var rxBuffer:Data
    // to monitor receipt of miaomiao packets
    weak private var packetRxMonitorTimer: Timer?
    // how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 8.0
    // length of header added by MiaoMiao in front of data dat is received from Libre sensor
    private let miaoMiaoHeaderLength = 18
    

    
    // MARK: - functions
    
    init(addressAndName: CGMGMiaoMiaoTransmitter.MiaoMiaoDeviceAddressAndName, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName
        switch addressAndName {
        case .alreadyConnectedBefore(let newAddress, let newName):
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: newAddress, name: newName)
        case .notYetConnected:
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        //initially no readings, set to 0
        timeStampLastBgReading = Date(timeIntervalSince1970: 0)
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_MiaoMiao, CBUUID_Service: CBUUID_Service_MiaoMiao, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao, delegate: delegate)
        
        //blueToothTransmitterDelegate = self
    }
    
    // MARK: - functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data.init(bytes: [0xF0]), type: .withoutResponse) {
            return true
        } else {
            os_log("in sendStartReadingCommmand, write failed", log: log, type: .error)
            return false
        }
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        if characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheral didUpdateValueFor", log: log, type: .debug)

        if let value = characteristic.value {
            
            //only for logging
            let data = value.hexEncodedString()
            os_log("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .debug, data)
            
            //check if buffer needs to be reset
            if (Date() > startDate.addingTimeInterval(CGMGMiaoMiaoTransmitter.maxWaitForpacketInSeconds - 1)) {
                os_log("in peripheral didUpdateValueFor, more than 10 seconds since last update - or first update since app launch, resetting buffer", log: log, type: .info)
                resetRxBuffer()
            }
            
            //add new packet to buffer
            rxBuffer.append(value)
            
            //check type of message and process according to type
            if let firstByte = rxBuffer.first {
                if let miaoMiaoResponseState = MiaoMiaoResponseState(rawValue: firstByte) {
                    switch miaoMiaoResponseState {
                    case .dataPacketReceived:
                        
                        // Set timer to check if data is still uncomplete after a certain time frame
                        // if so send start reading comand
                        packetRxMonitorTimer?.invalidate()
                        packetRxMonitorTimer = Timer.scheduledTimer(withTimeInterval: CGMGMiaoMiaoTransmitter.maxWaitForpacketInSeconds, repeats: false) { _ in
                            if self.sendStartReadingCommmand() {
                                os_log("in peripheral didUpdateValueFor, did not receive packet within %{public}@ seconds, startreadingcommand sent", log: self.log, type: .info, "\(CGMGMiaoMiaoTransmitter.maxWaitForpacketInSeconds)")
                            } else {
                                os_log("in peripheral didUpdateValueFor, did not receive packet within %{public}@ seconds, tried to send startreadingcommand but that failed", log: self.log, type: .error, "\(CGMGMiaoMiaoTransmitter.maxWaitForpacketInSeconds)")
                            }
                        }

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
                                cgmTransmitterDelegate?.newReadingsReceived(glucoseData: &result.glucoseData, sensorState: result.sensorState, firmware: firmware, hardware: hardware, batteryPercentage: batteryPercentage, sensorTimeInMinutes: result.sensorTimeInMinutes)

                                // set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
                                if result.glucoseData.count > 0 {
                                   timeStampLastBgReading = result.glucoseData[0].timeStamp
                                }
                                
                                //reset the buffer
                                resetRxBuffer()
                                
                                //invalidate the timer
                                packetRxMonitorTimer?.invalidate()
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
    
    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //just call super, we might as well just not override the function
        super.centralManagerDidUpdateState(central)
    }
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
        cgmTransmitterDelegate?.cgmTransmitterdidConnect()
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didWriteValueFor: characteristic, error: error)
        //nothing to do for MiaoMiao
    }

    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
        packetRxMonitorTimer?.invalidate()
        resendPacketCounter = 0
    }
    
    // MARK: - enum

    /// * if we never connected to a G4 bridge, then we don't know it's name and address as the Device itself is going to send.
    /// * If we already connected to a device before, then we know it's name and address
    enum MiaoMiaoDeviceAddressAndName {
        /// we already connected to the device so we should know the address and name as used by the device
        case alreadyConnectedBefore (address:String, name:String)
        /// * We never connected to the device, no need to send an expected device name
        case notYetConnected
    }
}

fileprivate enum MiaoMiaoResponseState: UInt8 {
    case dataPacketReceived = 0x28
    case newSensor = 0x32
    case noSensor = 0x34
    case frequencyChangedResponse = 0xD1
}

extension MiaoMiaoResponseState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacketReceived:
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

