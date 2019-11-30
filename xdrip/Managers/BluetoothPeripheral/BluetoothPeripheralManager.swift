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
                
                bluetoothTransmitters.append(M5StackBluetoothTransmitter(bluetoothPeripheral: m5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword))
                
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
    
    /// will send latest reading to all BluetoothPeripherals that need this info and only if it's less than 5 minutes old
    /// - parameters:
    ///     - forBluetoothPeripheral : if nil then latest reading will be sent to all connected BluetoothPeripherals that need this info, otherwise only to the specified BluetoothPeripheral
    ///
    /// this function has knowledge about different types of bluetoothperipheral and knows to which it should send to reading, to which not
    public func sendLatestReading(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral? = nil) {
        
        // get reading of latest 5 minutes
        let bgReadingToSend = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: Date(timeIntervalSinceNow: -5 * 60), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // check that there's at least 1 reading available
        guard bgReadingToSend.count >= 1 else {
            trace("in sendLatestReading, there's no recent reading to send", log: self.log, type: .info)
            return
        }

        if let bluetoothPeripheral = bluetoothPeripheral {

            // get type of bluetoothPeripheral
            let bluetoothPeripheralType = bluetoothPeripheral.bluetoothPeripheralType()
            
            // using bluetoothPeripheralType here so that whenever bluetoothPeripheralType is extended with new cases, we don't forget to handle them
            switch bluetoothPeripheralType {
                
            case .M5Stack:

                // get the bluetooth transmitter, and if it's an M5StackBluetoothTransmitter, then send the bgReading
                if let bluetoothTransmitter = bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter =  bluetoothTransmitter as? M5StackBluetoothTransmitter {
                    
                    _ = m5StackBluetoothTransmitter.writeBgReadingInfo(bgReading: bgReadingToSend[0])

                }

            }

            
        } else {
            
            // send the reading to all bluetoothPeripherals that want to receive a reading
            // to make sure new types are not forgotten, I use switch
            
            for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
                
                switch bluetoothPeripheralType {
                    
                case .M5Stack:
                    
                    for bluetoothPeripheral in bluetoothPeripherals {
                        
                        // get the bluetooth transmitter, and if it's an M5StackBluetoothTransmitter, then send the bgReading
                        if let bluetoothTransmitter = bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter =  bluetoothTransmitter as? M5StackBluetoothTransmitter {
                            
                            _ = m5StackBluetoothTransmitter.writeBgReadingInfo(bgReading: bgReadingToSend[0])
                            
                        }

                    }
                    
                }
                
            }
            
        }
    }
    
    // MARK: - private helper functions
    
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
    
    /// send all parameters to m5Stack
    /// - parameters:
    ///     - m5Stack : if m5Stack is not type M5Stack then
    /// - returns:
    ///     successfully written all parameters or not
    private func sendAllParametersToM5Stack(to m5Stack : M5Stack) -> Bool {
        
        guard let bluetoothTransmitter = bluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter =  bluetoothTransmitter as? M5StackBluetoothTransmitter else {
            trace("in sendAllParametersToM5Stack, there's no m5StackBluetoothTransmitter for the specified m5Stack", log: self.log, type: .info)
            return false
        }
        
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
    
    /// disconnect from bluetoothPeripheral - and don't reconnect - set shouldconnect to false
    func disconnect(fromBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        // device should not reconnect after disconnecting
        bluetoothPeripheral.dontTryToConnectToThisBluetoothPeripheral()
        
        // save in coredata
        coreDataManager.saveChanges()
        
        if let bluetoothTransmitter = bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            bluetoothTransmitter.disconnect(reconnectAfterDisconnect: false)
            
        }
        
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
        
        // loop through all bluetoothPeripheralTypes. Do a check on bluetoothPeripheralType, depending on type, loop through all bluetoothPeripherals, and if correct type, write the value to the peripheral
        // this usage of bluetoothPeripheralType is done to make sure this code is not forgotten when adding a bluetoothPeripheralType
        for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
            
            switch bluetoothPeripheralType {
                
            case .M5Stack:
                
                for bluetoothPeripheral in bluetoothPeripherals {
                    
                    // get the bluetooth transmitter, and if it's an M5StackBluetoothTransmitter, then send the bgReading
                    if let bluetoothTransmitter = bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
                        
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
                        
                    } else {
                        
                        // seems to be an M5Stack which is currently disconnected - need to set parameterUpdateNeeded = true, so that all parameters will be sent as soon as reconnect occurs
                        bluetoothPeripheral.parameterUpdateNeededAtNextConnect()
                        
                    }
                    
                }
                
            }
            
        }
        

                
    }
    

}

// MARK: - extensions

// MARK: extension BluetoothPeripheralManaging

extension BluetoothPeripheralManager: BluetoothPeripheralManaging {
    
