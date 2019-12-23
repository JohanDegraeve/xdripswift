import Foundation
import os
import CoreBluetooth
import CoreData

class BluetoothPeripheralManager: NSObject {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralManager)
    
    /// dictionary with key = an instance of BluetoothPeripheral, and value an instance of BluetoothTransmitter. Value can be nil in which case we found a BluetoothPeripheral in the coredata but shouldconnect == false so we don't instanstiate a BluetoothTransmitter
    //private var m5StacksBlueToothTransmitters = [BluetoothPeripheral : BluetoothTransmitter?]()
    
    /// all currently known BluetoothPeripheral's (MStacks, cgmtransmitters, watlaa , ...)
    private var bluetoothPeripherals: [BluetoothPeripheral] = []
    
    /// the bluetoothTransmitter's, array must have the same size as bluetoothPeripherals. For each element in bluetoothPeripherals, there's an element at the same index in bluetoothTransmitters, which may be nil. nil value means user selected not to connect
    private var bluetoothTransmitters: [BluetoothTransmitter?] = []
    
    /// to access m5Stack entity in coredata
    private var m5StackAccessor: M5StackAccessor
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// if scan is called, and a connection is successfully made to a new device, then a new M5Stack must be created, and this function will be called. It is owned by the UIViewController that calls the scan function
    private var callBackAfterDiscoveringDevice: ((BluetoothPeripheral) -> Void)?
    
    /// if scan is called, an instance of M5StackBluetoothTransmitter is created with address and name. The new instance will be assigned to this variable, temporary, until a connection is made
    private var tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral: BluetoothTransmitter?
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()

    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        
        // initialize properties
        self.coreDataManager = coreDataManager
        self.m5StackAccessor = M5StackAccessor(coreDataManager: coreDataManager)
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        super.init()
        
        // initialize m5Stacks
        let m5Stacks = m5StackAccessor.getM5Stacks()
        for m5Stack in m5Stacks {
            
            // add it to the list of bluetoothPeripherals
            bluetoothPeripherals.append(m5Stack)
            
            if m5Stack.shouldconnect {
                
                // create an instance of M5StackBluetoothTransmitter, M5StackBluetoothTransmitter will automatically try to connect to the M5Stack with the address that is stored in m5Stack
                // add it to the array of bluetoothTransmitters
                bluetoothTransmitters.append(M5StackBluetoothTransmitter(address: m5Stack.address, name: m5Stack.name, delegate: self, blePassword: m5Stack.blepassword, bluetoothPeripheralType: m5Stack.isM5StickC ? .M5StickCType : .M5StackType))
                
            } else {
                
                // shouldn't connect, so don't create an instance of M5StackBluetoothTransmitter
                // but append a nil element
                bluetoothTransmitters.append(nil)
                
            }
            
            // each time the app launches, we will send the parameters to all BluetoothPeripherals
            m5Stack.parameterUpdateNeededAtNextConnect()
            
        }
        
        // when user changes M5Stack related settings, then the transmitter need to get that info
        addObservers()

    }
    
    // MARK: - public functions
    
    /// will send latest reading to all BluetoothTransmitters that need this info and only if it's less than 5 minutes old
    /// - parameters:
    ///     - to :if nil then latest reading will be sent to all connected BluetoothTransmitters that need this info, otherwise only to the specified BluetoothTransmitter
    ///
    /// this function has knowledge about different types of BluetoothTransmitter and knows to which it should send to reading, to which not
    public func sendLatestReading(to toBluetoothPeripheral: BluetoothPeripheral? = nil) {
        
        // get reading of latest 5 minutes
        let bgReadingToSend = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: Date(timeIntervalSinceNow: -5 * 60), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // check that there's at least 1 reading available
        guard bgReadingToSend.count >= 1 else {
            trace("in sendLatestReading, there's no recent reading to send", log: self.log, type: .info)
            return
        }

        // loop through all bluetoothPeripherals
        for bluetoothPeripheral in bluetoothPeripherals {
            
            // if parameter toBluetoothPeripheral is not nil, then it means we need to send the reading only to this bluetoothPeripheral, so we skip all peripherals except that one
            if toBluetoothPeripheral != nil && toBluetoothPeripheral!.getAddress() != bluetoothPeripheral.getAddress() {
                continue
            }
            
            // find the index of the bluetoothPeripheral in bluetoothPeripherals array
            if let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral), let bluetoothTransmitter = bluetoothTransmitters[index]  {

                // get type of bluetoothPeripheral
                let bluetoothPeripheralType = bluetoothPeripheral.bluetoothPeripheralType()
                
                // using bluetoothPeripheralType here so that whenever bluetoothPeripheralType is extended with new cases, we don't forget to handle them
                switch bluetoothPeripheralType {
                    
                case .M5StackType, .M5StickCType:
                    
                    if let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
                        _ = m5StackBluetoothTransmitter.writeBgReadingInfo(bgReading: bgReadingToSend[0])
                    }
                    
                }

            }
   
        }
    }

    // MARK: - private functions
    
    /// when user changes M5Stack related settings, then the transmitter need to get that info, add observers
    private func addObservers() {
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiName1.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiName2.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiName3.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiPassword1.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiPassword2.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackWiFiPassword3.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.m5StackBlePassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutAPIKey.rawValue, options: .new, context: nil)


    }
    
    /// disconnect from bluetoothPeripheral - and don't reconnect - set shouldconnect to false
    private func disconnect(fromBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        // device should not reconnect after disconnecting
        bluetoothPeripheral.dontTryToConnectToThisBluetoothPeripheral()
        
        // save in coredata
        coreDataManager.saveChanges()
        
        if let bluetoothTransmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            bluetoothTransmitter.disconnect(reconnectAfterDisconnect: false)
            
        }
        
    }
    
    private func firstIndexInBluetoothPeripherals(bluetoothPeripheral: BluetoothPeripheral) -> Int? {
        return bluetoothPeripherals.firstIndex(where: {$0.getAddress() == bluetoothPeripheral.getAddress()})
    }
    
    private func createNewTransmitter(type: BluetoothPeripheralType) -> BluetoothTransmitter {
        
        switch type {
            
        case .M5StackType, .M5StickCType:
            
            return M5StackBluetoothTransmitter(address: nil, name: nil, delegate: self, blePassword: UserDefaults.standard.m5StackBlePassword, bluetoothPeripheralType: type)
            
        }

    }
    
    private func getTransmitterType(for bluetoothTransmitter:BluetoothTransmitter) -> BluetoothPeripheralType {
        
        for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
            
            // using switch through all cases, to make sure that new future types are supported
            switch bluetoothPeripheralType {
                
            case .M5StackType, .M5StickCType:
                
                if let bluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
                    return bluetoothTransmitter.bluetoothPeripheralType
                }
                
            }
            
        }
        
        // normally we shouldn't get here, but we need to return a value
        fatalError("BluetoothPeripheralManager :  getTransmitterType did not find a valid type")
        
    }
    
    // MARK:- override observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        guard let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else {return}
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnum {
            
        case UserDefaults.Key.m5StackWiFiName1, UserDefaults.Key.m5StackWiFiName2, UserDefaults.Key.m5StackWiFiName3, UserDefaults.Key.m5StackWiFiPassword1, UserDefaults.Key.m5StackWiFiPassword2, UserDefaults.Key.m5StackWiFiPassword3, UserDefaults.Key.nightScoutAPIKey, UserDefaults.Key.nightScoutUrl, UserDefaults.Key.bloodGlucoseUnitIsMgDl  :
            
            // transmittertype change triggered by user, should not be done within 200 ms
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        default:
            break
        }
        
        for bluetoothPeripheral in bluetoothPeripherals {
            
            // if the there's no bluetoothTransmitter for this bluetoothPeripheral, then call parameterUpdateNeededAtNextConnect
            guard let bluetoothTransmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) else {

                // seems to be bluetoothPeripheral which is currently disconnected - need to set parameterUpdateNeeded = true, so that all parameters will be sent as soon as reconnect occurs
                bluetoothPeripheral.parameterUpdateNeededAtNextConnect()
                
                return

            }
            
            // get the type
            switch bluetoothPeripheral.bluetoothPeripheralType() {
                
            case .M5StackType, .M5StickCType:
                
                guard let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter else {
                    trace("in observeValue, bluetoothPeripheral is of type M5Stack but bluetoothTransmitter is not M5StackBluetoothTransmitter", log: self.log, type: .error)
                    return
                }
                
                // check that bluetoothPeripheral is of type M5Stack, if not then this might be a coding error
                guard let m5Stack = bluetoothPeripheral as? M5Stack else {
                    trace("in observeValue, transmitter is of type M5StackBluetoothTransmitter but peripheral is not M5Stack", log: self.log, type: .error)
                    return
                }
                
                // is value successfully written or not
                var success = false
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.m5StackWiFiName1:
                    success = m5StackBluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName1, number: 1)
                    
                case UserDefaults.Key.m5StackWiFiName2:
                    success = m5StackBluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName2, number: 2)
                    
                case UserDefaults.Key.m5StackWiFiName3:
                    success = m5StackBluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName3, number: 3)
                    
                case UserDefaults.Key.m5StackWiFiPassword1:
                    success = m5StackBluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword1, number: 1)
                    
                case UserDefaults.Key.m5StackWiFiPassword2:
                    success = m5StackBluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword2, number: 2)
                    
                case UserDefaults.Key.m5StackWiFiPassword3:
                    success = m5StackBluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword3, number: 3)
                    
                case UserDefaults.Key.m5StackBlePassword:
                    // only if the password in the settings is not nil, and if the m5Stack doesn't have a password yet, then we will store it in the M5Stack.
                    if let blePassword = UserDefaults.standard.m5StackBlePassword, m5Stack.blepassword == nil {
                        m5Stack.blepassword = blePassword
                    }
                    
                case UserDefaults.Key.bloodGlucoseUnitIsMgDl:
                    success = m5StackBluetoothTransmitter.writeBloodGlucoseUnit(isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    
                case UserDefaults.Key.nightScoutAPIKey:
                    success = m5StackBluetoothTransmitter.writeNightScoutAPIKey(apiKey: UserDefaults.standard.nightScoutAPIKey)
                    
                case UserDefaults.Key.nightScoutUrl:
                    success = m5StackBluetoothTransmitter.writeNightScoutUrl(url: UserDefaults.standard.nightScoutUrl)
                    
                default:
                    break
                }
                
                // if not successful then set needs parameter update to true for the m5Stack
                if !success {
                    bluetoothPeripheral.parameterUpdateNeededAtNextConnect()
                }
                
            }
            
        }
                
    }

}

