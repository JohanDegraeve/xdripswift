import Foundation
import CoreBluetooth
import os

class BluetoothPeripheral: NSObject {
    var mac: String?
    var peripheral: CBPeripheral?
}

/// generic bluetoothtransmitter class that handles scanning, connect, discover services, discover characteristics, subscribe to receive characteristic, reconnect.
///
/// The class assumes that the transmitter has a receive and transmit characterisitc (which is mostly the case)
class BluetoothTransmitter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - properties
    
    /// the BluetoothTransmitterDelegate
    public weak var bluetoothTransmitterDelegate:BluetoothTransmitterDelegate?
    
    /// the address of the transmitter. If nil then transmitter never connected, so we don't know the name.
    private var deviceAddress:String?
    /// the name of the transmitter. If nil then transmitter never connected, so we don't know the name
    private var deviceName:String?
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    private let CBUUID_Advertisement:String?
    
    /// services to be discovered
    private let servicesCBUUIDs:[CBUUID]?
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic:String
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic:String
    
    /// if true, then scanning can start automatically as soon as an instance of the BluetoothTransmitter is created. This is typical for eg Dexcom G5, where an individual transitter can be idenfied via the transmitter id. Also the case for Blucon. For MiaoMiao and G4 xdrip this is different.
    ///
    /// parameter needs to be set during initialisation
    private let startScanningAfterInit:Bool

    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBlueTooth)

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
    let maxTimeToWaitForPeripheralResponse = 5.0
    
    /// should the app try to reconnect after disconnect?
    private var reconnectAfterDisconnect:Bool = true

    // MARK: - Initialization
    
    /// - parameters:
    ///     -  addressAndName: if we never connected to a device, then we don't know it's address as the Device itself is going to send. We can only have an expectedName which is what needs to be added then in the argument
    ///         * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///         * For an xDrip or xBridge, we don't expect a specific devicename, in which case the value stays nil
    ///         * If we already connected to a device before, then we know it's address
    ///     - CBUUID_Advertisement: UUID to use for scanning, if nil  then app will scan for all devices. (Example Blucon, MiaoMiao, should be nil value. For G5 it should have a value. For xDrip it will probably work with or without. Main difference is that if no advertisement UUID is specified, then app is not allowed to scan will in background. For G5 this can create problem for first time connect, because G5 only transmits every 5 minutes, which means the app would need to stay in the foreground for at least 5 minutes.
    ///     - servicesCBUUIDs: service uuid's
    ///     - CBUUID_ReceiveCharacteristic: receive characteristic uuid
    ///     - CBUUID_WriteCharacteristic: write characteristic uuid
    init(addressAndName:BluetoothTransmitter.DeviceAddressAndName, CBUUID_Advertisement:String?, servicesCBUUIDs:[CBUUID], CBUUID_ReceiveCharacteristic:String, CBUUID_WriteCharacteristic:String, startScanningAfterInit:Bool) {
        switch addressAndName {
        case .alreadyConnectedBefore(let newAddress):
            deviceAddress = newAddress
        case .notYetConnected(let newexpectedName):
            expectedName = newexpectedName
        }
        
        //assign uuid's
        self.servicesCBUUIDs = servicesCBUUIDs
        self.CBUUID_Advertisement = CBUUID_Advertisement
        self.CBUUID_WriteCharacteristic = CBUUID_WriteCharacteristic
        self.CBUUID_ReceiveCharacteristic = CBUUID_ReceiveCharacteristic
        
        // assign startScanningAfterInit
        self.startScanningAfterInit = startScanningAfterInit
        
        //initialize timeStampLastStatusUpdate
        timeStampLastStatusUpdate = Date()
        
        super.init()

        initialize()
    }
    
    // MARK: - De-initialization
    
    deinit {
        // reconnect not necessary
        reconnectAfterDisconnect = false
        
        // disconnect the device
        disconnect()
    }
    
    // MARK: - public functions
    
    // gets peripheral connection status, nil if peripheral not existing yet
    func getConnectionStatus() -> CBPeripheralState? {
        return peripheral?.state
    }
    
    func stopScanning() {
        if let centralManager = centralManager {
            if centralManager.isScanning {
                centralManager.stopScan()
            }
        }
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            if let centralManager = centralManager {
                trace("disconnect, disconnecting", log: log, type: .info)
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    /// start bluetooth scanning for device
    func startScanning() -> BluetoothTransmitter.startScanningResult {
        trace("in startScanning", log: log, type: .info)
        
        //assign default returnvalue
        var returnValue = BluetoothTransmitter.startScanningResult.other(reason: "unknown")
        
        // first check if already connected or connecting and if so stop processing
        if let peripheral = peripheral {
            switch peripheral.state {
            case .connected:
                trace("    peripheral is already connected, will not start scanning", log: log, type: .info)
                return .alreadyConnected
            case .connecting:
                if Date() > Date(timeInterval: maxTimeToWaitForPeripheralResponse, since: timeStampLastStatusUpdate) {
                    trace("    status connecting, but waiting more than %{public}d seconds, will disconnect", log: log, type: .info, maxTimeToWaitForPeripheralResponse)
                    disconnect()
                } else {
                    trace("    peripheral is currently connecting, will not start scanning", log: log, type: .info)
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
                trace("    already scanning", log: log, type: .info)
                return .alreadyScanning
            }
            switch centralManager.state {
            case .poweredOn:
                trace("    starting bluetooth scanning", log: log, type: .info)
                centralManager.scanForPeripherals(withServices: services, options: nil)
                returnValue = .success
            default:
                trace("    bluetooth is not powered on, actual state is %{public}@", log: log, type: .info, "\(centralManager.state.toString())")
                returnValue = .bluetoothNotPoweredOn(actualStateIs: centralManager.state.toString())
            }
        } else {
            trace("    centralManager is nil, can not starting scanning", log: log, type: .error)
            returnValue = .other(reason:"centralManager is nil, can not start scanning")
        }
        
        return returnValue
    }
    
    /// will write to writeCharacteristic with UUID CBUUID_WriteCharacteristic
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType)  -> Bool {
        if let peripheral = peripheral, let writeCharacteristic = writeCharacteristic {
            trace("in writeDataToPeripheral", log: log, type: .info)
            peripheral.writeValue(data, for: writeCharacteristic, type: type)
            return true
        } else {
            trace("in writeDataToPeripheral, failed because either peripheral or writeCharacteristic is nil", log: log, type: .error)
            return false
        }
    }

    /// will write to characteristicToWriteTo
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, characteristicToWriteTo:CBCharacteristic, type:CBCharacteristicWriteType)  -> Bool {
        if let peripheral = peripheral {
            trace("in writeDataToPeripheral for characteristic %{public}@", log: log, type: .info, characteristicToWriteTo.uuid.description)
            peripheral.writeValue(data, for: characteristicToWriteTo, type: type)
            return true
        } else {
            trace("in writeDataToPeripheral, failed because either peripheral or characteristicToWriteTo is nil", log: log, type: .error)
            return false
        }
    }
    
    /// calls setNotifyValue for characteristic with value enabled
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        if let peripheral = peripheral {
            trace("setNotifyValue, setting notify for characteristic %{public}@, to %{public}@", log: log, type: .info, characteristic.uuid.uuidString, enabled.description)
          peripheral.setNotifyValue(enabled, for: characteristic)
        } else {
            trace("setNotifyValue, failed to set notify for characteristic %{public}@, to %{public}@", log: log, type: .error, characteristic.uuid.uuidString, enabled.description)
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        disconnect()
        stopScanAndconnect(to: peripheral)
    }
    
    // MARK: - fileprivate functions
    
    /// stops scanning and connects. To be called after didiscover
    fileprivate func stopScanAndconnect(to peripheral: CBPeripheral) {
        
        self.centralManager?.stopScan()
        self.deviceAddress = peripheral.identifier.uuidString
        self.deviceName = peripheral.name
        peripheral.delegate = self
        self.peripheral = peripheral
        
        //in Spike a check is done to see if state is disconnected, this is code from the MiaoMiao developers, not sure if this is needed or not because normally the device should be disconnected
        trace("in stopScanAndconnect, status = %{public}@", log: log, type: .info, peripheral.state.description())
        if peripheral.state == .disconnected {
            trace("    trying to connect", log: log, type: .info)
            centralManager?.connect(peripheral, options: nil)
        } else {
            if let newCentralManager = centralManager {
                trace("    calling centralManager(newCentralManager, didConnect: peripheral", log: log, type: .info)
                centralManager(newCentralManager, didConnect: peripheral)
            }
        }
    }
    
    /// try to connect to peripheral to which connection was successfully done previously, and that has a uuid that matches the stored deviceAddress. If such peripheral exists, then try to connect, it's not necessary to start scanning. iOS will connect as soon as the peripheral comes in range, or bluetooth status is switched on, whatever is necessary
    ///
    /// the result of the attempt to try to find such device, is returned
    fileprivate func retrievePeripherals(_ central:CBCentralManager) -> Bool {
        if let deviceAddress = deviceAddress {
            debuglogging("in retrievePeripherals, deviceaddress is not nil")
            if let uuid = UUID(uuidString: deviceAddress) {
                debuglogging("    in retrievePeripherals, uuid is not nil")
                var peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
                if peripheralArr.count > 0 {
                    peripheral = peripheralArr[0]
                    if let peripheral = peripheral {
                        debuglogging("    in retrievePeripherals, peripheral is not nil")
                        trace("in retrievePeripherals, trying to connect", log: log, type: .info)
                        peripheral.delegate = self
                        central.connect(peripheral, options: nil)
                        return true
                    } else {
                        debuglogging("    in retrievePeripherals, peripheral isfstart nil")
                    }
                }
            } else {
                debuglogging("    in retrievePeripherals, uuid is nil")
            }
        }
        return false
    }
    
    // MARK: - methods from protocols CBCentralManagerDelegate, CBPeripheralDelegate
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        timeStampLastStatusUpdate = Date()
        /// for bubble
        if expectedName == "Bubble" {
            if peripheral.name == expectedName {
                if let data = advertisementData["kCBAdvDataManufacturerData"] as? Data {
                    var mac = ""
                    for i in 0 ..< 6 {
                        mac += data.subdata(in: (7 - i)..<(8 - i)).hexEncodedString().uppercased()
                        if i != 5 {
                            mac += ":"
                        }
                    }
                    let bubblePeripheral = BluetoothPeripheral()
                    bubblePeripheral.mac = "Bubble:" + mac
                    bubblePeripheral.peripheral = peripheral
                    bluetoothTransmitterDelegate?.centralManagerDidDiscover(peripheral: bubblePeripheral)
                }
            }
        } else {
            // devicename needed unwrapped for logging
            var deviceName = "unknown"
            if let temp = peripheral.name {
                deviceName = temp
            }
            trace("Did discover peripheral with name: %{public}@", log: log, type: .info, String(describing: deviceName))
            
            // check if stored address not nil, in which case we already connected before and we expect a full match with the already known device name
            if let deviceAddress = deviceAddress {
                if peripheral.identifier.uuidString == deviceAddress {
                    trace("    stored address matches peripheral address, will try to connect", log: log, type: .info)
                    stopScanAndconnect(to: peripheral)
                }
            } else {
                //the app never connected before to our device
                // do we expect a specific device name ?
                if let expectedName = expectedName {
                    // so it's a new device, we need to see if it matches the specifically expected device name
                    if (peripheral.name?.range(of: expectedName, options: .caseInsensitive)) != nil {
                        // peripheral.name is not nil and contains expectedName
                        trace("    new peripheral has expected device name, will try to connect", log: log, type: .info)
                        stopScanAndconnect(to: peripheral)
                    } else {
                        // peripheral.name is nil or does not contain expectedName
                        trace("    new peripheral doesn't have device name as expected, ignoring", log: log, type: .info)
                    }
                } else {
                    // we don't expect any specific device name, so let's connect
                    trace("    new peripheral, will try to connect", log: log, type: .info)
                    stopScanAndconnect(to: peripheral)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        timeStampLastStatusUpdate = Date()
        
        trace("connected, will discover services", log: log, type: .info)
        peripheral.discoverServices(servicesCBUUIDs)
        
        bluetoothTransmitterDelegate?.centralManagerDidConnect(address: deviceAddress, name: deviceName)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("failed to connect with error: %{public}@, will try again", log: log, type: .error , error.localizedDescription)
        } else {
            trace("failed to connect, will try again", log: log, type: .error)
        }
        
        centralManager?.connect(peripheral, options: nil)
        
        bluetoothTransmitterDelegate?.centralManagerDidFailToConnect(error: error)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        timeStampLastStatusUpdate = Date()
        
        trace("in centralManagerDidUpdateState, new state is %{public}@", log: log, type: .info, "\(central.state.toString())")

        /// in case status changed to powered on and if device address known then try either to retrieveperipherals, or if that doesn't succeed, start scanning
        if central.state == .poweredOn, reconnectAfterDisconnect {
            if (deviceAddress != nil) {
                /// try to connect to device to which connection was successfully done previously, this attempt is done by callling retrievePeripherals(central) - if that fails and if it's a device for which we can always scan (eg DexcomG5), then start scanning
                if !retrievePeripherals(central) && startScanningAfterInit {
                    _ = startScanning()
                }
            }
        }
        
        bluetoothTransmitterDelegate?.centralManagerDidUpdateState(state: central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("Did disconnect peripheral with error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        // check if automatic reconnect is needed or not
        if !reconnectAfterDisconnect {
            trace("reconnectAfterDisconnect is false, will not try to reconnect", log: log, type: .info)
        }
        
        // if self.peripheral == nil, then a manual disconnect or something like that has occured, no need to reconnect
        // otherwise disconnect occurred because of other (like out of range), so let's try to reconnect
        if let ownPeripheral = self.peripheral {
            trace("    Will try to connect", log: log, type: .info)
            centralManager?.connect(ownPeripheral, options: nil)
        } else {
            trace("    peripheral is nil, will not try to connect", log: log, type: .info)
        }
        
        bluetoothTransmitterDelegate?.centralManagerDidDisconnectPeripheral(error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        trace("didDiscoverServices", log: log, type: .info)
        if let error = error {
            trace("    didDiscoverServices error: %{public}@", log: log, type: .error ,  "\(error.localizedDescription)")
        }
        
        if let services = peripheral.services {
            for service in services {
                trace("    Call discovercharacteristics for service with uuid %{public}@", log: log, type: .info, String(describing: service.uuid))
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            disconnect()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        trace("didDiscoverCharacteristicsFor for service with uuid %{public}@", log: log, type: .info, String(describing:service.uuid))
        
        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("    characteristic: %{public}@", log: log, type: .info, String(describing: characteristic.uuid))
                if (characteristic.uuid == CBUUID(string: CBUUID_WriteCharacteristic)) {
                    trace("    found writeCharacteristic", log: log, type: .info)
                    writeCharacteristic = characteristic
                } //don't use else because some devices have only one characteristic uuid for both transmit and receive
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    trace("    found receiveCharacteristic", log: log, type: .info)
                    receiveCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("didWriteValueFor characteristic %{public}@, characteristic description %{public}@, error =  %{public}@", log: log, type: .error, String(describing: characteristic.uuid), String(characteristic.debugDescription), error.localizedDescription)
        } else {
            trace("didWriteValueFor characteristic %{public}@, characteristic description %{public}@", log: log, type: .info, String(describing: characteristic.uuid), String(characteristic.debugDescription))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("didUpdateNotificationStateFor characteristic %{public}@, characteristic description %{public}@, error =  %{public}@", log: log, type: .error, String(describing: characteristic.uuid), String(characteristic.debugDescription), error.localizedDescription)
        }
        
        // call delegate
        bluetoothTransmitterDelegate?.peripheralDidUpdateNotificationStateFor(characteristic: characteristic, error: error)
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        timeStampLastStatusUpdate = Date()
        
        if let error = error {
            trace("didUpdateValueFor characteristic %{public}@, characteristic description %{public}@, error =  %{public}@, no further processing", log: log, type: .error, String(describing: characteristic.uuid), String(characteristic.debugDescription), error.localizedDescription)
        } else {
            bluetoothTransmitterDelegate?.peripheralDidUpdateValueFor(characteristic: characteristic, error: error)
        }
    }
    
    // MARK: methods to get address and name
    
    /// read device address
    func address() -> String? {
        return deviceAddress
    }
    
    /// read device name
    func name() -> String? {
        return deviceName
    }
    
    // MARK: - helpers
    
    private func initialize() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // MARK: - enum's
    
    /// result of call to startscanning
    enum startScanningResult {
        //scanning started successfully
        case success
        // was already scanning, can be considred as successful
        case alreadyScanning
        // scanning ot started because bluetooth is not powered on, actual state of centralmanger is in response
        case bluetoothNotPoweredOn(actualStateIs:String)
        // in case peripheral is currently connected then it makes no sense to start scanning
        case alreadyConnected
        // peripheral is currently connecting, it makes no sense to start scanning
        case connecting
        // any other, reason specified in text
        case other(reason:String)
        
        func description() -> String {
            switch self {
                
            case .success:
                return "success"
            case .alreadyScanning:
                return "alreadyScanning"
            case .bluetoothNotPoweredOn(let actualState):
                return "not powered on, actual status =" + actualState
            case .alreadyConnected:
                return "alreadyConnected"
            case .connecting:
                return "connecting"
            case .other(let reason):
                return "other reason : " + reason
            }
        }
    }
    
    /// * if we never connected to a device, then we don't know it's address as the Device itself is going to send. We can only have an expected name,
    ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    /// * If we already connected to a device before, then we know it's address
    enum DeviceAddressAndName {
        /// we already connected to the device so we should know the address
        case alreadyConnectedBefore (address:String)
        /// * We never connected to the device, so we don't know it's name and address as the Device itself is going to send. We can only have an expected name,
        ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
        ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
        case notYetConnected (expectedName:String?)
    }
}



