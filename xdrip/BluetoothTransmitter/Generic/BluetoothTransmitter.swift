import Foundation
import CoreBluetooth
import os
import UIKit

/// Generic bluetoothtransmitter class that handles scanning, connect, discover services, discover characteristics, subscribe to receive characteristic, reconnect. This class is a base class for specific type of transmitters.
///
/// The class assumes that the transmitter has a receive and transmit characterisitc (which is mostly the case) - incase there's more characteristics to be processed, then the derived class will need to override didUpdateValueFor function
class BluetoothTransmitter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - public properties
    
    /// variable : it can get a new value during app run, will be used by rootviewcontroller's that want to receive info
    public weak var bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?

    // MARK: - private properties
    
    /// the address of the transmitter. If nil then transmitter never connected, so we don't know the address.
    private(set) var deviceAddress:String?
    
    /// the name of the transmitter. If nil then transmitter never connected, so we don't know the name
    private(set) var deviceName:String?
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    private let CBUUID_Advertisement:String?
    
    /// services to be discovered
    private let servicesCBUUIDs:[CBUUID]?
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic:String
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic:String
    
    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBlueToothTransmitter)

    /// centralManager
    private var centralManager: CBCentralManager?
    
    /// peripheral, gets value during connect
    private var peripheral: CBPeripheral?
    
    /// will be used to monitor progress
    private var timeStampLastStatusUpdate:Date
    
    /// if never connected before to the device, then possibily we expect a specific device name. For example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF. For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    /// the value is only used during first time connection to a new device. Once we've connected at least once, we know the final name (eg xBridge) and will store this name in the name attribute, the expectedName value can then be ignored
    private var expectedName:String?
    
    /// the write Characteristic
    private var writeCharacteristic:CBCharacteristic?
    
    /// the receive Characteristic
    private var receiveCharacteristic:CBCharacteristic?
    
    /// used in BluetoothTransmitter class, eg if after calling discoverServices new method is called and time is exceed, then cancel connection
    private let maxTimeToWaitForPeripheralResponse = 5.0
    
    /// when trying to connect to a discovered device for the first time, a timer will be used to avoid that connection attempts take forever
    private var connectTimeOutTimer: Timer?
    
    // MARK: - Initialization
    
    /// - parameters:
    ///     -  addressAndName : if we never connected to a device, then we don't know it's address as the Device itself is going to send. We can only have an expectedName which is what needs to be added then in the argument
    ///         * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///         * For an xDrip or xBridge, we don't expect a specific devicename, in which case the value stays nil
    ///         * If we already connected to a device before, then we know it's address
    ///     - CBUUID_Advertisement : UUID to use for scanning, if nil  then app will scan for all devices. (Example Blucon, MiaoMiao, should be nil value. For G5 it should have a value. For xDrip it will probably work with or without. Main difference is that if no advertisement UUID is specified, then app is not allowed to scan will in background. For G5 this can create problem for first time connect, because G5 only transmits every 5 minutes, which means the app would need to stay in the foreground for at least 5 minutes.
    ///     - servicesCBUUIDs: service uuid's
    ///     - CBUUID_ReceiveCharacteristic: receive characteristic uuid
    ///     - CBUUID_WriteCharacteristic: write characteristic uuid
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    init(addressAndName:BluetoothTransmitter.DeviceAddressAndName, CBUUID_Advertisement:String?, servicesCBUUIDs:[CBUUID]?, CBUUID_ReceiveCharacteristic:String, CBUUID_WriteCharacteristic:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        switch addressAndName {
            
        case .alreadyConnectedBefore(let address, let name):
            deviceAddress = address
            deviceName = name
            
        case .notYetConnected(let newexpectedName):
            expectedName = newexpectedName
            
        }
        
        //assign uuid's
        self.servicesCBUUIDs = servicesCBUUIDs
        self.CBUUID_Advertisement = CBUUID_Advertisement
        self.CBUUID_WriteCharacteristic = CBUUID_WriteCharacteristic
        self.CBUUID_ReceiveCharacteristic = CBUUID_ReceiveCharacteristic
        
        //initialize timeStampLastStatusUpdate
        timeStampLastStatusUpdate = Date()
        
        // assign bluetoothTransmitterDelegate
        self.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate
        
        super.init()

        initialize()
        
    }
    
    // MARK: - De-initialization
    
    deinit {
        
        // disconnect the device
        disconnect()
        
    }
    
    // MARK: - public functions
    
    /// will try to connect to the device, first by calling retrievePeripherals, if peripheral not known, then by calling startScanning
    func connect() {
        
        if let centralManager = centralManager, !retrievePeripherals(centralManager) {
            _ = startScanning()
        }

    }
    
    /// gets peripheral connection status, nil if peripheral not existing yet
    func getConnectionStatus() -> CBPeripheralState? {
        return peripheral?.state
    }
    
    /// disconnect the device
    func disconnect() {
        
        if let peripheral = peripheral {
            if let centralManager = centralManager {
                trace("in disconnect, disconnecting, for peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'")
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
      
    }
    
    /// in case a new device is being scanned for, and we connected (because name matched) but later we want to forget that device, then call this function
    func disconnectAndForget() {
        
        // force disconnect
        disconnect()

        // set to nil
        peripheral = nil
        deviceName = nil
        deviceAddress = nil
        
    }
    
    /// stops scanning
    func stopScanning() {
        self.centralManager?.stopScan()
    }
    
    /// is the transmitter currently scanning or not
    func isScanning() -> Bool {
        if let centralManager = centralManager {
            return centralManager.isScanning
        }
        return false
    }
    
    /// start bluetooth scanning for device
    func startScanning() -> BluetoothTransmitter.startScanningResult {
        
        trace("in startScanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        
        //assign default returnvalue
        var returnValue = BluetoothTransmitter.startScanningResult.unknown
        
        // first check if already connected or connecting and if so stop processing
        if let peripheral = peripheral {
            switch peripheral.state {
            case .connected:
                trace("    peripheral is already connected, will not start scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                return .alreadyConnected
            case .connecting:
                if Date() > Date(timeInterval: maxTimeToWaitForPeripheralResponse, since: timeStampLastStatusUpdate) {
                    trace("    status connecting, but waiting more than %{public}d seconds, will disconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, maxTimeToWaitForPeripheralResponse)
                    disconnect()
                } else {
                    trace("    peripheral is currently connecting, will not start scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                }
                return .connecting
            default:()
            }
        }
        
        /// list of uuid's to scan for, possibily nil, in which case scanning only if app is in foreground and scan for all devices
        var services:[CBUUID]?
        if let CBUUID_Advertisement = CBUUID_Advertisement {
            services = [CBUUID(string: CBUUID_Advertisement)]
        }
        
        // try to start the scanning
        if let centralManager = centralManager {
            if centralManager.isScanning {
                trace("    already scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                return .alreadyScanning
            }
            switch centralManager.state {
            case .poweredOn:
                
                trace("    state is poweredOn", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                centralManager.scanForPeripherals(withServices: services, options: nil)
                returnValue = .success
                
            case .poweredOff:
                
                trace("    state is poweredOff", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                return .poweredOff
            
            case .unknown:
                
                trace("    state is unknown", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                return .unknown
                
            case .unauthorized:
                
                trace("    state is unauthorized", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                return .unauthorized
                
            default:
                
                trace("    state is %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, centralManager.state.toString())
                return returnValue
           
            }
        } else {
            trace("    centralManager is nil, can not starting scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
            returnValue = .other(reason:"centralManager is nil, can not start scanning")
        }
        
        return returnValue
    }
    
    /// will write to writeCharacteristic with UUID CBUUID_WriteCharacteristic
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType)  -> Bool {
        if let peripheral = peripheral, let writeCharacteristic = writeCharacteristic, getConnectionStatus() == CBPeripheralState.connected {
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", writeCharacteristic.uuid.uuidString, data.hexEncodedString())
            peripheral.writeValue(data, for: writeCharacteristic, type: type)
            return true
        } else {
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, failed because either peripheral or writeCharacteristic is nil or not connected", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
            return false
        }
    }
    
    /// calls peripheral?.readValue(for: characteristic)
    func readValueForCharacteristic(for characteristic: CBCharacteristic) {
        peripheral?.readValue(for: characteristic)
    }

    /// will write to characteristicToWriteTo
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, characteristicToWriteTo:CBCharacteristic, type:CBCharacteristicWriteType)  -> Bool {
        
        if let peripheral = peripheral, getConnectionStatus() == CBPeripheralState.connected {
            
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, for characteristic %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", characteristicToWriteTo.uuid.description, data.hexEncodedString())
            
            peripheral.writeValue(data, for: characteristicToWriteTo, type: type)
            
            return true
            
        } else {
            
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, failed because either peripheral or characteristicToWriteTo is nil or not connected", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
            
            return false
            
        }
    }
    
    /// calls setNotifyValue for characteristic with value enabled
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        if let peripheral = peripheral {
            trace("setNotifyValue, for peripheral with name %{public}@, setting notify for characteristic %{public}@, to %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", characteristic.uuid.uuidString, enabled.description)
          peripheral.setNotifyValue(enabled, for: characteristic)
        } else {
            trace("setNotifyValue, for peripheral with name %{public}@, failed to set notify for characteristic %{public}@, to %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'", characteristic.uuid.uuidString, enabled.description)
        }
    }
    
    /// called by the delegate in the case of a transmitter that needs an NFC scan and used to update the expected name to include the recently scanned sensor serial number. This ensures that we only allow this sensor to connect.
    func updateExpectedDeviceName(name: String) {
        
        self.expectedName = name
        
    }
    
    // MARK: - fileprivate functions
    
    /// stops scanning and connect. To be called after diddiscover
    fileprivate func stopScanAndconnect(to peripheral: CBPeripheral) {
        
        self.centralManager?.stopScan()
        self.deviceAddress = peripheral.identifier.uuidString
        self.deviceName = peripheral.name
        peripheral.delegate = self
        self.peripheral = peripheral
        
        //in Spike a check is done to see if state is disconnected, this is code from the MiaoMiao developers, not sure if this is needed or not because normally the device should be disconnected
        trace("in stopScanAndconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, peripheral.state.description())
        if peripheral.state == .disconnected {
            trace("    trying to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            
            // set timer to avoid that connection attempt takes forever
            connectTimeOutTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(stopConnectAndRestartScanning), userInfo: nil, repeats: false)
            
            centralManager?.connect(peripheral, options: nil)
            
        } else {
            if let newCentralManager = centralManager {
                trace("    calling centralManager(newCentralManager, didConnect: peripheral", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                centralManager(newCentralManager, didConnect: peripheral)
            }
        }
    }
    
    ///
    @objc fileprivate func stopConnectAndRestartScanning() {
        
        trace("    disconnecting due to timeout, will restart scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        
        disconnectAndForget()

        _ =  startScanning()
        
    }
    
    /// connectionTimer monitors the connection setup for a new device. This function checks if the timer is running and if so cancels the timer
    public func cancelConnectionTimer() {
        
        if let connectTimeOutTimer = connectTimeOutTimer {
            connectTimeOutTimer.invalidate()
            self.connectTimeOutTimer = nil
        }
        
    }
    
    /// try to connect to peripheral to which connection was successfully done previously, and that has a uuid that matches the stored deviceAddress. If such peripheral exists, then try to connect, it's not necessary to start scanning. iOS will connect as soon as the peripheral comes in range, or bluetooth status is switched on, whatever is necessary
    ///
    /// the result of the attempt to try to find such device, is returned
    fileprivate func retrievePeripherals(_ central:CBCentralManager) -> Bool {
        if let deviceAddress = deviceAddress {
            trace("in retrievePeripherals, deviceaddress is %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceAddress)
            if let uuid = UUID(uuidString: deviceAddress) {
                trace("    uuid is not nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                let peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
                if peripheralArr.count > 0 {
                    peripheral = peripheralArr[0]
                    if let peripheral = peripheral {
                        trace("    trying to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                        peripheral.delegate = self
                        central.connect(peripheral, options: nil)
                        return true
                    } else {
                        trace("     peripheral is nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    }
                } else {
                    trace("    uuid is not nil, but central.retrievePeripherals returns 0 peripherals", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                }
            } else {
                trace("    uuid is nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            }
        }
        return false
    }
    
    // MARK: - methods from protocols CBCentralManagerDelegate, CBPeripheralDelegate
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        timeStampLastStatusUpdate = Date()
        
        // devicename needed unwrapped for logging
        var deviceName = "unknown"
        if let temp = peripheral.name {
            deviceName = temp
        }
        trace("Did discover peripheral with name: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: deviceName))
        
        // check if stored address not nil, in which case we already connected before and we expect a full match with the already known device name
        if let deviceAddress = deviceAddress {
            if peripheral.identifier.uuidString == deviceAddress {
                trace("    stored address matches peripheral address, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                stopScanAndconnect(to: peripheral)
            } else {
                trace("    stored address does not match peripheral address, ignoring this device", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            }
        } else {
            //the app never connected before to our device
            // do we expect a specific device name ?
            if let expectedName = expectedName {
                // so it's a new device, we need to see if it matches the specifically expected device name
                if (peripheral.name?.range(of: expectedName, options: .caseInsensitive)) != nil {
                    // peripheral.name is not nil and contains expectedName
                    trace("    new peripheral has expected device name, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    stopScanAndconnect(to: peripheral)
                } else {
                    // peripheral.name is nil or does not contain expectedName
                    trace("    new peripheral doesn't have device name as expected (%{public}@), ignoring this device", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, expectedName)
                }
            } else {
                // we don't expect any specific device name, so let's connect
                trace("    new peripheral, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                stopScanAndconnect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        cancelConnectionTimer()
        
        timeStampLastStatusUpdate = Date()
        
        trace("connected to peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'")
        
        bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)

        peripheral.discoverServices(servicesCBUUIDs)
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("failed to connect, for peripheral with name %{public}@, with error: %{public}@, will try again", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , deviceName ?? "'unknown'", error.localizedDescription)
        } else {
            trace("failed to connect, for peripheral with name %{public}@, will try again", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
        }
        
        centralManager?.connect(peripheral, options: nil)
        
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("in centralManagerDidUpdateState, for peripheral with name %{public}@, new state is %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", "\(central.state.toString())")
        
        bluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: central.state, bluetoothTransmitter: self)

        /// in case status changed to powered on and if device address known then try  to retrieveperipherals
        if central.state == .poweredOn {
            if (deviceAddress != nil) {
                
                /// try to connect to device to which connection was successfully done previously, this attempt is done by callling retrievePeripherals(central)
                _ = retrievePeripherals(central)
                
            }
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("    didDisconnect peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info , deviceName ?? "'unknown'")
        
        bluetoothTransmitterDelegate?.didDisconnectFrom(bluetoothTransmitter: self)

        if let error = error {
            trace("    error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }
        
        // if self.peripheral == nil, then a manual disconnect or something like that has occured, no need to reconnect
        // otherwise disconnect occurred because of other (like out of range), so let's try to reconnect
        if let ownPeripheral = self.peripheral {
            trace("    Will try to reconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            centralManager?.connect(ownPeripheral, options: nil)
        } else {
            trace("    peripheral is nil, will not try to reconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        }

    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("didDiscoverServices for peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'")
        
        if let error = error {
            trace("    didDiscoverServices error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error ,  "\(error.localizedDescription)")
        }
        
        if let services = peripheral.services {
            for service in services {
                trace("    Call discovercharacteristics for service with uuid %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: service.uuid))
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            disconnect()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", String(describing:service.uuid))
        
        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("    characteristic: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid))
                if (characteristic.uuid == CBUUID(string: CBUUID_WriteCharacteristic)) {
                    trace("    found writeCharacteristic", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    writeCharacteristic = characteristic
                } //don't use else because some devices have only one characteristic uuid for both transmit and receive
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    trace("    found receiveCharacteristic", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    receiveCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("in didWriteValueFor. Characteristic %{public}@, error =  %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, String(describing: characteristic.uuid), error.localizedDescription)
        } else {
            trace("in didWriteValueFor. Characteristic %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("didUpdateNotificationStateFor for peripheral with name %{public}@, characteristic %{public}@, error =  %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unkonwn'", String(describing: characteristic.uuid), error.localizedDescription)
        }
        
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        // trace the received value
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, value.hexEncodedString())
        }
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("didUpdateValueFor for peripheral with name %{public}@, characteristic %{public}@, characteristic description %{public}@, error =  %{public}@, no further processing", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'", String(describing: characteristic.uuid), String(characteristic.debugDescription), error.localizedDescription)
        }
        
    }
    
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String : Any]) {

        // willRestoreState must be defined, otherwise the app would crash (because the centralManager was created with a CBCentralManagerOptionRestoreIdentifierKey)
        // even if it's an empty function
        // trace is called here because it allows us to see in the issue reports if there was a restart after app crash or removed from memory - in all other cases (force closed by user) this function is not called

        trace("in willRestoreState", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        
    }

    // MARK: - helpers
    
    /// to ask transmitter that it initiates pairing
    ///
    /// to be overriden. For transmitter types that don't need pairing, or that don't need pairing initiated by user/view controller, this function does not need to be overriden
    func initiatePairing() {return}
    
    private func initialize() {
        
        // create centralManager with a CBCentralManagerOptionRestoreIdentifierKey. This to ensure that iOS relaunches the app whenever it's killed either due to a crash or due to lack of memory
        // iOS will restart the app as soon as a bluetooth transmitter tries to connect (which is under normal circumtances immediately)
        // the function willRestoreState (see below) is an empty function and that seems to be enough to make it work
        // see https://developer.apple.com/library/archive/qa/qa1962/_index.html
        //
        // the value used for CBCentralManagerOptionRestoreIdentifierKey depends :
        // - when scanning for a new device (or peripheral), use a random string. Disadvantage of using a random string is that willRestoreState doesn't get called when the app relaunches, because not the same value will be used (as it's a random string)
        // - when scanning for (better : trying to connect to) a known device, the device's mac address is used. In that case, after restart, it will be the same value. In this case the function willRestoreState gets called
        //
        // additional notes :
        // - the only reason why it's good to see willRestoreState starting, is because there's a trace statement in it. This allows to see in trace files if there was a restart after crash or being thrown out of memory
        
        /// restore identifier key to use
        var cBCentralManagerOptionRestoreIdentifierKeyToUse: String?
        
        if let deviceAddress = deviceAddress {
            
            trace("in initialize, creating centralManager for peripheral with address %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceAddress)
            
            // if it's an existing device, then restore identifier key will contain the device address, which is unique worldwide
            // the application name is also in the identifier key
            cBCentralManagerOptionRestoreIdentifierKeyToUse = ConstantsHomeView.applicationName + "-" + deviceAddress
            
        } else {

            trace("in initialize, creating centralManager for new peripheral", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)

            // if it's a new device, then restore identifier key will contain random string
            // the application name is also in the identifier key
            cBCentralManagerOptionRestoreIdentifierKeyToUse = ConstantsHomeView.applicationName + "-" + String((0..<24).map{ _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!})
            
        }
        
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: cBCentralManagerOptionRestoreIdentifierKeyToUse!])
        
    }
    
    // MARK: - enum's
    
    /// result of call to startscanning
    enum startScanningResult: Equatable {
        
        /// scanning started successfully
        case success
        
        /// was already scanning, can be considred as successful
        case alreadyScanning
        
        /// scanning ,ot started because bluetooth is not powered on,
        case poweredOff
        
        /// in case peripheral is currently connected then it makes no sense to start scanning
        case alreadyConnected
        
        /// peripheral is currently connecting, it makes no sense to start scanning
        case connecting
        
        /// unknown state
        case unknown
        
        /// unauthorized
        case unauthorized
        
        /// successful NFC scan needed before starting BLE scanning
        case nfcScanNeeded
        
        // any other, reason specified in text
        case other(reason:String)
        
        func description() -> String {
            switch self {
                
            case .success:
                return "success"
                
            case .alreadyScanning:
                return "alreadyScanning"
                
            case .poweredOff:
                return "poweredOff"
                
            case .alreadyConnected:
                return "alreadyConnected"
                
            case .connecting:
                return "connecting"
                
            case .other(let reason):
                return "other reason : " + reason
                
            case .unknown:
                return "unknown"
                
            case .unauthorized:
                return "unauthorized"
                
            case .nfcScanNeeded:
                return "nfcScanNeeded"
                
            }
        }
    }
    
    /// * if we never connected to a device, then we don't know it's address as the Device itself is going to send. We can only have an expected name,
    ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    /// * If we already connected to a device before, then we know it's address
    enum DeviceAddressAndName {
        
        /// we already connected to the device so we should know the address and name
        ///
        /// name kept optional, for in case it was not stored
        case alreadyConnectedBefore (address:String, name:String?)
        
        /// * We never connected to the device, so we don't know it's name and address as the Device itself is going to send. We can only have an expected name,
        ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
        ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
        case notYetConnected (expectedName:String?)
        
    }
}



