import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications

final class RootViewController: UIViewController, CGMTransmitterDelegate {
    // MARK: - Properties
    private var test:CGMTransmitter?
    
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryFirstView)
    
    /// did user authorize notifications ?
    private var notificationsAuthorized:Bool = false;

    /// coreDataManager to be used throughout the project
    private var coreDataManager:CoreDataManager?
    
    /// temporary ?
    private var calibrator:Calibrator?
    
    /// temporary ?
    private var currentTransmitterTypeAsString:String?
    
    /// temporary ?
    private var currentTransmitterId:String?
    
    /// temporary ?
    private var bgReadings:BgReadings?

    // used at initial app startup, during creation of constructor, so that cgm transmitter only uses most recent readings
    private  var timeStampLastBgReading:Date = {
      return Date(timeIntervalSince1970: 0)
    }()
    
    // MARK: - temporary properties
    var activeSensor:Sensor?
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like setting up the transmitter, start scanning
        // In the exceptional case that the transmitter would give a new reading before the DataManager is set up, then this new reading will be ignored
        coreDataManager = CoreDataManager(modelName: Constants.CoreData.modelName, completion: {
            self.setupApplicationData()
        })
        
        // Setup View
        setupView()

        // when user changes transmitter type or transmitter id, then new transmitter needs to be setup. That's why observer for these settings is required
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.transmitterTypeAsString.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.transmitterId.rawValue, options: .new, context: nil)

        // create transmitter
        initializeTransmitterType()
        
        UNUserNotificationCenter.current().delegate = self
        
        // check if app is allowed to send local notification and if not ask it
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            switch notificationSettings.authorizationStatus {
            case .notDetermined:
                self.requestNotificationAuthorization(completionHandler: { (success) in
                    guard success else {
                        os_log("failed to request notification authorization", log: self.log, type: .info)
                        return
                    }
                    self.notificationsAuthorized = true
                })
            case  .denied:
                //TODO : local dialog to say that user must give authorization via settings ?
                os_log("notification authorization denied", log: self.log, type: .info)
            default:
                self.notificationsAuthorized = true
            }
        }
    }
    
    private func setupApplicationData() {
        guard let coreDataManager = coreDataManager else {
            fatalError("In setupApplicationData but coreDataManager == nil")
        }
        bgReadings = BgReadings(coreDataManager: coreDataManager)
        
        tempfetchActiveSensor()
        tempfetchAllBgReadings()
        
        if let bgReadings = bgReadings, let lastReading = bgReadings.bgReadings.last {
            timeStampLastBgReading = lastReading.timeStamp
        }
        
        //logAllBgReadings()
        tempfetchAllCalibrations()
    }
    
    // Only MioaMiao will call this
    func newSensorDetected() {
        os_log("new sensor detected", log: log, type: .info)
    }
    
    // Only MioaMiao will call this
    func sensorNotDetected() {
        os_log("sensor not detected", log: log, type: .info)
    }
    
    /// - parameters:
    ///     - readings: first entry is the most recent
    func cgmTransmitterInfoReceived(glucoseData: inout [RawGlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorState: SensorState?, sensorTimeInMinutes: Int?, firmware: String?, hardware: String?, serialNumber: String?, bootloader: String?) {
        os_log("sensorstate %{public}@", log: log, type: .debug, sensorState?.description ?? "no sensor state found")
        os_log("firmware %{public}@", log: log, type: .debug, firmware ?? "no firmware version found")
        os_log("bootloader %{public}@", log: log, type: .debug, bootloader ?? "no bootloader  found")
        os_log("serialNumber %{public}@", log: log, type: .debug, serialNumber ?? "no serialNumber  found")
        os_log("hardware %{public}@", log: log, type: .debug, hardware ?? "no hardware version found")
        os_log("transmitterBatteryInfo  %{public}@", log: log, type: .debug, transmitterBatteryInfo?.description ?? 0)
        os_log("sensor time in minutes  %{public}@", log: log, type: .debug, sensorTimeInMinutes?.description ?? "not received")
        for (index, reading) in glucoseData.enumerated() {
            os_log("Reading %{public}d, raw level = %{public}f, realDate = %{public}s", log: log, type: .debug, index, reading.glucoseLevelRaw, reading.timeStamp.description)
        }

        temptesting(glucoseData: &glucoseData, sensorState: sensorState, firmware: firmware, hardware: hardware, batteryPercentage: transmitterBatteryInfo, sensorTimeInMinutes: sensorTimeInMinutes)
    }
    
    /// request notification authorization to the user for alert, sound and badge
    private func requestNotificationAuthorization(completionHandler: @escaping (_ success: Bool) -> ()) {
        // Request Authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
            if let error = error {
                os_log("Request Notification Authorization Failed : %{public}@", log: self.log, type: .error, error.localizedDescription)
            }
            completionHandler(success)
        }
    }
    
    // send request calibration notification
    private func requestCalibrationNotification() {
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure Notification Content
        if let activeSensor = activeSensor, let bgReadings = bgReadings {
            let lastReading = bgReadings.getLatestBgReadings(howMany: 1, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
            let calculatedValueAsString:String?
            if lastReading.count > 0 {
                var calculatedValue = lastReading[0].calculatedValue
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                    calculatedValue = calculatedValue.mgdlToMmol()
                    calculatedValueAsString = calculatedValue.bgValuetoString(mgdl: false)
                } else {
                    calculatedValueAsString = calculatedValue.bgValuetoString(mgdl: true)
                }
                notificationContent.title = "New Reading " + calculatedValueAsString!
            } else {
                notificationContent.title = "New Reading"
            }
        } else {
            notificationContent.title = "New Reading"
        }
        
        //notificationContent.subtitle = "Local Notifications"
        notificationContent.body = "Open the to calibrate."
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: Constants.NotificationIdentifiers.initialCalibrationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                os_log("Unable to Add Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
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
            if let activeSensor = self.activeSensor, let coreDataManager = self.coreDataManager, let bgReadings = self.bgReadings {
                if let textField = alert.textFields {
                    if let first = textField.first {
                        if let value = first.text {
                            let valueAsDouble = Double(value)!
                            var latestReadings = bgReadings.getLatestBgReadings(howMany: 36, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                            
                            var latestCalibrations = Calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)

                            if let calibrator = self.calibrator {
                                if latestCalibrations.count == 0 {
                                    let twoCalibrations = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDouble, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDouble, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                    if let firstCalibration = twoCalibrations.firstCalibration, let secondCalibration = twoCalibrations.secondCalibration {
                                        Calibrations.addCalibration(newCalibration: firstCalibration)
                                        Calibrations.addCalibration(newCalibration: secondCalibration)
                                    }
                                } else {
                                    let firstCalibrationForActiveSensor = Calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
                                    
                                    if let firstCalibrationForActiveSensor = firstCalibrationForActiveSensor {
                                        let newCalibration = calibrator.createNewCalibration(bgValue: valueAsDouble, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                        Calibrations.addCalibration(newCalibration: newCalibration)
                                    }
                                }
                                coreDataManager.saveChanges()
                                //self.logAllBgReadings()
                            }
                        }
                    }
                }
            }
        }))
        self.present(alert, animated: true)
    }
    
    private func temptesting(glucoseData: inout [RawGlucoseData], sensorState: SensorState?, firmware: String?, hardware: String?, batteryPercentage: TransmitterBatteryInfo?, sensorTimeInMinutes: Int?) {
        
        if activeSensor == nil, let coreDataManager = coreDataManager {
            if let transmitterType = UserDefaults.standard.transmitterType {
                switch transmitterType {
                    
                case .dexcomG4, .dexcomG5:
                    activeSensor = Sensor(startDate: Date(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

                case .miaomiao, .GNSentry:
                    if let sensorTimeInMinutes = sensorTimeInMinutes {
                        activeSensor = Sensor(startDate: Date(timeInterval: -Double(sensorTimeInMinutes * 60), since: Date()),nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        if let activeSensor = activeSensor {
                            os_log("created sensor with id : %{public}@ and startdate  %{public}@", log: self.log, type: .info, activeSensor.id, activeSensor.startDate.description)
                        } else {
                            os_log("creation active sensor failed", log: self.log, type: .info)
                        }
                    }
                }
            }
            coreDataManager.saveChanges()
        }

        if let activeSensor = activeSensor, let calibrator = self.calibrator, let coreDataManager = coreDataManager, let bgReadings = self.bgReadings {
            for (_, glucose) in glucoseData.enumerated().reversed() {
                if glucose.timeStamp > timeStampLastBgReading {
                    var latest3BgReadings = bgReadings.getLatestBgReadings(howMany: 3, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
                    
                    var lastCalibrationsForActiveSensorInLastXDays = Calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                    let firstCalibrationForActiveSensor = Calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
                    let lastCalibrationForActiveSensor = Calibrations.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
                    
                    let newBgReading = calibrator.createNewBgReading(rawData: (Double)(glucose.glucoseLevelRaw), filteredData: (Double)(glucose.glucoseLevelRaw), timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
                    debuglogging("newBgReading.calculatedValue = " + newBgReading.calculatedValue.description)
                    
                    bgReadings.addBgReading(newReading: newBgReading)
                }
            }
            
            coreDataManager.saveChanges()
            if glucoseData.count > 0 {requestCalibrationNotification()}
            //logAllBgReadings()
        }
        
        
        //print all readings
        /*os_log("printing all readings", log: self.log, type: .info)

        for (index, reading) in BgReadings.bgReadings.enumerated() {
            os_log("bgreading %{public}d has timestamp %{public}@", log: self.log, type: .info, index, reading.timeStamp.description)
            os_log("bgreading %{public}d has rawvalue  %{public}f", log: self.log, type: .info, index, reading.rawData)
        }*/
    }
    
    private func tempfetchActiveSensor() {
        let fetchRequest: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: false)]
        
        if let coreDataManager = coreDataManager {
            coreDataManager.mainManagedObjectContext.performAndWait {
                do {
                    // Execute Fetch Request
                    let sensors = try fetchRequest.execute()
                    
                    sensorloop: for sensor in sensors {
                        os_log("Found sensor with id : %{public}@ and startdate %{public}@", log: self.log, type: .info, sensor.id, sensor.startDate.description)
                        if sensor.endDate == nil {
                            //there should only be one sensor with enddate nil, the active sensor
                            // should be improved eg store the active sensor id in settings
                            activeSensor = sensor
                            break sensorloop
                        }
                    }
                    
                    //go through calibrations and readings and print the identifiers
                    if let activeSensor = activeSensor {
                        os_log("Found active sensor with id : %{public}@", log: self.log, type: .info, activeSensor.id)
                        if let setOfCalibrations = activeSensor.calibrations {
                            for element in setOfCalibrations {
                                if let calibration = element as? Calibration {
                                    os_log("Found calibration in that sensor with id : %{public}@", log: self.log, type: .info, calibration.id)
                                }
                            }
                        }
                        /*if let setOfReadings = activeSensor.readings {
                         for element in setOfReadings {
                         if let reading = element as? BgReading {
                         os_log("Found bgreading in that sensor with id : %{public}@", log: self.log, type: .info, reading.id)
                         }
                         }
                         }*/
                    }
                    
                } catch {
                    let fetchError = error as NSError
                    os_log("Unable to Execute Sensor Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
                }
            }
        }
    }

    private func tempfetchAllBgReadings() {
        let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
        
        if let coreDataManager = coreDataManager, let bgReadings = bgReadings {
            coreDataManager.mainManagedObjectContext.performAndWait {
                do {
                    // Execute Fetch Request
                    let readings = try fetchRequest.execute()
                    
                    readingloop: for reading in readings {
                        bgReadings.addBgReading(newReading: reading)
                        //os_log("Found reading with id : %{public}@, timestamp : %{public}@, calculatedvalue %{public}d, rawdata %{public}f", log: self.log, type: .info, reading.id, reading.timeStamp.description, reading.calculatedValue, reading.rawData)
                    }
                } catch {
                    let fetchError = error as NSError
                    os_log("Unable to Execute BgReading Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
                }
            }
        }
    }

    private func tempfetchAllCalibrations() {
        let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: true)]
        
        if let coreDataManager = coreDataManager {
            coreDataManager.mainManagedObjectContext.performAndWait {
                do {
                    // Execute Fetch Request
                    let calibrations = try fetchRequest.execute()
                    
                    calibrationloop: for calibration in calibrations {
                        Calibrations.calibrations.append(calibration)
                        os_log("Found calibration with id : %{public}@, timestamp : %{public}@", log: self.log, type: .info, calibration.id, calibration.timeStamp.description)
                    }
                } catch {
                    let fetchError = error as NSError
                    os_log("Unable to Execute Calibration Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
                }
            }
        }
    }
    
    // when user changes transmitter type or transmitter id, then new transmitter needs to be setup. That's why observer for these settings is required
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath, let coreDataManager = coreDataManager {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.transmitterTypeAsString :
                    if currentTransmitterTypeAsString != UserDefaults.standard.transmitterTypeAsString {
                        currentTransmitterTypeAsString = UserDefaults.standard.transmitterTypeAsString
                        UserDefaults.standard.bluetoothDeviceAddress = nil
                        UserDefaults.standard.bluetoothDeviceName =  nil
                        if let activeSensor = activeSensor {
                            activeSensor.endDate = Date()
                        }
                        coreDataManager.saveChanges()
                        activeSensor = nil
                        test = nil
                        initializeTransmitterType()
                    }
                case UserDefaults.Key.transmitterId:
                    if currentTransmitterId != UserDefaults.standard.transmitterId {
                        currentTransmitterId = UserDefaults.standard.transmitterId
                        UserDefaults.standard.bluetoothDeviceAddress = nil
                        UserDefaults.standard.bluetoothDeviceName =  nil
                        if let activeSensor = activeSensor {
                            activeSensor.endDate = Date()
                        }
                        coreDataManager.saveChanges()
                        activeSensor = nil
                        test = nil
                        initializeTransmitterType()
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func initializeTransmitterType() {
        if let currentTransmitterTypeAsEnum = UserDefaults.standard.transmitterType {
            
            switch currentTransmitterTypeAsEnum {
              
            case .dexcomG4:
                if let currentTransmitterId = currentTransmitterId {
                    test = CGMG4xDripTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, transmitterID: currentTransmitterId, delegate:self)
                    calibrator = DexcomCalibrator()
                }
                
            case .dexcomG5:
                if let currentTransmitterId = currentTransmitterId {
                    test = CGMG5Transmitter(address: UserDefaults.standard.bluetoothDeviceAddress, transmitterID: currentTransmitterId, delegate: self)
                    calibrator = DexcomCalibrator()
                }
                
            case .miaomiao:
                test = CGMMiaoMiaoTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0))
                calibrator = Libre1Calibrator()
                
            case .GNSentry:
                test = CGMGNSEntryTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0))
                calibrator = Libre1Calibrator()
            }
            
            _ = test?.startScanning()
        }
    }

    // MARK: - View Methods
    
    private func setupView() {
        // Configure View
        view.backgroundColor = UIColor(displayP3Red: 33, green: 33, blue: 33, alpha: 0)//#212121
    }
}

