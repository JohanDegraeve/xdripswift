import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications

final class RootHomeViewController: UIViewController, CGMTransmitterDelegate {
    // MARK: - Properties
    var test:CGMMiaoMiaoTransmitter?
    
    var address:String?
    var name:String?
    
    var log:OSLog?
    
    var notificationsAuthorized:Bool = false;

    // TODO: move to other location ?
    private var coreDataManager = CoreDataManager(modelName: "xdrip")
    
    private var libre1Calibration = Libre1Calibrator()
    
    // MARK: - temporary properties
    var activeSensor:Sensor?
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup View
        setupView()
        
        //let test:CGMG4xDripTransmitter = CGMG4xDripTransmitter(addressAndName: CGMG4xDripTransmitter.G4DeviceAddressAndName.notYetConnected)
        log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryFirstView)
        os_log("firstview viewdidload", log: log!, type: .info)
        
        tempfetchActiveSensor()
        tempfetchAllBgReadings()
        logAllBgReadings()
        tempfetchAllCalibrations()
        var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
        if let lastReading = BgReadings.bgReadings.last {
            timeStampLastBgReading = lastReading.timeStamp
        }

        var addressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: nil)
        if let address = UserDefaults.standard.bluetoothDeviceAddress, let name = UserDefaults.standard.bluetoothDeviceName {
            addressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        test = CGMMiaoMiaoTransmitter(addressAndName: addressAndName, delegate:self, timeStampLastBgReading: timeStampLastBgReading)

        UNUserNotificationCenter.current().delegate = self
        
        // check if app is allowed to send local notification and if not ask it
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            switch notificationSettings.authorizationStatus {
            case .notDetermined:
                self.requestNotificationAuthorization(completionHandler: { (success) in
                    guard success else {
                        os_log("failed to request notification authorization", log: self.log!, type: .info)
                        return
                    }
                    self.notificationsAuthorized = true
                })
            case  .denied:
                //TODO : local dialog to say that user must give authorization via settings ?
                os_log("notification authorization denied", log: self.log!, type: .info)
            default:
                self.notificationsAuthorized = true
            }
        }
        
        
    }
    
    // called when transmitter considered to be connected
    func cgmTransmitterdidConnect() {
        address = test?.address
        name = test?.name
        os_log("didconnect to device with address %{public}@ and name %{public}@", log: log!, type: .info, address!,name!)
    }
    
    // Only MioaMiao will call this
    func newSensorDetected() {
        os_log("new sensor detected", log: log!, type: .info)
    }
    
    // Only MioaMiao will call this
    func sensorNotDetected() {
        os_log("sensor not detected", log: log!, type: .info)
    }
    
    /// - parameters:
    ///     - readings: first entry is the most recent
    func newReadingsReceived(glucoseData: inout [RawGlucoseData], sensorState: LibreSensorState, firmware: String, hardware: String, batteryPercentage: Int, sensorTimeInMinutes: Int) {
        os_log("sensorstate %{public}@", log: log!, type: .debug, sensorState.description)
        os_log("firmware %{public}@", log: log!, type: .debug, firmware)
        os_log("hardware %{public}@", log: log!, type: .debug, hardware)
        os_log("battery percentage  %{public}d", log: log!, type: .debug, batteryPercentage)
        os_log("sensor time in minutes  %{public}d", log: log!, type: .debug, sensorTimeInMinutes)
        for (index, reading) in glucoseData.enumerated() {
            os_log("Reading %{public}d, raw level = %{public}f, realDate = %{public}s", log: log!, type: .debug, index, reading.glucoseLevelRaw, reading.timeStamp.description)
        }

        temptesting(glucoseData: &glucoseData, sensorState: sensorState, firmware: firmware, hardware: hardware, batteryPercentage: batteryPercentage, sensorTimeInMinutes: sensorTimeInMinutes)
    }
    
    /// request notification authorization to the user for alert, sound and badge
    private func requestNotificationAuthorization(completionHandler: @escaping (_ success: Bool) -> ()) {
        // Request Authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
            if let error = error {
                os_log("Request Notification Authorization Failed : %{public}@", log: self.log!, type: .error, error.localizedDescription)
            }
            completionHandler(success)
        }
    }
    
    // send request calibration notification
    private func requestCalibrationNotification() {
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure Notification Content
        notificationContent.title = "Initial Calibration"
        //notificationContent.subtitle = "Local Notifications"
        notificationContent.body = "Initial calibration required."
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: Constants.NotificationIdentifiers.initialCalibrationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                os_log("Unable to Add Notification Request %{public}@", log: self.log!, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func requestCalibration() {
        let alert = UIAlertController(title: "enter calibration value", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addTextField(configurationHandler: { textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "..."
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            if let activeSensor = self.activeSensor {
                if let textField = alert.textFields {
                    if let first = textField.first {
                        if let value = first.text {
                            let valueAsDouble = Double(value)!
                            var latestReadings = BgReadings.getLatestBgReadings(howMany: 36, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                            
                            var latestCalibrations = Calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)

                            if latestCalibrations.count == 0 {
                                let twoCalibrations = self.libre1Calibration.initialCalibration(firstCalibrationBgValue: valueAsDouble, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDouble, secondCalibrationTimeStamp: Date(), sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)
                                Calibrations.addCalibration(newCalibration: twoCalibrations.firstCalibration)
                                Calibrations.addCalibration(newCalibration: twoCalibrations.secondCalibration)
                            } else {
                                let firstCalibrationForActiveSensor = Calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)

                                if let firstCalibrationForActiveSensor = firstCalibrationForActiveSensor {
                                    let newCalibration = self.libre1Calibration.createNewCalibration(bgValue: valueAsDouble, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)
                                    Calibrations.addCalibration(newCalibration: newCalibration)
                                }
                            }

                            self.coreDataManager.saveChanges()
                            self.logAllBgReadings()
                        }
                    }
                }
            }
        }))
        
        self.present(alert, animated: true)
    }
    
    private func temptesting(glucoseData: inout [RawGlucoseData], sensorState: LibreSensorState, firmware: String, hardware: String, batteryPercentage: Int, sensorTimeInMinutes: Int) {
        if activeSensor == nil {
            activeSensor = Sensor(startDate: Date(timeInterval: -Double(sensorTimeInMinutes * 60), since: Date()),nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            if let activeSensor = activeSensor {
                os_log("created sensor with id : %{public}@ and startdate  %{public}@", log: self.log!, type: .info, activeSensor.id, activeSensor.startDate.description)
            } else {
                os_log("creation active sensor failed", log: self.log!, type: .info)
            }
        }
        
        if let activeSensor = activeSensor {
            for (_, glucose) in glucoseData.enumerated().reversed() {
                var latest3BgReadings = BgReadings.getLatestBgReadings(howMany: 3, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
                
                var lastCalibrationsForActiveSensorInLastXDays = Calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                let firstCalibrationForActiveSensor = Calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
                let lastCalibrationForActiveSensor = Calibrations.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
                
                let newBgReading = self.libre1Calibration.createNewBgReading(rawData: (Double)(glucose.glucoseLevelRaw), filteredData: (Double)(glucose.glucoseLevelRaw), timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                
                debuglogging("newBgReading.calculatedValue = " + newBgReading.calculatedValue.description)
                
                BgReadings.bgReadings.append(newBgReading)
                
                //let newBgReading = BgReading(timeStamp: glucose.timeStamp, sensor: activeSensor, calibration: nil, rawData: (Double)(glucose.glucoseLevelRaw), filteredData: Double(glucose.glucoseLevelRaw), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                
                //os_log("added new bgreading to bgreadings with  id : %{public}@ and timestamp  %{public}@", log: self.log!, type: .info, newBgReading.id, newBgReading.timeStamp.description)
            }
            
            coreDataManager.saveChanges()
            
            requestCalibrationNotification()
            logAllBgReadings()
        }
        
        
        //print all readings
        /*os_log("printing all readings", log: self.log!, type: .info)

        for (index, reading) in BgReadings.bgReadings.enumerated() {
            os_log("bgreading %{public}d has timestamp %{public}@", log: self.log!, type: .info, index, reading.timeStamp.description)
            os_log("bgreading %{public}d has rawvalue  %{public}f", log: self.log!, type: .info, index, reading.rawData)
        }*/
    }
    
    private func tempfetchActiveSensor() {
        let fetchRequest: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: false)]
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                let sensors = try fetchRequest.execute()
                
                sensorloop: for sensor in sensors {
                    os_log("Found sensor with id : %{public}@ and startdate %{public}@", log: self.log!, type: .info, sensor.id, sensor.startDate.description)
                    if sensor.endDate == nil {
                        //there should only be one sensor with enddate nil, the active sensor
                        // should be improved eg store the active sensor id in settings
                        activeSensor = sensor
                        break sensorloop
                    }
                }
                
                //go through calibrations and readings and print the identifiers
                if let activeSensor = activeSensor {
                    os_log("Found active sensor with id : %{public}@", log: self.log!, type: .info, activeSensor.id)
                    if let setOfCalibrations = activeSensor.calibrations {
                        for element in setOfCalibrations {
                            if let calibration = element as? Calibration {
                                os_log("Found calibration in that sensor with id : %{public}@", log: self.log!, type: .info, calibration.id)
                            }
                        }
                    }
                    /*if let setOfReadings = activeSensor.readings {
                        for element in setOfReadings {
                            if let reading = element as? BgReading {
                                os_log("Found bgreading in that sensor with id : %{public}@", log: self.log!, type: .info, reading.id)
                            }
                        }
                    }*/
                }
                
            } catch {
                let fetchError = error as NSError
                os_log("Unable to Execute Sensor Fetch Request : %{public}@", log: self.log!, type: .error, fetchError.localizedDescription)
            }
        }
    }

    private func tempfetchAllBgReadings() {
        let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                let readings = try fetchRequest.execute()
                
                readingloop: for reading in readings {
                    BgReadings.bgReadings.append(reading)
                    //os_log("Found reading with id : %{public}@, timestamp : %{public}@, calculatedvalue %{public}d, rawdata %{public}f", log: self.log!, type: .info, reading.id, reading.timeStamp.description, reading.calculatedValue, reading.rawData)
                }
            } catch {
                let fetchError = error as NSError
                os_log("Unable to Execute BgReading Fetch Request : %{public}@", log: self.log!, type: .error, fetchError.localizedDescription)
            }
        }
    }

    private func tempfetchAllCalibrations() {
        let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: true)]
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                let calibrations = try fetchRequest.execute()
                
                calibrationloop: for calibration in calibrations {
                    Calibrations.calibrations.append(calibration)
                    os_log("Found calibration with id : %{public}@, timestamp : %{public}@", log: self.log!, type: .info, calibration.id, calibration.timeStamp.description)
                }
            } catch {
                let fetchError = error as NSError
                os_log("Unable to Execute Calibration Fetch Request : %{public}@", log: self.log!, type: .error, fetchError.localizedDescription)
            }
        }
    }

    // MARK: - View Methods
    
    private func setupView() {
        // Configure View
        view.backgroundColor = UIColor(displayP3Red: 33, green: 33, blue: 33, alpha: 0)//#212121
    }


}