// MARK: - extensions

// MARK: extension BluetoothPeripheralManaging

extension BluetoothPeripheralManager: BluetoothPeripheralManaging {
    
    /// to scan for a new BluetoothPeripheral - callback will be called when a new BluetoothPeripheral is found and connected
    func startScanningForNewDevice(type: BluetoothPeripheralType, callback: @escaping (BluetoothPeripheral) -> Void) {
        
        callBackAfterDiscoveringDevice = callback
        
        tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = createNewTransmitter(type: type)
        
        _ = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral?.startScanning()

    }
    
    /// stops scanning for new device
    func stopScanningForNewDevice() {
        
        if let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral {
            
            tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral.stopScanning()
            
            self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = nil
            
        }
    }
    
    func isScanning() -> Bool {
        
        if let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral {
            
            return tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral.isScanning()
            
        } else {
            return false
        }
        
    }
    
    /// try to connect to the M5Stack
    func connect(to bluetoothPeripheral: BluetoothPeripheral) {
        
        // the trick : by calling bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: true), there's two cases
        // - either the bluetoothTransmitter already exists but not connected, it will be found in the call to bluetoothTransmitter and returned, then we connect to it
        // - either the bluetoothTransmitter doesn't exist yet. It will be created. We assum here that bluetoothPeripheral has a mac address, as a consequence the BluetoothTransmitter will automatically try to connect. Here we try to connect again, but that's no issue
        
        let transmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: true)
        
