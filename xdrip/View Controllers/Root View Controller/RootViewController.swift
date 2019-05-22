import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications

/// viewcontroller for the home screen
final class RootViewController: UIViewController {

    // MARK: - Properties - Outlets and Actions for buttons and labels in home screen
    
    @IBOutlet weak var calibrateButtonOutlet: UIButton!
    
    @IBAction func calibrateButtonAction(_ sender: UIButton) {
        requestCalibration()
    }
    
    @IBOutlet weak var transmitterButtonOutlet: UIButton!
    
    @IBAction func transmitterButtonAction(_ sender: UIButton) {
        createAndPresentTransmitterButtonActionSheet()
    }
    
    @IBOutlet weak var preSnoozeButtonOutlet: UIButton!
    
    @IBAction func preSnoozeButtonAction(_ sender: UIButton) {
    }
    
    /// a reference to the CGMTransmitter currently in use - nil means there's none, because user hasn't selected yet all required settings
    private var cgmTransmitter:CGMTransmitter?
    
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryFirstView)
    
    /// did user authorize notifications ?
    private var notificationsAuthorized:Bool = false;

    /// coreDataManager to be used throughout the project
    private var coreDataManager:CoreDataManager?
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()

    /// calibrator to be used for calibration, value will depend on transmitter type
    private var calibrator:Calibrator?
    
    /// BgReadings instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    /// Calibrations instance
    private var calibrationsAccessor:CalibrationsAccessor?
    
    /// NightScoutUploader instance
    private var nightScoutUploader:NightScoutUploader?
    
    /// AlerManager instance
    private var alertManager:AlertManager?
    
    /// PlaySound instance
    private var soundPlayer:SoundPlayer?

    // to keep track of latest processed reading, because transmitters like MiaoMiao will return a whole range of readings each time, we need to skip those that were already processed - this variable will be set during startup to the timestamp of the latest reading in coredata (if there's already readings)
    private var timeStampLastBgReading:Date = Date(timeIntervalSince1970: 0)
    
    // reference to activeSensor
    var activeSensor:Sensor?
    
    // if true, user manually started scanning for a device, when connection is made, we'll inform the user, see cgmTransmitterDidConnect
    var userDidInitiateScanning = false
    
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
        initializeCGMTransmitter()
        
        // setup delegate for UNUserNotificationCenter
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

        // get currently active sensor
        activeSensor = SensorsAccessor.init(coreDataManager: coreDataManager).fetchActiveSensor()
        
        // instantiate bgReadingsAccessor
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            fatalError("In setupApplicationData, failed to initialize bgReadings")
        }
        
        // set timeStampLastBgReading
        if let lastReading = bgReadingsAccessor.last(forSensor: activeSensor) {
            timeStampLastBgReading = lastReading.timeStamp
        }
        
        // instantiate calibrations
        calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        
        // setup nightscout synchronizer
        nightScoutUploader = NightScoutUploader(bgReadingsAccessor: bgReadingsAccessor)
        
        // setup playsound
        soundPlayer = SoundPlayer()
        
        // setup alertmanager
        if let soundPlayer = soundPlayer {
            alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        }
        
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
    
    private func processNewCGMInfo(glucoseData: inout [RawGlucoseData], sensorState: SensorState?, firmware: String?, hardware: String?, transmitterBatteryInfo: TransmitterBatteryInfo?, sensorTimeInMinutes: Int?) {
        
        // check that calibrations and coredata manager is not nil
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = coreDataManager else {
            fatalError("in processNewCGMInfo, calibrations or coreDataManager is nil")
        }

        if activeSensor == nil {
            if let transmitterType = UserDefaults.standard.transmitterType {
                switch transmitterType {
                    
                case .dexcomG4, .dexcomG5:
                   break // sensor start needs to be initiated by user

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
                
                // save the newly created Sensor permenantly in coredata
                coreDataManager.saveChanges()
            }
        }

        if let activeSensor = activeSensor, let calibrator = self.calibrator, let bgReadingsAccessor = self.bgReadingsAccessor {

            // initialize help variables
            var latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
            var lastCalibrationsForActiveSensorInLastXDays = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
            let lastCalibrationForActiveSensor = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            
            // was a new reading created or not
            var newReadingCreated = false

            for (_, glucose) in glucoseData.enumerated().reversed() {
                if glucose.timeStamp > timeStampLastBgReading {
                    
                    _ = calibrator.createNewBgReading(rawData: (Double)(glucose.glucoseLevelRaw), filteredData: (Double)(glucose.glucoseLevelRaw), timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

                    // save the newly created bgreading permenantly in coredata
                    coreDataManager.saveChanges()
                    
                    // a new reading was created
                    newReadingCreated = true
                    
                    // set timeStampLastBgReading to new timestamp
                    timeStampLastBgReading = glucose.timeStamp
                }
            }
            
            // if a new reading is created, created either initial calibration request or bgreading notification - upload to nightscout and check alerts
            if newReadingCreated {
                // if no two calibration exist yet then create calibration request notification, otherwise a bgreading notification
                if firstCalibrationForActiveSensor == nil && lastCalibrationForActiveSensor == nil {
                    createInitialCalibrationRequest()
                } else {
                    createBgReadingNotification()
                }
                
                if let nightScoutUploader = nightScoutUploader {
                    nightScoutUploader.synchronize()
                }
                
                if let alertManager = alertManager {
                    alertManager.checkAlerts()
                }
            }
        }
        
        // check transmitterBatteryInfo and if available store in settings
        if let transmitterBatteryInfo = transmitterBatteryInfo {
            UserDefaults.standard.transmitterBatteryInfo = transmitterBatteryInfo
        }
    }

    // MARK:- observe function
    
    // when user changes transmitter type or transmitter id, then new transmitter needs to be setup. That's why observer for these settings is required
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.transmitterTypeAsString, UserDefaults.Key.transmitterId :
                    
                    // transmittertype change triggered by user, should not be done within 200 ms
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        UserDefaults.standard.bluetoothDeviceAddress = nil
                        UserDefaults.standard.bluetoothDeviceName =  nil

                        // there's no need to stop the sensor, maybe the user is just switching from xdrip a to xdrip b
                        
                        // setting cgmTransmitter to nil, if currently cgmTransmitter is not nil, by assign to nil the deinit function of the currently used cgmTransmitter will be called, which will deconnect the device
                        setCGMTransmitterToNil()
                        
                        // set up na transmitter
                        initializeCGMTransmitter()
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - View Methods

    /// Configure View
    private func setupView() {
        
        calibrateButtonOutlet.setTitle(Texts_HomeView.calibrationButton, for: .normal)
        preSnoozeButtonOutlet.setTitle(Texts_HomeView.snoozeButton, for: .normal)
        transmitterButtonOutlet.setTitle(Texts_HomeView.transmitter, for: .normal)
        
    }
    
    // MARK: - private helper functions
    
    /// sets parameter cgmTransmitter to nil and also other settings
    ///
    ///     - cgmTransmitter to nil
    ///     - UserDefaults.standard.transmitterBatteryInfo to nil
    ///     - UserDefaults.standard.lastdisConnectTimestamp to nil
    ///     - stops the active sensor
    private func setCGMTransmitterToNil() {
        
        cgmTransmitter = nil // here don't use setCGMTransmitterToNil(), because it's not the goal tha transmitterBatteryInfo is set to nil at each app startup
        
        // reset also UserDefaults.standard.transmitterBatteryInfo
        UserDefaults.standard.transmitterBatteryInfo = nil
        
        // set lastdisconnecttimestamp to nil
        UserDefaults.standard.lastdisConnectTimestamp = nil
        
        // stop active sensor
        stopSensor()
    }
    
    /// opens an alert, that requests user to enter a calibration value, and calibrates
    private func requestCalibration() {
        
        // check that calibrationsAccessor is not nil
        guard let calibrationsAccessor = calibrationsAccessor else {
            fatalError("in requestCalibration, calibrationsAccessor is nil")
        }
        
        let alert = UIAlertController(title: Texts_Calibrations.enterCalibrationValue, message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: nil))
        
        alert.addTextField(configurationHandler: { textField in
            textField.keyboardType = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad
            textField.placeholder = "..."
        })
        
        alert.addAction(UIAlertAction(title: Texts_Common.Ok, style: .default, handler: { action in
            if let activeSensor = self.activeSensor, let coreDataManager = self.coreDataManager, let bgReadingsAccessor = self.bgReadingsAccessor {
                if let textField = alert.textFields {
                    if let first = textField.first {
                        if let value = first.text {
                            
                            let valueAsDouble = value.toDouble()!.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                            
                            var latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                            
                            var latestCalibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                            
                            if let calibrator = self.calibrator {
                                if latestCalibrations.count == 0 {
                                    // calling initialCalibration will create two calibrations, they are returned also but we don't need them
                                    _ = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDouble, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDouble, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                } else {
                                    // it's not the first calibration
                                    if let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) {
                                        // calling createNewCalibration will create a new  calibrations, it is returned but we don't need it
                                        _ = calibrator.createNewCalibration(bgValue: valueAsDouble, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName:UserDefaults.standard.bluetoothDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                                    }
                                }
                                
                                // this will store the newly created calibration(s) in coredata
                                coreDataManager.saveChanges()
                                
                                // initiate upload to NightScout, if needed
                                if let nightScoutUploader = self.nightScoutUploader {
                                    nightScoutUploader.synchronize()
                                }
                                
                                // check alerts
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
    

    /// will set first cgmTransmitter to nil, reads transmittertype from userdefaults, and if available creates the transmitter and start the scanning
    private func initializeCGMTransmitter() {
        
        // setting cgmTransmitter to nil, if currently cgmTransmitter is not nil, by assign to nil the deinit function of the currently used cgmTransmitter will be called, which will deconnect the device
        // setting to nil is also done in other places, doing it again just to be 100% sure
        cgmTransmitter = nil
        
        if let currentTransmitterTypeAsEnum = UserDefaults.standard.transmitterType {
            
            // first create transmitter
            switch currentTransmitterTypeAsEnum {
                
            case .dexcomG4:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMG4xDripTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, transmitterID: currentTransmitterId, delegate:self)
                    calibrator = DexcomCalibrator()
                }
                
            case .dexcomG5:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMG5Transmitter(address: UserDefaults.standard.bluetoothDeviceAddress, transmitterID: currentTransmitterId, delegate: self)
                    calibrator = DexcomCalibrator()
                }
                
            case .miaomiao:
                cgmTransmitter = CGMMiaoMiaoTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0))
                calibrator = Libre1Calibrator()
                
            case .GNSentry:
                cgmTransmitter = CGMGNSEntryTransmitter(address: UserDefaults.standard.bluetoothDeviceAddress, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0))
                calibrator = Libre1Calibrator()
            }
            
        }
    }

    /// for debug purposes
    private func logAllBgReadings() {
        if let bgReadingsAccessor = bgReadingsAccessor {
            let readings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: true)
            for (index,reading) in readings.enumerated() {
                if reading.sensor?.id == activeSensor?.id {
                    os_log("readings %{public}d timestamp = %{public}@, calculatedValue = %{public}f", log: log, type: .info, index, reading.timeStamp.description, reading.calculatedValue)
                }
            }
        }
    }
    
    // creates initial calibration request notification
    private func createInitialCalibrationRequest() {
        
        // first remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Constants.Notifications.NotificationIdentifiersForCalibration.initialCalibrationRequest])
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NotificationContent title
        notificationContent.title = Texts_Calibrations.calibrationNotificationRequestTitle
        
        // Configure NotificationContent body
        notificationContent.body = Texts_Calibrations.calibrationNotificationRequestBody
        
        // Configure NotificationContent sound with defalt sound
        notificationContent.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(""))
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: Constants.Notifications.NotificationIdentifiersForCalibration.initialCalibrationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                os_log("Unable to Add Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
            }
        }
    }
    
    // creates bgreading notification
    private func createBgReadingNotification() {
        
        // if activeSensor nil, then no reason to continue - bgReadings should not be nil at all, but let's not create a fatal error for that, there's already enough checks for it
        guard let activeSensor = activeSensor, let bgReadingsAccessor = bgReadingsAccessor else {
            // no need to create a notification
            return
        }

        // get lastReading for the currently activeSensor, wich a calculatedValue
        let lastReading = bgReadingsAccessor.getLatestBgReadings(limit: 2, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
        
        // if there's no reading for active sensor with calculated value , then no reason to continue
        if lastReading.count == 0 {
            return
        }
        
        // if reading is older than 4.5 minutes, then also no reason to continue - should probably never happen but let's check it anyway
        if Date().timeIntervalSince(lastReading[0].timeStamp) > 4.5 * 70 {
            return
        }
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Constants.Notifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NnotificationContent title, which is bg value in correct unit, add also slopeArrow if !hideSlope and finally the difference with previous reading, if there is one
        var calculatedValueAsString = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        if !lastReading[0].hideSlope {
            calculatedValueAsString = calculatedValueAsString + " " + lastReading[0].slopeArrow()
        }
        if lastReading.count > 1 {
            calculatedValueAsString = calculatedValueAsString + "      " + lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: true, highGranularity: true)
        }
        notificationContent.title = calculatedValueAsString

        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: Constants.Notifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                os_log("Unable to Add bg reading Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func createAndPresentTransmitterButtonActionSheet() {
        // intialize list of actions
        var listOfActions = [String : ((UIAlertAction) -> Void)]()
        
        // first action is to show the status
        listOfActions[Texts_HomeView.statusActionTitle] = {(UIAlertAction) in self.showStatus()}
        
        // next action is scan device or forget device, can also be omitted depending on type of device
        if cgmTransmitter != nil {
            // cgmTransmitter is setup, means user has set transmittertype and transmitter id
            // transmitterType should be not nil but we need to unwrap anyway
            if let transmitterType = UserDefaults.standard.transmitterType {
                if !transmitterType.startScanningAfterInit() {
                    // it's a transmitter for which user needs to initiate the scanning
                    // see if bluetoothDeviceAddress is known, results determines next action to add
                    if UserDefaults.standard.bluetoothDeviceAddress == nil {
                        listOfActions[Texts_HomeView.scanBluetoothDeviceActionTitle] = {(UIAlertAction) in self.userInitiatesStartScanning()}
                    } else {
                        listOfActions[Texts_HomeView.forgetBluetoothDeviceActionTitle] = {(UIAlertAction) in self.userInitiatesForgetDevice()}
                    }
                }
            }
        }
        
        // next action is to start or stop the sensor, can also be omitted depending on type of device
        if let transmitterType = UserDefaults.standard.transmitterType {
            if !transmitterType.canDetectNewSensor() {
                // user needs to start and stop the sensor manually
                if activeSensor != nil {
                    listOfActions[Texts_HomeView.stopSensorActionTitle] = {(UIAlertAction) in self.stopSensor()}
                } else {
                    listOfActions[Texts_HomeView.startSensorActionTitle] = {(UIAlertAction) in self.startSensor()}
                }
            }
        }
        
        // create and present new alertController of type actionsheet
        let actionSheet = UIAlertController(title: nil, message: nil, actions: listOfActions, cancelAction: (Texts_Common.Cancel, nil))
        self.present(actionSheet, animated: true)
    }
    
    /// will show the status
    private func showStatus() {
        
        // first sensor status
        var textToShow = Texts_HomeView.sensorStart + " : "
        if let activeSensor = activeSensor {
            textToShow += activeSensor.startDate.description(with: .current)
        } else {
            textToShow += Texts_HomeView.notStarted
        }
        
        // add 2 newlines
        textToShow += "\r\n\r\n"
        
        // add transmitter info
        // first the name
        textToShow += Texts_HomeView.transmitter + " : "
        if let deviceName = UserDefaults.standard.bluetoothDeviceName {
            textToShow += deviceName
        } else {
            textToShow += Texts_HomeView.notKnown
        }
        
        // add 1 newline with last connection timestamp
        textToShow += "\r\n\r\n"
        
        // check if connected, if not add last connection timestamp
        if let connectionStatus = cgmTransmitter?.getConnectionStatus(), connectionStatus == CBPeripheralState.connected {
            textToShow += Texts_HomeView.connected + "\r\n\r\n"
        } else {
            if let lastDisconnectTimestamp = UserDefaults.standard.lastdisConnectTimestamp {
                textToShow += Texts_HomeView.lastConnection + " : " + lastDisconnectTimestamp.description(with: .current)
                // add 1 newline with last connection timestamp
                textToShow += "\r\n\r\n"
            } else {
                textToShow += Texts_HomeView.neverConnected + "\r\n\r\n"
            }
        }
        
        // add transmitterBatteryInfo if known
        if let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo, let transmitterType = UserDefaults.standard.transmitterType {
            textToShow += Texts_HomeView.transmitterBatteryLevel + " : " + transmitterBatteryInfo.description
            // add 1 newline with last connection timestamp
            textToShow += "\r\n\r\n"
        }
        
        // display textoToshow
        UIAlertController(title: Texts_HomeView.statusActionTitle, message: textToShow, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)

    }
    
    /// user clicked start scanning action, this function will check if bluetooth is on (?) and if not yet scanning, start the scanning
    private func userInitiatesStartScanning() {
        
        // start the scanning, result of the startscanning will be in startScanningResult - this is not the result of the scanning itself. Scanning may have started successfully but maybe the peripheral is not yet connected, maybe it is
        if let startScanningResult = cgmTransmitter?.startScanning() {
            os_log("in userInitiatesStartScanning, startScanningResult = %{public}@", log: log, type: .info, startScanningResult.description())
            switch startScanningResult {
            case .success:
                // success : could be useful to display that scanning has started, however in most cases the connection will immediately happen, causing a second pop up to say that the transmitter is connected, let's not create to many pop ups
                // we do mark that the user initiated the scanning. If connection is setup, we'll inform the user, see cgmTransmitterDidConnect
                userDidInitiateScanning = true
                break
            case .alreadyConnected, .connecting:
                // alreadyConnected : should not happen because that would mean we gave the user the option to start scanning, although there is already a connection
                // connecting : same as for alreadyConnected
                break
            case .alreadyScanning:
                // probably user started scanning two times, let's show a pop up that scanning is ongoing
                UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.scanBluetoothDeviceOngoing, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
            case .bluetoothNotPoweredOn( _):
                // bluetooth is not on, user should switch it on
                UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.bluetoothIsNotOn, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
            case .other(let reason):
                // other unknown error occured
                UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: "Error while starting scanning. Reason : " + reason, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
            }
        }
    }
    
    /// user clicked forget device action, this function will forget the device
    private func userInitiatesForgetDevice() {
        
        // set device address and name to nil in userdefaults
        UserDefaults.standard.bluetoothDeviceAddress = nil
        UserDefaults.standard.bluetoothDeviceName =  nil

        // setting cgmTransmitter to nil,  the deinit function of the currently used cgmTransmitter will be called, which will disconnect the device
        setCGMTransmitterToNil()
        
        // by calling initializeCGMTransmitter, a new cgmTransmitter will be created - as it should be a device which does not automatically start scanning (otherwise we wouldn't be here). It will just create the transmitter but it will not scan, this needs to be initiated by the user
        initializeCGMTransmitter()

    }
    
    // stop the active sensor
    private func stopSensor() {
        if let activeSensor = activeSensor, let coreDataManager = coreDataManager {
            activeSensor.endDate = Date()
            coreDataManager.saveChanges()
        }
        activeSensor = nil
        
        // save the changes
        coreDataManager?.saveChanges()
    }
    
    // start a new sensor
    private func startSensor() {
        
        // craete timePickAlertController , but don't open it yet
        let timePickAlertController = UIAlertController(title:nil, message:nil, datePickerMode: .dateAndTime, date: Date(), minimumDate: nil, maximumDate: nil, actionHandler: {(dateTimePicker) in
            // set sensorStartTime
            if let coreDataManager = self.coreDataManager {
                let sensorStartTime = dateTimePicker.date
                self.activeSensor = Sensor(startDate: sensorStartTime, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                // save the newly created Sensor permenantly in coredata
                coreDataManager.saveChanges()
            }
        }, cancelHandler: nil)
        
        // if this is the first time user starts a sensor, give warning that time should be correct
        // if not the first them, then immediately open the timePickAlertController
        if (!UserDefaults.standard.startSensorTimeInfoGiven) {
            UIAlertController(title: Texts_HomeView.startSensorActionTitle, message: Texts_HomeView.startSensorTimeInfo, actionHandler: {
                self.present(timePickAlertController, animated: true, completion: nil)
                UserDefaults.standard.startSensorTimeInfoGiven = true
            }).presentInOwnWindow(animated: true, completion: nil)
        } else {
            self.present(timePickAlertController, animated: true, completion: nil)
        }

    }

}

/// conform to CGMTransmitterDelegate
extension RootViewController:CGMTransmitterDelegate {
    
    // MARK: - CGMTransmitter protocol functions
    
    func cgmTransmitterDidConnect(address:String?, name:String?) {
        // store address and name, if this is the first connect to a specific device, then this address and name will be used in the future to reconnect to the same device, without having to scan
        if let address = address, let name = name {
            UserDefaults.standard.bluetoothDeviceAddress = address
            UserDefaults.standard.bluetoothDeviceName =  name
        }
        
        // if the connect is a result of a user initiated start scanning, then display message that connection was successful
        if userDidInitiateScanning {
            userDidInitiateScanning = false
            // additional info for the user
            UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.bluetoothDeviceConnectedInfo, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
        }
    }
    
    func cgmTransmitterDidDisconnect() {
        
        // set disconnect timestamp
        UserDefaults.standard.lastdisConnectTimestamp = Date()
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState) {
        
        switch state {
            
        case .unknown:
            break
        case .resetting:
            break
        case .unsupported:
            break
        case .unauthorized:
            break
        case .poweredOff:
            UserDefaults.standard.lastdisConnectTimestamp = Date()
        case .poweredOn:
            // user changes device bluetooth status to on
            if UserDefaults.standard.bluetoothDeviceAddress == nil, let cgmTransmitter = cgmTransmitter, let transmitterType  = UserDefaults.standard.transmitterType, transmitterType.startScanningAfterInit() {
                // bluetoothDeviceAddress = nil, means app hasn't connected before to the transmitter
                // cgmTransmitter != nil, means user has configured transmitter type and transmitterid
                // transmitterType.startScanningAfterInit() gives true, means it's ok to start the scanning
                // possibly scanning is already running, but that's ok if we call the startScanning function again
                _ = cgmTransmitter.startScanning()
            }

        }
        
    }
    
    func cgmTransmitterNeedsPairing() {
        //TODO: needs implementation
        print("NEEDS IMPLEMENTATION")
    }
    
    // Only MioaMiao will call this
    func newSensorDetected() {
        os_log("new sensor detected", log: log, type: .info)
        stopSensor()
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
        
        processNewCGMInfo(glucoseData: &glucoseData, sensorState: sensorState, firmware: firmware, hardware: hardware, transmitterBatteryInfo: transmitterBatteryInfo, sensorTimeInMinutes: sensorTimeInMinutes)
    }

}

/// conform to UITabBarControllerDelegate, want to receive info when user clicks specific tabs
extension RootViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        
        // if user clicks the tab for settings, then configure it
        if let navigationController = viewController as? SettingsNavigationController {
            navigationController.configure(coreDataManager: coreDataManager)
        }
    }
}

/// conform to UNUserNotificationCenterDelegate, for notifications
extension RootViewController:UNUserNotificationCenterDelegate {
    
    //called when notification fired while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        if notification.request.identifier == Constants.Notifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
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
    
    // called when user clicks a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("userNotificationCenter didReceive", log: log, type: .info)
        
        if response.notification.request.identifier == Constants.Notifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            os_log("     userNotificationCenter didReceive, user pressed calibration notification to open the app", log: log, type: .info)
            // request calibration
            requestCalibration()
            
            // call completionhandler
            completionHandler()
        } else {
            // it's not an initial calibration request notification that the user clicked, by calling alertManager?.userNotificationCenter, we check if it was an alert notification that was clicked and if yes pickerViewData will have the list of alert snooze values
            if let pickerViewData = alertManager?.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler) {
                os_log("     userNotificationCenter didReceive, user pressed an alert notification to open the app", log: log, type: .info)
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
                
            } else {
                // it as also not an alert notification that the user clicked, there might come in other types of notifications in the future
            }
        }
    }
}

