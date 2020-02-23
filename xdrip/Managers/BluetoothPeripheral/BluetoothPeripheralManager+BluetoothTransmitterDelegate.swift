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
        
        // max timestamp when notification was fired - connection stays open for 1 minute, taking 1 second as d
        let maxTimeUserCanOpenApp = Date(timeIntervalSinceNow: TimeInterval(ConstantsDexcomG5.maxTimeToAcceptPairingInSeconds - 1))
        
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
    
    func reset(for bluetoothTransmitter: BluetoothTransmitter, successful: Bool) {
        
        // set resetrequired to false in coredata, there's no need to reset as it's just been done
        getBluetoothPeripheral(for: bluetoothTransmitter).blePeripheral.resetrequired = false
        
        // Create Notification Content to give info about reset result of reset attempt
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NnotificationContent title
        notificationContent.title = successful ? Texts_HomeView.info : Texts_Common.warning
        
        notificationContent.body = Texts_HomeView.transmitterResetResult + " : " + (successful ? Texts_HomeView.success : Texts_HomeView.failed)
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForResetResult.transmitterResetResult, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable add notification request : transmitter reset result, error:  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
        
    }
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        // temporary, till all cgm's are moved to second tab
        if bluetoothTransmitter is CGMTransmitter {
            onCGMTransmitterCreation((bluetoothTransmitter as! CGMTransmitter))
        }
        
        // if tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is nil, then this is a connection to an already known/stored BluetoothTransmitter. BluetoothPeripheralManager is not interested in this info.
        guard let tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral else {
            trace("in didConnect, tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral is nil, no further processing", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
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
            return
        }
        
        // check that it's a peripheral for which we don't know yet the address
        for buetoothPeripheral in bluetoothPeripherals {
            
            if buetoothPeripheral.blePeripheral.address == deviceAddressNewTransmitter {
                
                trace("in didConnect, transmitter address already known. This is not a new device, will disconnect", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
                
                // it's an already known BluetoothTransmitter, not storing this, on the contrary disconnecting because maybe it's a bluetoothTransmitter already known for which user has preferred not to connect to
                // If we're actually waiting for a new scan result, then there's an instance of BluetoothTransmitter stored in tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral - but this one stopped scanning, so let's recreate an instance of BluetoothTransmitter
                self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = createNewTransmitter(type: getTransmitterType(for: bluetoothTransmitter), transmitterId: buetoothPeripheral.blePeripheral.transmitterId)
                
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
        
        // assign tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral to nil here
        self.tempBlueToothTransmitterWhileScanningForNewBluetoothPeripheral = nil
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        
        trace("in deviceDidUpdateBluetoothState, no further action", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
        if bluetoothTransmitter.deviceAddress == nil {
            /// this bluetoothTransmitter is created to start scanning for a new, unknown M5Stack, so start scanning
            _ = bluetoothTransmitter.startScanning()
        }
        
    }
    
    func error(message: String) {
        
        trace("received error = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info, message)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        // no further action, This is for UIViewcontroller's that also receive this info, means info can only be shown if this happens while user has one of the UIViewcontrollers open
        trace("in didDisconnectFrom", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
        
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
        PropertyHolder.transmitterPairingResponseTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(informUserThatPairingTimedOut), userInfo: nil, repeats: false)
        
    }

    // inform user that pairing request timed out
    @objc private func informUserThatPairingTimedOut() {
        
        let alert = UIAlertController(title: Texts_Common.warning, message: "time out", actionHandler: nil)
        
        uIViewController.present(alert, animated: true, completion: nil)
        
    }

}