extension RootHomeViewController: UNUserNotificationCenterDelegate {
    
    //called when notification fired while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        os_log("userNotificationCenter willPresent, calling completionhandler", log: log!, type: .info)

        if notification.request.identifier == Constants.NotificationIdentifiers.initialCalibrationRequest {
            //calibration request was fired, no need to show the notification, show immediately the calibration dialog
            os_log("userNotificationCenter didReceive, user pressed calibration notification", log: log!, type: .info)
            requestCalibration()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("userNotificationCenter didReceive", log: log!, type: .info)
        
        if response.notification.request.identifier == Constants.NotificationIdentifiers.initialCalibrationRequest {
            os_log("userNotificationCenter didReceive, user pressed calibration notification", log: log!, type: .info)
            requestCalibration()
        }
    }
    
    private func logAllBgReadings() {
        for (index,reading) in BgReadings.bgReadings.enumerated() {
            os_log("readings %{public}d timestamp = %{public}@, calculatedValue = %{public}f", log: log!, type: .info, index, reading.timeStamp.description, reading.calculatedValue)
        }
    }
    
    // MARK: - CGMTransmitterDelegate functions
    
    func cgmTransmitterDidConnect() {
        if let address = test?.address, let name = test?.name {
            self.address = address
            self.name = name
            UserDefaults.standard.bluetoothDeviceAddress = address
            UserDefaults.standard.bluetoothDeviceName =  name
        }
    }
    
    func cgmTransmitterDidDisconnect() {
        //TODO:- complete
    }
    
    func didUpdateBluetoothState(state: CBManagerState) {
        if state == .poweredOn {
            if address == nil {
                _ = test?.startScanning()
            }
        }
    }
    

}

