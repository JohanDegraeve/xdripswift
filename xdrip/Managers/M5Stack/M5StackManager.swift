import Foundation
import os
import CoreBluetooth

class M5StackManager: NSObject {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryM5StackManager)
    
    /// dictionary with key = an instance of M5Stack, and value an instance of M5StackBluetoothTransmitter. Value can be nil in which case we found an M5Stack in the coredata but shouldconnect == false so we don't instanstiate an M5StackBluetoothTransmitter
    private var m5StacksBlueToothTransmitters = [M5Stack : M5StackBluetoothTransmitter?]()
    
    /// to access m5Stack entity in coredata
    private var m5StackAccessor: M5StackAccessor
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// if scan is called, and a connection is successfully made to a new device, then a new M5Stack must be created, and this function will be called. It is owned by the UIViewController that calls the scan function
    private var callBackAfterDiscoveringDevice: ((M5Stack) -> Void)?
    
    /// if scan is called, an instance of M5StackBluetoothTransmitter is created with address and name. The new instance will be assigned to this variable, temporary, until a connection is made
    private var tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack: M5StackBluetoothTransmitter?
    
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
            if m5Stack.shouldconnect {
                // create an instance of M5StackBluetoothTransmitter, M5StackBluetoothTransmitter will automatically try to connect to the M5Stack with the address that is stored in m5Stack
                self.m5StacksBlueToothTransmitters[m5Stack] = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
            } else {
                // shouldn't connect, so don't create an instance of M5StackBluetoothTransmitter
                self.m5StacksBlueToothTransmitters[m5Stack] = (M5StackBluetoothTransmitter?).none
            }
            
            // each time the app launches, we will send the parameter to all M5Stacks
            m5Stack.parameterUpdateNeeded = true
            
        }
        
        // when user changes M5Stack related settings, then the transmitter need to get that info
        addObservers()

    }
    
    // MARK: - public functions
    
    /// will send latest reading to all M5Stacks, only if it's less than 5 minutes old
    /// - parameters:
    ///     - forM5Stack : if nil then latest reading will be sent to all connected M5Stacks, otherwise only to the specified M5Stack
    public func sendLatestReading(forM5Stack m5Stack: M5Stack? = nil) {
        
        // get reading of latest 5 minutes
        let bgReadingToSend = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: Date(timeIntervalSinceNow: -5 * 60), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // check that there's at least 1 reading available
        guard bgReadingToSend.count >= 1 else {
            trace("in sendLatestReading, there's no recent reading to send", log: self.log, type: .info)
            return
        }

        if let m5Stack = m5Stack {
            // send bgReading to the single m5Stack
            _ = m5StackBluetoothTransmitter(forM5stack: m5Stack, createANewOneIfNecesssary: false)?.writeBgReadingInfo(bgReading: bgReadingToSend[0])
        } else {
            // send the reading to all M5Stacks
            for m5StackBlueToothTransmitter in m5StacksBlueToothTransmitters.values {
                if let transmitter = m5StackBlueToothTransmitter {
                    _ = transmitter.writeBgReadingInfo(bgReading: bgReadingToSend[0])
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
    
    /// send all parameters to m5StackBluetoothTransmitter
    /// - returns:
    ///     successfully written all parameters or not
    private func sendAllParameters(toM5Stack m5Stack : M5Stack) -> Bool {
        
        guard let m5StackBluetoothTransmitterValue = m5StacksBlueToothTransmitters[m5Stack], let m5StackBluetoothTransmitter = m5StackBluetoothTransmitterValue else {
            trace("in sendAllParameters, there's no m5StackBluetoothTransmitter for the specified m5Stack", log: self.log, type: .info)
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
        if !m5StackBluetoothTransmitter.writeTextColor(textColor: M5StackTextColor(forUInt16: UInt16(m5Stack.textcolor)) ?? UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor) {success = false}
        
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
    
    // MARK:- override observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                // first check keyValueObserverTimeKeeper
                switch keyPathEnum {
                    
                case UserDefaults.Key.m5StackWiFiName1, UserDefaults.Key.m5StackWiFiName2, UserDefaults.Key.m5StackWiFiName3, UserDefaults.Key.m5StackWiFiPassword1, UserDefaults.Key.m5StackWiFiPassword2, UserDefaults.Key.m5StackWiFiPassword3, UserDefaults.Key.nightScoutAPIKey, UserDefaults.Key.nightScoutUrl  :
                    
                    // transmittertype change triggered by user, should not be done within 200 ms
                    if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                       return
                    }

                default:
                    break
                }
                
                // assuming it's a setting to be sent to all m5Stacks, loop through all M5Stacks
                // only those settings that are to be handled by all M5Stacks need to be considered here
                // loop through all m5StacksBlueToothTransmitters
                for m5StackPair in m5StacksBlueToothTransmitters {
                    if let bluetoothTransmitter = m5StackPair.value {

                        // is value successfully written or not
                        var success = false
                        
                        switch keyPathEnum {
                            
                        case UserDefaults.Key.m5StackWiFiName1:
                            success = bluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName1, number: 1)
                            
                        case UserDefaults.Key.m5StackWiFiName2:
                            success = bluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName2, number: 2)
                            
                        case UserDefaults.Key.m5StackWiFiName3:
                            success = bluetoothTransmitter.writeWifiName(name: UserDefaults.standard.m5StackWiFiName3, number: 3)
                            
                        case UserDefaults.Key.m5StackWiFiPassword1:
                            success = bluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword1, number: 1)
                            
                        case UserDefaults.Key.m5StackWiFiPassword2:
                            success = bluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword2, number: 2)
                            
                        case UserDefaults.Key.m5StackWiFiPassword3:
                            success = bluetoothTransmitter.writeWifiPassword(password: UserDefaults.standard.m5StackWiFiPassword3, number: 3)
                            
                        case UserDefaults.Key.m5StackBlePassword:
                            // only if the password in the settings is not nil, and if the m5Stack doesn't have a password yet, then we will store it in the M5Stack.
                            if let blePassword = UserDefaults.standard.m5StackBlePassword, m5StackPair.key.blepassword == nil {
                                m5StackPair.key.blepassword = blePassword
                            }

                        case UserDefaults.Key.bloodGlucoseUnitIsMgDl:
                            success = bluetoothTransmitter.writeBloodGlucoseUnit(isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                            
                        case UserDefaults.Key.nightScoutAPIKey:
                            success = bluetoothTransmitter.writeNightScoutAPIKey(apiKey: UserDefaults.standard.nightScoutAPIKey)
                            
                        case UserDefaults.Key.nightScoutUrl:
                            success = bluetoothTransmitter.writeNightScoutUrl(url: UserDefaults.standard.nightScoutUrl)
                            
                        default:
                            break
                        }
                        
                        // if not successful then set needs parameter update to true for the m5Stack
                        if !success {
                            m5StackPair.key.parameterUpdateNeeded = true
                        }

                    }
                }
                
            }
        }
    }
    

}

