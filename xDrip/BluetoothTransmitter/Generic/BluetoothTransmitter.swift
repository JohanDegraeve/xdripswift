import Foundation
import CoreBluetooth
import os
import UIKit

/// Generic bluetoothtransmitter class that handles scanning, connect, discover services, discover characteristics, subscribe to receive characteristic, reconnect. This class is a base class for specific type of transmitters.
///
/// The class assumes that the transmitter has a receive and transmit characterisitc (which is mostly the case) - incase there's more characteristics to be processed, then the derived class will need to override didUpdateValueFor function
class BluetoothTransmitter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - persistence (UserDefaults keys)
    /// we use this to store the required info needed to restore a random ID if it was created that way during the init
    private enum DefaultsKey {
        static let lastKnownDeviceAddress = "bt.lastKnownDeviceAddress"
        static let lastKnownDeviceName    = "bt.lastKnownDeviceName"
    }
    
    // MARK: - public properties
    
    /// variable : it can get a new value during app run, will be used by rootviewcontroller's that want to receive info
    public weak var bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?
    
    // MARK: - private properties
    /// whether we should auto‑reconnect after the *next* disconnect callback (explicitly controlled)
    private var shouldReconnectOnNextDisconnect = true
    
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
    
    /// central queue for all CoreBluetooth work (dedicated serial queue)
    private let centralQueue = DispatchQueue(label: "bt.central", qos: .userInitiated)

    /// queue-specific flag so we can detect whether we're already running on centralQueue
    private let centralQueueSpecificKey = DispatchSpecificKey<Void>()
    
    /// assert helper to ensure code is running on centralQueue (debug-only)
    private func assertOnCentral(function: String = #function) {
        // Using dispatchPrecondition is safe and low-overhead. This is for development safety only.
        dispatchPrecondition(condition: .onQueue(centralQueue))
    }
    
    /// helper to hand off work to main thread (UI / Core Data)
    private func dispatchToMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// helper to synchronously execute work on centralQueue (re-entrant safe)
    private func runOnCentralQueueSync<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: centralQueueSpecificKey) != nil {
            return block()
        } else {
            return centralQueue.sync(execute: block)
        }
    }
    
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
    
    /// de-dup state for connection log spam
    private var lastConnectLogAt: Date = .distantPast
    private var lastConnectLogName: String? = nil
    
    private var hasLoggedPersistThisRun = false

    /// If set by a subclass, we will treat the *next* disconnect as a temporary rejection for this specific device name.
    /// This is intended for transient pre-auth cases (e.g. G7/ONE+ "Encryption is insufficient").
    private var pendingTemporaryRejectionDeviceName: String? = nil
    
    /// Names of devices we should avoid reconnecting to for a short period after a recent disconnect
    private var temporarilyRejectedDeviceNames: [String: Date] = [:]
    private let temporaryRejectionCooldownSeconds: TimeInterval = 180
    
    /// set the connection options
    private var connectOptions: [String: Any] {
        [CBConnectPeripheralOptionNotifyOnConnectionKey: true, CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
    }
    
    /// Returns true if the given device name is currently under temporary rejection cooldown
    private func isTemporarilyRejected(_ discoveredDeviceName: String) -> Bool {
        if let lastRejection = temporarilyRejectedDeviceNames[discoveredDeviceName] {
            return Date().timeIntervalSince(lastRejection) < temporaryRejectionCooldownSeconds
        }
        return false
    }
    
    /// Records a device name as temporarily rejected from immediate reconnection attempts
    private func markDeviceNameAsTemporarilyRejected(_ discoveredDeviceName: String) {
        temporarilyRejectedDeviceNames[discoveredDeviceName] = Date()
    }
    
    /// Returns true if the device name looks like a Dexcom G7/ONE+ (DX**)
    private func isDexcomG7StyleName(_ name: String) -> Bool {
        return name.uppercased().hasPrefix("DX")
    }
    
    // MARK: - Initialization
    
    /// - parameters:
    ///     -  addressAndName : if we never connected to a device, then we don't know it's address as the Device itself is going to send. We can only have an expectedName which is what needs to be added then in the argument
    ///         * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///         * For an xDrip or xBridge, we don't expect a specific devicename, in which case the value stays nil
    ///         * If we already connected to a device before, then we know it's address
    ///     - CBUUID_Advertisement : UUID to use for scanning, if nil  then app will scan for all devices. (Example MiaoMiao, should be nil value. For G5 it should have a value. For xDrip it will probably work with or without. Main difference is that if no advertisement UUID is specified, then app is not allowed to scan will in background. For G5 this can create problem for first time connect, because G5 only transmits every 5 minutes, which means the app would need to stay in the foreground for at least 5 minutes.
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

        centralQueue.setSpecific(key: centralQueueSpecificKey, value: ())

        initialize()
        
    }
    
    // MARK: - De-initialization
    
    deinit {
        // Clear CoreBluetooth delegates synchronously on main as last resort
        let clear = {
            self.centralManager?.delegate = nil
            self.peripheral?.delegate = nil
        }
        if Thread.isMainThread {
            clear()
        } else {
            DispatchQueue.main.sync(execute: clear)
        }
    }
    
    // MARK: - public functions
    
    /// Hook for subclasses to clear CoreBluetooth delegates/timers before ARC release.
    /// Default clears CoreBluetooth delegates on the main thread synchronously to avoid races with CB callbacks.
    @objc func prepareForRelease() {
        let clear = {
            self.centralManager?.delegate = nil
            self.peripheral?.delegate = nil
        }
        if Thread.isMainThread {
            clear()
        } else {
            DispatchQueue.main.sync(execute: clear)
        }
    }
    
    /// will try to connect to the device, first by calling retrievePeripherals, if peripheral not known, then by calling startScanning
    func connect() {
        centralQueue.async { [weak self] in
            guard let self = self else { return }
            if let centralManager = self.centralManager, !self.retrievePeripherals(centralManager) {
                _ = self.startScanning()
            }
        }
    }
    
    /// gets peripheral connection status, nil if peripheral not existing yet
    func getConnectionStatus() -> CBPeripheralState? {
        return peripheral?.state
    }
    
    /// disconnect the device (reconnect policy unchanged, see `disconnectAndForget()` to disable)
    func disconnect() {
        centralQueue.async { [weak self] in
            guard let self = self else { return }
            if let peripheral = self.peripheral {
                if let receiveCharacteristic = self.receiveCharacteristic {
                    peripheral.setNotifyValue(false, for: receiveCharacteristic)
                }
                if let centralManager = self.centralManager {
                    trace("in disconnect, disconnecting, for peripheral with name %{public}@", log: self.log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, self.deviceName ?? "'unknown'")
                    centralManager.cancelPeripheralConnection(peripheral)
                }
            }
        }
    }
    
    /// in case a new device is being scanned for, and we connected (because name matched) but later we want to forget that device, then call this function
    func disconnectAndForget() {
        // do not auto‑reconnect after a user‑initiated forget (for the next disconnect only)
        shouldReconnectOnNextDisconnect = false
        // request disconnect first so OS callbacks can complete
        disconnect()
        // clear local references (we are intentionally *not* clearing central/peripheral delegates here
        // final teardown should call prepareForRelease() when the instance is actually being released)
        peripheral = nil
        deviceName = nil
        deviceAddress = nil
    }
    
    /// stops scanning
    func stopScanning() {
        centralQueue.async { [weak self] in
            self?.centralManager?.stopScan()
        }
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
        return runOnCentralQueueSync {
            //assign default returnvalue
            var returnValue = BluetoothTransmitter.startScanningResult.unknown
            
            // first check if already connected or connecting and if so stop processing
            if let peripheral = peripheral {
                switch peripheral.state {
                case .connected:
                    trace("in startScanning, peripheral is already connected, will not start scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    return .alreadyConnected
                case .connecting:
                    if Date() > Date(timeInterval: maxTimeToWaitForPeripheralResponse, since: timeStampLastStatusUpdate) {
                        trace("in startScanning, status connecting, but waiting more than %{public}d seconds, will disconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, maxTimeToWaitForPeripheralResponse)
                        disconnect()
                    } else {
                        trace("in startScanning, peripheral is currently connecting, will not start scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    }
                    return .connecting
                default:()
                }
            }
            
            /// list of uuid's to scan for, possibly nil, in which case scanning only if app is in foreground and scan for all devices
            var services:[CBUUID]?
            if let CBUUID_Advertisement = CBUUID_Advertisement {
                services = [CBUUID(string: CBUUID_Advertisement)]
            }
            
            // try to start the scanning
            if let centralManager = centralManager {
                if centralManager.isScanning {
                    trace("in startScanning, already scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    return .alreadyScanning
                }
                switch centralManager.state {
                case .poweredOn:
                    
                    trace("in startScanning, state is poweredOn", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    centralManager.scanForPeripherals(withServices: services, options: nil)
                    returnValue = .success
                    
                case .poweredOff:
                    
                    trace("in startScanning, state is poweredOff", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                    return .poweredOff
                
                case .unknown:
                    
                    trace("in startScanning, state is unknown", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                    return .unknown
                    
                case .unauthorized:
                    
                    trace("in startScanning, state is unauthorized", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                    return .unauthorized
                    
                default:
                    
                    trace("in startScanning, state is %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, centralManager.state.toString())
                    return returnValue
               
                }
            } else {
                trace("in startScanning, centralManager is nil, can not starting scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                returnValue = .other(reason:"centralManager is nil, can not start scanning")
            }
            
            return returnValue
        }
    }
    
    /// will write to writeCharacteristic with UUID CBUUID_WriteCharacteristic
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType)  -> Bool {
        if let peripheral = peripheral, let writeCharacteristic = writeCharacteristic, getConnectionStatus() == CBPeripheralState.connected {
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", writeCharacteristic.uuid.uuidString, data.hexEncodedString())
            
            centralQueue.async {
                peripheral.writeValue(data, for: writeCharacteristic, type: type)
            }
            return true
        } else {
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, failed because either peripheral or writeCharacteristic is nil or not connected", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
            return false
        }
    }
    
    /// calls peripheral?.readValue(for: characteristic)
    func readValueForCharacteristic(for characteristic: CBCharacteristic) {
        centralQueue.async { [weak self] in
            self?.peripheral?.readValue(for: characteristic)
        }
    }
    
    /// will write to characteristicToWriteTo
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, characteristicToWriteTo:CBCharacteristic, type:CBCharacteristicWriteType)  -> Bool {
        
        if let peripheral = peripheral, getConnectionStatus() == CBPeripheralState.connected {
            
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, for characteristic %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", characteristicToWriteTo.uuid.description, data.hexEncodedString())
            
            centralQueue.async {
                peripheral.writeValue(data, for: characteristicToWriteTo, type: type)
            }
            
            return true
            
        } else {
            
            trace("in writeDataToPeripheral, for peripheral with name %{public}@, failed because either peripheral or characteristicToWriteTo is nil or not connected", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
            
            return false
            
        }
    }
    
    /// calls setNotifyValue for characteristic with value enabled
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        if let peripheral = peripheral {
            trace("in setNotifyValue, for peripheral with name %{public}@, setting notify for characteristic %{public}@, to %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, deviceName ?? "'unknown'", characteristic.uuid.uuidString, enabled.description)
            
            centralQueue.async {
                peripheral.setNotifyValue(enabled, for: characteristic)
            }
        } else {
            trace("in setNotifyValue, for peripheral with name %{public}@, failed to set notify for characteristic %{public}@, to %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'", characteristic.uuid.uuidString, enabled.description)
        }
    }
    
    /// called by the delegate in the case of a transmitter that needs an NFC scan and used to update the expected name to include the recently scanned sensor serial number. This ensures that we only allow this sensor to connect.
    func updateExpectedDeviceName(name: String) {
        self.expectedName = name
    }

    /// Requests that the next disconnect be treated as a temporary rejection for the given device name.
    /// Use this from subclasses only in specific transient pre-auth flows.
    func scheduleTemporaryRejectionOnNextDisconnect(forDeviceName name: String) {
        centralQueue.async { [weak self] in
            self?.pendingTemporaryRejectionDeviceName = name
        }
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
        if peripheral.state == .disconnected {
            trace("in stopScanAndconnect, trying to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            
            // set timer to avoid that connection attempt takes forever
            // schedule timer on main thread because background queues do not have a run loop
            DispatchQueue.main.async { [weak self] in
                self?.connectTimeOutTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self as Any, selector: #selector(BluetoothTransmitter.stopConnectAndRestartScanning), userInfo: nil, repeats: false)
            }
            
            centralManager?.connect(peripheral, options: connectOptions)
            
        } else {
            if let newCentralManager = centralManager {
                trace("in stopScanAndconnect, calling centralManager(newCentralManager, didConnect: peripheral", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                centralManager(newCentralManager, didConnect: peripheral)
            }
        }
    }
    
    ///
    @objc fileprivate func stopConnectAndRestartScanning() {
        
        trace("in stopConnectAndRestartScanning, disconnecting due to timeout, will restart scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        
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
                trace("in retrievePeripherals, uuid is not nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
                let peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
                if peripheralArr.count > 0 {
                    peripheral = peripheralArr[0]
                    if let peripheral = peripheral {
                        trace("in retrievePeripherals, trying to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                        peripheral.delegate = self
                        central.connect(peripheral, options: connectOptions)
                        return true
                    } else {
                        trace("in retrievePeripherals, peripheral is nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    }
                } else {
                    trace("in retrievePeripherals, uuid is not nil, but central.retrievePeripherals returns 0 peripherals", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
                }
            } else {
                trace("in retrievePeripherals, uuid is nil", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
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
        trace("in didDiscover, found peripheral with name: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: deviceName))
        
        // check if stored address not nil, in which case we already connected before and we expect a full match with the already known device name
        if let deviceAddress = deviceAddress {
            if peripheral.identifier.uuidString == deviceAddress {
                // Skip recently rejected devices for a short cooldown period to avoid latching on the same stale DX transmitter repeatedly
                if let discoveredName = peripheral.name, isDexcomG7StyleName(discoveredName), isTemporarilyRejected(discoveredName) {
                    trace("in didDiscover, discovery skip: %{public}@ is within temporary rejection cooldown, keep scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, discoveredName)
                    return
                }
                trace("in didDiscover, stored address matches peripheral address, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                stopScanAndconnect(to: peripheral)
            } else {
                trace("in didDiscover, stored address does not match peripheral address, ignoring this device", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            }
        } else {
            //the app never connected before to our device
            // do we expect a specific device name ?
            if let expectedName = expectedName {
                // so it's a new device, we need to see if it matches the specifically expected device name
                if (peripheral.name?.range(of: expectedName, options: .caseInsensitive)) != nil {
                    // peripheral.name is not nil and contains expectedName
                    // Skip recently rejected devices for a short cooldown period to avoid latching on the same stale DX transmitter repeatedly
                    if let discoveredName = peripheral.name, isDexcomG7StyleName(discoveredName), isTemporarilyRejected(discoveredName) {
                        trace("in didDiscover, discovery skip: %{public}@ is within temporary rejection cooldown, keep scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, discoveredName)
                        return
                    }
                    trace("in didDiscover, new peripheral has expected device name, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                    stopScanAndconnect(to: peripheral)
                } else {
                    // peripheral.name is nil or does not contain expectedName
                    trace("in didDiscover, new peripheral doesn't have device name as expected (%{public}@), ignoring this device", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, expectedName)
                }
            } else {
                // we don't expect any specific device name, so let's connect
                // Skip recently rejected devices for a short cooldown period to avoid latching on the same stale DX transmitter repeatedly
                if let discoveredName = peripheral.name, isDexcomG7StyleName(discoveredName), isTemporarilyRejected(discoveredName) {
                    trace("in didDiscover, discovery skip: %{public}@ is within temporary rejection cooldown, keep scanning", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, discoveredName)
                    return
                }
                trace("in didDiscover, new peripheral, will try to connect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                stopScanAndconnect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        cancelConnectionTimer()
        
        timeStampLastStatusUpdate = Date()
        
        let now = Date()
        let name = deviceName ?? "'unknown'"
        if now.timeIntervalSince(lastConnectLogAt) > 2.0 || lastConnectLogName != name {
            trace("in didConnect, connected to peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, name)
            lastConnectLogAt = now
            lastConnectLogName = name
        }
        
        // delegate can update UI / Core Data. Ensure main thread
        dispatchToMain { [weak self] in
            guard let self = self else { return }
            self.bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: self)
        }
        
        // Persist address/name only when they change log once (debug) per launch.
        if let uuidString = peripheral.identifier.uuidString as String? {
            var didChange = false
            if deviceAddress != uuidString {
                deviceAddress = uuidString
                didChange = true
            }
            let newName = peripheral.name
            if deviceName != newName {
                deviceName = newName
                didChange = true
            }
            if didChange {
                UserDefaults.standard.setValue(deviceAddress, forKey: DefaultsKey.lastKnownDeviceAddress)
                UserDefaults.standard.setValue(deviceName,    forKey: DefaultsKey.lastKnownDeviceName)
                trace("in didConnect, persisted device to defaults: address=%{public}@, name=%{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, deviceAddress ?? "'nil'", deviceName ?? "'unknown'")
                hasLoggedPersistThisRun = true
            } else if !hasLoggedPersistThisRun {
                // Only once per launch so we can see that persistence was already up-to-date.
                trace("in didConnect, persisted device unchanged (already up-to-date)", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
                hasLoggedPersistThisRun = true
            }
        }
        
        peripheral.discoverServices(servicesCBUUIDs)
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("in didFailToConnect, failed to connect for peripheral with name %{public}@, with error: %{public}@, will try again", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , deviceName ?? "'unknown'", error.localizedDescription)
        } else {
            trace("in didFailToConnect, failed to connect for peripheral with name %{public}@, will try again", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'")
        }
        
        centralManager?.connect(peripheral, options: connectOptions)
        
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("in centralManagerDidUpdateState, for peripheral with name %{public}@, new state is %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'", "\(central.state.toString())")
        
        // delegate can update UI / Core Dat. Ensure main thread
        dispatchToMain { [weak self] in
            guard let self = self else { return }
            self.bluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: central.state, bluetoothTransmitter: self)
        }
        
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
        
        // delegate can update UI / Core Data. Ensure main thread
        dispatchToMain { [weak self] in
            guard let self = self else { return }
            self.bluetoothTransmitterDelegate?.didDisconnectFrom(bluetoothTransmitter: self)
        }
        
        // Replace your current disconnect logging block with this:
        if let err = error {
            if let cbErr = err as? CBError, cbErr.code == .peripheralDisconnected {
                // Expected short-lived disconnect (normal Dexcom behavior)
                trace("in didDisconnectPeripheral, didDisconnect peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'")
            } else {
                // Unexpected error
                trace("in didDisconnectPeripheral, didDisconnect peripheral %{public}@ with error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'", err.localizedDescription)
            }
        } else {
            // Clean disconnect (rare, but handle)
            trace("in didDisconnectPeripheral, didDisconnect peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, deviceName ?? "'unknown'")
        }

        // One-shot, subclass-requested temporary rejection (e.g., pre-auth transient on G7/ONE+)
        if let requestedRejectionName = pendingTemporaryRejectionDeviceName {
            markDeviceNameAsTemporarilyRejected(requestedRejectionName)
            pendingTemporaryRejectionDeviceName = nil
        }

        // If this device name is under temporary rejection, do NOT auto-reconnect, resume scanning so we can discover other DX devices instead
        if let currentName = deviceName, isTemporarilyRejected(currentName) {
            trace("in didDisconnectPeripheral, skip auto-reconnect for %{public}@ (temporary rejection active), resuming scan", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, currentName)
            // Clear the peripheral reference so we do not request an OS-level reconnect to the same handle
            self.peripheral = nil
            self.deviceAddress = nil
            // Always re-enable default policy for future disconnects
            shouldReconnectOnNextDisconnect = true
            _ = startScanning()
            return
        }

        // Keep noisy reconnect intent at debug
        // if self.peripheral == nil, then a manual disconnect or something like that has occurred, no need to reconnect
        // otherwise disconnect occurred because of other (like out of range), so let's try to reconnect
        if shouldReconnectOnNextDisconnect, let ownPeripheral = self.peripheral {
            trace("in didDisconnectPeripheral, will try to reconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
            centralManager?.connect(ownPeripheral, options: connectOptions)
        } else {
            trace("in didDisconnectPeripheral, reconnect disabled for this disconnect or peripheral is nil, will not try to reconnect", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            _ = startScanning()
        }
        // Reset policy back to default (reconnect) after handling one disconnect
        shouldReconnectOnNextDisconnect = true
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("in didDiscoverServices, for peripheral with name %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, deviceName ?? "'unknown'")
        
        if let error = error {
            trace("in didDiscoverServices, didDiscoverServices error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error ,  "\(error.localizedDescription)")
        }
        
        if let services = peripheral.services {
            for service in services {
                trace("in didDiscoverServices, call discovercharacteristics for service with uuid %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, String(describing: service.uuid))
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            disconnect()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        trace("in didDiscoverCharacteristicsFor, for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, deviceName ?? "'unknown'", String(describing:service.uuid))
        
        if let error = error {
            trace("in didDiscoverCharacteristicsFor, error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("in didDiscoverCharacteristicsFor, characteristic: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, String(describing: characteristic.uuid))
                if (characteristic.uuid == CBUUID(string: CBUUID_WriteCharacteristic)) {
                    trace("in didDiscoverCharacteristicsFor, found writeCharacteristic", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
                    writeCharacteristic = characteristic
                } //don't use else because some devices have only one characteristic uuid for both transmit and receive
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    trace("in didDiscoverCharacteristicsFor, found receiveCharacteristic", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
                    receiveCharacteristic = characteristic
                    setNotifyValue(true, for: characteristic)
                }
            }
        } else {
            trace("in didDiscoverCharacteristicsFor, did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("in didWriteValueFor, characteristic %{public}@, error =  %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, String(describing: characteristic.uuid), error.localizedDescription)
        } else {
            trace("in didWriteValueFor, characteristic %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("in didUpdateNotificationStateFor, for peripheral with name %{public}@, characteristic %{public}@, error =  %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unkonwn'", String(describing: characteristic.uuid), error.localizedDescription)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        // trace the received value
        if let value = characteristic.value {
            trace("in didUpdateValueFor, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug, value.hexEncodedString())
        }
        
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("in didUpdateValueFor, for peripheral with name %{public}@, characteristic %{public}@, characteristic description %{public}@, error =  %{public}@, no further processing", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error, deviceName ?? "'unknown'", String(describing: characteristic.uuid), String(characteristic.debugDescription), error.localizedDescription)
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        trace("in willRestoreState", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
        
        // Attempt to reuse the restored peripheral (if any) without forcing a rescan.
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let restoredPeripheral = restoredPeripherals.first {
            
            // Re-attach references and delegates
            self.peripheral = restoredPeripheral
            self.deviceAddress = restoredPeripheral.identifier.uuidString
            self.deviceName = restoredPeripheral.name
            restoredPeripheral.delegate = self
            
            trace("didUpdateValueFor, restored peripheral %{public}@ (state = %{public}@)", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, restoredPeripheral.name ?? "'unknown'", restoredPeripheral.state.description())
            
            switch restoredPeripheral.state {
            case .connected:
                // On restore while connected, always rediscover services so subclasses can resubscribe ALL required characteristics (not just the cached receive one).
                trace("didUpdateValueFor, connected, rediscovering services for full resubscribe", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
                restoredPeripheral.discoverServices(self.servicesCBUUIDs)
            case .connecting:
                // Nothing to do. CoreBluetooth will finish the connection
                break
            default:
                // Reconnect restored peripheral to resume subscriptions after OS restore
                central.connect(restoredPeripheral, options: connectOptions)
            }
        }
    }
    
    // MARK: - helpers
    
    /// to ask transmitter that it initiates pairing
    ///
    /// to be overriden. For transmitter types that don't need pairing, or that don't need pairing initiated by user/view controller, this function does not need to be overriden
    func initiatePairing() { return }
    
    private func initialize() {
        // Prevent re-initialization when a central manager already exists for this instance.
        if centralManager != nil {
            trace("in initialize, centralManager already initialized for this instance, skipping re-init", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .debug)
            // Refresh handles to known peripherals if we already know the address
            if let centralManager = centralManager, let deviceAddress = deviceAddress, let uuid = UUID(uuidString: deviceAddress) {
                let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let reusedPeripheral = peripherals.first {
                    self.peripheral = reusedPeripheral
                    self.deviceName = reusedPeripheral.name
                }
            }
            return
        }
        
        // create centralManager with a CBCentralManagerOptionRestoreIdentifierKey. This to ensure that iOS relaunches the app whenever it's killed either due to a crash or due to lack of memory
        // iOS will restart the app as soon as a bluetooth transmitter tries to connect (which is under normal circumtances immediately)
        // the function willRestoreState (see below) is an empty function and that seems to be enough to make it work
        // see https://developer.apple.com/library/archive/qa/qa1962/_index.html
        //
        // the value used for CBCentralManagerOptionRestoreIdentifierKey depends :
        // - when scanning for a new device (or peripheral), use a random string. Disadvantage of using a random string is that willRestoreState doesn't get called when the app relaunches, because not the same value will be used (as it's a random string) - for this reason, we'll store this string in userdefaults (not shared, just local to this scope) and use when relaunching.
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
            trace("in initialize, restoreID created (stable from address): %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, cBCentralManagerOptionRestoreIdentifierKeyToUse!)
            
        } else {
            trace("in initialize, creating centralManager for new peripheral", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)
            
            // if it's a new device, then restore identifier key will contain random string. The application name is also in the identifier key
            let randomPart = String((0..<24).map{ _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!})
            
            cBCentralManagerOptionRestoreIdentifierKeyToUse = ConstantsHomeView.applicationName + "-" + randomPart
            
            trace("in initialize, restoreID created (random, no known address yet): %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, cBCentralManagerOptionRestoreIdentifierKeyToUse!)
        }
        
        // Create central manager on dedicated bt.central queue so all delegate callbacks arrive off the main thread
        centralManager = CBCentralManager(delegate: self, queue: centralQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true, CBCentralManagerOptionRestoreIdentifierKey: cBCentralManagerOptionRestoreIdentifierKeyToUse!])
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
