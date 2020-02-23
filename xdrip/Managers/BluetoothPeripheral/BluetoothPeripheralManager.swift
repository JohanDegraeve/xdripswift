import Foundation
import os
import CoreBluetooth
import CoreData
import UIKit

class BluetoothPeripheralManager: NSObject {
    
    // MARK: - public properties
    
    /// all currently known BluetoothPeripheral's (MStacks, cgmtransmitters, watlaa , ...)
    public var bluetoothPeripherals: [BluetoothPeripheral] = []
    
    /// the bluetoothTransmitter's, array must have the same size as bluetoothPeripherals. For each element in bluetoothPeripherals, there's an element at the same index in bluetoothTransmitters, which may be nil. nil value means user selected not to connect
    public var bluetoothTransmitters: [BluetoothTransmitter?] = []
    
    /// for logging
    public var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralManager)
    
    /// when xdrip connects to a BluetoothTransmitter that is also CGMTransmitter, then we'll call this function with the BluetoothTransmitter as argument. This is to let the cgmTransmitterDelegate know what is the CGMTransmitter
    public var onCGMTransmitterCreation: (CGMTransmitter?) -> ()

    /// if scan is called, an instance of M5StackBluetoothTransmitter is created with address and name. The new instance will be assigned to this variable, temporary, until a connection is made
    public var tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral: BluetoothTransmitter?

    /// if scan is called, and a connection is successfully made to a new device, then a new M5Stack must be created, and this function will be called. It is owned by the UIViewController that calls the scan function
    public var callBackAfterDiscoveringDevice: ((BluetoothPeripheral) -> Void)?

    /// will be used to present alerts, for example pairing failed
    public let uIViewController: UIViewController
    
    /// bluetoothtransmitter may need pairing, but app is in background. Notification will be sent to user, user will open the app, at that moment pairing can happen. variable bluetoothTransmitterThatNeedsPairing will temporary store the BluetoothTransmitter that needs the pairing
    public var bluetoothTransmitterThatNeedsPairing: BluetoothTransmitter?
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    public let coreDataManager:CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// reference to BLEPeripheralAccessor
    private var bLEPeripheralAccessor: BLEPeripheralAccessor
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// will be used to pass back bluetooth and cgm related events, probably temporary ?
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    // MARK: - initializer
    
    /// - parameters:
    ///     - onCGMTransmitterCreation : to be called when cgmtransmitter is created
    init(coreDataManager: CoreDataManager, cgmTransmitterDelegate: CGMTransmitterDelegate, uIViewController: UIViewController, onCGMTransmitterCreation: @escaping (CGMTransmitter?) -> ()) {
        
        // initialize properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.cgmTransmitterDelegate = cgmTransmitterDelegate
        self.onCGMTransmitterCreation = onCGMTransmitterCreation
        self.bLEPeripheralAccessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
        self.uIViewController = uIViewController
        
        super.init()
        
        // loop through blePeripherals
        for blePeripheral in bLEPeripheralAccessor.getBLEPeripherals() {

            // each time the app launches, we will send the parameters to all BluetoothPeripherals (only used for M5Stack for now)
            blePeripheral.parameterUpdateNeededAtNextConnect = true

            if !blePeripheral.shouldconnect {
                bluetoothTransmitters.append(nil)
            }
            
            // need to initialize all types of bluetoothperipheral
            // using enum here to make sure future types are not forgotten
            for bluetoothPeripheralType in BluetoothPeripheralType.allCases {

                switch bluetoothPeripheralType {
                    
                case .M5StackType:
                    // no seperate handling needed for M5StickC because M5StickC is stored in coredata as M5Stack objecct, so it will be handled when going through case M5StackType
                    break
                    
                case .M5StickCType:
                    if let m5Stack = blePeripheral.m5Stack {
                        
                        // add it to the list of bluetoothPeripherals
                        bluetoothPeripherals.append(m5Stack)
                        
                        if m5Stack.blePeripheral.shouldconnect {
                            
                            // create an instance of M5StackBluetoothTransmitter, M5StackBluetoothTransmitter will automatically try to connect to the M5Stack with the address that is stored in m5Stack
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.append(M5StackBluetoothTransmitter(address: m5Stack.blePeripheral.address, name: m5Stack.blePeripheral.name, bluetoothTransmitterDelegate: self, m5StackBluetoothTransmitterDelegate: self, blePassword: m5Stack.blepassword, bluetoothPeripheralType: m5Stack.isM5StickC ? .M5StickCType : .M5StackType))
                            
                        }
                        
                    }
                    
                case .watlaaMaster:
                    
                    if let watlaa = blePeripheral.watlaa {
                        
                        // add it to the list of bluetoothPeripherals
                        bluetoothPeripherals.append(watlaa)
                        
                        if watlaa.blePeripheral.shouldconnect {
                            
                            // create an instance of WatlaaBluetoothTransmitter, WatlaaBluetoothTransmitter will automatically try to connect to the watlaa with the address that is stored in watlaa
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.append(WatlaaBluetoothTransmitterMaster(address: watlaa.blePeripheral.address, name: watlaa.blePeripheral.name, cgmTransmitterDelegate: cgmTransmitterDelegate, bluetoothTransmitterDelegate: self, watlaaBluetoothTransmitterDelegate: self, bluetoothPeripheralType: .watlaaMaster))
                            
                        }

                    }
                    
                case .DexcomG5Type:
                
                    if let dexcomG5 = blePeripheral.dexcomG5 {
                        
                        // add it to the list of bluetoothPeripherals
                        bluetoothPeripherals.append(dexcomG5)
                        
                        if dexcomG5.blePeripheral.shouldconnect {
                            
                            if let transmitterId = dexcomG5.blePeripheral.transmitterId {

                                // create an instance of WatlaaBluetoothTransmitter, WatlaaBluetoothTransmitter will automatically try to connect to the watlaa with the address that is stored in watlaa
                                // add it to the array of bluetoothTransmitters
                                bluetoothTransmitters.append(CGMG5Transmitter(address: dexcomG5.blePeripheral.address, name: dexcomG5.blePeripheral.name, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMG5TransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate))

                            }
                            
                        }
                        
                    }
                    
                }

            }
            
        }
        
        // when user changes any of the buetooth peripheral related settings, that need to be sent to the transmitter
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
            trace("in sendLatestReading, there's no recent reading to send", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
            return
        }

        // loop through all bluetoothPeripherals
        for bluetoothPeripheral in bluetoothPeripherals {
            
            // if parameter toBluetoothPeripheral is not nil, then it means we need to send the reading only to this bluetoothPeripheral, so we skip all peripherals except that one
            if let toBluetoothPeripheral = toBluetoothPeripheral, toBluetoothPeripheral.blePeripheral.address != bluetoothPeripheral.blePeripheral.address {
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
                    
                case .watlaaMaster:
                    // no need to send reading to watlaa in master mode
                    break
                    
                case .DexcomG5Type:
                    // cgm's don't receive reading, they send it
                    break
                    
                }

            }
   
        }
    }

    /// disconnect from bluetoothPeripheral - and don't reconnect - set shouldconnect to false
    public func disconnect(fromBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        // device should not reconnect after disconnecting
        bluetoothPeripheral.blePeripheral.shouldconnect = false
        
        // save in coredata
        coreDataManager.saveChanges()
        
        if let bluetoothTransmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            _ = bluetoothTransmitter.disconnect(reconnectAfterDisconnect: false)
            
        }
        
    }

    /// returns the bluetoothTransmitter for the bluetoothPeripheral
    /// - parameters:
    ///     - forBluetoothPeripheral : the bluetoothPeripheral for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if bluetoothTransmitter is nil, then should one be created ?
    public func getBluetoothTransmitter(for bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter? {
        
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
                        
                        newTransmitter = M5StackBluetoothTransmitter(address: m5Stack.blePeripheral.address, name: m5Stack.blePeripheral.name, bluetoothTransmitterDelegate: self, m5StackBluetoothTransmitterDelegate: self, blePassword: blePassword, bluetoothPeripheralType: bluetoothPeripheral.bluetoothPeripheralType())
                    }
                    
                case .watlaaMaster:
                    
                    if let watlaa = bluetoothPeripheral as? Watlaa {
                        
                        newTransmitter = WatlaaBluetoothTransmitterMaster(address: watlaa.blePeripheral.address, name: watlaa.blePeripheral.name, cgmTransmitterDelegate: cgmTransmitterDelegate, bluetoothTransmitterDelegate: self, watlaaBluetoothTransmitterDelegate: self, bluetoothPeripheralType: .watlaaMaster)
                        
                    }
                    
                case .DexcomG5Type:
                    
                    if let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
                        
                        if let transmitterId = dexcomG5.blePeripheral.transmitterId, let cgmTransmitterDelegate = cgmTransmitterDelegate {
                            
                            newTransmitter = CGMG5Transmitter(address: dexcomG5.blePeripheral.address, name: dexcomG5.blePeripheral.name, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMG5TransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate)
                            
                        } else {
                            
                            trace("in getBluetoothTransmitter, case DexcomG5Type but transmitterId is nil or cgmTransmitterDelegate is nil, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                            
                        }
                    }
                }
                
                bluetoothTransmitters[index] = newTransmitter
                
                return newTransmitter
                
            }
            
        }
        
        return nil
    }

    public func getTransmitterType(for bluetoothTransmitter:BluetoothTransmitter) -> BluetoothPeripheralType {
        
        for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
            
            // using switch through all cases, to make sure that new future types are supported
            switch bluetoothPeripheralType {
                
            case .M5StackType, .M5StickCType:
                
                if let bluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
                    return bluetoothTransmitter.bluetoothPeripheralType
                }
                
            case .watlaaMaster:
                
                if bluetoothTransmitter is WatlaaBluetoothTransmitterMaster {
                    return .watlaaMaster
                }
                
            case .DexcomG5Type:
                if bluetoothTransmitter is CGMG5Transmitter {
                    return .DexcomG5Type
                }
                
            }
            
        }
        
        // normally we shouldn't get here, but we need to return a value
        fatalError("BluetoothPeripheralManager :  getTransmitterType did not find a valid type")
        
    }

    /// transmitterId only for transmitter types that need it (at the moment only Dexcom and Blucon)
    public func createNewTransmitter(type: BluetoothPeripheralType, transmitterId: String?) -> BluetoothTransmitter? {
        
        switch type {
            
        case .M5StackType, .M5StickCType:
            
            return M5StackBluetoothTransmitter(address: nil, name: nil, bluetoothTransmitterDelegate: self, m5StackBluetoothTransmitterDelegate: self, blePassword: UserDefaults.standard.m5StackBlePassword, bluetoothPeripheralType: type)
            
        case .watlaaMaster:
            
            return WatlaaBluetoothTransmitterMaster(address: nil, name: nil, cgmTransmitterDelegate: cgmTransmitterDelegate, bluetoothTransmitterDelegate: self, watlaaBluetoothTransmitterDelegate: self, bluetoothPeripheralType: type)
            
        case .DexcomG5Type:
            
            guard let transmitterId = transmitterId, let cgmTransmitterDelegate =  cgmTransmitterDelegate else {
                trace("in createNewTransmitter, transmitterId is nil or cgmTransmitterDelegate is nil", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                return nil
            }
            
            return CGMG5Transmitter(address: nil, name: nil, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMG5TransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate)
            
        }
        
    }

    // MARK: - private functions
    
    /// check if transmitter in bluetoothTransmitters with index, is the cgmtransmitter currently assigned to delegate, if so set cgmtransmitter at delegate to nil   - This should be temporary till cgm transmitters have moved to bluetooth tab
    private func setCGMTransmitterToNilAtDelegate(withIndexInBluetoothTransmitters index: Int) {

        if let cgmTransmitter = cgmTransmitterDelegate?.getCGMTransmitter() as? BluetoothTransmitter, let transmitterBeingDeleted = bluetoothTransmitters[index] {
            
            if cgmTransmitter.deviceAddress == transmitterBeingDeleted.deviceAddress {
                
                // so the cgmTransmitter is actually being deleted, so we need to also assign cgmTransmitterDelegate to nil to make sure there's no more reference to it
                onCGMTransmitterCreation(nil)
                
            }
            
        }

    }
    
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
    
    public func firstIndexInBluetoothPeripherals(bluetoothPeripheral: BluetoothPeripheral) -> Int? {
        return bluetoothPeripherals.firstIndex(where: {$0.blePeripheral.address == bluetoothPeripheral.blePeripheral.address})
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
                bluetoothPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                
                return

            }
            
            // get the type
            switch bluetoothPeripheral.bluetoothPeripheralType() {
                
            case .M5StackType, .M5StickCType:
                
                guard let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter else {
                    trace("in observeValue, bluetoothPeripheral is of type M5Stack but bluetoothTransmitter is not M5StackBluetoothTransmitter", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                    return
                }
                
                // check that bluetoothPeripheral is of type M5Stack, if not then this might be a coding error
                guard let m5Stack = bluetoothPeripheral as? M5Stack else {
                    trace("in observeValue, transmitter is of type M5StackBluetoothTransmitter but peripheral is not M5Stack", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
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
                    bluetoothPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                }
             
            case .watlaaMaster:
                break
                
            case .DexcomG5Type:
                break
                
            }
            
        }
                
    }

}