// MARK: - extensions

// MARK: extension M5StackManaging

extension M5StackManager: M5StackManaging {
    
    /// to scan for a new M5SStack - callback will be called when a new M5Stack is found and connected
    func startScanningForNewDevice(callback: @escaping (M5Stack) -> Void) {
        
        callBackAfterDiscoveringDevice = callback
        
        tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = M5StackBluetoothTransmitter(m5Stack: nil, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
        
        _ = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack?.startScanning()
        
    }
    
    /// stops scanning for new device
    func stopScanningForNewDevice() {
        
        if let tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack {
            
            tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack.stopScanning()
            
            self.tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = nil
            
        }
    }
    
    /// try to connect to the M5Stack
    func connect(toM5Stack m5Stack: M5Stack) {
        
        if let bluetoothTransmitter = m5StacksBlueToothTransmitters[m5Stack] {
            
            // because m5StacksBlueToothTransmitters is a dictionary whereby the value is optional, bluetoothTransmitter is now optional, so we have to check again if it's nil or not
            if let bluetoothTransmitter =  bluetoothTransmitter {
                
                // bluetoothtransmitter exists, but not connected, call the connect function
                _ = bluetoothTransmitter.connect()
                
            } else {
                
                // this can be the case where initially shouldconnect was set to false, and user sets it to true via uiviewcontroller, uiviewcontroller calls this function, connect should automatially be initiated
                let newBlueToothTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
                
                m5StacksBlueToothTransmitters[m5Stack] = newBlueToothTransmitter

            }
            
        } else {
            
            // I don't think this code will be used, because value m5Stack should always be in m5StacksBlueToothTransmitters, anyway let's add it
            let newBlueToothTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
            
            m5StacksBlueToothTransmitters[m5Stack] = newBlueToothTransmitter
            
        }
    }
    
    /// disconnect from M5Stack - and don't reconnect - set shouldconnect to false
    func disconnect(fromM5stack m5Stack: M5Stack) {
        
        // device should not reconnect after disconnecting
        m5Stack.shouldconnect = false
        
        // save in coredata
        coreDataManager.saveChanges()
        
        if let bluetoothTransmitter = m5StacksBlueToothTransmitters[m5Stack] {
            if let bluetoothTransmitter =  bluetoothTransmitter {
                bluetoothTransmitter.disconnect(reconnectAfterDisconnect: false)
            }
        }
    }

    /// returns the M5StackBluetoothTransmitter for the m5stack
    /// - parameters:
    ///     - forM5Stack : the m5Stack for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if bluetoothTransmitter is nil, then should one be created ?
    func m5StackBluetoothTransmitter(forM5stack m5Stack: M5Stack, createANewOneIfNecesssary: Bool) -> M5StackBluetoothTransmitter? {
        
        if let bluetoothTransmitter = m5StacksBlueToothTransmitters[m5Stack] {
            if let bluetoothTransmitter =  bluetoothTransmitter {
                return bluetoothTransmitter
            }
        }
        
        if createANewOneIfNecesssary {
            let newTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
            m5StacksBlueToothTransmitters[m5Stack] = newTransmitter
            return newTransmitter
        }
        return nil
    }
    
    /// deletes the M5Stack in coredata, and also the corresponding M5StackBluetoothTransmitter if there is one will be deleted
    func deleteM5Stack(m5Stack: M5Stack) {
       
        // if in dictionary remove it
        if m5StacksBlueToothTransmitters.keys.contains(m5Stack) {
            m5StacksBlueToothTransmitters[m5Stack] = (M5StackBluetoothTransmitter?).none
            m5StacksBlueToothTransmitters.removeValue(forKey: m5Stack)
        }
        
        // delete in coredataManager
        coreDataManager.mainManagedObjectContext.delete(m5Stack)
        
        // save in coredataManager
        coreDataManager.saveChanges()
        
    }
    
    /// - returns: the M5Stack's managed by this M5StackManager
    func m5Stacks() -> [M5Stack] {
        return Array(m5StacksBlueToothTransmitters.keys)
    }
    
    /// sets flag m5StacksParameterUpdateNeeded for m5Stack to true
    func updateNeeded(forM5Stack m5Stack: M5Stack) {
        m5Stack.parameterUpdateNeeded = true
    }
    
    /// bluetoothtransmitter for this m5Stack will be deleted, as a result this will also disconnect the M5Stack
    func setBluetoothTransmitterToNil(forM5Stack m5Stack: M5Stack) {
        
        self.m5StacksBlueToothTransmitters[m5Stack] = (M5StackBluetoothTransmitter?).none
    }

}

// MARK: extensions M5StackBluetoothDelegate

extension M5StackManager: M5StackBluetoothDelegate {
    
