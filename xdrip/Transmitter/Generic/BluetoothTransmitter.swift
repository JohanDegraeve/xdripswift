import Foundation
import CoreBluetooth
import os

/// generic class for bluetooth transmitter.
/// For new transmitters, extend BluetoothTransmitter and implement the protocol BluetoothTransmitterDelegate
///
/// class BluetoothTransmitter implements the protocols CBCentralManagerDelegate, CBPeripheralDelegate
///
/// some of those functions might still need override/re-implementation in the deriving specific class
///
/// the protocol BluetoothTransmitterDelegate handles events that need to be treated differently dependent on device type, eg data that is received from the transmitter
class BluetoothTransmitter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - properties
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    let CBUUID_Advertisement:String
    /// service to be discovered
    let CBUUID_Service:String
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic:String
    /// write characteristic
    let CBUUID_WriteCharacteristic:String

    /// the address of the transmitter. If nil then transmitter never connected, so we don't know the name.
    public private(set) var address:String?
    /// the name of the transmitter. If nil then transmitter never connected, so we don't know the name
    public private(set) var name:String?
    
    // for OS_log,
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryBlueTooth)

    /// centralManager
    private var centralManager: CBCentralManager?
    
    /// peripheral, gets value during connect
    private var peripheral: CBPeripheral?
    
    /// will be used to pass back bluetooth events to classes that inherit from BluetoothTransmitter
    ///
    /// not to be used by any other class than the classes that inherit from BluetoothTransmitter
    var blueToothTransmitterDelegate:BluetoothTransmitterDelegate?
    
    /// if never connected before to the device, then possibily we expect a specific device name. For example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF. For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    /// the value is only used during first time connection to a new device. Once we've connected at least once, we know the final name (eg xBridge) and will store this name in the name attribute, the expectedName value can then be ignored
    private var expectedName:String?
    
    private var writeCharacteristic:CBCharacteristic?
    
    private var receiveCharacteristic:CBCharacteristic?

    // MARK: - Initialization
    
    /// - parameters:
    ///     -  addressAndName: if we never connected to a device, then we don't know it's name and address as the Device itself is going to send. We can only have an expectedName which is what needs to be added then in the argument
    ///         * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///         * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    ///         * If we already connected to a device before, then we know it's name and address
    ///     - CBUUID_Advertisement: UUID to use for scanning, if empty string then app will scan for all devices. (Example Blucon, MiaoMiao, should be empty string. For G5 it should have a value. For xDrip it will probably work with or without. Main difference is that if no advertisement UUID is specified, then app is not allowed to scan will in background. For G5 this can create problem for first time connect, because G5 only transmits every 5 minutes, which means the app would need to stay in the foreground for at least 5 minutes.
    ///     - CBUUID_Service: service uuid
    ///     - CBUUID_ReceiveCharacteristic: receive characteristic uuid
    ///     - CBUUID_WriteCharacteristic: write characteristic uuid
    init(addressAndName:BluetoothTransmitter.DeviceAddressAndName, CBUUID_Advertisement:String, CBUUID_Service:String, CBUUID_ReceiveCharacteristic:String, CBUUID_WriteCharacteristic:String) {
        
        switch addressAndName {
        case .alreadyConnectedBefore(let newAddress, let newName):
            address = newAddress
            name = newName
        case .notYetConnected(let newexpectedName):
            expectedName = newexpectedName
        }

        //assign uuid's
        self.CBUUID_Service = CBUUID_Service
        self.CBUUID_Advertisement = CBUUID_Advertisement
        self.CBUUID_WriteCharacteristic = CBUUID_WriteCharacteristic
        self.CBUUID_ReceiveCharacteristic = CBUUID_ReceiveCharacteristic
        
        super.init()

        initialize()
    }
    
    // MARK: - public functions
    
    /// will disconnect the device, if connected
    func disconnect() {
        if let newCentralManager = centralManager {
            if let peripheral = peripheral {
                os_log("in disconnect, disconnecting")
                newCentralManager.cancelPeripheralConnection(peripheral)
            } else {
                os_log("in disconnect, but peripheral is nil", log: log, type: .info)
            }
        } else {
            os_log("in disconnect, but centralManager is nil", log: log, type: .info)
        }
    }
    
    /// start bluetooth scanning for device
    func startScanning() -> BluetoothTransmitter.startScanningResult {
        os_log("in startScanning", log: log, type: .info)
        
        //assign default returnvalue
        var returnValue = BluetoothTransmitter.startScanningResult.Other(reason: "unknown")
        
        // first check if already connected and if so stop processing
        if let peripheral = peripheral {
            if peripheral.state == .connected {
                os_log("peripheral is already connected, will not start scanning", log: log, type: .info)
                return .AlreadyConnected
            }
        } else if let peripheral = peripheral {
            if peripheral.state == .connecting {
                os_log("peripheral is currently connecting, will not start scanning", log: log, type: .info)
                return .Connecting
            }
        }
        
        ///ist of uuid's to scan for, possibily nil, in which case scanning only if app is in foreground and scan for all devices
        var services:[CBUUID]?
        if CBUUID_Advertisement.count > 0 {
            services = [CBUUID(string: CBUUID_Advertisement)]
        }
        
        // try to start the scanning
        if let centralManager = centralManager {
            switch centralManager.state {
            case .poweredOn:
                if centralManager.isScanning {
                    os_log("already scanning", log: log, type: .info)
                    returnValue = .AlreadyScanning
                } else {
                    os_log("starting bluetooth scanning", log: log, type: .info)
                    centralManager.scanForPeripherals(withServices: services, options: nil)
                    returnValue = .Success
                }
            default:
                os_log("bluetooth is not powered on, actual state is %{public}@", log: log, type: .info, "\(centralManager.state.toString())")
                returnValue = .BluetoothNotPoweredOn(actualStateIs: centralManager.state.toString())
            }
        } else {
            os_log("centralManager is nil, can not start scanning", log: log, type: .error)
            returnValue = .Other(reason:"centralManager is nil, can not start scanning")
        }
        
        return returnValue
    }
    
    /// - returns: true if writeValue was successfully called, doesn't necessarily mean data is successvully written to peripheral
    func writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType)  -> Bool {
        if let peripheral = peripheral, let writeCharacteristic = writeCharacteristic {
            os_log("in writeDataToPeripheral", log: log, type: .info)
            peripheral.writeValue(data, for: writeCharacteristic, type: type)
            return true
        } else {
            os_log("in writeDataToPeripheral, failed because either peripheral or writeCharacteristic is nil", log: log, type: .error)
            return false
        }
    }

    // MARK: - fileprivate functions
    
    /// stops scanning and connects. To be called after didiscover
    fileprivate func stopScanAndconnect(to peripheral: CBPeripheral) {
        
        self.centralManager?.stopScan()
        self.address = peripheral.identifier.uuidString
        self.name = peripheral.name
        peripheral.delegate = self
        self.peripheral = peripheral
        
        //in Spike a check is done to see if state is disconnected, this is code from the MiaoMiao developers, not sure if this is needed or not because normally the device should be disconnected
        if peripheral.state == .disconnected {
            os_log("trying to connect", log: log, type: .info)
            centralManager?.connect(peripheral, options: nil)
        } else {
            if let newCentralManager = centralManager {
                os_log("calling centralManager(newCentralManager, didConnect: peripheral", log: log, type: .info)
                centralManager(newCentralManager, didConnect: peripheral)
            }
        }
    }
    
    fileprivate func retrievePeripherals(_ central:CBCentralManager) -> Bool {
        if let address = address {
            let uuid =  UUID(uuidString: address)
            if let uuid = uuid {
                var peripheralArr = central.retrievePeripherals(withIdentifiers: [uuid])
                if peripheralArr.count > 0 {
                    peripheral = peripheralArr[0]
                    if let peripheral = peripheral {
                        os_log("in retrievePeripherals, trying to connect", log: log, type: .info)
                        peripheral.delegate = self
                        central.connect(peripheral, options: nil)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // MARK: - methods from protocols CBCentralManagerDelegate, CBPeripheralDelegate
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // devicename needed unwrapped for logging
        var deviceName = "unknown"
        if let temp = peripheral.name {
            deviceName = temp
        }
        os_log("Did discover peripheral with name: %{public}@", log: log, type: .info, String(describing: deviceName))
        
        // check if stored address not nil, in which case we already connected before and we expect a full match with the already known device name
        if let address = address {
            if peripheral.identifier.uuidString == address {
                os_log("stored address matches peripheral address, will try to connect", log: log, type: .info)
                stopScanAndconnect(to: peripheral)
            }
        } else {
            //the app never connected before to our device
            // do we expect a specific device name ?
            if let expectedName = expectedName {
                // so it's a new device, we need to see if it matches the specifically expected device name
                if (peripheral.name?.range(of: expectedName, options: .caseInsensitive)) != nil {
                    // peripheral.name is not nil and contains expectedName
                    os_log("new peripheral has expected device name, will try to connect", log: log, type: .info)
                    stopScanAndconnect(to: peripheral)
                } else {
                    // peripheral.name is nil or does not contain expectedName
                    os_log("new peripheral doesn't have device name as expected, ignoring", log: log, type: .info)
                }
            } else {
                // we don't expect any specific device name, so let's connect
                os_log("new peripheral, will try to connect", log: log, type: .info)
                stopScanAndconnect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("connected, will discover services", log: log, type: .info)
        
        var services:[CBUUID]?
        if CBUUID_Service.count > 0 {
            services = [CBUUID(string: CBUUID_Service)]
        }
        
        peripheral.discoverServices(services)
        
        blueToothTransmitterDelegate?.centralManagerD(central, didConnect: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if let error = error {
            os_log("failed to connect with error: %{public}@, will try again", log: log, type: .error ,  "\(error.localizedDescription)")
        } else {
            os_log("failed to connect, will try again", log: log, type: .error)
        }
        
        centralManager?.connect(peripheral, options: nil)
    }

    /// if new state is powered on and if address is known then try to retrieveperipherals, if that fails start scanning
    /// also calls delegate.centralManagerDidUpdateStateD in the end
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        os_log("in centralManagerDidUpdateState, new state is %{public}@", log: log, type: .info, "\(central.state.toString())")

        /// in case status changed to powered on and if device address known then try either to retrieveperipherals, or if that doesn't succeed, start scanning
        if central.state == .poweredOn {
            if (address != nil) {
                if !retrievePeripherals(central) {
                    _ = startScanning()
                }
            }
        }
        
        // also inform the delegate
        blueToothTransmitterDelegate?.centralManagerDidUpdateStateD(central)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            os_log("Did disconnect peripheral error: %{public}@", log: log, type: .error ,  "\(error.localizedDescription)")
        }
        
        // if self.peripheral == nil, then a manual disconnect or something like that has occured, no need to reconnect
        // otherwise disconnect occurred because of other (like out of range), so let's try to reconnect
        if let ownPeripheral = self.peripheral {
            os_log("Will try to connect", log: log, type: .info)
            centralManager?.connect(ownPeripheral, options: nil)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        os_log("Did discover services", log: log, type: .info)
        if let error = error {
            os_log("Did discover services error: %{public}@", log: log, type: .error ,  "\(error.localizedDescription)")
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                os_log("Call discovercharacteristics for service with uuid %{public}@", log: log, type: .info, String(describing: service.uuid))
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        os_log("Did discover characteristics", log: log, type: .info)
        if let error = error {
            os_log("Did discover characteristics error: %{public}@", log: log, type: .error ,  "\(error.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                os_log("characteristic: %{public}@", log: log, type: .info, String(describing: characteristic.uuid))
                if characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic) {
                    os_log("found receiveCharacteristic", log: log, type: .info)
                    receiveCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if (characteristic.uuid == CBUUID(string: CBUUID_WriteCharacteristic)) {
                    os_log("found writeCharacteristic", log: log, type: .info)
                    writeCharacteristic = characteristic
                }
            }
        } else {
            os_log("Did discover characteristics, but no characteristics listed. There must be some error.", log: log, type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("Did Write value %{public}@ for characteristic %{public}@", log: log, type: .info, String(describing: characteristic.uuid), String(characteristic.debugDescription))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        //send to delegate because it needs specific action depending on type of device
        blueToothTransmitterDelegate?.peripheralD(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        blueToothTransmitterDelegate?.peripheralD(peripheral, didUpdateValueFor: characteristic, error: error)
    }
    
    // MARK: - helpers
    
    private func initialize() {
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // MARK: - enum's
    
    /// distinguish types of transmitter : miaomiao, blucon, dexcomG5, ...
    enum TransmitterType {
        case DexcomxDripG4
        case DexcomG5
        case DexcomG6
        case Blucon
        case MiaoMiao
    }
    
    /// result of call to startscanning
    enum startScanningResult {
        //scanning started successfully
        case Success
        // was already scanning, can be considred as successful
        case AlreadyScanning
        // scanning ot started because bluetooth is not powered on, actual state of centralmanger is in response
        case BluetoothNotPoweredOn(actualStateIs:String)
        // in case peripheral is currently connected then it makes no sense to start scanning
        case AlreadyConnected
        // peripheral is currently connecting, it makes no sense to start scanning
        case Connecting
        // any other, reason specified in text
        case Other(reason:String)
    }
    
    /// * if we never connected to a device, then we don't know it's name and address as the Device itself is going to send. We can only have an expected name,
    ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
    ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
    /// * If we already connected to a device before, then we know it's name and address
    enum DeviceAddressAndName {
        /// we already connected to the device so we should know the address and name as used by the device
        case alreadyConnectedBefore (address:String, name:String)
        /// * We never connected to the device, so we don't know it's name and address as the Device itself is going to send. We can only have an expected name,
        ///     * example for G5, if transmitter id is ABCDEF, we expect as devicename DexcomEF.
        ///     * For an xDrip bridge, we don't expect a specific devicename, in which case the value stays nil
        case notYetConnected (expectedName:String?)
    }
}



