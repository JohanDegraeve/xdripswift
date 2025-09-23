import Foundation
import CoreBluetooth
import os

class CGMG5Transmitter:BluetoothTransmitter, CGMTransmitter {

    // MARK: - public properties
    
    /// G5 or G6 transmitter firmware version - only used internally, if nil then it was  never received
    ///
    /// created public because inheriting classes need it
    var firmware:String?
    
    /// G5 or G6 age - only used internally, if nil then it was  never received
    ///
    /// created public because inheriting classes need it
    var transmitterStartDate: Date?
    
    /// - if true then xDrip4iOS will not send anything to the transmitter, it will only listen
    /// - sending should be done by other app (eg official Dexcom app)
    /// - exception could be sending calibration request or start sensor request, because if user is calibrating or starting the sensor via xDrip4iOS then it would need to be send to the transmitter by xDrip4iOS
    public var useOtherApp = false
    
    /// is the G6 transmitter Anubis-modified?
    /// use this flag (once set by the TransmitterVersionRxMessage) to enable extra features as needed
    public var isAnubis = false
    
    /// CGMG5TransmitterDelegate
    public weak var cGMG5TransmitterDelegate: CGMG5TransmitterDelegate?

    // MARK: UUID's
    
    /// advertisement
    let CBUUID_Advertisement_G5 = "0000FEBC-0000-1000-8000-00805F9B34FB"
    
    /// service
    let CBUUID_Service_G5 = "F8083532-849E-531C-C594-30F1F86A4EA5"
    
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
    
    // MARK: - private properties
    
    /// the write and control Characteristic
    private var writeControlCharacteristic:CBCharacteristic?
    
    /// the receive and authentication Characteristic
    private var receiveAuthenticationCharacteristic:CBCharacteristic?
    
    /// the communication Characteristic (not used)
    private var communicationCharacteristic:CBCharacteristic?
    
    /// the backfill Characteristic
    private var backfillCharacteristic:CBCharacteristic?

    /// - timestamp of last reading received during previous session
    private var timeStampOfLastG5Reading = Date(timeIntervalSince1970: 0)
    
    /// last GlucoseData read in sensorDataRx message
    private var lastGlucoseInSensorDataRxReading: GlucoseData?
    
    /// transmitterId
    private let transmitterId:String

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG5)
    
    /// is G5 reset necessary or not
    private var G5ResetRequested = false
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    /// for creating testreadings
    private var testAmount:Double = 150000.0
    
    //// true if pairing request was done, and waiting to see if pairing was done
    private var waitingPairingConfirmation = false
    
    /// to swap between request firmware or battery
    private var requestFirmware = true
    
    /// - backFillStream, used while receiving backfill data from transmitter
    /// - will be processed when transmitter disconnects
    private var backFillStream = DexcomBackfillStream()
    
    /// when was sensor start time read the last time. Initialize to 0, means at app start it will be read
    private var timeStampLastSensorStartTimeRead = Date(timeIntervalSince1970: 0)
    
    /// to be used in firefly flow - glucoseTx must be sent before glucoseBackfillTx
    private var glucoseTxSent = false
    
    /// to be used in firefly flow - backfillTxSent should be sent only once per connection setting
    private var backfillTxSent = false
    
    /// - used to send calibration done by user via xDrip4iOS to Dexcom transmitter. For example, user may have given a calibration in the app, but it's not yet send to the transmitter.
    /// - calibrationToSendToTransmitter.sentToTransmitter says if it's been sent to transmitter or not
    private var calibrationToSendToTransmitter: Calibration?
    
    /// if the user starts the sensor via xDrip4iOS, then only after having receivec a confirmation from the transmitter, then sensorStartDate will be assigned to the actual sensor start date
    /// - if set then call cGMG5TransmitterDelegate.received(sensorStartDate
    private var sensorStartDate: Date? {
        
        didSet {
            
            // delegate may touch UI / Core Data → ensure main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMG5TransmitterDelegate?.received(sensorStartDate: self.sensorStartDate, cGMG5Transmitter: self)
            }
            
            timeStampLastSensorStartTimeRead = Date(timeIntervalSince1970: 0)
            
        }
    }
    
    /// to temporary store the received SensorStartDate. Will be compared to sensorStartDate only after having received a glucoseRx message with a valid algorithm status
    private var receivedSensorStartDate: Date?
    
    /// - used to send sensor start done by user via xDrip4iOS to Dexcom transmitter. For example, user may have started a sensor in the app, but it's not yet send to the transmitter.
    /// - tuple consisitng of startDate and dexcomCalibrationParameters. If startDate is nil, then there's no start sensor waiting to be sent to the transmitter.
    private var sensorStartToSendToTransmitter: (startDate: Date, dexcomCalibrationParameters: DexcomCalibrationParameters)?
    
    /// used to send stop session to transmitter
    private var dexcomSessionStopTxMessageToSendToTransmitter: DexcomSessionStopTxMessage?
    
    private var timeStampLastConnection = Date(timeIntervalSince1970: 0)
    
    /// to use in firefly flow, if true, then sensor status is ok, backfill request can be sent
    private var okToRequestBackfill = false
    
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    // Primary-mode guards (reset each connection)
    private var writeControlNotifyConfigured = false
    private var backfillNotifyConfigured = false
    private var authChallengeTxSent = false

    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    ///     - bluetoothTransmitterDelegate : a NluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMG5TransmitterDelegate : a CGMG5TransmitterDelegate
    ///     - transmitterStartDate : transmitter start date, optional - actual transmitterStartDate is received from transmitter itself, and stored in coredata. The stored value iss given here as parameter in the initializer. Means  at app start up, it's read from core data and added here as parameter
    ///     - sensorStartDate : should be sensorStartDate of active sensor. If a different sensor start date is received from the transmitter, then we know a new senosr was started
    ///     - calibrationToSendToTransmitter : used to send calibration done by user via xDrip4iOS to Dexcom transmitter. For example, user may have give a calibration in the app, but it's not yet send to the transmitter. This needs to be verified in CGMG5Transmitter, which is why it's given here as parameter - when initializing, assign last known calibration for the active sensor, even if it's already sent.
    ///     - webOOPEnabled : enabled or not, if nil then default false
    ///     - userOtherApp
    ///     - isAnubis: true or false. If true then we can take advantage of extra features
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMG5TransmitterDelegate: CGMG5TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, transmitterStartDate: Date?, sensorStartDate: Date?, calibrationToSendToTransmitter: Calibration?, firmware: String?, webOOPEnabled: Bool?, useOtherApp: Bool, isAnubis: Bool) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "DEXCOM" + transmitterID[transmitterID.index(transmitterID.startIndex, offsetBy: 4)..<transmitterID.endIndex])
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign useOtherApp
        self.useOtherApp = useOtherApp
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false

        //assign transmitterId
        self.transmitterId = transmitterID
        
        // whilst we're at it, let's assign to userdefaults for the UI to use
        UserDefaults.standard.activeSensorTransmitterId = transmitterID
        
        // initalize transmitterStartDate
        self.transmitterStartDate = transmitterStartDate
        
        // initialize firmware
        self.firmware = firmware
        
        // initialize isAnubis
        self.isAnubis = isAnubis
        
        // assign calibrationToSendToTransmitter
        self.calibrationToSendToTransmitter = calibrationToSendToTransmitter
        
        // assign sensorStartDate
        self.sensorStartDate = sensorStartDate
        
        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will probably not be used in the superclass
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G5, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G5)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)

        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMG5TransmitterDelegate
        self.cGMG5TransmitterDelegate = cGMG5TransmitterDelegate
        
    }
    
    #if DEBUG
    /// for testing , make the function public and call it after having activate a sensor in rootviewcontroller
    ///
    /// amount is rawvalue for testreading, should be number like 150000
    private func temptesting(amount:Double) {
        testAmount = amount
        // schedule test timer on main thread to guarantee a run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Timer.scheduledTimer(timeInterval: 60 * 5, target: self, selector: #selector(self.createTestReading), userInfo: nil, repeats: true)
        }
    }
    
    /// for testing, used by temptesting
    @objc private func createTestReading() {
        let testData = GlucoseData(timeStamp: Date(), glucoseLevelRaw: testAmount)
        debuglogging("timestamp testdata = " + testData.timeStamp.description + ", with amount = " + testAmount.description)
        let testDataAsArray = [testData]
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var copy = testDataAsArray
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: nil)
        }
        testAmount = testAmount + 1
    }