        transmitter?.connect()

    }
    
    /// returns the BluetoothPeripheral for the specified BluetoothTransmitter
    /// - parameters:
    ///     - for : the bluetoothTransmitter, for which BluetoothPeripheral should be returned
    func getBluetoothPeripheral(for bluetoothTransmitter: BluetoothTransmitter) -> BluetoothPeripheral {
        
        guard let index = bluetoothTransmitters.firstIndex(of: bluetoothTransmitter) else {
            fatalError("in BluetoothPeripheralManager, function getBluetoothPeripherals, could not find specified bluetoothTransmitter")
        }
        
        return bluetoothPeripherals[index]
        
    }
    
    /// returns the bluetoothTransmitter for the bluetoothPeripheral
    /// - parameters:
    ///     - forBluetoothPeripheral : the bluetoothPeripheral for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if bluetoothTransmitter is nil, then should one be created ?
    func getBluetoothTransmitter(for bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter? {
        
        if let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) {
            
            if let bluetoothTransmitter = bluetoothTransmitters[index] {
                return bluetoothTransmitter
            }

            if createANewOneIfNecesssary {
                
                var newTransmitter: BluetoothTransmitter? = nil

                switch bluetoothPeripheral.bluetoothPeripheralType() {
                    
                case .M5StackType, .M5StickCType:
                    
                    if let m5Stack = bluetoothPeripheral as? M5Stack {
                        
                        // blePassword : first check if m5Stack has a blepassword configured. If not then user blepassword from userDefaults, which can also still be nil
                        var blePassword = m5Stack.blepassword
                        if blePassword == nil {
                            blePassword = UserDefaults.standard.m5StackBlePassword
                        }
                        
                        newTransmitter = M5StackBluetoothTransmitter(address: m5Stack.address, name: m5Stack.name, delegate: self, blePassword: blePassword, bluetoothPeripheralType: bluetoothPeripheral.bluetoothPeripheralType())
                    }
                    
                }

                bluetoothTransmitters[index] = newTransmitter
                
                return newTransmitter
                
            }

        }
        
        return nil
    }
    
    /// deletes the BluetoothPeripheral in coredata, and also the corresponding BluetoothTransmitter if there is one will be deleted
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral) {
       
        // find the bluetoothPeripheral in array bluetoothPeripherals, if it's not there then this looks like a coding error
        guard let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) else {
            trace("in deleteBluetoothPeripheral but bluetoothPeripheral not found in bluetoothPeripherals, looks like a coding error ", log: self.log, type: .error)
            return
        }
        
        // set bluetoothTransmitter to nil, this will also initiate a disconnect
        bluetoothTransmitters[index] = nil

        // delete in coredataManager
        coreDataManager.mainManagedObjectContext.delete(bluetoothPeripherals[index] as! NSManagedObject)
        
        // remove bluetoothTransmitter and bluetoothPeripheral entry from the two arrays
        bluetoothTransmitters.remove(at: index)
        bluetoothPeripherals.remove(at: index)
        
        // save in coredataManager
        coreDataManager.saveChanges()
        
    }
    
    /// - returns: the bluetoothPeripheral's managed by this BluetoothPeripheralManager
    func getBluetoothPeripherals() -> [BluetoothPeripheral] {
        
        return bluetoothPeripherals
        
    }
    
    /// - returns: the bluetoothTransmitters managed by this BluetoothPeripheralManager
    func getBluetoothTransmitters() -> [BluetoothTransmitter] {
        
        var bluetoothTransmitters: [BluetoothTransmitter] = []
        
        for bluetoothTransmitter in self.bluetoothTransmitters {
            if let bluetoothTransmitter = bluetoothTransmitter {
                bluetoothTransmitters.append(bluetoothTransmitter)
            }
        }
        
        return bluetoothTransmitters
        
    }

    /// bluetoothtransmitter for this bluetoothPeripheral will be deleted, as a result this will also disconnect the bluetoothPeripheral
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        if let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) {
            
            bluetoothTransmitters[index] = nil
            
        }
    }

}

