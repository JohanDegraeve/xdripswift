import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications

/// viewcontroller for the home screen
final class RootViewController: UIViewController, CGMTransmitterDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Properties - Outlets and Actions for buttons and labels in home screen
    
    @IBOutlet weak var calibrateButtonOutlet: UIButton!
    
    @IBAction func calibrateButtonAction(_ sender: UIButton) {
    }
    
    @IBOutlet weak var transmitterButtonOutlet: UIButton!
    
    @IBAction func transmitterButtonAction(_ sender: UIButton) {
    }
    
    @IBOutlet weak var preSnoozeButtonOutlet: UIButton!
    
    @IBAction func preSnoozeButtonAction(_ sender: UIButton) {
    }
    
    
    
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
    
    /// BgReadings instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    /// Calibrations instance
    private var calibrationsAccessor:CalibrationsAccessor?
    
    /// NightScoutManager instance
    private var nightScoutManager:NightScoutUploader?
    
    /// AlerManager instance
    private var alertManager:AlertManager?
    
    /// PlaySound instance
    private var soundPlayer:SoundPlayer?

    // maybe not needed in future
    private  var timeStampLastBgReading:Date = {
      return Date(timeIntervalSince1970: 0)
    }()
    
    var activeSensorAccessor:Sensor?
    
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
        
        // setup self as delegate for tabbarcontrolelr
        self.tabBarController?.delegate = self
    }
    
    private func setupApplicationData() {
        
        // if coreDataManager is nil then there's no reason to continue
        guard let coreDataManager = coreDataManager else {
            fatalError("In setupApplicationData but coreDataManager == nil")
        }

        activeSensorAccessor = SensorsAccessor.init(coreDataManager: coreDataManager).fetchActiveSensor()
        
        // test
        /*if let activeSensor = activeSensor {
            debuglogging("activesensor has id " + activeSensor.id + " and starttime " + activeSensor.startDate.description(with: .current))
        }*/

        // instantiate bgReadings
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            fatalError("In setupApplicationData, failed to initialize bgReadings")
        }
        
        // set timeStampLastBgReading
        if let lastReading = bgReadingsAccessor.last(forSensor: activeSensorAccessor) {
            timeStampLastBgReading = lastReading.timeStamp
        }
        
        // instantiate calibrations
        calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        guard calibrationsAccessor != nil else {
            fatalError("In setupApplicationData, failed to initialize calibrations")
        }
        
        /// test
        /*for (index,calibration) in  calibrations.getLatestCalibrations(howManyDays: 2, forSensor: nil).enumerated() {
            debuglogging("calibration nr " + index.description + ", timestamp " + calibration.timeStamp.description(with: .current) + ", sensor id = " + calibration.sensor.id)
        }*/
        
        // setup nightscout synchronizer
        nightScoutManager = NightScoutUploader(bgReadingsAccessor: bgReadingsAccessor)
        
        // setup playsound
        soundPlayer = SoundPlayer()
        
        // setup alertmanager
        if let soundPlayer = soundPlayer {
            alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        }
        
    }
    
    // Only MioaMiao will call this
    func newSensorDetected() {
        os_log("new sensor detected", log: log, type: .info)
        if let activeSensor = activeSensorAccessor, let coreDataManager = coreDataManager {
            activeSensor.endDate = Date()
            coreDataManager.saveChanges()
        }
        activeSensorAccessor = nil
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
    
    // creates notification with bg reading
    // for the moment also creates calibration request if there's no calibration done yet
    private func createBGReadingNotification() {
        
        // first remove existing notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Constants.Notifications.NotificationIdentifiersForAlerts.initialCalibrationRequest])

        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure Notification Content
        if let activeSensor = activeSensorAccessor, let bgReadings = bgReadingsAccessor {
            let lastReading = bgReadings.getLatestBgReadings(limit: 1, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
            let calculatedValueAsString:String?
            if lastReading.count > 0 {
                let calculatedValue = lastReading[0].calculatedValue
                calculatedValueAsString = calculatedValue.mgdlToMmolAndToString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                notificationContent.title = "New Reading " + calculatedValueAsString!
            } else {
                notificationContent.title = "New Reading"
            }
        } else {
            notificationContent.title = "New Reading"
        }
        
        //notificationContent.subtitle = "Local Notifications"
        notificationContent.body = "Open the notification to calibrate."
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: Constants.Notifications.NotificationIdentifiersForAlerts.initialCalibrationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                os_log("Unable to Add Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func requestCalibration() {
        
        // check that calibrations is not nil
        guard let calibrations = calibrationsAccessor, let activeSensor = activeSensorAccessor else {
            fatalError("in requestCalibration, calibrations is nil")
        }
        
        // temporary check if a calibration already exists, this is to test the pickerviewcontroller
        if calibrations.getLatestCalibrations(howManyDays: 30, forSensor: activeSensor).count > 0 {
            return
        }
        
        let alert = UIAlertController(title: "enter calibration value", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addTextField(configurationHandler: { textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "..."
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            if let activeSensor = self.activeSensorAccessor, let coreDataManager = self.coreDataManager, let bgReadings = self.bgReadingsAccessor {
                if let textField = alert.textFields {
                    if let first = textField.first {
                        if let value = first.text {
                            let valueAsDouble = Double(value)!
                            var latestReadings = bgReadings.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                            
                            var latestCalibrations = calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)

                            if let calibrator = self.calibrator {
                                if latestCalibrations.count == 0 {
                                    // calling initialCalibration will create two calibrations, they are returned also but we don't need them
                                    _ = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDouble, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDouble, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                } else {
                                    let firstCalibrationForActiveSensor = calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
                                    
                                    if let firstCalibrationForActiveSensor = firstCalibrationForActiveSensor {
                                        // calling createNewCalibration will create a new  calibrations, it is returned but we don't need it
                                        _ = calibrator.createNewCalibration(bgValue: valueAsDouble, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                    }
                                }
                                // this will store the newly created calibration(s) in coredata
                                coreDataManager.saveChanges()
                                
                                if let nightScoutManager = self.nightScoutManager {
                                    nightScoutManager.synchronize()
                                }
                                if let alertManager = self.alertManager {
                                    alertManager.checkAlerts()
                                }

                            }
                        }
                    }
                }
            }
        }))
        self.present(alert, animated: true)
    }
    
    private func temptesting(glucoseData: inout [RawGlucoseData], sensorState: SensorState?, firmware: String?, hardware: String?, batteryPercentage: TransmitterBatteryInfo?, sensorTimeInMinutes: Int?) {
        
        // check that calibrations and coredata manager is not nil
        guard let calibrations = calibrationsAccessor, let coreDataManager = coreDataManager else {
            fatalError("in temptesting, calibrations or coreDataManager is nil")
        }

        if activeSensorAccessor == nil {
            if let transmitterType = UserDefaults.standard.transmitterType {
                switch transmitterType {
                    
                case .dexcomG4, .dexcomG5:
                    activeSensorAccessor = Sensor(startDate: Date(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

                case .miaomiao, .GNSentry:
                    if let sensorTimeInMinutes = sensorTimeInMinutes {
                        activeSensorAccessor = Sensor(startDate: Date(timeInterval: -Double(sensorTimeInMinutes * 60), since: Date()),nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        if let activeSensor = activeSensorAccessor {
                            os_log("created sensor with id : %{public}@ and startdate  %{public}@", log: self.log, type: .info, activeSensor.id, activeSensor.startDate.description)
                        } else {
                            os_log("creation active sensor failed", log: self.log, type: .info)
                        }
                    }
                }
            }
            coreDataManager.saveChanges()
        }

        if let activeSensor = activeSensorAccessor, let calibrator = self.calibrator, let bgReadings = self.bgReadingsAccessor {
            for (_, glucose) in glucoseData.enumerated().reversed() {
                if glucose.timeStamp > timeStampLastBgReading {
                    
                    var latest3BgReadings = bgReadings.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
                    
                    var lastCalibrationsForActiveSensorInLastXDays = calibrations.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                    let firstCalibrationForActiveSensor = calibrations.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
                    let lastCalibrationForActiveSensor = calibrations.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
                    
                    let newBgReading = calibrator.createNewBgReading(rawData: (Double)(glucose.glucoseLevelRaw), filteredData: (Double)(glucose.glucoseLevelRaw), timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
                    debuglogging("newBgReading, timestamp = " + newBgReading.timeStamp.description(with: .current) + ", calculatedValue = " + newBgReading.calculatedValue.description)
                }
            }
            
            coreDataManager.saveChanges()
            if glucoseData.count > 0 {createBGReadingNotification()}
            if let nightScoutManager = nightScoutManager {
                nightScoutManager.synchronize()
            }
            if let alertManager = alertManager {
                alertManager.checkAlerts()
            }
        }
        
        
        //print all readings
        /*os_log("printing all readings", log: self.log, type: .info)

        for (index, reading) in BgReadings.bgReadings.enumerated() {
            os_log("bgreading %{public}d has timestamp %{public}@", log: self.log, type: .info, index, reading.timeStamp.description)
            os_log("bgreading %{public}d has rawvalue  %{public}f", log: self.log, type: .info, index, reading.rawData)
        }*/
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
                        if let activeSensor = activeSensorAccessor {
                            activeSensor.endDate = Date()
                        }
                        coreDataManager.saveChanges()
                        activeSensorAccessor = nil
                        test = nil
                        initializeTransmitterType()
                    }
                case UserDefaults.Key.transmitterId:
                    if currentTransmitterId != UserDefaults.standard.transmitterId {
                        currentTransmitterId = UserDefaults.standard.transmitterId
                        UserDefaults.standard.bluetoothDeviceAddress = nil
                        UserDefaults.standard.bluetoothDeviceName =  nil
                        if let activeSensor = activeSensorAccessor {
                            activeSensor.endDate = Date()
                        }
                        coreDataManager.saveChanges()
                        activeSensorAccessor = nil
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

extension RootViewController {
    
    //called when notification fired while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        if notification.request.identifier == Constants.Notifications.NotificationIdentifiersForAlerts.initialCalibrationRequest {
            // request calibration
             requestCalibration()
            
            // call completionhandler
            completionHandler([])
        } else {
            if let pickerViewData = alertManager?.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) {
                
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)

            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("userNotificationCenter didReceive", log: log, type: .info)
        
        if response.notification.request.identifier == Constants.Notifications.NotificationIdentifiersForAlerts.initialCalibrationRequest {
            os_log("userNotificationCenter didReceive, user pressed calibration notification", log: log, type: .info)
            // request calibration
            requestCalibration()
            
            // call completionhandler
            completionHandler()
        } else {
            if let pickerViewData = alertManager?.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler) {
                
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)

            }
        }
    }
    
    private func logAllBgReadings() {
        if let bgReadingsAccessor = bgReadingsAccessor {
            let readings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: true)
            for (index,reading) in readings.enumerated() {
                if reading.sensor?.id == activeSensorAccessor?.id {
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

/// conform to UITabBarControllerDelegate, want to receive info when user clicks specific tabs
extension RootViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        
        // if user clicks the tab for settings, then configure
        if let navigationController = viewController as? SettingsNavigationController {
            navigationController.configure(coreDataManager: coreDataManager)
        }
    }
}

