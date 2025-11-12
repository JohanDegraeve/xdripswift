import Foundation
import CoreBluetooth
import os

@objcMembers
class CGMG7Transmitter: BluetoothTransmitter, CGMTransmitter {

    /// is the transmitter oop web enabled or not. For G7/ONE+/Stelo this must be set to true to use only the transmitter algorithm
    private var webOOPEnabled: Bool

    /// stored when receiving single reading, needed when receiving backfill data
    private var sensorAge: TimeInterval?
    
    /// used when receiving backfill data from G7 sensor
    private var backfill = [GlucoseData]()
    
    /// if timeStampLastReading > 5 min + 30 seconds, then, when receiving a new reading, it means there's a gap, and most likely the official Dexcom app will request for backfill data. So in that case we'll not immediately send the reading to the  delegate, but wait for the backfill to arrive
    private var timeStampLastReading: Date?

    /// buffer for raw backfill frames that may arrive before sensorAge is known or parsable
    private var pendingBackfillRawFrames: [Data] = []


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
    
    /// Rolling connection id for log correlation (increments on each didConnect)
    private var cycleId: Int = 0

    /// Tracks the name of the authenticated transmitter while a valid coexistence session is active
    private var currentlyAuthenticatedDeviceName: String?
    
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


    // MARK: - public functions

    // Helper to check whether we are discovering a brand-new device
    // (set when initializer used .notYetConnected(expectedName: ...))
    var isNewDeviceDiscovery: Bool {
        return deviceName == nil
    }
    
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
    
    override func prepareForRelease() {
        // First let the base class clear CoreBluetooth delegates synchronously on main
        super.prepareForRelease()

        let tearDown = {
            // Clear characteristic strong refs so no accidental retains persist
            self.writeControlCharacteristic = nil
            self.receiveAuthenticationCharacteristic = nil
            self.communicationCharacteristic = nil
            self.backfillCharacteristic = nil
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }
    
    deinit {
        // Delegate cleanup is handled by the base class in prepareForRelease()/deinit.
    }

    // MARK: - BluetoothTransmitter overriden functions

    // Intercept BluetoothTransmitter's discovery logic to avoid auto-connecting the previous transmitter in new-device discovery mode.
    override func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        trace("Did discover peripheral with name: %{public}@", log: self.log, category: ConstantsLog.categoryCGMG7, type: .info, peripheral.name ?? "nil")
        // New-device flow: never connect to the *previously active* transmitter.
        // This prevents immediately latching onto DXCMx5 and allows the scan to find the *new* DXCMxx.
        if self.isNewDeviceDiscovery, let activeId = UserDefaults.standard.activeSensorTransmitterId, let discoveredName = peripheral.name, discoveredName == activeId {
            trace("    skipping previous active transmitter (%{public}@) during new device discovery, keep scanning for the new sensor.", log: self.log, category: ConstantsLog.categoryCGMG7, type: .info, activeId)
            return
        }
        // Call super to retain normal discovery/connect behavior for all other cases
        super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)

        // Clear authenticated session tracking on disconnect
        self.currentlyAuthenticatedDeviceName = nil

        // Ensure any queued raw backfill frames are parsed before flushing
        processPendingBackfillFramesIfPossible()

        // backfill should not contain at leats the latest reading, and possibly also real backfill data
        // this is the right moment to send it to the delegate
        
        // if nothing to deliver, skip
        if backfill.isEmpty == false {
            // sort backfill, first element should be youngest
            backfill = backfill.sorted(by: { $0.timeStamp > $1.timeStamp })
            
            // send glucoseData to cgmTransmitterDelegate on main (UI/Core Data safety), use a local copy for inout
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var copy = self.backfill
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
            }
            
            // set timeStampLastReading to timestamp of the most recent reading, which is the first
            if let firstReading = backfill.first {
                timeStampLastReading = firstReading.timeStamp
            }
            