    /// to scan for a new BluetoothPeripheral - callback will be called when a new BluetoothPeripheral is found and connected
    func startScanningForNewDevice(callback: @escaping (BluetoothPeripheral) -> Void) {
        
        callBackAfterDiscoveringDevice = callback
        
        tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = M5StackBluetoothTransmitter(bluetoothPeripheral: nil, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
        
        _ = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral?.startScanning()
        
    }
    
    /// stops scanning for new device
    func stopScanningForNewDevice() {
        
        if let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral {
            
            tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral.stopScanning()
            
            self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = nil
            
        }
    }
    
    /// try to connect to the M5Stack
    func connect(toBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        if let bluetoothTransmitter = m5StacksBlueToothTransmitters[bluetoothPeripheral] {
            
            // because m5StacksBlueToothTransmitters is a dictionary whereby the value is optional, bluetoothTransmitter is now optional, so we have to check again if it's nil or not
            if let bluetoothTransmitter =  bluetoothTransmitter {
                
                // bluetoothtransmitter exists, but not connected, call the connect function
                _ = bluetoothTransmitter.connect()
                
            } else {
                
                // this can be the case where initially shouldconnect was set to false, and user sets it to true via uiviewcontroller, uiviewcontroller calls this function, connect should automatially be initiated
                let newBlueToothTransmitter = M5StackBluetoothTransmitter(bluetoothPeripheral: bluetoothPeripheral, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
                
                m5StacksBlueToothTransmitters[bluetoothPeripheral] = newBlueToothTransmitter

            }
            
        } else {
            
            // I don't think this code will be used, because value m5Stack should always be in m5StacksBlueToothTransmitters, anyway let's add it
            let newBlueToothTransmitter = M5StackBluetoothTransmitter(bluetoothPeripheral: bluetoothPeripheral, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
            
            m5StacksBlueToothTransmitters[bluetoothPeripheral] = newBlueToothTransmitter
            
        }
    }
    
    /// returns the bluetoothTransmitter for the bluetoothPeripheral
    /// - parameters:
    ///     - forBluetoothPeripheral : the bluetoothPeripheral for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if bluetoothTransmitter is nil, then should one be created ?
    func bluetoothTransmitter(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter? {
        
        if let index = bluetoothPeripherals.firstIndex(where: {$0.getAddress() == bluetoothPeripheral.getAddress()}) {
            
            if let bluetoothTransmitter = bluetoothTransmitters[index] {
                return bluetoothTransmitter
            }

            if createANewOneIfNecesssary {
                
                var newTransmitter: BluetoothTransmitter? = nil
                
                for bluetoothPeripheralType in BluetoothPeripheralType.allCases {

                    switch bluetoothPeripheralType {
                        
                        case .M5Stack:
                            newTransmitter = M5StackBluetoothTransmitter(bluetoothPeripheral: bluetoothPeripheral as? M5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)

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
        guard let index = bluetoothPeripherals.firstIndex(where: {$0.getAddress() == bluetoothPeripheral.getAddress()}) else {
            trace("in deleteBluetoothPeripheral but bluetoothPeripheral not found in bluetoothPeripherals, looks like a coding error ", log: self.log, type: .error)
        }
        
        // set bluetoothTransmitter to nil, this will also initiate a disconnect
        bluetoothTransmitters[index] = nil

        // remove bluetoothTransmitter and bluetoothPeripheral entry from the two arrays
        bluetoothTransmitters.remove(at: index)
        bluetoothPeripherals.remove(at: index)
        
        // delete in coredataManager
        coreDataManager.mainManagedObjectContext.delete(bluetoothPeripherals[index] as! NSManagedObject)
        
        // save in coredataManager
        coreDataManager.saveChanges()
        
    }
    
    /// - returns: the bluetoothPeripheral's managed by this BluetoothPeripheralManager
    func getBluetoothPeripherals() -> [BluetoothPeripheral] {
        return bluetoothPeripherals
    }

    /// bluetoothtransmitter for this bluetoothPeripheral will be deleted, as a result this will also disconnect the bluetoothPeripheral
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        if let index = bluetoothPeripherals.firstIndex(where: {$0.getAddress() == bluetoothPeripheral.getAddress()}) {
            bluetoothTransmitters[index] = nil
            
        }
    }

}

// MARK: extensions M5StackBluetoothDelegate

extension BluetoothPeripheralManager: BluetoothPeripheralDelegate {
    
    /// bluetoothPeripheral is asking for an update of all parameters, send them
    func isAskingForAllParameters(bluetoothPeripheral: BluetoothPeripheral) {
        
        // send all parameters, if successful,then for this m5Stack we can set parameterUpdateNeeded to false
        if sendAllParameters(toM5Stack: bluetoothPeripheral) {
            bluetoothPeripheral.parameterUpdateNeeded = false
        } else {
            // failed, so we need to set parameterUpdateNeeded to true, so that next time it connects we will send all parameters
            bluetoothPeripheral.parameterUpdateNeeded = true
        }

    }
    
    /// will be called if M5Stack is connected, and authentication was successful, BluetoothPeripheralManager can start sending data like parameter updates or bgreadings
    func isReadyToReceiveData(m5Stack : M5Stack) {
        
        // if the M5Stack needs new parameters, then send them
        if m5Stack.parameterUpdateNeeded {
            
            // send all parameters
            if sendAllParameters(toM5Stack: m5Stack) {
                m5Stack.parameterUpdateNeeded = false
            }
            
        }
        
        // send latest reading
        sendLatestReading(forBluetoothPeripheral: m5Stack)
        
    }

    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter : M5StackBluetoothTransmitter) {
        
        guard tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral != nil else {
            trace("in didConnect, tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack is nil, no further processing", log: self.log, type: .info)
            return
        }
        
        // we're interested in new M5stack's which were scanned for, so that would mean m5Stack parameter would be nil, and if nil, then address should not yet be any of the known/stored M5Stack's
        if m5Stack == nil, let address = address, let name = name {
            
            // go through all the known m5Stacks and see if the address matches to any of them
            for m5StackPair in m5StacksBlueToothTransmitters {
                if m5StackPair.key.address == address {
                    
                    // it's an already known m5Stack, not storing this, on the contrary disconnecting because maybe it's an m5stack already known for which user has preferred not to connect to
                    // If we're actually waiting for a new scan result, then there's an instance of M5StacksBlueToothTransmitter stored in tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack - but this one stopped scanning, so let's recreate an instance of M5StacksBlueToothTransmitter
                    tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = M5StackBluetoothTransmitter(bluetoothPeripheral: nil, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
                    _ = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral?.startScanning()

                    return
                    
                }
            }
            
            // looks like we haven't found the address in list of known M5Stacks, so it's a new M5Stack, stop the scanning
            bluetoothTransmitter.stopScanning()
            
            // create a new M5Stack with new peripheral's address and name
            let newM5Stack = M5Stack(address: address, name: name, textColor: UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor, backGroundColor: ConstantsM5Stack.defaultBackGroundColor, rotation: ConstantsM5Stack.defaultRotation, brightness: 100, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            
            // assign password stored in UserDefaults (might be nil)
            newM5Stack.blepassword = UserDefaults.standard.m5StackBlePassword
            
            // add to list of m5StacksBlueToothTransmitters
            m5StacksBlueToothTransmitters[newM5Stack] = bluetoothTransmitter
            
            // no need to keep a reference to the bluetothTransmitter, this is now stored in m5StacksBlueToothTransmitters
            tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = nil
            
            // assign n
            bluetoothTransmitter.m5Stack = newM5Stack
            
            // call the callback function
            if let callBackAfterDiscoveringDevice = callBackAfterDiscoveringDevice {
                callBackAfterDiscoveringDevice(newM5Stack)
                self.callBackAfterDiscoveringDevice = nil
            }

        } else {
            // if m5Stack is not nil, then this is a connect of one of the known M5Stacks
            // nothing needed
        }
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, forM5Stack m5Stack: M5Stack) {
        trace("in deviceDidUpdateBluetoothState, no further action", log: self.log, type: .info)
    }
    
    func error(message: String) {
        trace("in error, no further action", log: self.log, type: .info)
    }
    
    /// if a new ble password is received from M5Stack
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack: M5Stack) {
        
        trace("in newBlePassWord, storing the password in M5Stack", log: self.log, type: .info)
        // possibily this is a new scanned m5stack, calling coreDataManager.saveChanges() but still the user may be in M5stackviewcontroller and decide not to save the m5stack, tant pis
        m5Stack.blepassword = newBlePassword
        coreDataManager.saveChanges()
        
    }

    /// did the app successfully authenticate towards M5Stack, if no, then disconnect will be done
    ///
    func authentication(success: Bool, forM5Stack m5Stack:M5Stack) {
        trace("in authentication with success = %{public}@", log: self.log, type: .info, success.description)
        
        // if authentication not successful then disconnect and don't reconnect, user should verify password or reset the M5Stack, disconnect and set shouldconnect to false, permenantly (ie store in core data)
        // disconnection is done because maybe another device is trying to connect to the M5Stack, need to make it free
        // also set shouldConnect to false (note that this is also done in M5StackViewController if an instance of that exists, no issue, shouldConnect will be set to false two times
        if !success {
            
            m5Stack.shouldconnect = false
            coreDataManager.saveChanges()
            
            // disconnect
            disconnect(fromBluetoothPeripheral: m5Stack)
            
        }
    }
    
    /// there's no ble password set, user should set it in the settings - disconnect will be called, shouldconnect is set to false
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {

        trace("in blePasswordMissing", log: self.log, type: .info)
        
        m5Stack.shouldconnect = false
        coreDataManager.saveChanges()

        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)

    }

    /// it's an M5Stack without password configured in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset. - disconnect will be called, shouldconnect is set to false
    func m5StackResetRequired(forM5Stack m5Stack:M5Stack) {

        trace("in m5StackResetRequired", log: self.log, type: .info)
        
        m5Stack.shouldconnect = false
        coreDataManager.saveChanges()

        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)

    }

    /// did disconnect from M5Stack
    func didDisconnect(forM5Stack m5Stack:M5Stack) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in didDisconnect", log: self.log, type: .info)
    }

}