extension RootViewController: UNUserNotificationCenterDelegate {
    
    //called when notification fired while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        os_log("userNotificationCenter willPresent, calling completionhandler", log: log, type: .info)

        if notification.request.identifier == Constants.NotificationIdentifiers.initialCalibrationRequest {
            //calibration request was fired, no need to show the notification, show immediately the calibration dialog
            os_log("userNotificationCenter didReceive, user pressed calibration notification or app was open the moment the notification was fired", log: log, type: .info)
            requestCalibration()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("userNotificationCenter didReceive", log: log, type: .info)
        
        if response.notification.request.identifier == Constants.NotificationIdentifiers.initialCalibrationRequest {
            os_log("userNotificationCenter didReceive, user pressed calibration notification", log: log, type: .info)
            requestCalibration()
        }
    }
    
    private func logAllBgReadings() {
        if let bgReadings = bgReadings {
            for (index,reading) in bgReadings.bgReadings.enumerated() {
                if reading.sensor?.id == activeSensor?.id {
                    os_log("readings %{public}d timestamp = %{public}@, calculatedValue = %{public}f", log: log, type: .info, index, reading.timeStamp.description, reading.calculatedValue)
                }
            }
        }
    }
    
    // MARK: - CGMTransmitter protocol functions
    
    func cgmTransmitterDidConnect(address:String?, name:String?) {
        if let address = address, let name = name {
            UserDefaults.standard.bluetoothDeviceAddress = address
            UserDefaults.standard.bluetoothDeviceName =  name
        }
    }
    
    func cgmTransmitterDidDisconnect() {
        //TODO:- complete
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState) {
        if state == .poweredOn {
            if UserDefaults.standard.bluetoothDeviceAddress == nil {
                _ = test?.startScanning()
            }
        }
    }
    
    func cgmTransmitterNeedsPairing() {
        //TODO: needs implementation
        print("NEEDS IMPLEMENTATION")
    }
}

