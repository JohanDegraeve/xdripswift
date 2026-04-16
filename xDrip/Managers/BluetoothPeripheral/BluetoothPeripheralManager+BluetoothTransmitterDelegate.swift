import UIKit
import CoreBluetooth
import AVFoundation
import AudioToolbox

extension BluetoothPeripheralManager: BluetoothTransmitterDelegate {

    /// because extension dont allow var's, this is a workaround as explained here https://medium.com/@valv0/computed-properties-and-extensions-a-pure-swift-approach-64733768112c
    private struct PropertyHolder {
        
        /// timestamp of last notification for pairing
        static var timeStampLastNotificationForPairing:Date?

        /// timer used when asking the transmitter to initiate pairing. The user is waiting for the response, if the response from the transmitter doesn't come within a few seconds, then we'll inform the user
        static var transmitterPairingResponseTimer:Timer?

    }
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - initiate pairing
    static let applicationManagerKeyInitiatePairing = "RootViewController-InitiatePairing"
    
    /// Transmitter is calling this delegate function to indicate that bluetooth pairing is needed. If the app is in the background, the user will be informed, after opening the app a pairing request will be initiated. if the app is in the foreground, the pairing request will be initiated immediately
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
        
        trace("transmitter needs pairing", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        if let timeStampLastNotificationForPairing = PropertyHolder.timeStampLastNotificationForPairing {
            
            // check timestamp of last notification, if too soon then return
            if Int(abs(timeStampLastNotificationForPairing.timeIntervalSinceNow)) < ConstantsBluetoothPairing.minimumTimeBetweenTwoPairingNotificationsInSeconds {
                return
            }
        }
        
        // set timeStampLastNotificationForPairing
        PropertyHolder.timeStampLastNotificationForPairing = Date()
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing])
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NnotificationContent title
        notificationContent.title = Texts_Common.warning
        
        notificationContent.body = Texts_HomeView.transmitterNotPaired
        
        // add sound
        notificationContent.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(""))
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable add notification request : transmitter needs pairing Notification Request, error :  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
        
        // vibrate
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
        // add closure to ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground so that if user opens the app, the pairing request will be initiated. This can be done only if the app is opened within 60 seconds.
        // If the app is already in the foreground, then userNotificationCenter willPresent will be called, in this function the closure will be removed immediately, and the pairing request will be called. As a result, if the app is in the foreground, the user will not see (or hear) any notification, but the pairing will be initiated
        
        // max timestamp when notification was fired - connection stays open for 1 minute, taking 1 second as margin
        let maxTimeUserCanOpenApp = Date(timeIntervalSinceNow: TimeInterval(Double(ConstantsDexcomG5.maxTimeToAcceptPairing) - 1.0))
        
        // we will not just count on it that the user will click the notification to open the app (assuming the app is in the background, if the app is in the foreground, then we come in another flow)
        // whenever app comes from-back to foreground, updateLabelsAndChart needs to be called
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: BluetoothPeripheralManager.applicationManagerKeyInitiatePairing, closure: {
            
            // first of all reremove from application key manager
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: BluetoothPeripheralManager.applicationManagerKeyInitiatePairing)
            
            // first remove existing notification if any
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing])
            
            // if it was too long since notification was fired, then forget about it - inform user that it's too late
            if Date() > maxTimeUserCanOpenApp {
                trace("in cgmTransmitterNeedsPairing, user opened the app too late", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.transmitterPairingTooLate, actionHandler: nil)
                
                self.uIViewController.present(alert, animated: true, completion: nil)
                
                return
            }
            
            // initiate the pairing
            self.initiateTransmitterPairing(bluetoothTransmitter: bluetoothTransmitter)
            
        })
        
        // need to temporary store the bluetooth transmitter that needs the pairing, user will now open the app, pairing will then be initiated
        bluetoothTransmitterThatNeedsPairing = bluetoothTransmitter
        
    }

    func successfullyPaired() {
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing])
        
        // invalidate transmitterPairingResponseTimer
        if let transmitterPairingResponseTimer = PropertyHolder.transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
        
        // inform user
        let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.transmitterPairingSuccessful, actionHandler: nil)
        
        uIViewController.present(alert, animated: true, completion: nil)
        
    }

    
    func pairingFailed() {
        // this should be the consequence of the user not accepting the pairing request, there's no need to inform the user
        // invalidate transmitterPairingResponseTimer
        if let transmitterPairingResponseTimer = PropertyHolder.transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
    }
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        // before exiting save the changes
        defer {
            coreDataManager.saveChanges()
        }

        /// helper function : if bluetoothTransmitter is a CGMTransmitter and if it's a new one (ie address is different than currentCgmTransmitterAddress then call cgmTransmitterChanged
        let checkCurrentCGMTransmitterHelper = {
            
            // if it's a CGMTransmitter and if it's a new one then call cgmTransmitterChanged,
            if bluetoothTransmitter is CGMTransmitter, bluetoothTransmitter.deviceAddress != self.currentCgmTransmitterAddress {
                
                trace("    calling cgmTransmitterChanged", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
                
                // this will implicitly call cgmTransmitterChanged
                self.currentCgmTransmitterAddress = bluetoothTransmitter.deviceAddress
                
            }
            
        }
        
        // if tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is nil, then this is a connection to an already known/stored BluetoothTransmitter.
        guard let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral else {
            
            // Need to call checkCurrentCGMTransmitterHelper
            checkCurrentCGMTransmitterHelper()
            
            // set lastConnectionStatusChangeTimeStamp in blePeripheral to now
            if let bluetoothPeripheral = getBluetoothPeripheral(for: bluetoothTransmitter) {
                bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
            }
            
            return
            
        }
        
        // check that address and name are not nil, otherwise this looks like a coding error
        guard let deviceAddressNewTransmitter = bluetoothTransmitter.deviceAddress, let deviceNameNewTransmitter = bluetoothTransmitter.deviceName else {
            
            trace("in didConnect, address or name of new transmitter is nil, looks like a coding error", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .error)
            
            return
            
        }
        
        // check that tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral and the bluetoothTransmitter to which connection is made are actually the same objects, otherwise it's a connection that is made to a already known/stored BluetoothTransmitter
        guard tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral == bluetoothTransmitter else {
            
            trace("in didConnect, tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is not nil and not equal to  bluetoothTransmitter", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
            
            // Need to call checkCurrentCGMTransmitterHelper
            checkCurrentCGMTransmitterHelper()
            
            // set lastConnectionStatusChangeTimeStamp in blePeripheral to now
            if let bluetoothPeripheral = getBluetoothPeripheral(for: bluetoothTransmitter) {
                bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
            }
            
            return
            
        }
        
        // check that it's a peripheral for which we don't know yet the address
        for bluetoothPeripheral in bluetoothPeripherals {
            
            if bluetoothPeripheral.blePeripheral.address == deviceAddressNewTransmitter {
                
                trace("in didConnect, transmitter address already known. Treating as existing device, continuing setup (no disconnect)", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)

                // This is an already known BluetoothTransmitter. Do not disconnect, avoid creating a duplicate entry.
                // Clear the temporary scanning transmitter so we do not go through the "new device" creation path below.
                self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = nil

                // Ensure current CGM transmitter address is set if needed.
                checkCurrentCGMTransmitterHelper()

                // Update the existing peripheral's last connection status change timestamp to now.
                bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()

                // Continue normal flow without creating a new BluetoothPeripheral and without disconnecting.
                return
                
            }
        }
        
        // it's a new peripheral that we will store. No need to continue scanning
        bluetoothTransmitter.stopScanning()
        
        trace("in didconnect to, going to create a new bluetoothperipheral", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        // create bluetoothPeripheral
        let newBluetoothPeripheral = getTransmitterType(for: tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral).createNewBluetoothPeripheral(withAddress: deviceAddressNewTransmitter, withName: deviceNameNewTransmitter, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

        // bluetoothTransmitter has initially been created with webOOPEnabled = false (possibily it's not even a CGM transmitter
        // if it's a CGM transmitter being created here, then we need to reassign webOOPEnabled to the value in the blePeripheral
        // possibly webOOPEnabled is false, because user sees the option to enable/disable weboop if the transmitter is not connected. So user might have disabled weboop. So as soon as connected, check if nonweboop is allowed
        //  if not, then set weboopenabled to true
        if let bluetoothTransmitterAsCGM = bluetoothTransmitter as? CGMTransmitter {
            
            if !bluetoothTransmitterAsCGM.nonWebOOPAllowed() {
                
                newBluetoothPeripheral.blePeripheral.webOOPEnabled = true
                
                bluetoothTransmitterAsCGM.setWebOOPEnabled(enabled: true)
                
            } else {

                bluetoothTransmitterAsCGM.setWebOOPEnabled(enabled: newBluetoothPeripheral.blePeripheral.webOOPEnabled)

            }
            
        }
        
        trace("in didconnect to, created a new bluetoothperipheral", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        // add new bluetoothPeripheral and bluetoothTransmitter to array of bluetoothPeripherals and bluetoothTransmitters
        bluetoothTransmitters.insert(bluetoothTransmitter, at: insertInBluetoothPeripherals(bluetoothPeripheral: newBluetoothPeripheral))
        
        // call the callback function
        if let callBackAfterDiscoveringDevice = callBackAfterDiscoveringDevice {
            callBackAfterDiscoveringDevice(newBluetoothPeripheral)
            self.callBackAfterDiscoveringDevice = nil
        }
        
        // Need to call checkCurrentCGMTransmitterHelper
        checkCurrentCGMTransmitterHelper()
        
        // set lastConnectionStatusChangeTimeStamp in blePeripheral to now
        newBluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
        
        // call sendSettings function
        newBluetoothPeripheral.sendSettings(to: bluetoothTransmitter)
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        
        trace("in deviceDidUpdateBluetoothState", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        if bluetoothTransmitter.deviceAddress == nil {
            
            /// this bluetoothTransmitter is created to start scanning for a new, unknown bluetoothtransmitter, so start scanning
            let scanningResult = bluetoothTransmitter.startScanning()
            
            if let callBackForScanningResult = self.callBackForScanningResult {
                
                callBackForScanningResult(scanningResult)
                
            }
            
        }
        
        // disconnect doesn't get triggered if status changes to off
        // so if the device already has a lastConnectionStatusChangeTimeStamp and if new state = poweredoff then set lastConnectionStatusChangeTimeStamp to current date
        if let bluetoothPeripheral = getBluetoothPeripheral(for: bluetoothTransmitter) {
            if bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp != nil && state == .poweredOff {
                bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
            }
        }
        
        coreDataManager.saveChanges()
        
    }
    
    func error(message: String) {
        
        trace("received error = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info, message)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        trace("in didDisconnectFrom", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .debug)
        
        // set lastConnectionStatusChangeTimeStamp in blePeripheral to now
        if let bluetoothPeripheral = getBluetoothPeripheral(for: bluetoothTransmitter) {
            bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
        }

        coreDataManager.saveChanges()
        
    }
    
    /// will call bluetoothTransmitter.initiatePairing() - also sets timer, if no successful pairing within a few seconds, then info will be given to user asking to wait another few minutes
    private func initiateTransmitterPairing(bluetoothTransmitter: BluetoothTransmitter) {
        
        // initiate the pairing
        bluetoothTransmitter.initiatePairing()
        
        // invalide the timer, if it exists
        if let transmitterPairingResponseTimer = PropertyHolder.transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
        
        // create and schedule timer
        PropertyHolder.transmitterPairingResponseTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(informUserThatPairingTimedOut), userInfo: nil, repeats: false)
        
    }

    // inform user that pairing request timed out
    @objc private func informUserThatPairingTimedOut() {
        
        let alert = UIAlertController(title: Texts_Common.warning, message: "time out", actionHandler: nil)
        
        uIViewController.present(alert, animated: true, completion: nil)
        
    }

    // to confirm to protocol BluetoothPeripheralDelegate
    func heartBeat() {
        // bluetooth peripheral's heart is beating
        // if a heartBeat function is set, then call it
        if let heartBeatFunction = heartBeatFunction {
            heartBeatFunction()
        }
    }

}