// MARK: extension M5StackBluetoothDelegate

extension BluetoothPeripheralManager: BluetoothTransmitterDelegate {
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        // if tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is nil, then this is a connection to an already known/stored BluetoothTransmitter. BluetoothPeripheralManager is not interested in this info.
        guard let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral else {
            trace("in didConnect, tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is nil, no further processing", log: self.log, type: .info)
            return
        }
        
        // check that address and name are not nil, otherwise this looks like a codding error
        guard let deviceAddressNewTransmitter = bluetoothTransmitter.deviceAddress, let deviceNameNewTransmitter = bluetoothTransmitter.deviceName else {
            trace("in didConnect, address or name of new transmitter is nil, looks like a coding error", log: self.log, type: .error)
            return
        }
        
        // check that tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral and the bluetoothTransmitter to which connection is made are actually the same objects, otherwise it's a connection that is made to a already known/stored BluetoothTransmitter
        guard tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral == bluetoothTransmitter else {
            trace("in didConnect, tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is not nil and not equal to  bluetoothTransmitter", log: self.log, type: .info)
            return
        }
        
        // check that it's a peripheral for which we don't know yet the address
        for buetoothPeripheral in bluetoothPeripherals {
            if buetoothPeripheral.getAddress() == deviceAddressNewTransmitter {
                
                trace("in didConnect, transmitter address already known. This is not a new device, will disconnect", log: self.log, type: .info)

                // it's an already known BluetoothTransmitter, not storing this, on the contrary disconnecting because maybe it's a bluetoothTransmitter already known for which user has preferred not to connect to
                // If we're actually waiting for a new scan result, then there's an instance of BluetoothTransmitter stored in tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral - but this one stopped scanning, so let's recreate an instance of BluetoothTransmitter
                self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = createNewTransmitter(type: getTransmitterType(for: bluetoothTransmitter))
                
                _ = self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral?.startScanning()
                
                return
            }
        }
        
