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
    
    /// if scan is called, and a connection is successfully made to a new device, then a new M5Stack must be created, and this function will be called. It is owned by the UIViewController that calls the scan function
    private var callBackAfterDiscoveringDevice: ((M5Stack) -> Void)?
    
    /// if scan is called, an instance of M5StackBluetoothTransmitter is created with address and name. The new instance will be assigned to this variable, temporary, until a connection is made
    private var tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack: M5StackBluetoothTransmitter?
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        
        // initialize properties
        self.coreDataManager = coreDataManager
        self.m5StackAccessor = M5StackAccessor(coreDataManager: coreDataManager)
        
        super.init()
        
        // initialize m5Stacks
        let m5Stacks = m5StackAccessor.getM5Stacks()
        for m5Stack in m5Stacks {
            if m5Stack.shouldconnect {
                // create an instance of M5StackBluetoothTransmitter, M5StackBluetoothTransmitter will automatically try to connect to the M5Stack with the address that is stored in m5Stack
                self.m5StacksBlueToothTransmitters[m5Stack] = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self)
            } else {
                // shouldn't connect, so don't create an instance of M5StackBluetoothTransmitter
                self.m5StacksBlueToothTransmitters[m5Stack] = (M5StackBluetoothTransmitter?).none
            }
        }

    }
}

extension M5StackManager: M5StackManaging {
    
    
    /// to scan for a new M5SStack - callback will be called when a new M5Stack is found and connected
    func startScanningForNewDevice(callback: @escaping (M5Stack) -> Void) {
        
        callBackAfterDiscoveringDevice = callback
        
        tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = M5StackBluetoothTransmitter(m5Stack: nil, delegateFixed: self)
        
        _ = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack?.startScanning()
        
    }
    
    /// stops scanning for new device
    func stopScanningForNewDevice() {
        
        if let tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack {
            
            tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack.stopScanning()
            
            self.tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = nil
            
        }
    }
    
    /// will call coreDataManager.saveChanges
    func save() {
        coreDataManager.saveChanges()
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
                let newBlueToothTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self)
                
                m5StacksBlueToothTransmitters[m5Stack] = newBlueToothTransmitter

            }
            
        } else {
            
            // I don't think this code will be used, because value m5Stack should always be in m5StacksBlueToothTransmitters, anyway let's add it
            let newBlueToothTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self)
            
            m5StacksBlueToothTransmitters[m5Stack] = newBlueToothTransmitter
            
        }
    }
    
    /// disconnect from M5Stack
    func disconnect(fromM5stack m5Stack: M5Stack) {
        
        if let bluetoothTransmitter = m5StacksBlueToothTransmitters[m5Stack] {
            if let bluetoothTransmitter =  bluetoothTransmitter {
                bluetoothTransmitter.disconnect()
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
            let newTransmitter = M5StackBluetoothTransmitter(m5Stack: m5Stack, delegateFixed: self)
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
}

extension M5StackManager: M5StackBluetoothDelegate {
    
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
                    tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack = M5StackBluetoothTransmitter(m5Stack: nil, delegateFixed: self)
                    _ = tempM5StackBlueToothTransmitterWhileScanningForNewM5Stack?.startScanning()

                    return
                    
                }
            }
            
            // looks like we haven't found the address in list of known M5Stacks, so it's a new M5Stack, stop the scanning
            bluetoothTransmitter.stopScanning()
            
            // create a new M5Stack with new peripheral's address and name
            let newM5Stack = M5Stack(address: address, name: name, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            
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

    /// did the app successfully authenticate towards M5Stack
    ///
    /// in case of failure, then user should set the correct password in the M5Stack ini file, or, in case there's no password set in the ini file, switch off and on the M5Stack
    func authentication(success: Bool, forM5Stack m5Stack:M5Stack) {
        trace("in authentication with success = %{public}@", log: self.log, type: .info, success.description)
    }
    
    /// there's no ble password set, user should set it in the settings
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in blePasswordMissing", log: self.log, type: .info)
    }

    /// it's an M5Stack without password configired in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset
    func m5StackResetRequired(forM5Stack m5Stack:M5Stack) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in m5StackResetRequired", log: self.log, type: .info)
    }

    /// did disconnect from M5Stack
    func didDisconnect(forM5Stack m5Stack:M5Stack) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in didDisconnect", log: self.log, type: .info)
    }

}