// MARK: - conform to BluetoothPeripheralManaging

extension BluetoothPeripheralManager: BluetoothPeripheralManaging {
    
    func startScanningForNewDevice(type: BluetoothPeripheralType, transmitterId: String?, callback: @escaping (BluetoothPeripheral) -> Void) {
        
        callBackAfterDiscoveringDevice = callback
        
        tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = createNewTransmitter(type: type, transmitterId: transmitterId)
        
        // example DexcomG5 starts scanning as soon as the transmitter is created, so there's no need to start it here.
        // (actually transmitterStartsScanningAfterInit has become obsolete, or will be.  Because all transmitters should come here, this will be the only place where scanning starts and it will always be immediately after creating the transmitter
        if !type.transmitterStartsScanningAfterInit() {
            _ = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral?.startScanning()
        }
        
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
    
    /// deletes the BluetoothPeripheral in coredata, and also the corresponding BluetoothTransmitter if there is one will be deleted
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral) {
        
        // find the bluetoothPeripheral in array bluetoothPeripherals, if it's not there then this looks like a coding error
        guard let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) else {
            trace("in deleteBluetoothPeripheral but bluetoothPeripheral not found in bluetoothPeripherals, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
            return
        }
        
        // check if transmitter being deleted is assigned to cgmTransmitterDelegate, if so we need to set it also to nil, otherwise the bluetoothTransmitter deinit function wouldn't get called
        setCGMTransmitterToNilAtDelegate(withIndexInBluetoothTransmitters: index)
        
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
            
            // check if transmitter being deleted is assigned to cgmTransmitterDelegate, if so we need to set it also to nil, otherwise the bluetoothTransmitter deinit function wouldn't get called
            setCGMTransmitterToNilAtDelegate(withIndexInBluetoothTransmitters: index)
            
            bluetoothTransmitters[index] = nil
            
        }
    }
    
    func initiatePairing() {
        
        bluetoothTransmitterThatNeedsPairing?.initiatePairing()

        /// remove applicationManagerKeyInitiatePairing from application key manager - there's no need to initiate the pairing via this closure
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: BluetoothPeripheralManager.applicationManagerKeyInitiatePairing)
        
    }
    
}