#endif // DEBUG – test helpers only  DEBUG
    
    /// scale the rawValue, dependent on transmitter version G5 , G6 --
    /// for G6, there's two possible scaling factors, depending on the firmware version. For G5 there's only one, firmware version independent
    /// - parameters:
    ///     - firmwareVersion : for G6, the scaling factor is firmware dependent. Parameter created optional although it is known at the moment the function is used
    ///     - the value to be scaled
    /// this function can be override in CGMG6Transmitter, which can then return the scalingFactor , firmware dependent
    func scaleRawValue(firmwareVersion: String?, rawValue: Double) -> Double {
        
        // for G5, the scaling is independent of the firmwareVersion
        // and there's no scaling to do
        if transmitterId.startsWith("4") {

            return rawValue

        }
        
        // so it's G6 (non firefly)
        guard let firmwareVersion = firmwareVersion else { return rawValue }
        
        if firmwareVersion.starts(with: "1.") {
            
            return rawValue * 34.0
            
        } else if firmwareVersion.starts(with: "2.") {
            
            return (rawValue - 1151500000.0) / 110.0
            
        }
        
        return rawValue
        
    }
    
    /// to ask transmitter reset
    func reset(requested:Bool) {
        G5ResetRequested = requested
    }
    
    // MARK: - Resource teardown for ARC safety

    override func prepareForRelease() {
        // First clear CoreBluetooth delegates synchronously on main via base class
        super.prepareForRelease()
        // Then synchronously clear characteristic references on main to avoid races
        let tearDown = {
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
        // if deinit is called, it means user deletes the transmitter or clicks 'stop scanning' or 'disconnect'.
        UserDefaults.standard.timeStampOfLastBatteryReading = nil
        // Delegate cleanup is performed in prepareForRelease() on the main queue
    }

    // MARK: - BluetoothTransmitter overriden functions

    override func initiatePairing() {
        // assuming that the transmitter is effectively awaiting the pairing, otherwise this obviously won't work
        sendPairingRequest()
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        // Coexistence: tiny debounce; Primary: forward immediately.
        if useOtherApp {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.delayedSuperDidDisconnect(central: central, peripheral: peripheral, error: error)
            }
        } else {
            super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        }
        
        if waitingPairingConfirmation {
            // device has requested a pairing request and is now in a status of verifying if pairing was successfull or not, this by doing setNotify to writeCharacteristic. If a disconnect occurs now, it means pairing has failed (probably because user didn't approve it
            waitingPairingConfirmation = false
            
            // inform delegate
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.pairingFailed()
            }
            
        }

        // disconnect seems best moment to send stored glucose data (backfill dand and received last glucose value) to delegate
        sendGlucoseDataToDelegate()

        // setting characteristics to nil, they will be reinitialized at next connect
        writeControlCharacteristic = nil
        receiveAuthenticationCharacteristic = nil
        communicationCharacteristic = nil
        backfillCharacteristic = nil
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        // get characteristic description and trace
        var characteristicDescription = characteristic.uuid.uuidString
        if let characteristic = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) { characteristicDescription = characteristic.description}
        trace("in peripheralDidUpdateNotificationStateFor. characteristic = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, characteristicDescription)
        
        if let error = error {
            trace("    error: %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .error , error.localizedDescription)
        }
        
        if let characteristicValue = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) {
            
            trace("    characteristic : %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, characteristicValue.description)
            
            switch characteristicValue {
                
            case .CBUUID_Receive_Authentication:

                sendAuthRequestTxMessage()
                
                break
                
            case .CBUUID_Backfill:
                // ensure we stay subscribed to Backfill. Retry once if needed
                if !characteristic.isNotifying { setNotifyValue(true, for: characteristic) } // keep notify on
                break

            case .CBUUID_Write_Control:
                // ensure we stay subscribed to Write_Control. Retry once if needed
                if !characteristic.isNotifying { setNotifyValue(true, for: characteristic) } // keep notify on
                
                if (G5ResetRequested) {
                    // send ResetTxMessage
                    sendG5Reset()
                    
                    //reset G5ResetRequested to false
                    G5ResetRequested = false
                    
                } else {

                    // is webOOPEnabled ?
                    // if no treat it as a G5, with own calibration
                    if !useFireFlyFlow() {
                        
                        // send SensorTxMessage to transmitter
                        getSensorData()
                        
                        return
                        
                    }
                    
                    // webOOPEnabled, continue with the firefly message flow
                    fireflyMessageFlow()
                    
                }
                
                break
                
            case .CBUUID_Communication:
                
                break
                
            }
        } else {
            trace("    characteristicValue is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        guard let characteristic_UUID = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) else {
            trace("in peripheralDidUpdateValueFor, unknown characteristic received with uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .error, characteristic.uuid.uuidString)
            return
        }
        
        trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, characteristic_UUID.description)
        
        if let error = error {
            trace("error: %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .error , error.localizedDescription)
        }
        
        switch characteristic_UUID {

        case .CBUUID_Backfill:
            
            trace("    storing received value on backFillStream", log: log, category: ConstantsLog.categoryCGMG5, type: .info, characteristic_UUID.description)
            
            // unwrap characteristic value
            guard let value = characteristic.value else {return}
            
            // push value to backFillStream
            backFillStream.push(value)

            
        default:
            
            if let value = characteristic.value {
                
                //check type of message and process according to type
                if let firstByte = value.first {
                    
                    if let opCode = DexcomTransmitterOpCode(rawValue: firstByte) {
                        
                        trace("    opcode = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, opCode.description)
                        
                        switch opCode {
                        case .authChallengeRx:
                            
                            if let authChallengeRxMessage = AuthChallengeRxMessage(data: value) {
                                // if not paired, then send message to delegate
                                if !authChallengeRxMessage.paired {
                                    trace("    transmitter needs pairing, calling sendKeepAliveMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                                    // will send keep alive message
                                    sendKeepAliveMessage()
                                    // delegate needs to be informed that pairing is needed
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self = self else { return }
                                        self.bluetoothTransmitterDelegate?.transmitterNeedsPairing(bluetoothTransmitter: self)
                                    }
                                } else {
                                    // Configure required notifies once per connection (no abbreviations)
                                    if let writeControlCharacteristic = writeControlCharacteristic, !writeControlNotifyConfigured {
                                        trace("    will set notifyValue for writeControlCharacteristic to true", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                        setNotifyValue(true, for: writeControlCharacteristic)
                                        writeControlNotifyConfigured = true
                                    } else if writeControlCharacteristic == nil {
                                        trace("    writeControlCharacteristic is nil, can not set notifyValue", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                    }

                                    if useFireFlyFlow() {
                                        if let backfillCharacteristic = backfillCharacteristic, !backfillNotifyConfigured {
                                            trace("    will set notifyValue for backfillCharacteristic to true", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                            setNotifyValue(true, for: backfillCharacteristic)
                                            backfillNotifyConfigured = true
                                        } else if backfillCharacteristic == nil {
                                            // expected in non-Firefly or when discovery has not yet delivered it
                                            trace("    backfillCharacteristic is nil, can not set notifyValue", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                        }
                                    }
                                }
                            } else {
                                trace("    failed to create authChallengeRxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                            }
                            
                        case .authRequestRx:
                            // In coexistence, do not participate in the authentication handshake; remain passive so the transmitter drops us quickly.
                            if useOtherApp {
                                trace("authRequestRx: coexistence mode, remaining passive (no AuthChallengeTx).", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                return
                            }
                            if authChallengeTxSent {
                                trace("authRequestRx (primary): authChallengeTx already sent, ignoring duplicate", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                                return
                            }
                            if let authRequestRxMessage = AuthRequestRxMessage(data: value), let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {
                                
                                guard let challengeHash = CGMG5Transmitter.computeHash(transmitterId, of: authRequestRxMessage.challenge) else {
                                    trace("    failed to calculate challengeHash, no further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                                    return
                                }
                                
                                let authChallengeTxMessage = AuthChallengeTxMessage(challengeHash: challengeHash)
                                
                                trace("sending authChallengeTxMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, authChallengeTxMessage.data.hexEncodedString())
                                
                                _ = writeDataToPeripheral(data: authChallengeTxMessage.data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)
                                
                                // Mark that the AuthChallengeTx was sent to avoid duplicate sends within the same connection session.
                                authChallengeTxSent = true
                                
                            } else {
                                trace("    writeControlCharacteristic is nil or authRequestRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                            }
                        case .sensorDataRx:
                            
                            // if this is the first sensorDataRx after a successful pairing, then inform delegate that pairing is finished
                            if waitingPairingConfirmation {
                                waitingPairingConfirmation = false
                                DispatchQueue.main.async { [weak self] in
                                    self?.bluetoothTransmitterDelegate?.successfullyPaired()
                                }
                            }
                            
                            if let sensorDataRxMessage = SensorDataRxMessage(data: value) {
                                
                                // should we request firmware or battery level
                                if !requestFirmware {
                                    
                                    // request battery level now, next time request firmware
                                    requestFirmware = true
                                    
                                    // transmitterversion was already received, let's see if we need to get the batterystatus
                                    // and if not, then disconnect
                                    if !batteryStatusRequested() {
                                        
                                        disconnect()
                                        
                                    }
                                    
                                } else {
                                    
                                    // request firmware now, next time request battery level
                                    requestFirmware = false
                                    
                                    if firmware == nil {
                                        
                                        sendTransmitterVersionTxMessage()
                                        
                                    }
                                }
                                
                                if Date() < Date(timeInterval: ConstantsDexcomG5.minimumTimeBetweenTwoReadings, since: timeStampOfLastG5Reading) {
                                    
                                    // should probably never come here because this check is already done at connection time
                                    trace("    last reading was less than %{public}@ minutes ago, ignoring", log: log, category: ConstantsLog.categoryCGMG5, type: .info, ConstantsDexcomG5.minimumTimeBetweenTwoReadings.minutes.description)
                                    
                                } else {
                                    
                                    // check if rawValue equals 2096896, this indicates low battery, error message needs to be shown in that case
                                    if sensorDataRxMessage.unfiltered == 2096896.0 {
                                        
                                        trace("    received unfiltered value 2096896.0, which is caused by low battery. Creating error message", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                                        
                                        DispatchQueue.main.async { [weak self] in
                                            self?.cgmTransmitterDelegate?.errorOccurred(xDripError: DexcomError.receivedEnfilteredValue2096896)
                                        }
                                        
                                    } else {
                                        
                                        timeStampOfLastG5Reading = Date()
                                        
                                        let glucoseData = GlucoseData(timeStamp: sensorDataRxMessage.timestamp, glucoseLevelRaw: scaleRawValue(firmwareVersion: firmware, rawValue: sensorDataRxMessage.unfiltered))
                                        
                                        let glucoseDataArray = [glucoseData]
                                        
                                        DispatchQueue.main.async { [weak self] in
                                            guard let self = self else { return }
                                            var copy = glucoseDataArray
                                            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: nil)
                                        }
                                        
                                    }
                                    
                                    
                                }

                            } else {
                                trace("    sensorDataRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                            }
                            
                        case .resetRx:
                            
                            processResetRxMessage(value: value)
                            
                        case .batteryStatusRx:
                            
                            processBatteryStatusRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        case .transmitterVersionRx:
                            
                            processTransmitterVersionRxMessage(value: value)

                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }

                        case .keepAliveRx:
                            
                            // seems no processing is necessary, now the user should get a pairing requeset
                            break
                            
                        case .pairRequestRx:
                            
                            // don't know if the user accepted the pairing request or not, we can only know by trying to subscribe to writeControlCharacteristic - if the device is paired, we'll receive a sensorDataRx message, if not paired, then a disconnect will happen
                            
                            // set status to waitingForPairingConfirmation
                            waitingPairingConfirmation = true
                            
                            // setNotifyValue
                            if let writeControlCharacteristic = writeControlCharacteristic {
                                setNotifyValue(true, for: writeControlCharacteristic)
                            } else {
                                trace("    writeControlCharacteristic is nil, can not set notifyValue", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                            }
                            
                        case .transmitterTimeRx:
                            
                            processTransmitterTimeRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        case .glucoseBackfillRx:
                            
                            processGlucoseBackfillRxMessage(value: value)

                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }

                        case .glucoseRx:
                            
                            processGlucoseDataRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        case .glucoseG6Rx:
                            // received when relying on official Dexcom app, ie in mode useOtherApp = true
                            
                            processGlucoseG6DataRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        case .calibrateGlucoseRx:
                            
                            processCalibrateGlucoseRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        case .sessionStopRx:
                            
                            processSessionStopRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }

                        case .sessionStartRx:

                            processSessionStartRxMessage(value: value)
                            
                            // if firefly continue with the firefly message flow
                            if useFireFlyFlow() { fireflyMessageFlow() }
                            
                        default:
                            trace("    unknown opcode received ", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                            break
                        }
                    } else {
                        trace("    value doesn't start with a known opcode = %{public}d", log: log, category: ConstantsLog.categoryCGMG5, type: .error, Int(firstByte))
                    }
                } else {
                    trace("    value is empty (no first byte)", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                }
            }
            
            break
            
        }
        
    }
    
    override func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if useOtherApp {
            trace("didDiscover, useOtherApp = true, no further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            return
        }

        if Date() < Date(timeInterval: ConstantsDexcomG5.minimumTimeBetweenTwoReadings, since: timeStampOfLastG5Reading) {
            // will probably never come here because reconnect doesn't happen with scanning, hence diddiscover will never be called except the very first time that an app tries to connect to a G5
            trace("diddiscover peripheral, but last reading was less than %{public}@ minutes ago, will ignore", log: log, category: ConstantsLog.categoryCGMG5, type: .info, ConstantsDexcomG5.minimumTimeBetweenTwoReadings.minutes.description)
        } else {
            super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
        
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        // calling super.didConnect here to keep base setup (service discovery, timers, etc.)
        
        // No predictive/quiet-window gating — keep it simple and reliable.
        super.centralManager(central, didConnect: peripheral)
        
        timeStampLastConnection = Date()

        // to be sure waitingPairingConfirmation is reset to false
        waitingPairingConfirmation = false
        
        // reset per-connection guards
        writeControlNotifyConfigured = false
        backfillNotifyConfigured = false
        authChallengeTxSent = false
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        // not using super.didDiscoverCharacteristicsFor here
        
        trace("didDiscoverCharacteristicsFor", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
        
        // log error if any
        if let error = error {
            trace("    error: %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            
            for characteristic in characteristics {
                
                if let characteristicValue = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) {

                    trace("    characteristic : %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, characteristicValue.description)
                    
                    switch characteristicValue {
                    case .CBUUID_Backfill:
                        backfillCharacteristic = characteristic
                        
                    case .CBUUID_Write_Control:
                        writeControlCharacteristic = characteristic
                        
                    case .CBUUID_Communication:
                        communicationCharacteristic = characteristic
                        
                    case .CBUUID_Receive_Authentication:
                        
                        receiveAuthenticationCharacteristic = characteristic
                        
                        trace("    calling setNotifyValue true for characteristic %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.description)
                        
                        setNotifyValue(true, for: characteristic)
                        
                    }
                } else {
                    trace("    characteristic UUID unknown : %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, characteristic.uuid.uuidString)
                }
            }
        } else {
            trace("characteristics is nil. There must be some error.", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // if our Dexcom service was invalidated, clear cached characteristics and rediscover
        let serviceUUID = CBUUID(string: CBUUID_Service_G5)
        if invalidatedServices.contains(where: { $0.uuid == serviceUUID }) {
            trace("didModifyServices: Dexcom service invalidated, clearing characteristic handles and rediscovering", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            writeControlCharacteristic = nil
            receiveAuthenticationCharacteristic = nil
            communicationCharacteristic = nil
            backfillCharacteristic = nil
            peripheral.discoverServices([serviceUUID]) // re-discover our service
        }
    }
    
    /// overrides writeDataToPeripheral and checks if useOtherApp is true and if so, data is not written to characteristic
    override func writeDataToPeripheral(data: Data, characteristicToWriteTo: CBCharacteristic, type: CBCharacteristicWriteType) -> Bool {
        
        if !useOtherApp {
            
            return super.writeDataToPeripheral(data: data, characteristicToWriteTo: characteristicToWriteTo, type: type)
            
        } else {
            
            trace("in writeDataToPeripheral, useOtherApp - data not written to characteristic", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            
            return true
            
        }
        
    }
    

    // MARK: - CGMTransmitter protocol functions
    
    func setWebOOPEnabled(enabled: Bool) {
        
        if webOOPEnabled != enabled {
            
            webOOPEnabled = enabled
            
            trace("in setWebOOPEnabled, new value for webOOPEnabled = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, webOOPEnabled.description)
            
            // reset sensor start date, because changing webOOPEnabled value stops the sensor
            sensorStartDate = nil
            
            // as sensor is stopped, also set sensorStatus to nil
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMG5TransmitterDelegate?.received(sensorStatus: nil, cGMG5Transmitter: self)
            }
            
        }
        
    }
    
    func isWebOOPEnabled() -> Bool {
        
        return webOOPEnabled
        
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .dexcom
    }
    
    // if using an Anubis transmitter and the user has chosen to override the max days, we can return this value
    // if not, return the standard maxSensorAgeInDays
    func maxSensorAgeInDays() -> Double? {
        if isAnubis, let activeSensorMaxSensorAgeInDaysOverridenAnubis = UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis, activeSensorMaxSensorAgeInDaysOverridenAnubis > 0 {
            return activeSensorMaxSensorAgeInDaysOverridenAnubis
        } else {
            return ConstantsDexcomG5.maxSensorAgeInDays
        }
    }
    
    func overruleIsWebOOPEnabled() -> Bool {
        
        // dexcom transmitters can be calibrated, even if dexcom algorithm is used
        // that only applies if webOOPEnabled
        // if not webOOPEnabled, then this transmitter is working in raw mode, no overrule required
        if webOOPEnabled {

            return true

        } else {
            
            return false
            
        }
        
    }
    
    func nonWebOOPAllowed() -> Bool {
        
        return !transmitterId.isFireFly()
        
    }
    
    func startSensor(sensorCode: String?, startDate: Date) {
        
        // assign sensorStartToSendToTransmitter to nil, because a new sensor start command must be sent
        sensorStartToSendToTransmitter = nil
        
        guard startDate != sensorStartDate else {
            
            trace("in startSensor, but startDate is equal to already known sensorStartDate, so it looks as if a startSensor is done for a sensor that is already started. No further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            
            return
            
        }
        
        guard let dexcomCalibrationParameters = DexcomCalibrationParameters(sensorCode: sensorCode) else {
            
            trace("in startSensor, failed to create dexcomCalibrationParameters for sensorcode %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, (sensorCode == nil ? "nil" : sensorCode!))
            
            return
            
        }
        
        trace("in startSensor, storing sensor start  info, will be sent to transmitter at next connect", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        
        // assign sensorStartToSendToTransmitter
        sensorStartToSendToTransmitter = (startDate, dexcomCalibrationParameters)
        
    }

    func stopSensor(stopDate: Date) {
        
        // if there's no sensorStartDate known, then don't send any stopSensor command to the transmitter
        if sensorStartDate == nil {
            
            trace("in stopSensor, sensorStartDate is nil, no further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            
            return
            
        }
        
        guard let transmitterStartDate = transmitterStartDate else {
            
            trace("in stopsensor, but transmitterStartDate is  nil, no further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            
            return
            
        }

        trace("in stopsensor, storing sensor stop  info, will be sent to transmitter at next connect", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        
        dexcomSessionStopTxMessageToSendToTransmitter = DexcomSessionStopTxMessage(stopDate: stopDate, transmitterStartDate: transmitterStartDate)
        
        // set it to nil
        calibrationToSendToTransmitter = nil
            
        trace("in stopsensor, setting calibrationToSendToTransmitter to nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        
    }

    func calibrate(calibration: Calibration) {
        
        // - if calibration is valid, then it assigns calibrationToSendToTransmitter to calibration, will be picked up when transmitter connects , and if it's within an hour
        // - the function does not immediately send the calibration to the transmitter, this will happen only if connected, after successful authentication
        
        // set calibrationToSendToTransmitter to nil, because a new calibration needs to be sent
        calibrationToSendToTransmitter = nil
        
        if calibrationIsValid(calibration: calibration) {
            
            calibrationToSendToTransmitter = calibration
            
            trace("in calibrate. New calibration stored. value = %{public}@, timestamp = %{public}@ ", log: log, category: ConstantsLog.categoryCGMG5, type: .info, calibration.bg.description, calibration.timeStamp.toString(timeStyle: .long, dateStyle: .none))
            
        }
        
    }
    
    func needsSensorStartCode() -> Bool {
        return transmitterId.isFireFly()
    }
    
    func needsSensorStartTime() -> Bool {
        return !transmitterId.isFireFly()
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_Service_G5
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue
    }
    
    func isAnubisG6() -> Bool {
        return isAnubis
    }
    
    // MARK: - private helper functions
    
    /// sends SensorTxMessage to transmitter
    private func getSensorData() {
        
        trace("trying to send SensorDataTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            _ = super.writeDataToPeripheral(data: SensorDataTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("    writeControlCharacteristic is nil, not sending SensorDataTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
    }
    
    
    /// sends G5 reset to transmitter
    private func sendG5Reset() {
        
        let resetTxMessage = ResetTxMessage()
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending resetTxMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, resetTxMessage.data.hexEncodedString())

            _ = writeDataToPeripheral(data: resetTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
            G5ResetRequested = false
            
        } else {
            
            trace("    writeControlCharacteristic is nil, not sending G5 reset", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
    }
    
    /// sends transmitterTimeTxMessage to transmitter (also used to request sensor start time, because the response includes both transmitter and sensor start date)
    private func sendTransmitterTimeTxMessage() {
        
        let transmitterTimeTxMessage = DexcomTransmitterTimeTxMessage()
        
        if let writeControlCharacteristic = writeControlCharacteristic {
    
            trace("sending transmitterTimeTxMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, transmitterTimeTxMessage.data.hexEncodedString())

            _ = writeDataToPeripheral(data: transmitterTimeTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }

    /// sends glucoseTxMessage to transmitter
    private func sendGlucoseTxMessage() {
        
        let glucoseDataTxMessage = DexcomGlucoseDataTxMessage()
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending glucoseDataTxMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, glucoseDataTxMessage.data.hexEncodedString())
            
            _ = writeDataToPeripheral(data: glucoseDataTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// sends calibrationTxMessage. Will use super.writeDataToPeripheral, meaning, even if useOtherApp = true, then still it will send the data to the transmitter
    private func sendCalibrationTxMessage(calibration: Calibration, transmitterStartDate: Date) {
        
        let calibrationTxMessage = DexcomCalibrationTxMessage(glucose: Int(calibration.bg), timeStamp: calibration.timeStamp, transmitterStartDate: transmitterStartDate)
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending calibrationTxMessage with timestamp %{public}@, value %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, calibration.timeStamp.toString(timeStyle: .long, dateStyle: .long), calibration.bg.description)
            
            _ = super.writeDataToPeripheral(data: calibrationTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
            // set sentToTransmitter to true
            calibration.sentToTransmitter = true
            
        } else {
            
            trace("in sendCalibrationTxMessage, writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }

    }
    
    private func sendSessionStopTxMessage(dexcomSessionStopTxMessage: DexcomSessionStopTxMessage) {
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending sendSessionStopTxMessage with stopDate %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, dexcomSessionStopTxMessage.stopDate.toString(timeStyle: .long, dateStyle: .long))
            
            _ = super.writeDataToPeripheral(data: dexcomSessionStopTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("in sendSessionStopTxMessage, writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// sends startDate and dexcomCalibrationParameters to transmitter. Will use super.writeDataToPeripheral, meaning, even if useOtherApp = true, then still it will send the data to the transmitter
    private func sendSessionStartTxMessage(sensorStartToSendToTransmitter: (startDate: Date, dexcomCalibrationParameters: DexcomCalibrationParameters), transmitterStartDate: Date) {
        
        let sessionStartTxMessage = DexcomSessionStartTxMessage(startDate: sensorStartToSendToTransmitter.startDate, transmitterStartDate: transmitterStartDate, dexcomCalibrationParameters: sensorStartToSendToTransmitter.dexcomCalibrationParameters)
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending sessionStartTxMessage with startDate %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, sensorStartToSendToTransmitter.startDate.toString(timeStyle: .long, dateStyle: .long))
            
            _ = super.writeDataToPeripheral(data: sessionStartTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("in sendSessionStartTxMessage, writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// sends backfillTxMessage to transmitter
    private func sendBackfillTxMessage(startTime: Date, endTime: Date, transmitterStartDate: Date) {
        
        if useOtherApp {
            trace("use other app/coexistence: suppress backfillTx", log:log, category:ConstantsLog.categoryCGMG5, type:.debug)
            return
        }
        
        let backfillTxMessage = DexcomBackfillTxMessage(startTime: startTime, endTime: endTime, transmitterStartDate: transmitterStartDate)
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending backfillTxMessage with startTime %{public}@, endTime %{public}@, data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, startTime.toString(timeStyle: .long, dateStyle: .none), endTime.toString(timeStyle: .long, dateStyle: .none), backfillTxMessage.data.hexEncodedString())
            
            _ = super.writeDataToPeripheral(data: backfillTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("writeControlCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// sends AuthRequestTxMessage to transmitter
    private func sendAuthRequestTxMessage() {
        if useOtherApp {
            trace("use other app/coexistence: suppress authRequestTx", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
            return
        }
        
        let authMessage = AuthRequestTxMessage()
        
        if let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {

            trace("sending authMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, authMessage.data.hexEncodedString())

            _ = writeDataToPeripheral(data: authMessage.data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)
            
        } else {
            
            trace("receiveAuthenticationCharacteristic is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
    }
    
    private func sendTransmitterVersionTxMessage() {
        
        let transmitterVersionTxMessage = TransmitterVersionTxMessage()
        
        if let writeControlCharacteristic = writeControlCharacteristic {
            
            trace("sending transmitterVersionTxMessage with data %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, transmitterVersionTxMessage.data.hexEncodedString())

            _ = writeDataToPeripheral(data: transmitterVersionTxMessage.data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)
            
        } else {
            
            trace("    writeControlCharacteristic is nil, can not send TransmitterVersionTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }

    }
    
    /// Helper to allow calling super.didDisconnectPeripheral from a delayed closure
    private func delayedSuperDidDisconnect(central: CBCentralManager, peripheral: CBPeripheral, error: Error?) {
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    private func processResetRxMessage(value:Data) {
        
        if let resetRxMessage = ResetRxMessage(data: value) {

            trace("in processResetRxMessage, considering reset successful = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, (resetRxMessage.status == 0).description)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMG5TransmitterDelegate?.reset(for: self, successful: resetRxMessage.status == 0 )
            }
            
        } else {
            
            trace("resetRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// process batteryStatusRxMessage
    private func processBatteryStatusRxMessage(value:Data) {
        
        if let batteryStatusRxMessage = BatteryStatusRxMessage(data: value) {

            trace("in processBatteryStatusRxMessage, voltageA = %{public}@, voltageB = %{public}@, resist = %{public}@, runtime = %{public}@, temperature = %{public}@, status = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, batteryStatusRxMessage.voltageA.description, batteryStatusRxMessage.voltageB.description, batteryStatusRxMessage.resist.description, batteryStatusRxMessage.runtime.description, batteryStatusRxMessage.temperature.description, batteryStatusRxMessage.status.description)

            // possibly other app is running in parallel and also requested battery info, in that case don't store it again
            if Date() > Date(timeInterval: ConstantsDexcomG5.batteryReadPeriod, since: UserDefaults.standard.timeStampOfLastBatteryReading != nil ? UserDefaults.standard.timeStampOfLastBatteryReading! : Date(timeIntervalSince1970: 0)) {

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let batteryInfo = TransmitterBatteryInfo.DexcomG5(voltageA: batteryStatusRxMessage.voltageA, voltageB: batteryStatusRxMessage.voltageB, resist: batteryStatusRxMessage.resist, runtime: batteryStatusRxMessage.runtime, temperature: batteryStatusRxMessage.temperature)
                    self.cGMG5TransmitterDelegate?.received(transmitterBatteryInfo: batteryInfo, cGMG5Transmitter: self)
                    var empty: [GlucoseData] = []
                    self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &empty, transmitterBatteryInfo: batteryInfo, sensorAge: nil)
                }

            }
            
        } else {
            
            trace("batteryStatusRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }

    /// process glucoseBackfillRxMessage
    private func processGlucoseBackfillRxMessage(value:Data) {

        if let transmitterStartDate = transmitterStartDate, let glucoseBackFillRxMessage = GlucoseBackfillRxMessage(data: value, transmitterStartDate: transmitterStartDate) {
            
            trace("in processGlucoseBackfillRxMessage. backFillStartTimeStamp = %{public}@, backFillEndTimeStamp = %{public}@, backFillIdentifier = %{public}@, backFillStatus = %{public}@, transmitterStatus = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, glucoseBackFillRxMessage.backFillStartTimeStamp.toString(timeStyle: .short, dateStyle: .short), glucoseBackFillRxMessage.backFillEndTimeStamp.toString(timeStyle: .short, dateStyle: .short), glucoseBackFillRxMessage.backFillIdentifier.description, glucoseBackFillRxMessage.backFillStatus.description, glucoseBackFillRxMessage.transmitterStatus.description)
                        
        } else {
            
            trace("backFillRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// process sessionStopRxMessage
    private func processSessionStopRxMessage(value: Data) {
        
        if let dexcomSessionStopRxMessage = DexcomSessionStopRxMessage(data: value) {
            
            trace("in processSessionStopRxMessage, received dexcomSessionStopRxMessage, isOkay = %{public}@, sessionStopResponse = %{public}@, sessionStopDate = %{public}@, status = %{public}@, transmitterStartDate = %{public}@,", log: log, category: ConstantsLog.categoryCGMG5, type: .info, dexcomSessionStopRxMessage.isOkay.description, dexcomSessionStopRxMessage.sessionStopResponse.description, dexcomSessionStopRxMessage.sessionStopDate.toString(timeStyle: .long, dateStyle: .long), dexcomSessionStopRxMessage.status.description, dexcomSessionStopRxMessage.transmitterStartDate.toString(timeStyle: .long, dateStyle: .long))
            
        } else {
            
            trace("dexcomSessionStopRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        
        }
        
    }
    
    /// process sessionStartRxMessage
    private func processSessionStartRxMessage(value: Data) {
        
        if let dexcomSessionStartRxMessage = DexcomSessionStartRxMessage(data: value) {
            
            trace("in processSessionStartRxMessage, received dexcomSessionStartRxMessage, sessionStartResponse = %{public}@, requestedStartDate = %{public}@, sessionStartDate = %{public}@, status = %{public}@, transmitterStartDate = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info,
                  dexcomSessionStartRxMessage.sessionStartResponse.description,
                  dexcomSessionStartRxMessage.requestedStartDate.toString(timeStyle: .long, dateStyle: .long),
                  dexcomSessionStartRxMessage.sessionStartDate.toString(timeStyle: .long, dateStyle: .long),
                  dexcomSessionStartRxMessage.status.description,
                  dexcomSessionStartRxMessage.transmitterStartDate.toString(timeStyle: .long, dateStyle: .long))
            
            // send sensor status to delegate
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMG5TransmitterDelegate?.received(sensorStatus: dexcomSessionStartRxMessage.sessionStartResponse.description, cGMG5Transmitter: self)
            }
            
        } else {
            trace("in processSessionStartRxMessage, dexcomSessionStartRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }
        
    }
    
    /// process CalibrateGlucoseRxMessage
    private func processCalibrateGlucoseRxMessage(value: Data) {
        
        if let dexcomCalibrationRxMessage = DexcomCalibrationRxMessage(data: value) {
            
            guard let dexcomCalibrationResponseType = dexcomCalibrationRxMessage.type  else {

                trace("in processCalibrateGlucoseRxMessage, received unknown type", log: log, category: ConstantsLog.categoryCGMG5, type: .info, dexcomCalibrationRxMessage.accepted.description)

                return
                
            }
            
            trace("in processCalibrateGlucoseRxMessage, received dexcomCalibrationRxMessage, accepted = %{public}@, type = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, dexcomCalibrationRxMessage.accepted.description, dexcomCalibrationResponseType.description)
            
            // if calibrationToSendToTransmitter not nil, then set calibrationToSendToTransmitter.acceptedByTransmitter to value received from transmitter
            if let calibrationToSendToTransmitter = calibrationToSendToTransmitter {
                
                // assumption is that the stored calibration is the one for which we receive this dexcomCalibrationRxMessage
                calibrationToSendToTransmitter.acceptedByTransmitter = dexcomCalibrationRxMessage.accepted
                
                // set calibrationToSendToTransmitter to nil so it's not processed next run
                self.calibrationToSendToTransmitter = nil

            }
            
            switch dexcomCalibrationRxMessage.type {
                
            case .secondCalibrationNeeded:
                
                trace("in processCalibrateGlucoseRxMessage, transmitter is asking for second calibration, that still needs to be implemented", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                
            default:
                break
                
            }
            
            
        } else {
            trace("in processCalibrateGlucoseRxMessage, dexcomCalibrationRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }
        
    }

    /// - used by processGlucoseDataRxMessage and processGlucoseG6DataRxMessage
    /// - verifies the algorithmStatus and if ok, creates lastGlucoseInSensorDataRxReading
    /// - parameters;
    ///     - calculatedValue : the value in the reading
    ///     - algorithmStatus : algorithm status
    ///     - timeStamp : timestamp in the reading
    private func processGlucoseG6DataRxMessageOrGlucoseDataRxMessage(calculatedValue: Double, algorithmStatus: DexcomAlgorithmState, timeStamp: Date) {
        
        // send algorithm status to delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cGMG5TransmitterDelegate?.received(sensorStatus: algorithmStatus.description, cGMG5Transmitter: self)
        }

        switch algorithmStatus {
            
        case .okay, .needsCalibration:
            
            // create glucose data and assign to lastGlucoseInSensorDataRxReading
            lastGlucoseInSensorDataRxReading = GlucoseData(timeStamp: timeStamp, glucoseLevelRaw: calculatedValue)
            
            // it's a valid sensor state, so it's ok to send a backfill request after this message is processed
            okToRequestBackfill = true
            
            // setting glucoseTxSent to true, because we received just glucose data
            // possibly a glucoseTx message (was sent by other app on the same device, so it's not necessary to send a new one
            glucoseTxSent = true
            
            var forceNewSensor = false
            
            if let sensorStartDate = self.sensorStartDate, let activeSensorStartDate = UserDefaults.standard.activeSensorStartDate, activeSensorStartDate < sensorStartDate.addingTimeInterval(-15.0) || activeSensorStartDate > sensorStartDate.addingTimeInterval(15.0) {
                forceNewSensor = true
            }

            // this is a valid sensor state, now it's time to process receivedSensorStartDate if it exists
            if let receivedSensorStartDate = receivedSensorStartDate {
                
                // if current sensorStartDate is < receivedSensorStartDate then it seems a new sensor
                // adding an interval of 15 seconds, because sensorStartDate reported by transmitter can vary a second
                if forceNewSensor || sensorStartDate == nil || (sensorStartDate! < receivedSensorStartDate.addingTimeInterval(-15.0)) {
                    
                    if let sensorStartDate = sensorStartDate {
                        trace("    Currently known sensorStartDate = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, sensorStartDate.toString(timeStyle: .long, dateStyle: .long))
                    } else {
                        trace("    current sensorStartDate is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    }
                    trace("    received sensorStartDate minus 15 seconds = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, receivedSensorStartDate.addingTimeInterval(-15.0).toString(timeStyle: .long, dateStyle: .long))
                    
                    trace("    Seems a new sensor is detected.", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    
                    self.receivedSensorStartDate = receivedSensorStartDate
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: receivedSensorStartDate)
                    }
                    
                }
                
                // assign sensorStartDate to receivedSensorStartDate
                sensorStartDate = receivedSensorStartDate
                
                // reset receivedSensorStartDate to nil
                //self.receivedSensorStartDate = nil
                
            }
            
            break
            
        case .SensorWarmup:
            
            var forceNewSensor = false
            
            if let sensorStartDate = self.sensorStartDate, let activeSensorStartDate = UserDefaults.standard.activeSensorStartDate, activeSensorStartDate < sensorStartDate.addingTimeInterval(-15.0) || activeSensorStartDate > sensorStartDate.addingTimeInterval(15.0) {
                forceNewSensor = true
            }
            
            // this is a valid sensor state, now it's time to process receivedSensorStartDate if it exists
            if let receivedSensorStartDate = receivedSensorStartDate {
                
                // if current sensorStartDate is < receivedSensorStartDate then it seems a new sensor
                // adding an interval of 15 seconds, because sensorStartDate reported by transmitter can vary a second
                if forceNewSensor || sensorStartDate == nil || (sensorStartDate! < receivedSensorStartDate.addingTimeInterval(-15.0)) {
                    
                    if let sensorStartDate = sensorStartDate {
                        trace("    Currently known sensorStartDate = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, sensorStartDate.toString(timeStyle: .long, dateStyle: .long))
                    } else {
                        trace("    current sensorStartDate is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    }
                    trace("    received sensorStartDate minus 15 seconds = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, receivedSensorStartDate.addingTimeInterval(-15.0).toString(timeStyle: .long, dateStyle: .long))
                    
                    trace("    Seems a new sensor is detected.", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    
                    self.receivedSensorStartDate = receivedSensorStartDate
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: receivedSensorStartDate)
                    }
                    
                }
                
                // assign sensorStartDate to receivedSensorStartDate
                sensorStartDate = receivedSensorStartDate
            }

            // for safety assign nil to lastGlucoseInSensorDataRxReading
            lastGlucoseInSensorDataRxReading = nil
            
        case .SessionStopped:
            
            // session stopped, means sensor stopped?
            DispatchQueue.main.async { [weak self] in
                self?.cgmTransmitterDelegate?.sensorStopDetected()
            }
            
            sensorStartDate = nil
            
        default:
            
            trace("    algorithm state is %{public}@, not creating last glucoseData", log: log, category: ConstantsLog.categoryCGMG5, type: .info, algorithmStatus.description)
            
            // for safety assign nil to lastGlucoseInSensorDataRxReading
            lastGlucoseInSensorDataRxReading = nil
            
        }
        
        // don't send reading to delegate, will be done when transmitter disconnects, then we're sure we also received al necessary backfill data

    }
    

    /// process glucoseRxMessage
    private func processGlucoseDataRxMessage(value: Data) {

        if let glucoseDataRxMessage = GlucoseDataRxMessage(data: value) {
            
            trace("in processGlucoseDataRxMessage, received glucoseDataRxMessage, value = %{public}@, algorithm status = %{public}@, transmitter status = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, glucoseDataRxMessage.calculatedValue.description, glucoseDataRxMessage.algorithmStatus.description, glucoseDataRxMessage.transmitterStatus.description)
            
            processGlucoseG6DataRxMessageOrGlucoseDataRxMessage(calculatedValue: glucoseDataRxMessage.calculatedValue, algorithmStatus: glucoseDataRxMessage.algorithmStatus, timeStamp: Date())
            
        } else {
            
            trace("in processGlucoseDataRxMessage, glucoseDataRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// process glucoseG6RxMessage
    private func processGlucoseG6DataRxMessage(value: Data) {
        
        if let transmitterStartDate = transmitterStartDate, let glucoseDataRxMessage = DexcomG6GlucoseDataRxMessage(data: value, transmitterStartDate: transmitterStartDate) {
            
            trace("in processGlucoseG6DataRxMessage, received glucoseDataRxMessage, value = %{public}@, timeStamp = %{public}@, algorithmState = %{public}@, transmitterStatus = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, glucoseDataRxMessage.calculatedValue.description, glucoseDataRxMessage.timeStamp.toString(timeStyle: .long, dateStyle: .none), glucoseDataRxMessage.algorithmStatus.description,
                glucoseDataRxMessage.transmitterStatus.description)
            
            processGlucoseG6DataRxMessageOrGlucoseDataRxMessage(calculatedValue: glucoseDataRxMessage.calculatedValue, algorithmStatus: glucoseDataRxMessage.algorithmStatus, timeStamp: glucoseDataRxMessage.timeStamp)
            
        } else {
            
            trace("processGlucoseG6DataRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            
        }
        
    }
    
    /// process transmitterTimeRxMessage
    private func processTransmitterTimeRxMessage(value:Data) {
        
        if let transmitterTimeRxMessage = DexcomTransmitterTimeRxMessage(data: value) {
            
            trace("in processTransmitterTimeRxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)

            if let receivedSensorStartDate = transmitterTimeRxMessage.sensorStartDate {
                
                trace("    receivedSensorStartDate = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, receivedSensorStartDate.toString(timeStyle: .long, dateStyle: .long))
                
                // send to delegate (UI/Core Data) on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cGMG5TransmitterDelegate?.received(sensorStartDate: receivedSensorStartDate, cGMG5Transmitter: self)
                }
                
                // set timeStampLastSensorStartTimeRead
                timeStampLastSensorStartTimeRead = Date()
                
                // if current sensorStartDate is < from receivedSensorStartDate then it seems a new sensor
                if self.receivedSensorStartDate == nil || sensorStartDate == nil || (sensorStartDate! < receivedSensorStartDate.addingTimeInterval(-15.0)) {
                   
                    if let sensorStartDate = sensorStartDate {
                        trace("    Currently known sensorStartDate = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, sensorStartDate.toString(timeStyle: .long, dateStyle: .long))
                    } else {
                        trace("    current sensorStartDate is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    }
                    trace("    received sensorStartDate minus 15 seconds = %{public}@.", log: log, category: ConstantsLog.categoryCGMG5, type: .info, receivedSensorStartDate.addingTimeInterval(-15.0).toString(timeStyle: .long, dateStyle: .long))

                    trace("    Temporary storing the received SensorStartDate till a glucoseRx message is received with valid sensor status", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    
                    self.receivedSensorStartDate = receivedSensorStartDate
                }
                
            } else {
                trace("    sensorStartDate is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            }
            
            // assign transmitterStartDate to local var
            transmitterStartDate = transmitterTimeRxMessage.transmitterStartDate
            
            if let transmitterStartDate = transmitterStartDate {
                
                // send to delegate (UI/Core Data) on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cGMG5TransmitterDelegate?.received(transmitterStartDate: transmitterStartDate, cGMG5Transmitter: self)
                }

                trace("    transmitterStartDate = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, transmitterStartDate.toString(timeStyle: .long, dateStyle: .long))

            } else {
                trace("    transmitterStartDate is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            }
            
        } else {
            trace("in processTransmitterTimeRxMessage, transmitterTimeRxMessage is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        }
        
    }

    private func processTransmitterVersionRxMessage(value:Data) {
        if let transmitterVersionRxMessage = TransmitterVersionRxMessage(data: value) {
            // assign transmitterVersion
            firmware = transmitterVersionRxMessage.firmwareVersionFormatted()
            
            // unwrap it cleanly instead of force-unwrapping it in the call
            if let firmware = firmware {
                // send the firmware string to delegate (UI/Core Data) on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cGMG5TransmitterDelegate?.received(firmware: firmware, cGMG5Transmitter: self)
                }
                trace("in  processTransmitterVersionRxMessage, firmware = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, firmware)
            }
            
            // assign the isAnubis property
            isAnubis = transmitterVersionRxMessage.isAnubis()
            
            // send the isAnubis boolean to delegate (UI/Core Data) on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMG5TransmitterDelegate?.received(isAnubis: self.isAnubis, cGMG5Transmitter: self)
            }
            trace("in  processTransmitterVersionRxMessage, isAnubis = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, isAnubis.description)
        } else {
            trace("transmitterVersionRxMessage is nil or firmware to hex is nil", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
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

    /// sends pairing request to transmitter, this will result in an iOS generated pairing request
    private func sendPairingRequest() {
        
        if let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {
            
            _ = writeDataToPeripheral(data: PairRequestTxMessage().data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)

        } else {
            trace("    in sendBondingRequest, receiveAuthenticationCharacteristic is nil, can not send KeepAliveTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }

    }

    /// sends a keepalive message, this will keep the connection with the transmitter open for 60 seconds
    private func sendKeepAliveMessage() {

        if let receiveAuthenticationCharacteristic = receiveAuthenticationCharacteristic {
            
            // to make sure the Dexcom doesn't disconnect the next 60 seconds, this gives the user sufficient time to accept the pairing request, which will come next
            _ = writeDataToPeripheral(data: KeepAliveTxMessage(time: UInt8(ConstantsDexcomG5.maxTimeToAcceptPairing)).data, characteristicToWriteTo: receiveAuthenticationCharacteristic, type: .withResponse)
            
        } else {
            trace("    in sendKeepAliveMessage, receiveAuthenticationCharacteristic is nil, can not send KeepAliveTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }

    }
    
    /// - checks if battery status needs to be requested to tranmsitter (depends on when it was last updated), and if yes requests it (ie sends message BatteryStatusTxMessage)
    /// - returns:
    ///     - true if batter status requested, otherwise false
    private func batteryStatusRequested() -> Bool {
        
        if Date() > Date(timeInterval: ConstantsDexcomG5.batteryReadPeriod, since: UserDefaults.standard.timeStampOfLastBatteryReading != nil ? UserDefaults.standard.timeStampOfLastBatteryReading! : Date(timeIntervalSince1970: 0)) {
            
            trace("    last battery reading was long time ago, requesting now", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            
            if let writeControlCharacteristic = writeControlCharacteristic {
                
                _ = super.writeDataToPeripheral(data: BatteryStatusTxMessage().data, characteristicToWriteTo: writeControlCharacteristic, type: .withResponse)

                return true
                
            } else {
                
                trace("    writeControlCharacteristic is nil, can not send BatteryStatusTxMessage", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
                
                return false
                
            }
            
        } else {
            
            return false
            
        }
        
    }
    
    /// - if firefly then calls setNotifyValue(true) for both writeControlCharacteristic and backfillCharacteristic
    /// - if not firefly then only calls setNotifyValue(true) for both writeControlCharacteristic
    private func subscribeToWriteControlAndBackFillCharacteristic() {
        
        // subscribe to writeControlCharacteristic once
        if let writeControlCharacteristic = writeControlCharacteristic {
            if !writeControlNotifyConfigured {
                trace("    calling setNotifyValue true for characteristic %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, CBUUID_Characteristic_UUID.CBUUID_Write_Control.description)
                setNotifyValue(true, for: writeControlCharacteristic)
                writeControlNotifyConfigured = true
            }
        } else {
            trace("    writeControlCharacteristic is nil, can not set notifyValue", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
        }
        
        // backfill characteristic only applies to Firefly
        if useFireFlyFlow() {
            if let backfillCharacteristic = backfillCharacteristic {
                if !backfillNotifyConfigured {
                    trace("    calling setNotifyValue true for characteristic %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, CBUUID_Characteristic_UUID.CBUUID_Backfill.description)
                    setNotifyValue(true, for: backfillCharacteristic)
                    backfillNotifyConfigured = true
                }
            } else {
                trace("    backfillCharacteristic is nil, can not set notifyValue", log: log, category: ConstantsLog.categoryCGMG5, type: .error)
            }
        } else {
            // Not Firefly: this is expected. Avoid noisy error logs.
            trace("    backfill subscription not applicable (non-Firefly)", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
        }
        
    }
    
    /// - verifies what is the next message to send to the firefly (is it battery request, firmware request, etc...
    /// - and sends that message
    private func fireflyMessageFlow() {
        if useOtherApp {
            trace("firefly flow suppressed (use other app/coexistence)", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
            return
        }
        
        // first of all check that the transmitter is really a firefly, if not stop processing
        if !useFireFlyFlow() { return }
        
        trace("start of firefly flow", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
        
        // check if firmware is known, if not ask it
        guard firmware != nil else {
            
            sendTransmitterVersionTxMessage()
            
            return
            
        }
        
        // calibrationToSendToTransmitter is not nil but not valid anymore, then set already to nil here
        // to have a correct flow in the next steps
        if let calibrationToSendToTransmitter = calibrationToSendToTransmitter,         !calibrationIsValid(calibration: calibrationToSendToTransmitter) {
            
            self.calibrationToSendToTransmitter =  nil
            
        }
        
        // if there's a sessionStopTxMessage to send, then send it
        if let dexcomSessionStopTxMessage = dexcomSessionStopTxMessageToSendToTransmitter {
            
            sendSessionStopTxMessage(dexcomSessionStopTxMessage: dexcomSessionStopTxMessage)
            
            self.dexcomSessionStopTxMessageToSendToTransmitter = nil
            
            self.sensorStartDate = nil
            
            return
            
        }
        
        // if there's a sensor start command to send, then send it
        if let sensorStartToSendToTransmitter = sensorStartToSendToTransmitter, let transmitterStartDate = transmitterStartDate {
            
            sendSessionStartTxMessage(sensorStartToSendToTransmitter: (startDate: sensorStartToSendToTransmitter.startDate, dexcomCalibrationParameters: sensorStartToSendToTransmitter.dexcomCalibrationParameters), transmitterStartDate: transmitterStartDate)
            
            self.sensorStartToSendToTransmitter = nil
            
            return
            
        }
        
        // check if battery status update needed, if not proceed with flow
        // if yes, request battery status (done in function batteryStatusRequested)
        if !batteryStatusRequested() {
            
            // check if transmitterStartDate is known
            // and if sensorStartTime is known:
            //     - check if we've recently requested the sensorStartTime, less than sensorStartTimeReadPeriod ago
            // and if sensorStartTime is not known:
            //     - check if we've recently requested the sensorStartTime, less than 2.1 minutes ago
            // otherwise get transmitterStartDate and sensorStartTime
            if let transmitterStartDate = transmitterStartDate,
                (
                    (Date() < Date(timeInterval: ConstantsDexcomG5.sensorStartTimeReadPeriod, since: timeStampLastSensorStartTimeRead) && sensorStartDate != nil)
                    ||
                    (Date() < Date(timeInterval: TimeInterval(minutes: 2.1), since: timeStampLastSensorStartTimeRead) && sensorStartDate == nil)
                )  {

                // if there's a valid calibrationToSendToTransmitter (should be valid because it was just checked but let's do the check anyway
                if let calibrationToSendToTransmitter = calibrationToSendToTransmitter, calibrationIsValid(calibration: calibrationToSendToTransmitter) {
                    
                        sendCalibrationTxMessage(calibration: calibrationToSendToTransmitter, transmitterStartDate: transmitterStartDate)

                } else
                
                // if glucoseTx was not yet sent and minimumTimeBetweenTwoReadings larger than now - timeStampOfLastG5Reading (for safety)
                // then send glucoseTx message
                // and sensor must be active
                if !glucoseTxSent && Date() > Date(timeInterval: ConstantsDexcomG5.minimumTimeBetweenTwoReadings, since: timeStampOfLastG5Reading) {

                    // ask latest glucose value
                    sendGlucoseTxMessage()
                    
                    trace("in fireflyMessageFlow, did send glucoseTxMessage, setting glucoseTxSent to true", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
                    
                    // next time don't ask again for glucoseTx, but ask for backfill if needed
                    glucoseTxSent = true
                    
                    
                } else
                
                // check if backfill needed, and request backfill if needed
                // if not needed continue with flow
                // sensor must be active
                if Date().timeIntervalSince(timeStampOfLastG5Reading) > ConstantsDexcomG5.minPeriodOfLatestReadingsToStartBackFill && !backfillTxSent && sensorStartDate != nil && okToRequestBackfill {
                      
                    // send backfillTxMessage
                    // start time = timeStampOfLastG5Reading - maximum maxBackfillPeriod
                    // end time = now
                    sendBackfillTxMessage(startTime: max(timeStampOfLastG5Reading, Date(timeIntervalSinceNow: -ConstantsDexcomG5.maxBackfillPeriod)), endTime: Date(), transmitterStartDate: transmitterStartDate)
                    
                    // set backfillTxSent to true, to avoid that again backfillTx is sent next time we come here
                    backfillTxSent = true
                    
                } else {
                    
                    trace("    end of firefly flow", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
                    
                    if useOtherApp {

                        trace("    useOtherApp = true, will not disconnect", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)

                    } else {

                        trace("    will disconnect", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)

                        // deliver any accumulated readings before disconnecting
                        sendGlucoseDataToDelegate()

                        // disconnect
                        disconnect()
                        
                    }
                }
                
                // reset okToRequestBackfill to false
                okToRequestBackfill = false

            } else {
                
                // request transmitterStartDate
                sendTransmitterTimeTxMessage()
                
            }
            
        }
        
    }
    
    /// - sends contents of backFillStream and lastGlucoseInSensorDataRxReading
    /// - also assigns timeStampOfLastG5Reading to timestamp of lastGlucoseInSensorDataRxReading
    /// - only to be used for firefly
    /// - reset backFillStream, lastGlucoseInSensorDataRxReading, backfillTxSent, glucoseTxSent
    private func sendGlucoseDataToDelegate() {
        
        guard useFireFlyFlow() else {return}
        
        // transmitterDate should be non nil
        guard let transmitterStartDate = transmitterStartDate else {
            trace("in sendGlucoseDataToDelegate but transmitterStartDate is nil, no further processing", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            return
        }
        
        trace("in sendGlucoseDataToDelegate", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
        
        // initialize glucoseDataArray, in this array we will store the glucose values in the backfillStream and also othe lastGlucoseInSensorDataRxReading
        var glucoseDataArray = [GlucoseData]()
        
        // decode backfill stream
        let backFills = backFillStream.decode()
        
        if backFills.count > 0 {

            trace("    start processing backfillstream", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
            
            // iterate through backfill's
            for backFill in backFills {
                
                let backfillDate = transmitterStartDate + Double(backFill.dexTime)
                
                let diff = Date().timeIntervalSince1970 - backfillDate.timeIntervalSince1970
                
                // readings older dan maxBackfillPeriod are ignored
                guard diff > 0, diff < TimeInterval.hours(ConstantsDexcomG5.maxBackfillPeriod) else { continue }
                
                glucoseDataArray.insert(GlucoseData(timeStamp: backfillDate, glucoseLevelRaw: Double(backFill.glucose)), at: 0)
                
                trace("    new backfill, value = %{public}@, date = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .debug, backFill.glucose.description, backfillDate.toString(timeStyle: .long, dateStyle: .long))
                
            }

        }
        
        // - add lastGlucoseInSensorDataRxReading, which should already have been received in GlucoseDataRxMessage or DexcomG6GlucoseDataRxMessage
        if let lastGlucoseInSensorDataRxReading = lastGlucoseInSensorDataRxReading {
            
            trace("    adding glucose data that was received in GlucoseDataRxMessage/DexcomG6GlucoseDataRxMessage, value = %{public}@, date = %{public}@", log: log, category: ConstantsLog.categoryCGMG5, type: .info, lastGlucoseInSensorDataRxReading.glucoseLevelRaw.description, lastGlucoseInSensorDataRxReading.timeStamp.toString(timeStyle: .long, dateStyle: .none))
            
            glucoseDataArray.insert(lastGlucoseInSensorDataRxReading, at: 0)
            
        }
        
        if glucoseDataArray.count > 0 {

            // assign timeStampOfLastG5Reading to the the timestamp of the most recent reading, which should be the first reading
            timeStampOfLastG5Reading = glucoseDataArray.first!.timeStamp
            
            trace("    calling cgmTransmitterInfoReceived with %{public}@ values", log: log, category: ConstantsLog.categoryCGMG5, type: .info, glucoseDataArray.count.description)

            // Emit summary before dispatching to main so logs reflect BLE flow chronology
            if let latest = glucoseDataArray.first {
                let v = String(format: "%.1f", latest.glucoseLevelRaw)
                let t = DateFormatter.localizedString(from: latest.timeStamp, dateStyle: .none, timeStyle: .medium)
                trace("    G5/G6 connection cycle summary: value = %{public}@ mg/dL at %{public}@",
                      log: log, category: ConstantsLog.categoryCGMG5, type: .info,
                      v, t)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                var copy = glucoseDataArray
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: nil)
            }

        } else {
            
            trace("    glucoseDataArray has no values", log: log, category: ConstantsLog.categoryCGMG5, type: .debug)
            
        }
        
        // reset both backFillStream
        backFillStream = DexcomBackfillStream()

        // reset lastGlucoseInSensorDataRxReading
        lastGlucoseInSensorDataRxReading = nil

        // reset backfillTxSent
        backfillTxSent = false
        
        // reset glucoseTxSent to false
        glucoseTxSent = false
        
    }
    
    /// - check if stored calibration is valid or not, valid in the sense of "is it ok to send it to the transmitter"
    ///
    /// - returns: false if calibration.sentToTransmitter is true, false if calibrationToSendToTransmitter has a timestamp in the future, false if calibrationToSendToTransmitter has an invalid value ( < 40 or > 400). true in all other cases
    private func calibrationIsValid(calibration: Calibration) -> Bool {
        
        trace("in calibrationIsValid", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        
        // if already sent to transmitter then invalid
        if calibration.sentToTransmitter {
            trace("    calibration.sentToTransmitter is true, means this calibration is already sent to the transmitter", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            return false
        }
        
        // if calibrationToSendToTransmitter timestamp in future, then invalid
        if Date().timeIntervalSince1970 - calibration.timeStamp.timeIntervalSince1970 < 0 {
            trace("    calibration has timestamp in the future, not valid", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            return false
        }
        
        // if calibrationToSendToTransmitter timestamp older than 5 minutes
        if Date().timeIntervalSince1970 - calibration.timeStamp.timeIntervalSince1970 > ConstantsDexcomG5.maxUnSentCalibrationAge {
            trace("    calibration has timestamp older than %{public}@ minutes, not valid", log: log, category: ConstantsLog.categoryCGMG5, type: .info, ConstantsDexcomG5.maxUnSentCalibrationAge.minutes.description)
            return false
        }
        
        // value out of range
        if calibration.bg < 40 || calibration.bg > 400 {
            trace("    calibration invalid value, lower than 40 or higher than 400", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
            return false
        }
        
        return true
        
    }
    
    /// Possibly webOOPEnabled might be set to false, even though it's a transmitter that can only use with webOOPEnabled true. This can happen if transmitter is known but disconnected, app is launched, user goes to bluetooth settings. At that time, view will show the option to disable weboopenabled, then user disables oopweb, then clicks 'connect'. App will crash, and then user relaunches. At that time, webOOPEnabled will not be shown (transmitter is known, it returns false to nonWebOOPAllowed), but it's actually enabled. To avoid that transmitter starts using raw, this function here i sused
    private func useFireFlyFlow() -> Bool {
        
        if !nonWebOOPAllowed() {return true}
        
        return webOOPEnabled
        
    }
}
