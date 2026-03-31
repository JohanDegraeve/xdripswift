import Foundation

// MARK: - conform to M5StackBluetoothTransmitterDelegate

extension BluetoothPeripheralManager: M5StackBluetoothTransmitterDelegate {
    
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        m5Stack.batteryLevel = level
        
    }
    
    /// did the app successfully authenticate towards M5Stack, if no, then disconnect will be done
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in authentication with success = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info, success.description)
        
        // if authentication not successful then disconnect and don't reconnect, user should verify password or reset the M5Stack, disconnect and set shouldconnect to false, permenantly (ie store in core data)
        // disconnection is done because maybe another device is trying to connect to the M5Stack, need to make it free
        // also set shouldConnect to false (note that this is also done in M5StackViewController if an instance of that exists, no issue, shouldConnect will be set to false two times
        if !success {
            
            // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
            guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
            
            // don't try to reconnect after disconnecting
            m5Stack.blePeripheral.shouldconnect = false
            
            // store in core data
            coreDataManager.saveChanges()
            
            // disconnect
            disconnect(fromBluetoothPeripheral: m5Stack)
            
        }
    }
    
    /// there's no ble password set, user should set it in the settings - disconnect will be called, shouldconnect is set to false
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in blePasswordMissing", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        // don't try to reconnect after disconnecting
        m5Stack.blePeripheral.shouldconnect = false
        
        // store in core data
        coreDataManager.saveChanges()
        
        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)
        
    }
    
    /// if a new ble password is received from M5Stack
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in newBlePassWord, storing the password in M5Stack", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and also the bluetoothPeripheral and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        // possibily this is a new scanned m5stack, calling coreDataManager.saveChanges() but still the user may be in M5stackviewcontroller and decide not to save the m5stack, bad luck
        m5Stack.blepassword = newBlePassword
        
        coreDataManager.saveChanges()
        
    }
    
    /// it's an M5Stack without password configured in the ini file. xdrip app has been requesting temp password to M5Stack but this was already done once. M5Stack needs to be reset. - disconnect will be called, shouldconnect is set to false
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        trace("in m5StackResetRequired", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        // should not try to reconnect, wait till user decide to push the "always connect button"
        m5Stack.blePeripheral.shouldconnect = false
        coreDataManager.saveChanges()
        
        // disconnect
        disconnect(fromBluetoothPeripheral: m5Stack)
        
    }
    
    /// M5Stack is asking for an update of all parameters, send them
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter) else {
            trace("in isAskingForAllParameters, could not find index of bluetoothTransmitter, looks like a coding error", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
            return
        }
        
        // send all parameters, if successful, then for this m5Stack we can set parameterUpdateNeeded to false
        if sendAllParametersToM5Stack(to: m5StackBluetoothTransmitter) {
            (bluetoothPeripherals[index] as? M5Stack)?.blePeripheral.parameterUpdateNeededAtNextConnect = false
        } else {
            // failed, so we need to set parameterUpdateNeeded to true, so that next time it connects we will send all parameters
            (bluetoothPeripherals[index] as? M5Stack)?.blePeripheral.parameterUpdateNeededAtNextConnect = true
        }
        
    }
    
    /// will be called if M5Stack is connected, and authentication was successful, BluetoothPeripheralManager can start sending data like parameter updates or bgreadings
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // should find the m5StackBluetoothTransmitter in bluetoothTransmitters and it should be an M5Stack
        guard let index = bluetoothTransmitters.firstIndex(of: m5StackBluetoothTransmitter), let m5Stack = bluetoothPeripherals[index] as? M5Stack else {return}
        
        // if the M5Stack needs new parameters, then send them
        if m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect {
            
            // send all parameters
            if sendAllParametersToM5Stack(to: m5StackBluetoothTransmitter) {
                m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = false
            }
            
        }
        
        // send latest reading
        sendLatestReading(to: m5Stack)
        
    }
    
    // MARK: - private functions related to M5Stack
    
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
            trace("in sendAllParameters, bluetoothTransmitter is not ready to receive data", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
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
        
        // send connectToWiFi
        if !m5StackBluetoothTransmitter.writeConnectToWiFi(connect: m5Stack.connectToWiFi) {success = false}
        
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
        if let url = UserDefaults.standard.nightscoutUrl {
            if !m5StackBluetoothTransmitter.writeNightscoutUrl(url: url) {success = false}
        }
        
        // send nightscout token
        if let token = UserDefaults.standard.nightscoutAPIKey {
            if !m5StackBluetoothTransmitter.writeNightscoutAPIKey(apiKey: token) {success = false}
        }
        
        // return success
        return success
    }
    
    
}
