import CoreBluetooth
import Foundation
import os

@objcMembers
class CGMLibre2Transmitter: Libre2BluetoothTransmitter, CGMTransmitter {
    override var isConnectionAllowed: Bool {
        super.isConnectionAllowed && Libre2ConnectionStore.shared.snapshot?.allowsPhone == true
    }

    // MARK: - properties
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMLibre2TransmitterDelegate
    public weak var cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// Phone preferences and native-algorithm configuration.
    private let phoneSensor: Libre2PhoneSensor
    
    /// current sensor serial number, if nil then it's not known yet
    var sensorSerialNumber: String? {
        get { phoneSensor.serialNumber }
        set { phoneSensor.serialNumber = newValue }
    }
    
    /// temp storage of libreSensorSerialNumber, value will be stored after NFC scanning, but possible there's no transmitter created yet (if this is a first scan for a new transmitter), so we can't store the serial number yet in coredata. As soon as transmitter is connected,  and if tempSensorSerialNumber is not nil, it will be sent to the delegate
    var tempSensorSerialNumber: LibreSensorSerialNumber?
    /// Retains the phone's provisioning session; accessed by the NFC extension.
    var libreNFC: LibreNFC?
    
    /// sensor type
    var libreSensorType: LibreSensorType?

    /// Bluetooth name selected from the NFC result. Newer 7F sensors advertise the returned
    /// MAC-derived name instead of the legacy "ABBOTT" + sensor serial number.
    var expectedBluetoothNameFromNFC: String?
    
    // MARK: - Initialization

    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    ///     - cGMLibre2TransmitterDelegate : a CGMLibre2TransmitterDelegate
    ///     - sensorSerialNumber : optional, sensor serial number, should be set if already known from previous session
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - webOOPEnabled : enabled or not, if nil then default false
    init(address: String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate, sensorSerialNumber: String?, cGMTransmitterDelegate: CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?, webOOPEnabled: Bool?) {
        // assign addressname and name or expected devicename
        // (actually this now isn't really necessary as for new devices, sensorSerialNumber will be nil and we'll update the superclass expectedName anyway after the NFC scan via the delegate)
        var newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "ABBOTT" + (sensorSerialNumber ?? ""))
        
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: "ABBOTT" + (sensorSerialNumber ?? ""))
        }
        
        // initialize sensorSerialNumber
        phoneSensor = Libre2PhoneSensor(serialNumber: sensorSerialNumber, webOOPEnabled: webOOPEnabled ?? false)

        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMLibre2TransmitterDelegate
        self.cGMLibre2TransmitterDelegate = cGMLibre2TransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // A committed return must restore the durable Watch counter before the first BLE attempt.
        let selection = Libre2ConnectionStore.shared.snapshot
        if selection?.phase == .phone, let id = selection?.sessionID,
           let returned = try? Libre2WatchSession.load(from: Libre2ConnectionStore.shared.sessionURL),
           returned.id == id, returned.sensorUID == UserDefaults.standard.libreSensorUID {
            UserDefaults.standard.libreActiveSensorUnlockCount = max(UserDefaults.standard.libreActiveSensorUnlockCount, returned.unlockCount)
        }
        super.init(addressAndName: newAddressAndName, sensor: phoneSensor, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        Libre2PhoneConnection.shared.transmitter = self
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        return startNFCScanning()
    }

    /// Start BLE discovery after provisioning, without opening an NFC session.
    func startBLEScanning() {
        _ = super.startScanning()
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
        guard isConnectionAllowed else { return }
        
        if let sensorSerialNumber = tempSensorSerialNumber {
            // we need to send the sensorSerialNumber here. Possibly this is a new transmitter being scanned for, in which case the call to cGMLibre2TransmitterDelegate?.received(sensorSerialNumber: ..) in NFCTagReaderSessionDelegate functions wouldn't have stored the status in coredata, because it' doesn't find the transmitter, so let's store it again, at each connect, if not nil
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMLibre2TransmitterDelegate?.received(serialNumber: sensorSerialNumber.serialNumber, from: self)
            }
            
            // set to nil so we don't send it again to the delegate when there's a new connect
            tempSensorSerialNumber = nil
            
            // Validate using the identity advertised by this sensor generation. Older Libre 2
            // sensors include their serial number in the Bluetooth name, while 7F sensors use
            // the MAC-derived name returned by the NFC enable-streaming command.
            if connectedDeviceMatchesScannedSensor(serialNumber: sensorSerialNumber) == false {
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.connectedLibre2DoesNotMatchScannedLibre2)
                }
                
            } else {
                // user should be informed not to scan with the Libre app
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.donotusethelibrelinkapp)
                }
            }
        }
    }

    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Libre2-specific transient state cleanup
        let tearDown = {
            self.tempSensorSerialNumber = nil
            self.libreNFC = nil
            self.libreSensorType = nil
            self.expectedBluetoothNameFromNFC = nil
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    // MARK: - helpers

    /// Returns nil when the connected peripheral cannot be validated. A missing identifier must
    /// not be reported as a wrong sensor because connection and payload authentication still
    /// provide their own checks.
    private func connectedDeviceMatchesScannedSensor(serialNumber: LibreSensorSerialNumber) -> Bool? {
        guard let deviceName = deviceName else { return nil }

        if libreSensorType?.usesMacAddressAsBluetoothName == true {
            guard let expectedBluetoothNameFromNFC = expectedBluetoothNameFromNFC else { return nil }

            return deviceName.caseInsensitiveCompare(expectedBluetoothNameFromNFC) == .orderedSame
        }

        // Preserve the legacy comparison: historically the first decoded serial character was
        // unreliable, so only the final nine characters were used to identify ABBOTT-named sensors.
        return serialNumber.serialNumber.suffix(9).uppercased() == deviceName.suffix(9).uppercased()
    }
    
    override func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {
        Libre2PhoneConnection.shared.received(glucoseData, from: self)
        var copy = glucoseData
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: TimeInterval(minutes: Double(sensorTimeInMinutes)))
        cGMLibre2TransmitterDelegate?.received(sensorTimeInMinutes: Int(sensorTimeInMinutes), from: self)
    }

    func watchSession(id: UUID) throws -> Libre2WatchSession {
        guard let uid = UserDefaults.standard.libreSensorUID,
              let patchInfo = UserDefaults.standard.librePatchInfo,
              let serial = sensorSerialNumber, let name = deviceName,
              let parameters = UserDefaults.standard.libre1DerivedAlgorithmParameters,
              isWebOOPEnabled(), !UserDefaults.standard.suppressUnLockPayLoad else {
            throw Libre2ConnectionError("Libre Native Algorithm and unlock payload must be enabled for a provisioned sensor.")
        }
        let session = Libre2WatchSession(id: id, sensorUID: uid, patchInfo: patchInfo,
            serialNumber: serial, bluetoothName: name,
            unlockCode: UserDefaults.standard.libreActiveSensorUnlockCode,
            unlockCount: UserDefaults.standard.libreActiveSensorUnlockCount, algorithmParameters: parameters)
        try session.validate()
        return session
    }

    // MARK: - CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        if nonFixedSlopeEnabled != enabled {
            nonFixedSlopeEnabled = enabled
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        if phoneSensor.webOOPEnabled != enabled {
            phoneSensor.webOOPEnabled = enabled
        }
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Libre2
    }
    
    func isWebOOPEnabled() -> Bool {
        return phoneSensor.webOOPEnabled
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func maxSensorAgeInDays() -> Double? {
        return libreSensorType?.maxSensorAgeInDays()
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_Service_Libre2
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Libre2
    }
}
