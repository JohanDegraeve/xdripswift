import Foundation
import os
import CoreBluetooth
import CoreData
import UIKit

class BluetoothPeripheralManager: NSObject {
    
    // MARK: - public properties
    
    /// - all currently known BluetoothPeripheral's (MStacks, cgmtransmitters, watlaa , ...)
    /// - stored by type of bluetoothperipherals. In BluetoothPeripheralType, if the first type is M5Stack, then the first set of peripherals in the array will be all M5Stacks, and so on
    public var bluetoothPeripherals: [BluetoothPeripheral] = []

    /// the bluetoothTransmitter's, array must have the same size as bluetoothPeripherals. For each element in bluetoothPeripherals, there's an element at the same index in bluetoothTransmitters, which may be nil. nil value means user selected not to connect
    public var bluetoothTransmitters: [BluetoothTransmitter?] = []
    
    /// for logging
    public var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralManager)
    
    /// if scan is called, an instance of M5StackBluetoothTransmitter is created with address and name. The new instance will be assigned to this variable, temporary, until a connection is made
    public var tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral: BluetoothTransmitter?

    /// to be called with result of StartScanning
    public var callBackForScanningResult: ((BluetoothTransmitter.startScanningResult) -> Void)?
    
    /// if scan is called, and a connection is successfully made to a new device, then a new M5Stack must be created, and this function will be called. It is owned by the UIViewController that calls the scan function
    public var callBackAfterDiscoveringDevice: ((BluetoothPeripheral) -> Void)?

    /// will be used to present alerts, for example pairing failed
    public let uIViewController: UIViewController
    
    /// bluetoothtransmitter may need pairing, but app is in background. Notification will be sent to user, user will open the app, at that moment pairing can happen. variable bluetoothTransmitterThatNeedsPairing will temporary store the BluetoothTransmitter that needs the pairing
    public var bluetoothTransmitterThatNeedsPairing: BluetoothTransmitter?
    
    /// when xdrip connects to a BluetoothTransmitter that is also CGMTransmitter, then we'll call this function with the BluetoothTransmitter as argument. This function is defined by RootViewController, it will allow the RootViewController to set the CGMTransmitter, calibrator ...
    public var cgmTransmitterInfoChanged: () -> ()
    
    /// address of the last active cgmTransmitter
    ///
    /// this is to keep track of changes in cgmTransmitter (ie if switching from transmitter A to B)
    public var currentCgmTransmitterAddress: String? {
        didSet(newValue) {
            if newValue != currentCgmTransmitterAddress {
                cgmTransmitterInfoChanged()
            }
        }
    }
    
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
    ///     - cgmTransmitterInfoChanged : to be called when currently used cgmTransmitter changes or is set to nil
    init(coreDataManager: CoreDataManager, cgmTransmitterDelegate: CGMTransmitterDelegate, uIViewController: UIViewController, cgmTransmitterInfoChanged: @escaping () -> ()) {
        
        // initialize properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.cgmTransmitterDelegate = cgmTransmitterDelegate
        self.cgmTransmitterInfoChanged = cgmTransmitterInfoChanged
        self.bLEPeripheralAccessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
        self.uIViewController = uIViewController
        
        super.init()
        
        // loop through blePeripherals
        for blePeripheral in bLEPeripheralAccessor.getBLEPeripherals() {

            // each time the app launches, we will send the parameters to all BluetoothPeripherals (only used for M5Stack for now)
            blePeripheral.parameterUpdateNeededAtNextConnect = true

            // need to initialize all types of bluetoothperipheral
            // using enum here to make sure future types are not forgotten
            for bluetoothPeripheralType in BluetoothPeripheralType.allCases {

                switch bluetoothPeripheralType {
                    
                case .M5StackType:
                    // no seperate handling needed for M5StickC because M5StickC is stored in coredata as M5Stack objecct, so it will be handled when going through case M5StackType
                    // in other words this case will never be applicable
                    break
                    
                case .M5StickCType:
                    if let m5Stack = blePeripheral.m5Stack {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: m5Stack)
                        
                        if m5Stack.blePeripheral.shouldconnect {
                            
                            // create an instance of M5StackBluetoothTransmitter, M5StackBluetoothTransmitter will automatically try to connect to the M5Stack with the address that is stored in m5Stack
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.insert(M5StackBluetoothTransmitter(address: m5Stack.blePeripheral.address, name: m5Stack.blePeripheral.name, bluetoothTransmitterDelegate: self, m5StackBluetoothTransmitterDelegate: self, blePassword: m5Stack.blepassword, bluetoothPeripheralType: m5Stack.isM5StickC ? .M5StickCType : .M5StackType), at: index)
                            
                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }
                        
                    }
                    
                case .watlaaMaster:
                    
                    if let watlaa = blePeripheral.watlaa {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: watlaa)
                        
                        if watlaa.blePeripheral.shouldconnect {
                            
                            // create an instance of WatlaaBluetoothTransmitter, WatlaaBluetoothTransmitter will automatically try to connect to the watlaa with the address that is stored in watlaa
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.insert(WatlaaBluetoothTransmitterMaster(address: watlaa.blePeripheral.address, name: watlaa.blePeripheral.name, cgmTransmitterDelegate: cgmTransmitterDelegate, bluetoothTransmitterDelegate: self, watlaaBluetoothTransmitterDelegate: self, bluetoothPeripheralType: .watlaaMaster), at: index)
                            
                            // if watlaa is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                            if bluetoothPeripheralType.category() == .CGM {
                                currentCgmTransmitterAddress = blePeripheral.address
                            }
                        
                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }

                    }
                    
                case .DexcomG5Type:
                
                    if let dexcomG5 = blePeripheral.dexcomG5 {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: dexcomG5)
                        
                        if dexcomG5.blePeripheral.shouldconnect {
                            
                            if let transmitterId = dexcomG5.blePeripheral.transmitterId {

                                // create an instance of WatlaaBluetoothTransmitter, WatlaaBluetoothTransmitter will automatically try to connect to the watlaa with the address that is stored in watlaa
                                // add it to the array of bluetoothTransmitters
                                bluetoothTransmitters.insert(CGMG5Transmitter(address: dexcomG5.blePeripheral.address, name: dexcomG5.blePeripheral.name, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMG5TransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate), at: index)

                                // if DexcomG5Type is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                                if bluetoothPeripheralType.category() == .CGM {
                                    currentCgmTransmitterAddress = blePeripheral.address
                                }
                                
                            }
                            
                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }
                        
                    }
                    
                case .BubbleType:
                    
                    if let bubble = blePeripheral.bubble {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: bubble)
                        
                        if bubble.blePeripheral.shouldconnect {
                            
                            // create an instance of BubbleBluetoothTransmitter, BubbleBluetoothTransmitter will automatically try to connect to the Bubble with the address that is stored in bubble
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.insert(CGMBubbleTransmitter(address: bubble.blePeripheral.address, name: bubble.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMBubbleTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: bubble.timeStampLastBgReading, sensorSerialNumber: bubble.blePeripheral.sensorSerialNumber, webOOPEnabled: bubble.blePeripheral.webOOPEnabled, oopWebSite: bubble.blePeripheral.oopWebSite, oopWebToken: bubble.blePeripheral.oopWebToken), at: index)
                            
                            // if BubbleType is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                            if bluetoothPeripheralType.category() == .CGM {
                                currentCgmTransmitterAddress = blePeripheral.address
                            }

                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }
                        
                    }
                    
                case .MiaoMiaoType:
                    
                    if let miaoMiao = blePeripheral.miaoMiao {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: miaoMiao)
                        
                        if miaoMiao.blePeripheral.shouldconnect {
                            
                            // create an instance of CGMMiaoMiaoTransmitter, CGMMiaoMiaoTransmitter will automatically try to connect to the Bubble with the address that is stored in bubble
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.insert(CGMMiaoMiaoTransmitter(address: miaoMiao.blePeripheral.address, name: miaoMiao.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMMiaoMiaoTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: miaoMiao.timeStampLastBgReading, sensorSerialNumber: miaoMiao.blePeripheral.sensorSerialNumber, webOOPEnabled: miaoMiao.blePeripheral.webOOPEnabled, oopWebSite: miaoMiao.blePeripheral.oopWebSite, oopWebToken: miaoMiao.blePeripheral.oopWebToken), at: index)
                            
                            // if BubbleType is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                            if bluetoothPeripheralType.category() == .CGM {
                                currentCgmTransmitterAddress = blePeripheral.address
                            }
                            
                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }
                        
                    }
                 
                case .GNSentryType:
                    
                    if let gNSEntry = blePeripheral.gNSEntry {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: gNSEntry)
                        
                        if gNSEntry.blePeripheral.shouldconnect {
                            
                            // create an instance of CGMGNSEntryTransmitter, CGMGNSEntryTransmitter will automatically try to connect to the Bubble with the address that is stored in bubble
                            // add it to the array of bluetoothTransmitters
                            bluetoothTransmitters.insert(CGMGNSEntryTransmitter(address: gNSEntry.blePeripheral.address, name: gNSEntry.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMGNSEntryTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: gNSEntry.timeStampLastBgReading), at: index)
                            
                            // if BubbleType is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                            if bluetoothPeripheralType.category() == .CGM {
                                currentCgmTransmitterAddress = blePeripheral.address
                            }
                            
                        } else {
                            
                            // bluetoothTransmitters array (which shoul dhave the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
                        }
                        
                    }
                    
                case .BluconType:
                    
                    if let blucon = blePeripheral.miaoMiao {
                        
                        // add it to the list of bluetoothPeripherals
                        let index = insertInBluetoothPeripherals(bluetoothPeripheral: blucon)
                        
                        if blucon.blePeripheral.shouldconnect {
                            
                            if let transmitterId = blucon.blePeripheral.transmitterId {
                                
                                // create an instance of CGMBluconTransmitter, CGMBluconTransmitter will automatically try to connect to the Bluon with the address that is stored in blucon
                                // add it to the array of bluetoothTransmitters
                                bluetoothTransmitters.insert(CGMBluconTransmitter(address: blucon.blePeripheral.address, name: blucon.blePeripheral.name, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMBluconTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: blucon.timeStampLastBgReading, sensorSerialNumber: blucon.blePeripheral.sensorSerialNumber), at: index)
                                
                                // if bluconType is of type CGM, then assign the address to currentCgmTransmitterAddress, there shouldn't be any other bluetoothPeripherals of type .CGM with shouldconnect = true
                                if bluetoothPeripheralType.category() == .CGM {
                                    currentCgmTransmitterAddress = blePeripheral.address
                                }
                                
                            }
                            
                        } else {
                            
                            // bluetoothTransmitters array (which should have the same number of elements as bluetoothPeripherals) needs to have an empty row for the transmitter
                            bluetoothTransmitters.insert(nil, at: index)
                            
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
                    
                case .DexcomG5Type, .BubbleType, .MiaoMiaoType, .BluconType, .GNSentryType:
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
                    
                case .BubbleType:
                    
                    if let bubble = bluetoothPeripheral as? Bubble {
                    
                        if let cgmTransmitterDelegate = cgmTransmitterDelegate  {
                            
                            newTransmitter = CGMBubbleTransmitter(address: bubble.blePeripheral.address, name: bubble.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMBubbleTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: bubble.blePeripheral.sensorSerialNumber, webOOPEnabled: bubble.blePeripheral.webOOPEnabled, oopWebSite: bubble.blePeripheral.oopWebSite, oopWebToken: bubble.blePeripheral.oopWebSite)
                            
                        } else {
                            
                            trace("in getBluetoothTransmitter, case BubbleType but cgmTransmitterDelegate is nil, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                            
                        }
                    }
                    
                case .MiaoMiaoType:
                    
                    if let miaoMiao = bluetoothPeripheral as? MiaoMiao {
                        
                        if let cgmTransmitterDelegate = cgmTransmitterDelegate  {
                            
                            newTransmitter = CGMMiaoMiaoTransmitter(address: miaoMiao.blePeripheral.address, name: miaoMiao.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMMiaoMiaoTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: miaoMiao.blePeripheral.sensorSerialNumber, webOOPEnabled: miaoMiao.blePeripheral.webOOPEnabled, oopWebSite: miaoMiao.blePeripheral.oopWebSite, oopWebToken: miaoMiao.blePeripheral.oopWebSite)
                            
                        } else {
                            
                            trace("in getBluetoothTransmitter, case MiaoMiaoType but cgmTransmitterDelegate is nil, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                            
                        }
                    }
                    
                case .GNSentryType:
                    
                    if let gNSEntry = bluetoothPeripheral as? GNSEntry {
                        
                        if let cgmTransmitterDelegate = cgmTransmitterDelegate  {
                            
                            newTransmitter = CGMGNSEntryTransmitter(address: gNSEntry.blePeripheral.address, name: gNSEntry.blePeripheral.name, bluetoothTransmitterDelegate: self, cGMGNSEntryTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil)
                            
                        } else {
                            
                            trace("in getBluetoothTransmitter, case GNSEntryType but cgmTransmitterDelegate is nil, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                            
                        }
                    }
                    
                case .BluconType:
                    
                    if let blucon = bluetoothPeripheral as? Blucon {
                        
                        if let transmitterId = blucon.blePeripheral.transmitterId, let cgmTransmitterDelegate = cgmTransmitterDelegate {
                            
                            newTransmitter = CGMBluconTransmitter(address: blucon.blePeripheral.address, name: blucon.blePeripheral.name, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMBluconTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: blucon.blePeripheral.sensorSerialNumber)
                            
                        } else {
                            
                            trace("in getBluetoothTransmitter, case BluconType but transmitterId is nil or cgmTransmitterDelegate is nil, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
                            
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
                
            case .BubbleType:
                if bluetoothTransmitter is CGMBubbleTransmitter {
                    return .BubbleType
                }
                
            case .MiaoMiaoType:
                if bluetoothTransmitter is CGMMiaoMiaoTransmitter {
                    return .MiaoMiaoType
                }
                
            case .BluconType:
                if bluetoothTransmitter is CGMBluconTransmitter {
                    return .BluconType
                }
                
            case .GNSentryType:
                if bluetoothTransmitter is CGMBluconTransmitter {
                    return .GNSentryType
                }
                
            }
            
        }
        
        // normally we shouldn't get here, but we need to return a value
        fatalError("BluetoothPeripheralManager :  getTransmitterType did not find a valid type")
        
    }

    /// - parameters:
    ///     - transmitterId : only for transmitter types that need it (at the moment only Dexcom and Blucon)
    public func createNewTransmitter(type: BluetoothPeripheralType, transmitterId: String?) -> BluetoothTransmitter {
        
        switch type {
            
        case .M5StackType, .M5StickCType:
            
            return M5StackBluetoothTransmitter(address: nil, name: nil, bluetoothTransmitterDelegate: self, m5StackBluetoothTransmitterDelegate: self, blePassword: UserDefaults.standard.m5StackBlePassword, bluetoothPeripheralType: type)
            
        case .watlaaMaster:
            
            return WatlaaBluetoothTransmitterMaster(address: nil, name: nil, cgmTransmitterDelegate: cgmTransmitterDelegate, bluetoothTransmitterDelegate: self, watlaaBluetoothTransmitterDelegate: self, bluetoothPeripheralType: type)
            
        case .DexcomG5Type:
            
            guard let transmitterId = transmitterId, let cgmTransmitterDelegate =  cgmTransmitterDelegate else {
                fatalError("in createNewTransmitter, type DexcomG5Type, transmitterId is nil or cgmTransmitterDelegate is nil")
            }
            
            return CGMG5Transmitter(address: nil, name: nil, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMG5TransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate)
            
        case .BubbleType:
            
            guard let cgmTransmitterDelegate =  cgmTransmitterDelegate else {
                fatalError("in createNewTransmitter, type DexcomG5Type, cgmTransmitterDelegate is nil")
            }
            
            return CGMBubbleTransmitter(address: nil, name: nil, bluetoothTransmitterDelegate: self, cGMBubbleTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: nil, webOOPEnabled: nil, oopWebSite: nil, oopWebToken: nil)
            
        case .MiaoMiaoType:
            
            guard let cgmTransmitterDelegate = cgmTransmitterDelegate else {
                fatalError("in createNewTransmitter, MiaoMiaoType, cgmTransmitterDelegate is nil")
            }
            
            return CGMMiaoMiaoTransmitter(address: nil, name: nil, bluetoothTransmitterDelegate: self, cGMMiaoMiaoTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: nil, webOOPEnabled: nil, oopWebSite: nil, oopWebToken: nil)
            
        case .GNSentryType:
            
            guard let cgmTransmitterDelegate = cgmTransmitterDelegate else {
                fatalError("in createNewTransmitter, GNSEntryType, cgmTransmitterDelegate is nil")
            }
            
            return CGMGNSEntryTransmitter(address: nil, name: nil, bluetoothTransmitterDelegate: self, cGMGNSEntryTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil)
            
        case .BluconType:
            
            guard let transmitterId = transmitterId, let cgmTransmitterDelegate = cgmTransmitterDelegate else {
                fatalError("in createNewTransmitter, type BluconType, transmitterId is nil or cgmTransmitterDelegate is nil")
            }
            
            return CGMBluconTransmitter(address: nil, name: nil, transmitterID: transmitterId, bluetoothTransmitterDelegate: self, cGMBluconTransmitterDelegate: self, cGMTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: nil, sensorSerialNumber: nil)
            
        }
        
    }

    public func firstIndexInBluetoothPeripherals(bluetoothPeripheral: BluetoothPeripheral) -> Int? {
        return bluetoothPeripherals.firstIndex(where: {$0.blePeripheral.address == bluetoothPeripheral.blePeripheral.address})
    }

    /// - will insert bluetoothPeripheral in the array bluetoothPeripherals, and returns the index where it's been inserted.
    /// - it will be inserted in the correct location, ie depending on the BluetoothPeripheralType
    public func insertInBluetoothPeripherals(bluetoothPeripheral: BluetoothPeripheral) -> Int {
        
        /// start with assuming we'll insert at location 0
        var insertAt = 0
        
        /// index of bluetoothPeripheral's type in the enum BluetoothPeripheralType
        let typeIndex: Int =  bluetoothPeripheral.bluetoothPeripheralType().category().index()

        /// search for the first category which is higher ranked in the list (ie higher index) than typeIndex
        while insertAt < bluetoothPeripherals.count && typeIndex > bluetoothPeripherals[insertAt].bluetoothPeripheralType().category().index() {
            
            insertAt = insertAt + 1
        }
        
        if insertAt == bluetoothPeripherals.count {
            bluetoothPeripherals.append(bluetoothPeripheral)
        } else {
            bluetoothPeripherals.insert(bluetoothPeripheral, at: insertAt)
        }
        
        return insertAt
        
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
    
    /// checks if the bluetoothTransmitter is the currently assigned CGMTransmitter. If yes it means bluetoothTransmitter is a CGMTransmitter and has shouldconnect = true and device address should match
    /// - parameters:
    ///     - bluetoothTransmitter if nil then returnvalue is false
    private func transmitterIsCurrentlyUsedCGMTransmitter(bluetoothTransmitter: BluetoothTransmitter?) -> Bool {
        
        // assumption is that there can only be one bluetoothTransmitter that is of type CGMTransmitter and that has shouldconnect = true

        // check bluetoothTransmitter not nil, if nil return false
        guard let bluetoothTransmitter = bluetoothTransmitter else {return false}
        
        // if bluetoothTransmitter.deviceAddress matches currentCgmTransmitterAddress, then it's the cgm transmitter
        return bluetoothTransmitter.deviceAddress == currentCgmTransmitterAddress
        
    }
    
    private func  setTransmitterToNilAndCallcgmTransmitterInfoChangedIfNecessary(indexInBluetoothTransmittersArray index: Int) {
        
        // check if transmitter being deleted is the currently assigned CGMTransmitter and if yes call cgmTransmitterInfoChanged after setting bluetoothTransmitter to nil
        var callcgmTransmitterInfoChanged = false
        if transmitterIsCurrentlyUsedCGMTransmitter(bluetoothTransmitter: bluetoothTransmitters[index]) {
            callcgmTransmitterInfoChanged = true
        }
        
        // set bluetoothTransmitter to nil, this will also initiate a disconnect
        bluetoothTransmitters[index] = nil
        
        if callcgmTransmitterInfoChanged {
            
            // set currentCgmTransmitterAddress to nil, this will implicitly call cgmTransmitterInfoChanged
            currentCgmTransmitterAddress = nil
            
        }
        
    }
    
    /// helper function for extension BluetoothPeripheralManaging
    private func getCGMTransmitter(for bluetoothPeripheral: BluetoothPeripheral) -> CGMTransmitter? {
        
        if bluetoothPeripheral.bluetoothPeripheralType().category() == .CGM {
            
            if let cgmTransmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) as? CGMTransmitter {
                return cgmTransmitter
            }
        }
        
        return nil
        
    }

    // MARK:- override observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        guard let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else {return}
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnum {
            
        case UserDefaults.Key.m5StackWiFiName1, UserDefaults.Key.m5StackWiFiName2, UserDefaults.Key.m5StackWiFiName3, UserDefaults.Key.m5StackWiFiPassword1, UserDefaults.Key.m5StackWiFiPassword2, UserDefaults.Key.m5StackWiFiPassword3, UserDefaults.Key.nightScoutAPIKey, UserDefaults.Key.nightScoutUrl, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.m5StackBlePassword  :
            
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
                
                continue

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
                // none of the observed values needs to be sent to the watlaa
                break
                
            case .DexcomG5Type:
                // none of the observed values needs to be sent to the watlaa
                break
                
            case .BubbleType:
                // none of the observed values needs to be sent to the watlaa
                break
                
            case .MiaoMiaoType:
                // none of the observed values needs to be sent to the watlaa
                break
                
            case .BluconType:
                // none of the observed values needs to be sent to the watlaa
                break
                
            case .GNSentryType:
                // none of the observed values needs to be sent to the watlaa
                break
                
            }
            
        }
                
    }

}

// MARK: - conform to BluetoothPeripheralManaging

extension BluetoothPeripheralManager: BluetoothPeripheralManaging {
    
    func requestNewReading() {
        
        if let cgmTransmitter = getCGMTransmitter() {
            
            cgmTransmitter.requestNewReading()
        }
        
    }

    func getCGMTransmitter() -> CGMTransmitter? {
        
        for bluetoothTransmitter in bluetoothTransmitters {
            
            if transmitterIsCurrentlyUsedCGMTransmitter(bluetoothTransmitter: bluetoothTransmitter) {
                
                return bluetoothTransmitter as? CGMTransmitter
                
            }
            
        }
        
        return nil
        
    }
    
    func receivedNewValue(webOOPEnabled: Bool, for bluetoothPeripheral: BluetoothPeripheral) {
        
        if let cgmTransmitter = getCGMTransmitter(for: bluetoothPeripheral) {

            cgmTransmitter.setWebOOPEnabled(enabled: webOOPEnabled)
            
            // webOOPEnabled changed, initate a reading immediately should user gets either a new value or a calibration request, depending on value of webOOPEnabled
            cgmTransmitter.requestNewReading()
            
            // call cgmTransmitterInfoChanged
            cgmTransmitterInfoChanged()

        }
        
    }
    
    func receivedNewValue(oopWebSite: String?, for bluetoothPeripheral: BluetoothPeripheral) {
        
        /// if oopWebSite is nil, then there's no need to send that value to the transmitter, because this should only be the case if webOOPEnabled is false
        guard let oopWebSite = oopWebSite else {return}
        
        getCGMTransmitter(for: bluetoothPeripheral)?.setWebOOPSite(oopWebSite: oopWebSite)
        
        if let cgmTransmitter = getCGMTransmitter(for: bluetoothPeripheral) {

            cgmTransmitter.setWebOOPSite(oopWebSite: oopWebSite)
            
            // oopWebSite changed, initate a reading immediately should user gets either a new value or a calibration request, depending on value of webOOPEnabled
            cgmTransmitter.requestNewReading()

        }

    }
    
    func receivedNewValue(oopWebToken: String?, for bluetoothPeripheral: BluetoothPeripheral) {
        
        /// if oopWebToken is nil, then there's no need to send that value to the transmitter, because this should only be the case if oopWebToken is false
        guard let oopWebToken = oopWebToken else {return}
        
        if let cgmTransmitter = getCGMTransmitter(for: bluetoothPeripheral) {
            
            cgmTransmitter.setWebOOPToken(oopWebToken: oopWebToken)
            
            // oopWebToken changed, initate a reading immediately should user gets either a new value or a calibration request, depending on value of webOOPEnabled
            cgmTransmitter.requestNewReading()
            
        }

    }
    
    func startScanningForNewDevice(type: BluetoothPeripheralType, transmitterId: String?, callBackForScanningResult: ((BluetoothTransmitter.startScanningResult) -> Void)?, callback: @escaping (BluetoothPeripheral) -> Void)  {
        
        callBackAfterDiscoveringDevice = callback
        
        // create a temporary transmitter of requested type
        let newBluetoothTranmsitter = createNewTransmitter(type: type, transmitterId: transmitterId)
        
        tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = newBluetoothTranmsitter
        
        // start scanning
        let scanningResult = newBluetoothTranmsitter.startScanning()
        
        // temporary store callBackForScanningResult, will be used in deviceDidUpdateBluetoothState, when startScanning is called again
        self.callBackForScanningResult = callBackForScanningResult
        
        if let callBackForScanningResult = callBackForScanningResult {
            
            self.callBackForScanningResult = callBackForScanningResult
            
            callBackForScanningResult(scanningResult)
            
        }
        
    }
    
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
    
    func connect(to bluetoothPeripheral: BluetoothPeripheral) {
        
        // the trick : by calling bluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheral, createANewOneIfNecesssary: true), there's two cases
        // - either the bluetoothTransmitter already exists but not connected, it will be found in the call to bluetoothTransmitter and returned, then we connect to it
        // - either the bluetoothTransmitter doesn't exist yet. It will be created. We assum here that bluetoothPeripheral has a mac address, as a consequence the BluetoothTransmitter will automatically try to connect. Here we try to connect again, but that's no issue
        
        let transmitter = getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: true)
        
        transmitter?.connect()
        
    }
    
    func getBluetoothPeripheral(for bluetoothTransmitter: BluetoothTransmitter) -> BluetoothPeripheral? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: bluetoothTransmitter) else {return nil}
        
        return bluetoothPeripherals[index]
        
    }
    
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral) {
        
        // find the bluetoothPeripheral in array bluetoothPeripherals, if it's not there then this looks like a coding error
        guard let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) else {
            trace("in deleteBluetoothPeripheral but bluetoothPeripheral not found in bluetoothPeripherals, looks like a coding error ", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
            return
        }
        
        setTransmitterToNilAndCallcgmTransmitterInfoChangedIfNecessary(indexInBluetoothTransmittersArray: index)
        
        // delete in coredataManager
        coreDataManager.mainManagedObjectContext.delete(bluetoothPeripherals[index] as! NSManagedObject)

        // save in coredataManager
        coreDataManager.saveChanges()

        // remove bluetoothTransmitter and bluetoothPeripheral entry from the two arrays
        bluetoothTransmitters.remove(at: index)
        bluetoothPeripherals.remove(at: index)
        
    }
    
    func getBluetoothPeripherals() -> [BluetoothPeripheral] {
        
        return bluetoothPeripherals
        
    }
    
    func getBluetoothTransmitters() -> [BluetoothTransmitter] {
        
        var bluetoothTransmitters: [BluetoothTransmitter] = []
        
        for bluetoothTransmitter in self.bluetoothTransmitters {
            if let bluetoothTransmitter = bluetoothTransmitter {
                bluetoothTransmitters.append(bluetoothTransmitter)
            }
        }
        
        return bluetoothTransmitters
        
    }
    
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        if let index = firstIndexInBluetoothPeripherals(bluetoothPeripheral: bluetoothPeripheral) {
            
            setTransmitterToNilAndCallcgmTransmitterInfoChangedIfNecessary(indexInBluetoothTransmittersArray: index)
            
        }
    }
    
    func initiatePairing() {
        
        bluetoothTransmitterThatNeedsPairing?.initiatePairing()

        /// remove applicationManagerKeyInitiatePairing from application key manager - there's no need to initiate the pairing via this closure
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: BluetoothPeripheralManager.applicationManagerKeyInitiatePairing)
        
    }
    
}


