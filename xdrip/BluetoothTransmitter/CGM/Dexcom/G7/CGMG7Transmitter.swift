import Foundation
import CoreBluetooth
import os

class CGMG7Transmitter: BluetoothTransmitter, CGMTransmitter {

    /// is the transmitter oop web enabled or not. For G7/ONE+/Stelo this must be set to true to use only the transmitter algorithm
    private var webOOPEnabled: Bool

    /// stored when receiving single reading, needed when receiving backfill data
    private var sensorAge: TimeInterval?
    
    /// used when receiving backfill data from G7 sensor
    private var backfill = [GlucoseData]()
    
    /// if timeStampLastReading > 5 min + 30 seconds, then, when receiving a new reading, it means there's a gap, and most likely the official Dexcom app will request for backfill data. So in that case we'll not immediately send the reading to the  delegate, but wait for the backfill to arrive
    private var timeStampLastReading: Date?

    // MARK: UUID's
    
    /// advertisement
    let CBUUID_Advertisement_G7 = "FEBC"
    
    /// service
    let CBUUID_Service_G7 = "F8083532-849E-531C-C594-30F1F86A4EA5"
    
    /// characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    private enum CBUUID_Characteristic_UUID:String, CustomStringConvertible  {
        
        /// Read/Notify characteristic
        case CBUUID_Communication = "F8083533-849E-531C-C594-30F1F86A4EA5"
        
        /// Write/Indicate - write characteristic
        case CBUUID_Write_Control = "F8083534-849E-531C-C594-30F1F86A4EA5"
        
        /// Read/Write/Indicate - Read Characteristic
        case CBUUID_Receive_Authentication = "F8083535-849E-531C-C594-30F1F86A4EA5"
        
        /// Read/Write/Notify
        case CBUUID_Backfill = "F8083536-849E-531C-C594-30F1F86A4EA5"