        // it's a new peripheral that we will store. No need to continue scanning
        bluetoothTransmitter.stopScanning()
        
        // create bluetoothPeripheral
        let newBluetoothPeripheral = getTransmitterType(for: tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral).createNewBluetoothPeripheral(withAddress: deviceAddressNewTransmitter, withName: deviceNameNewTransmitter, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

        bluetoothPeripherals.append(newBluetoothPeripheral)
        bluetoothTransmitters.append(bluetoothTransmitter)

        // call the callback function
        if let callBackAfterDiscoveringDevice = callBackAfterDiscoveringDevice {
            callBackAfterDiscoveringDevice(newBluetoothPeripheral)
            self.callBackAfterDiscoveringDevice = nil
        }

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        trace("in deviceDidUpdateBluetoothState, no further action", log: self.log, type: .info)

    }
    
    func error(message: String) {
        trace("in error, no further action", log: self.log, type: .info)
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in didDisconnectFrom", log: self.log, type: .info)

    }

}

// MARK: conform to M5StackBluetoothTransmitterDelegate

extension BluetoothPeripheralManager: M5StackBluetoothTransmitterDelegate {
    
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        m5Stack.batteryLevel = level
        
    }
    
    /// did the app successfully authenticate towards M5Stack, if no, then disconnect will be done
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in authentication with success = %{public}@", log: self.log, type: .info, success.description)
        
        // if authentication not successful then disconnect and don't reconnect, user should verify password or reset the M5Stack, disconnect and set shouldconnect to false, permenantly (ie store in core data)
        // disconnection is done because maybe another device is trying to connect to the M5Stack, need to make it free
        // also set shouldConnect to false (note that this is also done in M5StackViewController if an instance of that exists, no issue, shouldConnect will be set to false two times
        if !success {
            
            // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
            guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}

            // don't try to reconnect after disconnecting
            m5Stack.shouldconnect = false
            
            // store in core data
            coreDataManager.saveChanges()
            
            // disconnect
            disconnect(fromBluetoothPeripheral: m5Stack)
            
        }
    }

    /// there's no ble password set, user should set it in the settings - disconnect will be called, shouldconnect is set to false
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in blePasswordMissing", log: self.log, type: .info)
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}

        // don't try to reconnect after disconnecting
        m5Stack.shouldconnect = false
        
        // store in core data
        coreDataManager.saveChanges()
        
        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)
        
    }

    /// if a new ble password is received from M5Stack
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in newBlePassWord, storing the password in M5Stack", log: self.log, type: .info)

        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and also the bluetoothPeripheral and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}

        // possibily this is a new scanned m5stack, calling coreDataManager.saveChanges() but still the user may be in M5stackviewcontroller and decide not to save the m5stack, bad luck
        m5Stack.blepassword = newBlePassword
        
        coreDataManager.saveChanges()
        
    }

    /// it's an M5Stack without password configured in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset. - disconnect will be called, shouldconnect is set to false
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in m5StackResetRequired", log: self.log, type: .info)
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}

        m5Stack.dontTryToConnectToThisBluetoothPeripheral()
        coreDataManager.saveChanges()
        
        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)
        
    }

    /// bluetoothPeripheral is asking for an update of all parameters, send them
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter) else {
            trace("in isAskingForAllParameters, could not find index of bluetoothTransmitter, looks like a coding error", log: self.log, type: .error)
            return
        }
        
        // send all parameters, if successful,then for this m5Stack we can set parameterUpdateNeeded to false
        if sendAllParametersToM5Stack(to: m5StackBluetoothTransmitter) {
            (bluetoothPeripherals[index] as? M5Stack)?.parameterUpdateNotNeededAtNextConnect()
        } else {
            // failed, so we need to set parameterUpdateNeeded to true, so that next time it connects we will send all parameters
            (bluetoothPeripherals[index] as? M5Stack)?.parameterUpdateNeededAtNextConnect()
        }
        
    }
    
    /// will be called if M5Stack is connected, and authentication was successful, BluetoothPeripheralManager can start sending data like parameter updates or bgreadings
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {

        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}

        // if the M5Stack needs new parameters, then send them
        if m5Stack.isParameterUpdateNeededAtNextConnect() {
            
            // send all parameters
            if sendAllParametersToM5Stack(to: m5StackBluetoothTransmitter) {
                m5Stack.parameterUpdateNotNeededAtNextConnect()
            }
            
        }
        
        // send latest reading
        sendLatestReading(to: m5Stack)
        
    }
    
    // MARK: private functions related to M5Stack
    
    /// send all parameters to m5Stack
    /// - parameters:
    ///     - to : m5StackBluetoothTransmitter to send all parameters
    /// - returns:
    ///     successfully written all parameters or not
    private func sendAllParametersToM5Stack(to m5StackBluetoothTransmitter : M5StackBluetoothTransmitter) -> Bool {
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return false}

        // M5Stack must be ready to receive data
        guard m5StackBluetoothTransmitter.isReadyToReceiveData else {
            trace("in sendAllParameters, bluetoothTransmitter is not ready to receive data", log: self.log, type: .info)
            return false
        }
        
        // initialise returnValue, result
        var success = true
        
        // send bloodglucoseunit
        if !m5StackBluetoothTransmitter.writeBloodGlucoseUnit(isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {success = false}
        
        // send textColor
        if !m5StackBluetoothTransmitter.writeTextColor(textColor: M5StackColor(forUInt16: UInt16(m5Stack.textcolor)) ?? UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor) {success = false}
        
        // send backGroundColor
        if !m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor)) ?? ConstantsM5Stack.defaultBackGroundColor ) {success = false}
        
        // send rotation
        if !m5StackBluetoothTransmitter.writeRotation(rotation: Int(m5Stack.rotation)) {success = false}
        
        // send WiFiSSID's
        if let wifiName = UserDefaults.standard.m5StackWiFiName1 {
            if !m5StackBluetoothTransmitter.writeWifiName(name: wifiName, number: 1) {success = false}
        }
        if let wifiName = UserDefaults.standard.m5StackWiFiName2 {
            if !m5StackBluetoothTransmitter.writeWifiName(name: wifiName, number: 2) {success = false}
        }
        if let wifiName = UserDefaults.standard.m5StackWiFiName3 {
            if !m5StackBluetoothTransmitter.writeWifiName(name: wifiName, number: 3) {success = false}
        }
        
        // send WiFiPasswords
        if let wifiPassword = UserDefaults.standard.m5StackWiFiPassword1 {
            if !m5StackBluetoothTransmitter.writeWifiPassword(password: wifiPassword, number: 1) {success = false}
        }
        if let wifiPassword = UserDefaults.standard.m5StackWiFiPassword2 {
            if !m5StackBluetoothTransmitter.writeWifiPassword(password: wifiPassword, number: 2) {success = false}
        }
        if let wifiPassword = UserDefaults.standard.m5StackWiFiPassword3 {
            if !m5StackBluetoothTransmitter.writeWifiPassword(password: wifiPassword, number: 3) {success = false}
        }
        
        // send nightscout url
        if let url = UserDefaults.standard.nightScoutUrl {
            if !m5StackBluetoothTransmitter.writeNightScoutUrl(url: url) {success = false}
        }
        
        // send nightscout token
        if let token = UserDefaults.standard.nightScoutAPIKey {
            if !m5StackBluetoothTransmitter.writeNightScoutAPIKey(apiKey: token) {success = false}
        }
        
        // return success
        return success
    }
    
    
}