    /// m5Stack is asking for an update of all parameters, send them
    func isAskingForAllParameters(m5Stack: M5Stack) {
        
        // send all parameters, if successful,then for this m5Stack we can set m5StacksParameterUpdateNeeded to false
        if sendAllParameters(toM5Stack: m5Stack) {
            m5Stack.parameterUpdateNeeded = false
        } else {
            // failed, so we need to set m5StacksParameterUpdateNeeded to true, so that next time it connects we will send all parameters
            m5Stack.parameterUpdateNeeded = true
        }

    }
    
    /// will be called if M5Stack is connected, and authentication was successful, M5StackManager can start sending data like parameter updates or bgreadings
    func isReadyToReceiveData(m5Stack : M5Stack) {
        
        // if the M5Stack needs new parameters, then send them
        if m5Stack.parameterUpdateNeeded {
            
            // send all parameters
            if sendAllParameters(toM5Stack: m5Stack) {
                m5Stack.parameterUpdateNeeded = false
            }
            
        }
        
        // send latest reading
        sendLatestReading(forM5Stack: m5Stack)
        
    }

    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter : M5StackBluetoothTransmitter) {
        
        guard tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack != nil else {
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
                    tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = M5StackBluetoothTransmitter(m5Stack: nil, delegateFixed: self, blePassword: UserDefaults.standard.m5StackBlePassword)
                    _ = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack?.startScanning()

                    return
                    
                }
            }
            
            // looks like we haven't found the address in list of known M5Stacks, so it's a new M5Stack, stop the scanning
            bluetoothTransmitter.stopScanning()
            
            // create a new M5Stack with new peripheral's address and name
            let newM5Stack = M5Stack(address: address, name: name, textColor: UserDefaults.standard.m5StackTextColor ?? ConstantsM5Stack.defaultTextColor, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            
            // add to list of m5StacksBlueToothTransmitters
            m5StacksBlueToothTransmitters[newM5Stack] = bluetoothTransmitter
            
            // no need to keep a reference to the bluetothTransmitter, this is now stored in m5StacksBlueToothTransmitters
            tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = nil
            
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
            disconnect(fromM5stack: m5Stack)
            
        }
    }
    
    /// there's no ble password set, user should set it in the settings - disconnect will be called, shouldconnect is set to false
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {

        trace("in blePasswordMissing", log: self.log, type: .info)
        
        m5Stack.shouldconnect = false
        coreDataManager.saveChanges()

        // disconnect
        disconnect(fromM5stack: m5Stack)

    }

    /// it's an M5Stack without password configured in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset. - disconnect will be called, shouldconnect is set to false
    func m5StackResetRequired(forM5Stack m5Stack:M5Stack) {

        trace("in m5StackResetRequired", log: self.log, type: .info)
        
        m5Stack.shouldconnect = false
        coreDataManager.saveChanges()

        // disconnect
        disconnect(fromM5stack: m5Stack)

    }

    /// did disconnect from M5Stack
    func didDisconnect(forM5Stack m5Stack:M5Stack) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in didDisconnect", log: self.log, type: .info)
    }

}