        //// for logging, returns a readable name for the characteristic
        var description: String {
            switch self {
                
            case .CBUUID_Communication:
                return "Communication"
                
            case .CBUUID_Write_Control:
                return "Write_Control"
                
            case .CBUUID_Receive_Authentication:
                return "Receive_Authentication"
                
            case .CBUUID_Backfill:
                return "Backfill"
                
            }
        }
    }
    
    // MARK: - public properties

    /// CGMG7TransmitterDelegate
    public weak var cGMG7TransmitterDelegate: CGMG7TransmitterDelegate?

    // MARK: - private properties
    
    /// the write and control Characteristic
    private var writeControlCharacteristic:CBCharacteristic?
    
    /// the receive and authentication Characteristic
    private var receiveAuthenticationCharacteristic:CBCharacteristic?
    
    /// the communication Characteristic (not used)
    private var communicationCharacteristic:CBCharacteristic?
    
    /// the backfill Characteristic
    private var backfillCharacteristic:CBCharacteristic?

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG7)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []
    
    /// if the user starts the sensor via xDrip4iOS, then only after having receivec a confirmation from the transmitter, then sensorStartDate will be assigned to the actual sensor start date
    /// - if set then call cGMG5TransmitterDelegate.received(sensorStartDate
    private var sensorStartDate: Date? {
        
        didSet {
            
            //cGMG7TransmitterDelegate?.received(sensorStartDate: sensorStartDate, cGMG7Transmitter: self)
            
        }
    }

    /// after subscribing to receiveAuthenticationCharacteristic (which is also used for authentication), and if not receiving a successful authentication within 2 seconds, then this is not the correct device
    private var authenticationTimeOutTimer: Timer?

    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMG7TransmitterDelegate : a CGMG7TransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMG7TransmitterDelegate: CGMG7TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        // For G7/ONE+/Stelo we don't listen for a specific device name. Dexcom uses an advertising id, which already filters out all other devices (like tv's etc. We will verify in another way that we have the current active G7/ONE+/Stelo, and not an old one, which is still near
        var newAddressAndName: BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "DX")
        
        if let name = name {
            UserDefaults.standard.activeSensorTransmitterId = name
        }
        
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // set this to true to make sure that only the raw G7 data is *always* used, even if upgrading from a previous version with a sensor already calibrated in xDrip algorithm
        self.webOOPEnabled = true
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G7, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G7)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)

        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMG5TransmitterDelegate
        self.cGMG7TransmitterDelegate = cGMG7TransmitterDelegate
        
    }
    
    // MARK: - BluetoothTransmitter overriden functions

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)

        // backfill should not contain at leats the latest reading, and possibly also real backfill data
        // this is the right moment to send it to the delegate
        
        // sort backfill, first element should be youngest
        backfill = backfill.sorted(by: { $0.timeStamp > $1.timeStamp })
        
        // send glucoseData to cgmTransmitterDelegate
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &backfill, transmitterBatteryInfo: nil, sensorAge: sensorAge)

        // set timeStampLastReading to timestamp of the most recent reading, which is the first
        if let firstReading = backfill.first {
            timeStampLastReading = firstReading.timeStamp
        }
        
        // reset backfill
        backfill = [GlucoseData]()
        
        // setting characteristics to nil, they will be reinitialized at next connect
        writeControlCharacteristic = nil
        receiveAuthenticationCharacteristic = nil
        communicationCharacteristic = nil
        backfillCharacteristic = nil
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let characteristic_UUID = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) else {
            trace("in peripheralDidUpdateValueFor, unknown characteristic received with uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, characteristic.uuid.uuidString)
            return
        }
        
        guard let value = characteristic.value else {
            trace("in peripheralDidUpdateValueFor, characteristic.value is nil", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
            return
        }
        
        if let error = error {
            trace("error: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error , error.localizedDescription)
        }
        
        switch characteristic_UUID {

        case .CBUUID_Write_Control:
            
            guard let firstByte = value.first else {
                trace("    value has no contents", log: log, category: ConstantsLog.categoryCGMG7, type: .error )
                return
            }
            
            guard let opCode = DexcomTransmitterOpCode(rawValue: firstByte) else {
                trace("    unknown opCode", log: log, category: ConstantsLog.categoryCGMG7, type: .error )
                return
            }
            
            switch opCode {
                
            case .glucoseG6Tx:
                
                guard let g7GlucoseMessage = G7GlucoseMessage(data: value) else {
                    trace("    failed to create G7GlucoseMessage", log: log, category: ConstantsLog.categoryCGMG7, type: .error )
                    return
                }
                
                trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, characteristic_UUID.description)
                
                trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, value.hexEncodedString())
                
                let sensorAgeInDays = Double(round((g7GlucoseMessage.sensorAge / 3600 / 24) * 10) / 10)
                
                var maxSensorAgeInDays: Double = 0.0
                
                // check if we already have the transmitterId (or device name). If so, set the maxSensorAge and then perform a quick check to see if the sensor hasn't expired.
                if let transmitterIdString = UserDefaults.standard.activeSensorTransmitterId {
                    if transmitterIdString.startsWith("DX01") {
                        maxSensorAgeInDays = ConstantsDexcomG7.maxSensorAgeInDaysStelo
                    } else {
                        maxSensorAgeInDays = ConstantsDexcomG7.maxSensorAgeInDays
                    }
                                        
                    // G7/ONE+/Stelo has the peculiarity that it will keep sending/repeating the same BG value (without ever changing) via BLE even after the session officially ends.
                    // to avoid this, let's check if the sensor is still within maxSensorAge before we continue
                    if sensorAgeInDays > maxSensorAgeInDays {
                        trace("    %{public}@ is expired so will not process reading. sensorAge: %{public}@ / maxSensorAgeInDays: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, UserDefaults.standard.activeSensorTransmitterId ?? "sensor", sensorAgeInDays.description, maxSensorAgeInDays.description)
                        return
                    }
                }
                
                trace("    received g7GlucoseMessage mesage, calculatedValue = %{public}@, timeStamp = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, g7GlucoseMessage.calculatedValue.description, g7GlucoseMessage.timeStamp.description(with: .current))
                
                trace("    received g7GlucoseMessage mesage, sensorAge = %{public}@ / %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, sensorAgeInDays.description, maxSensorAgeInDays > 0 ? maxSensorAgeInDays.description : "waiting...")
                
                sensorAge = g7GlucoseMessage.sensorAge
                
                // check if more than 5 equal values are received, if so ignore, might be faulty sensor
                addGlucoseValueToUserDefaults(Int(g7GlucoseMessage.calculatedValue))
                if (hasSixIdenticalValues()) {
                    trace("    received 6 equal values, ignoring, value = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, g7GlucoseMessage.calculatedValue.description)
                    return
                }
                
                
                let newGlucoseData = GlucoseData(timeStamp: g7GlucoseMessage.timeStamp, glucoseLevelRaw: g7GlucoseMessage.calculatedValue)
                
                // add glucoseData to backfill
                // possibly we will send it still later, if we receive also backfill data.
                backfill.append(newGlucoseData)
                
                // if it's been more than 5 min + 30 seconds since previous reading, then it means there's a gap, and most likely the official Dexcom app will request for backfill data. So in that case we'll not immediately send the reading to the  delegate, but wait for the backfill to arrive
                if let timeStampLastReading = timeStampLastReading {
                    if abs(timeStampLastReading.timeIntervalSinceNow) < 330.0 {
                        var newGlucoseDataArray = [newGlucoseData]
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &newGlucoseDataArray, transmitterBatteryInfo: nil, sensorAge: sensorAge)
                    }
                }
                
                // send algorithm status of the transmitter to cGMG7TransmitterDelegate
                cGMG7TransmitterDelegate?.received(sensorStatus: g7GlucoseMessage.algorithmStatus.description, cGMG7Transmitter: self)
                
                // send sensorStartDate to cGMG7TransmitterDelegate
                cGMG7TransmitterDelegate?.received(sensorStartDate: Date(timeIntervalSinceNow: -g7GlucoseMessage.sensorAge), cGMG7Transmitter: self)
                        
            case .backfillFinished:
                
                // we don't use this, backfill data will be sent to the delegate at disconnect (because I didn't receive the backfillFinished opcode during tests)
                break
                
            default:
                break
                
            }

            break
            
        case .CBUUID_Backfill:
            guard value.count == 9 else { return }
            
            trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, characteristic_UUID.description)
            
            trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, value.hexEncodedString())

            if let sensorAge = sensorAge, sensorAge < (ConstantsDexcomG7.maxSensorAgeInDays * 24 * 3600), let dexcomG7BackfillMessage = DexcomG7BackfillMessage(data: value, sensorAge: sensorAge) {
                trace("    received backfill mesage, calculatedValue = %{public}@, timeStamp = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, dexcomG7BackfillMessage.calculatedValue.description, dexcomG7BackfillMessage.timeStamp.description(with: .current))
                
                backfill.append(GlucoseData(timeStamp: dexcomG7BackfillMessage.timeStamp, glucoseLevelRaw: dexcomG7BackfillMessage.calculatedValue))
            }
            
        case .CBUUID_Receive_Authentication:
            
            trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, characteristic_UUID.description)
            
            trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, value.hexEncodedString())
            
            if let authChallengeRxMessage = AuthChallengeRxMessage(data: value) {

                if authChallengeRxMessage.paired, authChallengeRxMessage.authenticated {
                    
                    trace("Connected to Dexcom G7 that is paired and authenticated by other app. Will stay connected to this one.", log: log, category: ConstantsLog.categoryCGMG7, type: .info )
                    
                    bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)
                    
                    cancelAuthenticationTimer()
                    
                } else {
                    
                    trace("Connected to Dexcom G7 that is not paired and/or authenticated by other app. Will disconnect and scan for another Dexcom G7/ONE+/Stelo", log: log, category: ConstantsLog.categoryCGMG7, type: .info )
                    
                    disconnectAndForget()
                    
                    _ = startScanning()
                    
                }

            }
            
            break
            
        default:
            
            break
            
        }
        
    }
    
    // override here didConnect, because we don't want to call bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self) which would be done if we don't override
    // bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self) will be called later when we're sure we're connected to the Dexcom that is currently used by the other app
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        cancelConnectionTimer()
        
        trace("connected to peripheral with name %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, deviceName ?? "'unknown'")
        
        peripheral.discoverServices([CBUUID(string: CBUUID_Service_G7)])
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, deviceName ?? "'unknown'", String(describing:service.uuid))
        
        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("    characteristic: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, String(describing: characteristic.uuid))
                
                    peripheral.setNotifyValue(true, for: characteristic)
                
                    if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue) {
                    
                        // this is the authentication characteristic, if the authentication is not successful within 2 seconds, then this is not the device that is currently being used by the official dexcom app, so let's forget it
                        authenticationTimeOutTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(authenticationFailed), userInfo: nil, repeats: false)
                    
                    }

            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
        }

    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error, error.localizedDescription.contains(find: "Encryption is insufficient") {
            trace("didUpdateNotificationStateFor for peripheral with name %{public}@, characteristic %{public}@, error contains Encryption is insufficient. This is not the device we're looking for.", log: log, category: ConstantsLog.categoryCGMG7, type: .info, (deviceName != nil ? deviceName! : "unknown"), String(describing: characteristic.uuid))
            
            // it's not the device we're interested in, disconnect, forget this device, and restart scanning for a new, other device
            
            cancelAuthenticationTimer()
            
            disconnectAndForget()
            
            _ = startScanning()
            
        }
        
    }
    
    // MARK: - CGMTransmitter protocol functions
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .dexcomG7
    }
    
    
    func maxSensorAgeInDays() -> Double? {
        if let transmitterIdString = UserDefaults.standard.activeSensorTransmitterId {
            if transmitterIdString.startsWith("DX01") {
                return ConstantsDexcomG7.maxSensorAgeInDaysStelo
            } else {
                return ConstantsDexcomG7.maxSensorAgeInDays
            }
        } else {
            // if we haven't yet established the activeSensorTransmitterId (or device name) then return 0 - RVC will use this to know that we're still waiting
            return 0
        }
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_Service_G7
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue
    }
    
    func isWebOOPEnabled() -> Bool {
        
        return webOOPEnabled
        
    }
    
    // MARK: - private functions
    @objc private func authenticationFailed() {
        
        trace("Connected to Dexcom G7 but authentication not received. Will disconnect and scan for another Dexcom G7/ONE+/Stelo", log: log, category: ConstantsLog.categoryCGMG7, type: .info )
        
        disconnectAndForget()
        
        _ = startScanning()
        
    }
    
    private func cancelAuthenticationTimer() {
        if let authenticationTimeOutTimer = authenticationTimeOutTimer {
            if authenticationTimeOutTimer.isValid {
                authenticationTimeOutTimer.invalidate()
                self.authenticationTimeOutTimer = nil
            }
        }
    }
    
    private func addGlucoseValueToUserDefaults(_ newValue: Int) {
        // Als de array nil is, initialiseer ze
        if UserDefaults.standard.previousRawGlucoseValues == nil {
            UserDefaults.standard.previousRawGlucoseValues = []
        }

        // Voeg de nieuwe waarde toe aan het begin van de array
        UserDefaults.standard.previousRawGlucoseValues!.insert(newValue, at: 0)

        // Als er meer dan 6 waarden zijn, verwijder de laatste
        if UserDefaults.standard.previousRawGlucoseValues!.count > 6 {
            UserDefaults.standard.previousRawGlucoseValues!.removeLast()
        }
    }

    func hasSixIdenticalValues() -> Bool {
        guard let values = UserDefaults.standard.previousRawGlucoseValues, values.count == 6 else {
            return false
        }
        
        // Controleer of alle waarden gelijk zijn aan de eerste
        return values.allSatisfy { $0 == values[0] }
    }
    
}