            // reset backfill
            backfill = [GlucoseData]()
        }

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
                
                // set sensorAge as early as possible to avoid race with Backfill frames
                sensorAge = g7GlucoseMessage.sensorAge
                
                // if any Backfill frames arrived just before this, parse them now
                processPendingBackfillFramesIfPossible()

                trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, characteristic_UUID.description)

                trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())

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

                trace("    received g7GlucoseMessage mesage, calculatedValue = %{public}@, timeStamp = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, g7GlucoseMessage.calculatedValue.description, g7GlucoseMessage.timeStamp.description(with: .current))

                trace("    received g7GlucoseMessage mesage, sensorAge = %{public}@ / %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, sensorAgeInDays.description, maxSensorAgeInDays > 0 ? maxSensorAgeInDays.description : "waiting...")

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
                        let newGlucoseDataArray = [newGlucoseData]
                        
                        // Per-cycle summary log before delegate dispatch
                        let glucoseLevelRawString = String(format: "%.1f", newGlucoseData.glucoseLevelRaw)
                        let timeStampString = DateFormatter.localizedString(from: newGlucoseData.timeStamp, dateStyle: .none, timeStyle: .medium)
                        let writeControlCharacteristicIsNotifying = self.writeControlCharacteristic?.isNotifying ?? false
                        let backfillCharacteristicIsNotifying = self.backfillCharacteristic?.isNotifying ?? false
                        
                        trace("    G7 connection cycle summary: value = %{public}@ mg/dL at %{public}@ (cid=%{public}d, extra flow: wc_notify_on = %{public}@, bf_notify_on = %{public}@)", log: log, category: ConstantsLog.categoryCGMG7, type: .info, glucoseLevelRawString, timeStampString, self.cycleId, String(writeControlCharacteristicIsNotifying), String(backfillCharacteristicIsNotifying))
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            var copy = newGlucoseDataArray
                            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
                        }
                        // stability: keep gap logic accurate by advancing last delivered timestamp on immediate delivery
                        self.timeStampLastReading = g7GlucoseMessage.timeStamp
                    } else {
                        // stability: we expect backfill soon, debounce a short flush so UI doesn't look stuck if Dexcom keeps link open
                    }
                } else {
                    // no previous reading, deliver immediately and advance last timestamp
                    let newGlucoseDataArray = [newGlucoseData]
                    
                    // Per-cycle summary log before delegate dispatch
                    let glucoseLevelRawString = String(format: "%.1f", newGlucoseData.glucoseLevelRaw)
                    let timeStampString = DateFormatter.localizedString(from: newGlucoseData.timeStamp, dateStyle: .none, timeStyle: .medium)
                    let writeControlCharacteristicIsNotifying = self.writeControlCharacteristic?.isNotifying ?? false
                    let backfillCharacteristicIsNotifying = self.backfillCharacteristic?.isNotifying ?? false
                    
                    trace("    G7 connection cycle summary: value = %{public}@ mg/dL at %{public}@ (cid=%{public}d, extra flow: wc_notify_on = %{public}@, bf_notify_on = %{public}@)", log: log, category: ConstantsLog.categoryCGMG7, type: .info, glucoseLevelRawString, timeStampString, self.cycleId, String(writeControlCharacteristicIsNotifying), String(backfillCharacteristicIsNotifying))
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        var copy = newGlucoseDataArray
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
                    }
                    self.timeStampLastReading = g7GlucoseMessage.timeStamp // stability
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.cGMG7TransmitterDelegate?.received(sensorStatus: g7GlucoseMessage.algorithmStatus.description, cGMG7Transmitter: self)

                    // send sensorStartDate to cGMG7TransmitterDelegate
                    self.cGMG7TransmitterDelegate?.received(sensorStartDate: Date(timeIntervalSinceNow: -g7GlucoseMessage.sensorAge), cGMG7Transmitter: self)
                }

            case .backfillFinished:

                // parse any queued backfill frames before final flush
                processPendingBackfillFramesIfPossible()
                // stability: flush any accumulated backfill immediately when Dexcom signals completion
                flushBackfillDeliveringToDelegate()

            default:
                break

            }

            break

        case .CBUUID_Backfill:
            guard value.count == 9 else { return }

            trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, characteristic_UUID.description)

            trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())

            if let sensorAge = sensorAge, sensorAge < (ConstantsDexcomG7.maxSensorAgeInDays * 24 * 3600) {
                if let dexcomG7BackfillMessage = DexcomG7BackfillMessage(data: value, sensorAge: sensorAge) {
                    trace("    received backfill mesage, calculatedValue = %{public}@, timeStamp = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, dexcomG7BackfillMessage.calculatedValue.description, dexcomG7BackfillMessage.timeStamp.description(with: .current))

                    let newBackfillGlucoseData = GlucoseData(timeStamp: dexcomG7BackfillMessage.timeStamp, glucoseLevelRaw: dexcomG7BackfillMessage.calculatedValue)

                    backfill.append(newBackfillGlucoseData)

                    // Immediately deliver this backfill item so it is not lost if no "current" value arrives in the same cycle.
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        var copy = [newBackfillGlucoseData]
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
                    }

                    if timeStampLastReading == nil || dexcomG7BackfillMessage.timeStamp > timeStampLastReading! {
                        timeStampLastReading = dexcomG7BackfillMessage.timeStamp
                    }
                } else {
                    // We have sensorAge but parsing failed right now—queue for a guaranteed second attempt.
                    pendingBackfillRawFrames.append(value)
                    trace("    queued backfill frame for deferred parse (parse failed now). raw = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())
                    processPendingBackfillFramesIfPossible()
                }
            } else {
                // Sensor age not yet known, queue raw frame until it becomes available.
                pendingBackfillRawFrames.append(value)
                trace("    queued backfill frame pending sensorAge. raw = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())
                processPendingBackfillFramesIfPossible()
            }

        case .CBUUID_Receive_Authentication:

            trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, characteristic_UUID.description)

            trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())

            if let authChallengeRxMessage = AuthChallengeRxMessage(data: value) {

                if authChallengeRxMessage.paired, authChallengeRxMessage.authenticated {

                    trace("    connected to Dexcom G7/ONE+ that is paired and authenticated by other app. Will stay connected to this one.", log: log, category: ConstantsLog.categoryCGMG7, type: .info )
                    self.currentlyAuthenticatedDeviceName = self.deviceName
                    
                    // when paired && authenticated:
                    if let authenticatedDeviceName = self.deviceName, authenticatedDeviceName.hasPrefix("DX"), UserDefaults.standard.activeSensorTransmitterId != authenticatedDeviceName {
                        UserDefaults.standard.activeSensorTransmitterId = authenticatedDeviceName
                        trace("    active transmitter id set after authentication: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, authenticatedDeviceName)
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }

                        self.bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)
                    }
                } else {

                    trace("    connected to Dexcom G7/ONE+ that is not paired and/or authenticated by other app. Waiting briefly for data (coexistence)", log: log, category: ConstantsLog.categoryCGMG7, type: .info )
                    // Do nothing here, the generic data-timeout will disconnect if no data arrives.

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
        
        cycleId += 1

        trace("connected to peripheral with name %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, deviceName ?? "'unknown'")


        // Use descriptive name for deviceName
        if let detectedDeviceName = deviceName, detectedDeviceName.hasPrefix("DX02") {
            trace("DX02 detected (ONE+). Proceeding with coexistence notify subscription.", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        }

        peripheral.discoverServices([CBUUID(string: CBUUID_Service_G7)])
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, deviceName ?? "'unknown'", String(describing:service.uuid))

        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("    characteristic: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, String(describing: characteristic.uuid))
                
                // Store references to discovered characteristics
                if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue) {
                    receiveAuthenticationCharacteristic = characteristic
                } else if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue) {
                    writeControlCharacteristic = characteristic
                } else if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Backfill.rawValue) {
                    backfillCharacteristic = characteristic
                } else if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Communication.rawValue) {
                    communicationCharacteristic = characteristic
                }
                
                // DEBUG
                let have = [receiveAuthenticationCharacteristic != nil, writeControlCharacteristic != nil, backfillCharacteristic != nil, communicationCharacteristic != nil]
                trace("G7 notify: discovered refs - auth: %{public}@ write: %{public}@ backfill: %{public}@ comm: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, String(have[0]), String(have[1]), String(have[2]), String(have[3]))
                
                // Subscribe to all relevant characteristics immediately (coexistence: read-only notifies)
                if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue) {
                    traceNotifyState(characteristic, label: "notify requested (we issued setNotifyValue)")
                    if !characteristic.isNotifying { setNotifyValue(true, for: characteristic) }
                } else if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue) {
                    traceNotifyState(characteristic, label: "notify requested (we issued setNotifyValue)")
                    if !characteristic.isNotifying { setNotifyValue(true, for: characteristic) }
                } else if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Backfill.rawValue) {
                    traceNotifyState(characteristic, label: "notify requested (we issued setNotifyValue)")
                    if !characteristic.isNotifying { setNotifyValue(true, for: characteristic) }
                }
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        // DEBUG
        if error == nil {
            // move Write_Control confirmation to .info. Others remain .debug
            if characteristic.uuid == CBUUID(string: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue) {
                let name = "Write_Control"
                trace("G7 notify: %{public}@ - %{public}@ isNotifying = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, "notify state updated (CoreBluetooth confirmed)", name, String(characteristic.isNotifying))
            } else {
                traceNotifyState(characteristic, label: "notify state updated (CoreBluetooth confirmed)")
            }
        }
        
        if let error = error, error.localizedDescription.contains(find: "Encryption is insufficient") {
            trace("didUpdateNotificationStateFor: transient auth state (Encryption is insufficient) for %{public}@, characteristic %{public}@. Coexistence: disconnect only, no forget.",
                  log: log, category: ConstantsLog.categoryCGMG7, type: .info,
                  (deviceName != nil ? deviceName! : "unknown"), String(describing: characteristic.uuid))

            // Deliver any pending readings/backfill before disconnecting
            flushBackfillDeliveringToDelegate()

            // Schedule a one-shot temporary rejection for this device name to prevent immediate reconnect loop
            if let dxName = deviceName {
                scheduleTemporaryRejectionOnNextDisconnect(forDeviceName: dxName)
            }
            
            // Coexistence: do NOT forget. Allow quick retry without blacklisting the peripheral
            disconnect()
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
    /// Forget peripherals only during new-device discovery, once an active transmitter id is known, avoid blacklisting in coexistence
    private func shouldForgetCurrentPeripheral() -> Bool {
        // In coexistence (G7/ONE+/Stelo) never blacklist/forget on transient authentication states.
        // Returning false prevents forget+rescan loops on brand-new sensors during first contact and avoids pinning to the wrong nearby transmitter.
        return false
    }

    /// Returns true only if we are currently authenticated with the active transmitter id kept in UserDefaults
    private func isCurrentlyConnectedToActiveTransmitter() -> Bool {
        guard let activeId = UserDefaults.standard.activeSensorTransmitterId,
              let current = currentlyAuthenticatedDeviceName else { return false }
        return current == activeId
    }
    
    // DEBUG
    private func traceNotifyState(_ characteristic: CBCharacteristic, label: String) {
        let name: String
        switch CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) {
        case .CBUUID_Receive_Authentication?:
            name = "Receive_Authentication"
        case .CBUUID_Write_Control?:
            name = "Write_Control"
        case .CBUUID_Backfill?:
            name = "Backfill"
        case .CBUUID_Communication?:
            name = "Communication"
        default:
            name = characteristic.uuid.uuidString
        }
        trace("G7 notify: %{public}@ - %{public}@ isNotifying = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, label, name, String(characteristic.isNotifying))
    }

    /// Attempt to parse and deliver any queued raw backfill frames now that sensorAge is available
    private func processPendingBackfillFramesIfPossible() {
        guard let sensorAge = sensorAge, sensorAge < (ConstantsDexcomG7.maxSensorAgeInDays * 24 * 3600) else { return }
        guard pendingBackfillRawFrames.isEmpty == false else { return }

        var delivered: [GlucoseData] = []

        for raw in pendingBackfillRawFrames {
            if let message = DexcomG7BackfillMessage(data: raw, sensorAge: sensorAge) {
                let glucoseDataItem = GlucoseData(timeStamp: message.timeStamp, glucoseLevelRaw: message.calculatedValue)
                backfill.append(glucoseDataItem)
                delivered.append(glucoseDataItem)
                trace("    received backfill mesage (deferred parse), calculatedValue = %{public}@, timeStamp = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, message.calculatedValue.description, message.timeStamp.description(with: .current))
            } else {
                trace("    backfill parse failed (deferred). raw = %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, raw.hexEncodedString())
            }
        }

        if delivered.isEmpty == false {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var copy = delivered
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
            }

            if let newest = delivered.max(by: { $0.timeStamp < $1.timeStamp }) {
                if self.timeStampLastReading == nil || newest.timeStamp > self.timeStampLastReading! {
                    self.timeStampLastReading = newest.timeStamp
                }
            }
        }

        pendingBackfillRawFrames.removeAll(keepingCapacity: true)
    }
    
    private func flushBackfillDeliveringToDelegate() {
        guard backfill.isEmpty == false else { return }
        // sort backfill, first element should be youngest
        backfill = backfill.sorted(by: { $0.timeStamp > $1.timeStamp })

        // send glucoseData to cgmTransmitterDelegate on main (UI/Core Data safety), use a local copy for inout
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var copy = self.backfill
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: self.sensorAge)
            if let latest = copy.first {
                let v = String(format: "%.1f", latest.glucoseLevelRaw)
                let t = DateFormatter.localizedString(from: latest.timeStamp, dateStyle: .none, timeStyle: .medium)
                trace("G7 backfill summary: count=%{public}d, latest=%{public}@ mg/dL @ %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, copy.count, v, t)
            }
        }

        // set timeStampLastReading to timestamp of the most recent reading, which is the first
        if let firstReading = backfill.first {
            timeStampLastReading = firstReading.timeStamp
        }

        // reset backfill
        backfill = [GlucoseData]()
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
