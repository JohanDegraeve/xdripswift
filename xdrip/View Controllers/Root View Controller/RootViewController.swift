import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications
import AVFoundation
import AudioToolbox
import SwiftCharts
import HealthKitUI
    
/// viewcontroller for the home screen
final class RootViewController: UIViewController {
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Properties - Outlets and Actions for buttons and labels in home screen
    
    // app string outlet
    
    @IBOutlet weak var appInfoOutlet: UILabel!
    
    @IBOutlet weak var calibrateButtonOutlet: UIButton!
    
    @IBAction func calibrateButtonAction(_ sender: UIButton) {
        
        if let transmitterType = UserDefaults.standard.transmitterType, transmitterType.canWebOOP(), UserDefaults.standard.webOOPEnabled {
            
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.calibrationNotNecessary, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            requestCalibration(userRequested: true)
        }
        
    }
    
    @IBOutlet weak var transmitterButtonOutlet: UIButton!
    
    @IBAction func transmitterButtonAction(_ sender: UIButton) {
        createAndPresentTransmitterButtonActionSheet()
    }
    
    @IBOutlet weak var preSnoozeButtonOutlet: UIButton!
    
    @IBAction func preSnoozeButtonAction(_ sender: UIButton) {
        
        let alert = UIAlertController(title: "Info", message: "Unfortuantely, presnooze functionality is not yet implemented", actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)

    }
    
    /// outlet for label that shows how many minutes ago and so on
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    
    /// outlet for label that shows difference with previous reading
    @IBOutlet weak var diffLabelOutlet: UILabel!
    
    /// outlet for label that shows the current reading
    @IBOutlet weak var valueLabelOutlet: UILabel!

    /// outlet for chart
    @IBOutlet weak var chartOutlet: BloodGlucoseChartView!
    
    /// user long pressed the value label
    @IBAction func valueLabelLongPressGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        valueLabelLongPressed(sender)
    }
    
    @IBAction func chartPanGestureRecognizerAction(_ sender: UIPanGestureRecognizer) {
        
        glucoseChartManager.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: {

            // user has been panning, if chart is panned backward, then need to set valueLabel to value of latest chartPoint shown in the chart, and minutesAgo text to timeStamp of latestChartPoint
            if self.glucoseChartManager.chartIsPannedBackward {
                
                if let lastChartPointEarlierThanEndDate = self.glucoseChartManager.lastChartPointEarlierThanEndDate, let chartAxisValueDate = lastChartPointEarlierThanEndDate.x as? ChartAxisValueDate  {
                    
                    // valuueLabel text should not be strikethrough (might still be strikethrough in case latest reading is older than 10 minutes
                    self.valueLabelOutlet.attributedText = nil
                    // set value to value of latest chartPoint

                    self.valueLabelOutlet.text = lastChartPointEarlierThanEndDate.y.scalar.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

                    // set timestamp to timestamp of latest chartPoint, in red so user can notice this is an old value
                    self.minutesLabelOutlet.text =  self.dateTimeFormatterForMinutesLabelWhenPanning.string(from: chartAxisValueDate.date)
                    self.minutesLabelOutlet.textColor = UIColor.red
                    self.valueLabelOutlet.textColor = UIColor.lightGray

                    // apply strikethrough to the BG value text format
                    
                    let attributedString = NSMutableAttributedString(string: self.valueLabelOutlet.text!)
                attributedString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: 1, range: NSMakeRange(0, attributedString.length))
                    
                // attributedString.addAttribute(NSAttributedString.Key.strikethroughColor, value: UIColor.darkGray, range: NSMakeRange(0, attributedString.length))
                    
                    self.valueLabelOutlet.attributedText = attributedString
                    
                    // don't show anything in diff outlet
                    self.diffLabelOutlet.text = ""
                    
                } else {
                    
                    // this should normally not happen because lastChartPointEarlierThanEndDate should normally always be set
                    self.updateLabelsAndChart(overrideApplicationState: false)
                    
                }

            } else {
                
                // chart is not panned, update labels is necessary
                self.updateLabelsAndChart(overrideApplicationState: false)
                
            }
            
        })
        
    }
    
    @IBOutlet var chartPanGestureRecognizerOutlet: UIPanGestureRecognizer!
    
    @IBAction func chartLongPressGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        
        // this one needs trigger in case user has panned, chart is decelerating, user clicks to stop the decleration, call to handleUIGestureRecognizer will stop the deceleration
        // there's no completionhandler needed because the call in chartPanGestureRecognizerAction to handleUIGestureRecognizer already includes a completionhandler
        glucoseChartManager.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: nil)
        
    }
    
    @IBOutlet var chartLongPressGestureRecognizerOutlet: UILongPressGestureRecognizer!
    
    // MARK: - Constants for ApplicationManager usage
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create updateLabelsAndChartTimer
    private let applicationManagerKeyCreateupdateLabelsAndChartTimer = "RootViewController-CreateupdateLabelsAndChartTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - invalidate updateLabelsAndChartTimer
    private let applicationManagerKeyInvalidateupdateLabelsAndChartTimer = "RootViewController-InvalidateupdateLabelsAndChartTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - updateLabels
    private let applicationManagerKeyUpdateLabelsAndChart = "RootViewController-UpdateLabelsAndChart"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - initiate pairing
    private let applicationManagerKeyInitiatePairing = "RootViewController-InitiatePairing"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - initial calibration
    private let applicationManagerKeyInitialCalibration = "RootViewController-InitialCalibration"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground -  isIdleTimerDisabled
    private let applicationManagerKeyIsIdleTimerDisabled = "RootViewController-isIdleTimerDisabled"
    
    // MARK: - Properties - other private properties
    
    /// a reference to the CGMTransmitter currently in use - nil means there's none, because user hasn't selected yet all required settings
    private var cgmTransmitter:CGMTransmitter?
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// coreDataManager to be used throughout the project
    private var coreDataManager:CoreDataManager?
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// calibrator to be used for calibration, value will depend on transmitter type
    private var calibrator:Calibrator?
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    /// CalibrationsAccessor instance
    private var calibrationsAccessor:CalibrationsAccessor?
    
    /// NightScoutUploadManager instance
    private var nightScoutUploadManager:NightScoutUploadManager?
    
    /// AlerManager instance
    private var alertManager:AlertManager?
    
    /// SoundPlayer instance
    private var soundPlayer:SoundPlayer?
    
    /// nightScoutFollowManager instance
    private var nightScoutFollowManager:NightScoutFollowManager?
    
    /// dexcomShareUploadManager instance
    private var dexcomShareUploadManager:DexcomShareUploadManager?
    
    /// WatchManager instance
    private var watchManager: WatchManager?
    
    /// timer used when asking the transmitter to initiate pairing. The user is waiting for the response, if the response from the transmitter doesn't come within a few seconds, then we'll inform the user
    private var transmitterPairingResponseTimer:Timer?
    
    /// healthkit manager instance
    private var healthKitManager:HealthKitManager?
    
    /// reference to activeSensor
    private var activeSensor:Sensor?
    
    /// if true, user manually started scanning for a device, when connection is made, we'll inform the user, see cgmTransmitterDidConnect
    private var userDidInitiateScanning = false
    
    /// reference to bgReadingSpeaker
    private var bgReadingSpeaker:BGReadingSpeaker?
    
    /// timestamp of last notification for pairing
    private var timeStampLastNotificationForPairing:Date?
    
    /// manages bluetoothPeripherals that this app knows
    private var bluetoothPeripheralManager: BluetoothPeripheralManager?
    
    /// manage glucose chart
    private var glucoseChartManager: GlucoseChartManager!
    
    /// dateformatter for minutesLabelOutlet, when user is panning the chart
    private let dateTimeFormatterForMinutesLabelWhenPanning: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = ConstantsGlucoseChart.dateFormatLatestChartPointWhenPanning
        
        return dateFormatter
    }()
    
    // MARK: - View Life Cycle
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // never seen it triggered, copied that from Loop
        glucoseChartManager.didReceiveMemoryWarning()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // viewWillAppear when user switches eg from Settings Tab to Home Tab - latest reading value needs to be shown on the view, and also update minutes ago etc.
        updateLabelsAndChart(overrideApplicationState: true)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // initialize glucoseChartManager
        glucoseChartManager = GlucoseChartManager(chartLongPressGestureRecognizer: chartLongPressGestureRecognizerOutlet)

        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            
            self.setupApplicationData()
            
            // glucoseChartManager still needs the reference to coreDataManager
            self.glucoseChartManager.coreDataManager = self.coreDataManager

            // update label texts, minutes ago, diff and value
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            // create transmitter based on UserDefaults
            self.initializeCGMTransmitter()
            
            // if licenseinfo not yet accepted, show license info with only ok button
            if !UserDefaults.standard.licenseInfoAccepted {
                
                let alert = UIAlertController(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress, actionHandler: {
                    
                    // set licenseInfoAccepted to true
                    UserDefaults.standard.licenseInfoAccepted = true
                    
                    // create info screen about transmitters
                    let infoScreenAlert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.transmitterInfo, actionHandler: nil)
                    
                    self.present(infoScreenAlert, animated: true, completion: nil)
                    
                })
                
                self.present(alert, animated: true, completion: nil)
                
            }

        })
        
        // Setup View
        setupView()
        
        // observe setting changes
        // when user changes transmitter type or transmitter id, theThat's why observer for these settings is required
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.transmitterTypeAsString.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.transmitterId.rawValue, options: .new, context: nil)
        // changing from follower to master or vice versa requires transmitter setup
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new
            , context: nil)
        // need to prepare transmitter reset
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.transmitterResetRequired.rawValue, options: .new
            , context: nil)
        // web oop
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.webOOPEnabled.rawValue, options: .new
            , context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.webOOPtoken.rawValue, options: .new
            , context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.webOOPsite.rawValue, options: .new
            , context: nil)
        // bg reading notification and badge, and multiplication factor
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInNotification.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInAppBadge.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.multipleAppBadgeValueWith10.rawValue, options: .new, context: nil)
        // also update of unit requires update of badge
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)

        // setup delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self
        
        // check if app is allowed to send local notification and if not ask it
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            switch notificationSettings.authorizationStatus {
            case .notDetermined, .denied:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
                    if let error = error {
                        trace("Request Notification Authorization Failed : %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
                    }
                }
            default:
                break
            }
        }
        
        // setup self as delegate for tabbarcontrolelr
        self.tabBarController?.delegate = self
        
        // setup the timer logic for updating the view regularly
        setupUpdateLabelsAndChartTimer()
        
        // whenever app comes from-back to foreground, updateLabelsAndChart needs to be called
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyUpdateLabelsAndChart, closure: {self.updateLabelsAndChart(overrideApplicationState: true)})
        
        // setup AVAudioSession
        setupAVAudioSession()
        
        // initialize chartGenerator in chartOutlet
        self.chartOutlet.chartGenerator = { [weak self] (frame) in
            return self?.glucoseChartManager.glucoseChartWithFrame(frame)?.view
        }
        
        // user may have long pressed the value label, so the screen will not lock, when going back to background, set isIdleTimerDisabled back to false
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyIsIdleTimerDisabled, closure: {
            UIApplication.shared.isIdleTimerDisabled = false
        })

    }
    
    /// sets AVAudioSession category to AVAudioSession.Category.playback with option mixWithOthers and
    /// AVAudioSession.sharedInstance().setActive(true)
    private func setupAVAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            trace("in init, could not set AVAudioSession category to playback and mixwithOthers, error = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
    }
    
    // creates activeSensor, bgreadingsAccessor, calibrationsAccessor, NightScoutUploadManager, soundPlayer, dexcomShareUploadManager, nightScoutFollowManager, alertManager, healthKitManager, bgReadingSpeaker, bluetoothPeripheralManager, watchManager
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
        
        // instantiate calibrations
        calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        
        // setup nightscout synchronizer
        nightScoutUploadManager = NightScoutUploadManager(coreDataManager: coreDataManager, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        // setup SoundPlayer
        soundPlayer = SoundPlayer()
        
        // setup FollowManager
        guard let soundPlayer = soundPlayer else { fatalError("In setupApplicationData, this looks very in appropriate, shame")}
        
        // setup nightscoutmanager
        nightScoutFollowManager = NightScoutFollowManager(coreDataManager: coreDataManager, nightScoutFollowerDelegate: self)
        
        // setup alertmanager
        alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        
        // setup healthkitmanager
        healthKitManager = HealthKitManager(coreDataManager: coreDataManager)
        
        // setup bgReadingSpeaker
        bgReadingSpeaker = BGReadingSpeaker(sharedSoundPlayer: soundPlayer, coreDataManager: coreDataManager)
        
        // setup dexcomShareUploadManager
        dexcomShareUploadManager = DexcomShareUploadManager(bgReadingsAccessor: bgReadingsAccessor, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        // setup bluetoothPeripheralManager
        bluetoothPeripheralManager = BluetoothPeripheralManager(coreDataManager: coreDataManager, cgmTransmitterDelegate: self, onCGMTransmitterCreation: {
            (cgmTransmitter: CGMTransmitter?) in
            
            self.cgmTransmitter = cgmTransmitter
            
        })
        
        // setup watchmanager
        watchManager = WatchManager(coreDataManager: coreDataManager)
        
    }
    
    /// process new glucose data received from transmitter.
    /// - parameters:
    ///     - glucoseData : array with new readings
    ///     - sensorTimeInMinutes : should be present only if it's the first reading(s) being processed for a specific sensor and is needed if it's a transmitterType that returns true to the function canDetectNewSensor
    private func processNewGlucoseData(glucoseData: inout [GlucoseData], sensorTimeInMinutes: Int?) {
        
        // check that calibrations and coredata manager is not nil
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = coreDataManager else {
            fatalError("in processNewCGMInfo, calibrations or coreDataManager is nil")
        }
        
        if activeSensor == nil {
            
            if let sensorTimeInMinutes = sensorTimeInMinutes, UserDefaults.standard.transmitterType?.canDetectNewSensor() ?? false {
                activeSensor = Sensor(startDate: Date(timeInterval: -Double(sensorTimeInMinutes * 60), since: Date()),nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                if let activeSensor = activeSensor {
                    trace("created sensor with id : %{public}@ and startdate  %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, activeSensor.id, activeSensor.startDate.description)
                } else {
                    trace("creation active sensor failed", log: log, category: ConstantsLog.categoryRootView, type: .info)
                }
                
                // save the newly created Sensor permenantly in coredata
                coreDataManager.saveChanges()
            }
            
        }
        
        // also for cases where calibration is not needed, we go through this code
        if let activeSensor = activeSensor, let calibrator = calibrator, let bgReadingsAccessor = bgReadingsAccessor {
            
            // initialize help variables
            var latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
            var lastCalibrationsForActiveSensorInLastXDays = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
            let lastCalibrationForActiveSensor = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            
            // was a new reading created or not
            var newReadingCreated = false
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            if let lastReading = bgReadingsAccessor.last(forSensor: activeSensor) {
                timeStampLastBgReading = lastReading.timeStamp
            }
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, let's create first the oldest, although it shouldn't matter in what order the readings are created
            for (_, glucose) in glucoseData.enumerated().reversed() {
                if glucose.timeStamp > timeStampLastBgReading {
                    
                    _ = calibrator.createNewBgReading(rawData: (Double)(glucose.glucoseLevelRaw), filteredData: (Double)(glucose.glucoseLevelRaw), timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: UserDefaults.standard.cgmTransmitterDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
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
                
                // only for webOOPEnabled : if no two calibration exist yet then create calibration request notification, otherwise a bgreading notification and update labels
                if firstCalibrationForActiveSensor == nil && lastCalibrationForActiveSensor == nil && !UserDefaults.standard.webOOPEnabled {
                    // there must be at least 2 readings
                    let latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                    
                    if latestReadings.count > 1 {
                        createInitialCalibrationRequest()
                    }
                    
                } else {
                    // update notification
                    createBgReadingNotificationAndSetAppBadge()
                    // update all text in  first screen
                    updateLabelsAndChart(overrideApplicationState: false)
                }
                
                nightScoutUploadManager?.upload()
                
                alertManager?.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsMaster.maximumBgReadingAgeForAlertsInSeconds)
                
                healthKitManager?.storeBgReadings()

                bgReadingSpeaker?.speakNewReading()
                
                dexcomShareUploadManager?.upload()
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                watchManager?.processNewReading()
                
            }
        }
        
    }
    
    // MARK:- observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                // for these three settings, a forgetdevice can be done and reinitialize cgmTransmitter. In case of switching from master to follower, initializeCGMTransmitter will not initialize a cgmTransmitter, so it's ok to call that function
                case UserDefaults.Key.transmitterTypeAsString, UserDefaults.Key.transmitterId, UserDefaults.Key.isMaster :
                    
                    // transmittertype change triggered by user, should not be done within 200 ms
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // there's no need to stop the sensor here, maybe the user is just switching from xdrip a to xdrip b
                        // except if moving to follower
                        if !UserDefaults.standard.isMaster {
                            stopSensor()
                        }
                        
                        // forget current device
                        forgetDevice()
                        
                        // set up na transmitter
                        initializeCGMTransmitter()
                    }
                    
                case UserDefaults.Key.transmitterResetRequired :
                    
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        cgmTransmitter?.reset(requested: UserDefaults.standard.transmitterResetRequired)
                    }
                    
                case UserDefaults.Key.webOOPEnabled:
                    
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // set webOOPEnabled for transmitter to new value - there's no need to reinit the transmitter, values like device address, timstamp of last reading, connection status, ... can stay as is
                        cgmTransmitter?.setWebOOPEnabled(enabled: UserDefaults.standard.webOOPEnabled)
                        
                        // call stopSensor which sets activeSensor to nil. Swapping from enabled to not enabled, requires that user will need to calibrate the sensor, it needs to be a new entry in the database. (it's probably nil anyway) - a  new sensor will be created as soon as a reading arrives
                        stopSensor()
                        
                        // reinitialize calibrator
                        // calling initializeCGMTransmitter is not a good idea here because that would mean set cgmTransmitter to nil, for some type of transmitters that would mean the user needs to scan again
                        if let selectedTransmitterType = UserDefaults.standard.transmitterType {
                            calibrator = RootViewController.getCalibrator(transmitterType: selectedTransmitterType, webOOPEnabled: UserDefaults.standard.webOOPEnabled)
                        }
                    }
                    
                case UserDefaults.Key.webOOPtoken, UserDefaults.Key.webOOPsite:
                    cgmTransmitter?.setWebOOPSiteAndToken(oopWebSite: UserDefaults.standard.webOOPSite ?? ConstantsLibreOOP.site, oopWebToken: UserDefaults.standard.webOOPtoken ?? ConstantsLibreOOP.token)
                    
                case UserDefaults.Key.showReadingInNotification:
                    if !UserDefaults.standard.showReadingInNotification {
                        // remove existing notification if any
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])

                    }
                    
                case UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl:
                    // this will trigger update of app badge, will also create notification, but as app is most likely in foreground, this won't show up
                    createBgReadingNotificationAndSetAppBadge()
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - View Methods
    
    /// Configure View, only stuff that is independent of coredata
    private func setupView() {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
        // set texts for buttons on top
        calibrateButtonOutlet.setTitle(Texts_HomeView.calibrationButton, for: .normal)
        preSnoozeButtonOutlet.setTitle(Texts_HomeView.snoozeButton, for: .normal)
        transmitterButtonOutlet.setTitle(Texts_HomeView.transmitter, for: .normal)
        
        chartLongPressGestureRecognizerOutlet.delegate = self
        chartPanGestureRecognizerOutlet.delegate = self
        
        // at this moment, coreDataManager is not yet initialized, we're just calling here prerender and reloadChart to show the chart with x and y axis and gridlines, but without readings. The readings will be loaded once coreDataManager is setup, after which updateChart() will be called, which will initiate loading of readings from coredata
        self.chartOutlet.reloadChart()

    }
    
    // MARK: - private helper functions
    
    // inform user that pairing request timed out
    @objc private func informUserThatPairingTimedOut() {
        
        let alert = UIAlertController(title: Texts_Common.warning, message: "time out", actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// will update the chart with endDate = currentDate
    private func updateChartWithResetEndDate() {
        
        glucoseChartManager.updateGlucoseChartPoints(endDate: Date(), startDate: nil, chartOutlet: chartOutlet, completionHandler: nil)

    }
    
    /// will call cgmTransmitter.initiatePairing() - also sets timer, if no successful pairing within a few seconds, then info will be given to user asking to wait another few minutes
    private func initiateTransmitterPairing() {
        
        // initiate the pairing
        cgmTransmitter?.initiatePairing()
        
        // invalide the timer, if it exists
        if let transmitterPairingResponseTimer = transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
        
        // create and schedule timer
        transmitterPairingResponseTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(informUserThatPairingTimedOut), userInfo: nil, repeats: false)
        
    }
    
    /// launches timer that will do regular screen updates - and adds closure to ApplicationManager : when going to background, stop the timer, when coming to foreground, restart the timer
    ///
    /// should be called only once immediately after app start, ie in viewdidload
    private func setupUpdateLabelsAndChartTimer() {
        
        // this is the actual timer
        var updateLabelsAndChartTimer:Timer?
        
        // create closure to invalide the timer, if it exists
        let invalidateUpdateLabelsAndChartTimer = {
            if let updateLabelsAndChartTimer = updateLabelsAndChartTimer {
                updateLabelsAndChartTimer.invalidate()
            }
        }
        
        // create closure that launches the timer to update the first view every x seconds, and returns the created timer
        let createAndScheduleUpdateLabelsAndChartTimer:() -> Timer = {
            // check if timer already exists, if so invalidate it
            invalidateUpdateLabelsAndChartTimer()
            // now recreate, schedule and return
            return Timer.scheduledTimer(timeInterval: ConstantsHomeView.updateHomeViewIntervalInSeconds, target: self, selector: #selector(self.updateLabelsAndChart), userInfo: nil, repeats: true)
        }
        
        // call scheduleUpdateLabelsAndChartTimer function now - as the function setupUpdateLabelsAndChartTimer is called from viewdidload, it will be called immediately after app launch
        updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()
        
        // updateLabelsAndChartTimer needs to be created when app comes back from background to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyCreateupdateLabelsAndChartTimer, closure: {updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()})
        
        // updateLabelsAndChartTimer needs to be invalidated when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyInvalidateupdateLabelsAndChartTimer, closure: {invalidateUpdateLabelsAndChartTimer()})
    }
    
    /// opens an alert, that requests user to enter a calibration value, and calibrates
    /// - parameters:
    ///     - userRequested : if true, it's a requestCalibration initiated by user clicking on the calibrate button in the homescreen
    private func requestCalibration(userRequested:Bool) {
        
        // check that calibrationsAccessor is not nil
        guard let calibrationsAccessor = calibrationsAccessor else {
            fatalError("in requestCalibration, calibrationsAccessor is nil")
        }
        
        // check if sensor active and if not don't continue
        guard let activeSensor = activeSensor else {
            
            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.startSensorBeforeCalibration, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
            return
        }
        
        // if it's a user requested calibration, but there's no calibration yet, then give info and return - first calibration will be requested by app via notification
        if calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) == nil && userRequested {
            
            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.thereMustBeAreadingBeforeCalibration, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
            return
        }
        
        let alert = UIAlertController(title: Texts_Calibrations.enterCalibrationValue, message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: nil))
        
        alert.addTextField(configurationHandler: { textField in
            textField.keyboardType = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad
            textField.placeholder = "..."
        })
        
        alert.addAction(UIAlertAction(title: Texts_Common.Ok, style: .default, handler: { action in
            if let coreDataManager = self.coreDataManager, let bgReadingsAccessor = self.bgReadingsAccessor {
                if let textField = alert.textFields, let first = textField.first, let value = first.text {
                    
                    guard let valueAsDouble = value.toDouble() else {
                        self.present(UIAlertController(title: Texts_Common.warning, message: Texts_Common.invalidValue, actionHandler: nil), animated: true, completion: nil)
                        return
                    }
                    
                    let valueAsDoubleConvertedToMgDl = valueAsDouble.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    
                    var latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                    
                    var latestCalibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                    
                    if let calibrator = self.calibrator {
                        if latestCalibrations.count == 0 {
                            // calling initialCalibration will create two calibrations, they are returned also but we don't need them
                            _ = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDoubleConvertedToMgDl, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDoubleConvertedToMgDl, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName: UserDefaults.standard.cgmTransmitterDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        } else {
                            // it's not the first calibration
                            if let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) {
                                // calling createNewCalibration will create a new  calibrations, it is returned but we don't need it
                                _ = calibrator.createNewCalibration(bgValue: valueAsDoubleConvertedToMgDl, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName: UserDefaults.standard.cgmTransmitterDeviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                            }
                        }
                        
                        // this will store the newly created calibration(s) in coredata
                        coreDataManager.saveChanges()
                        
                        // initiate upload to NightScout, if needed
                        if let nightScoutUploadManager = self.nightScoutUploadManager {
                            nightScoutUploadManager.upload()
                        }
                        
                        // initiate upload to Dexcom Share, if needed
                        if let dexcomShareUploadManager = self.dexcomShareUploadManager {
                            dexcomShareUploadManager.upload()
                        }
                        
                        // check alerts
                        if let alertManager = self.alertManager {
                            alertManager.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsMaster.maximumBgReadingAgeForAlertsInSeconds)
                        }
                        
                        // update labels
                        self.updateLabelsAndChart(overrideApplicationState: false)
                        
                        // bluetoothPeripherals (M5Stack, ..) should receive latest reading with calculated value
                        self.bluetoothPeripheralManager?.sendLatestReading()
                        
                        // watchManager should process new reading
                        self.watchManager?.processNewReading()

                    }
                }
            }
        }))
        self.present(alert, animated: true)
    }
    
    /// will set first cgmTransmitter to nil, reads transmittertype from userdefaults, if applicable also transmitterid and if available creates the property cgmTransmitter - if follower mode then cgmTransmitter is set to nil
    ///
    /// depending on transmitter type, scanning will automatically start as soon as cgmTransmitter is created
    private func initializeCGMTransmitter() {
        
        // setting cgmTransmitter to nil, if currently cgmTransmitter is not nil, by assign to nil the deinit function of the currently used cgmTransmitter will be called, which will deconnect the device
        // setting to nil is also done in other places, doing it again just to be 100% sure
        cgmTransmitter = nil
        
        // if transmitter type is set and device is master
        if let selectedTransmitterType = UserDefaults.standard.transmitterType, UserDefaults.standard.isMaster {
            
            // first create transmitter
            switch selectedTransmitterType {
                
            case .dexcomG4:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMG4xDripTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, transmitterID: currentTransmitterId, delegate:self)
                }
                
            case .dexcomG5:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMG5Transmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, transmitterID: currentTransmitterId, delegate: self)
                }
                
            case .dexcomG6:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMG6Transmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, transmitterID: currentTransmitterId, delegate: self)
                }
                
            case .miaomiao:
                cgmTransmitter = CGMMiaoMiaoTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0), webOOPEnabled: UserDefaults.standard.webOOPEnabled, oopWebSite: UserDefaults.standard.webOOPSite ?? ConstantsLibreOOP.site, oopWebToken: UserDefaults.standard.webOOPtoken ?? ConstantsLibreOOP.token)
                
            case .Bubble:
                cgmTransmitter = CGMBubbleTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0), sensorSerialNumber: UserDefaults.standard.sensorSerialNumber, webOOPEnabled: UserDefaults.standard.webOOPEnabled, oopWebSite: UserDefaults.standard.webOOPSite ?? ConstantsLibreOOP.site, oopWebToken: UserDefaults.standard.webOOPtoken ?? ConstantsLibreOOP.token)
                
            case .GNSentry:
                cgmTransmitter = CGMGNSEntryTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0))
                
            case .Blucon:
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    cgmTransmitter = CGMBluconTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, transmitterID: currentTransmitterId, delegate: self, timeStampLastBgReading: Date(timeIntervalSince1970: 0), sensorSerialNumber: UserDefaults.standard.sensorSerialNumber)
                }
                
            case .Droplet1:
                cgmTransmitter = CGMDroplet1Transmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, delegate: self)
                
            case .blueReader:
                cgmTransmitter = CGMBlueReaderTransmitter(address: UserDefaults.standard.cgmTransmitterDeviceAddress, name: UserDefaults.standard.cgmTransmitterDeviceName, delegate: self)
                
            case .watlaa:
                // watlaa transmitter needs to be set through bluetooth devices tab
                cgmTransmitter = nil
                
            }
            
            // assign calibrator
            switch selectedTransmitterType {
                
            case .dexcomG4, .dexcomG5, .dexcomG6:
                calibrator = DexcomCalibrator()
            case .miaomiao, .GNSentry, .Blucon, .Bubble, .Droplet1, .blueReader, .watlaa:
                // for all transmitters used with Libre1, calibrator is either NoCalibrator or Libre1Calibrator, depending if oopWeb is supported by the transmitter and on value of webOOPEnabled in settings
                calibrator = RootViewController.getCalibrator(transmitterType: selectedTransmitterType, webOOPEnabled: UserDefaults.standard.webOOPEnabled)
            }
        }
        
        //reset UserDefaults.standard.transmitterResetRequired to false, might have been set to true.
        UserDefaults.standard.transmitterResetRequired = false
    }
    
    /// if transmitterType.canWebOOP and UserDefaults.standard.webOOPEnabled then returns an instance of NoCalibrator otherwise returns an instance of Libre1Calibrator
    ///
    /// this is just some functionality which is used frequently
    private static func getCalibrator(transmitterType: CGMTransmitterType, webOOPEnabled: Bool) -> Calibrator {
        
        if transmitterType.canWebOOP() && UserDefaults.standard.webOOPEnabled {
            return NoCalibrator()
        } else {
            return Libre1Calibrator()
        }
        
    }
    
    /// for debug purposes
    private func logAllBgReadings() {
        if let bgReadingsAccessor = bgReadingsAccessor {
            let readings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: true)
            for (index,reading) in readings.enumerated() {
                if reading.sensor?.id == activeSensor?.id {
                    trace("readings %{public}d timestamp = %{public}@, calculatedValue = %{public}f", log: log, category: ConstantsLog.categoryRootView, type: .info, index, reading.timeStamp.description, reading.calculatedValue)
                }
            }
        }
    }
    
    /// creates initial calibration request notification
    private func createInitialCalibrationRequest() {
        
        // first remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest])
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NotificationContent title
        notificationContent.title = Texts_Calibrations.calibrationNotificationRequestTitle
        
        // Configure NotificationContent body
        notificationContent.body = Texts_Calibrations.calibrationNotificationRequestBody
        
        // Configure NotificationContent sound with defalt sound
        notificationContent.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(""))
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable to Add Notification Request : %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
        
        // we will not just count on it that the user will click the notification to open the app (assuming the app is in the background, if the app is in the foreground, then we come in another flow)
        // whenever app comes from-back to foreground, requestCalibration needs to be called
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyInitialCalibration, closure: {
            
            // first of all reremove from application key manager
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitialCalibration)
            
            // remove existing notification if any
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest])
            
            // request the calibration
            self.requestCalibration(userRequested: false)
            
        })
        
    }
    
    /// creates bgreading notification, and set app badge to value of reading
    private func createBgReadingNotificationAndSetAppBadge() {
        
        // first of all remove the application badge number. Possibly this is an old reading
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // bgReadingsAccessor should not be nil at all, but let's not create a fatal error for that, there's already enough checks for it
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            return
        }
        
        // get lastReading, with a calculatedValue - no check on activeSensor because in follower mode there is no active sensor
        let lastReading = bgReadingsAccessor.getLatestBgReadings(limit: 2, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if there's no reading for active sensor with calculated value , then no reason to continue
        if lastReading.count == 0 {
            trace("in createBgReadingNotificationAndSetAppBadge, lastReading.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            return
        }
        
        // if reading is older than 4.5 minutes, then also no reason to continue - this may happen eg in case of follower mode
        if Date().timeIntervalSince(lastReading[0].timeStamp) > 4.5 * 60 {
            trace("in createBgReadingNotificationAndSetAppBadge, timestamp of last reading > 4.5 * 60", log: log, category: ConstantsLog.categoryRootView, type: .info)
            return
        }
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
        
        // also remove the sensor not detected notification, if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected])
        
        // prepare value for badge
        var readingValueForBadge = lastReading[0].calculatedValue
        // values lower dan 12 are special values, don't show anything
        guard readingValueForBadge > 12 else {return}
        // high limit to 400
        if readingValueForBadge >= 400.0 {readingValueForBadge = 400.0}
        // low limit ti 40
        if readingValueForBadge <= 40.0 {readingValueForBadge = 40.0}
        
        // check if notification on home screen is enabled in the settings
        if UserDefaults.standard.showReadingInNotification  {
            
            // Create Notification Content
            let notificationContent = UNMutableNotificationContent()
            
            // set value in badge if required
            if UserDefaults.standard.showReadingInAppBadge {
                
                // rescale if unit is mmol
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                    readingValueForBadge = readingValueForBadge.mgdlToMmol().roundToDecimal(1)
                } else {
                    readingValueForBadge = readingValueForBadge.roundToDecimal(0)
                }
                
                notificationContent.badge = NSNumber(value: readingValueForBadge.rawValue)
                
            }
            
            // Configure notificationContent title, which is bg value in correct unit, add also slopeArrow if !hideSlope and finally the difference with previous reading, if there is one
            var calculatedValueAsString = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            if !lastReading[0].hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading[0].slopeArrow()
            }
            if lastReading.count > 1 {
                calculatedValueAsString = calculatedValueAsString + "      " + lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: true, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            }
            notificationContent.title = calculatedValueAsString
            
            // must set a body otherwise notification doesn't show up on iOS10
            notificationContent.body = " "
            
            // Create Notification Request
            let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest, content: notificationContent, trigger: nil)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    trace("Unable to Add bg reading Notification Request %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
                }
            }
        }
        else {
            
            // notification shouldn't be shown, but maybe the badge counter. Here the badge value needs to be shown in another way
            if UserDefaults.standard.showReadingInAppBadge {
                
                // rescale of unit is mmol
                readingValueForBadge = readingValueForBadge.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                
                // if unit is mmol and if value needs to be multiplied by 10, then multiply by 10
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.multipleAppBadgeValueWith10 {
                    readingValueForBadge = readingValueForBadge * 10.0
                }
                
                UIApplication.shared.applicationIconBadgeNumber = Int(round(readingValueForBadge))
                
            }
        }

    }
    
    /// - updates the labels and the chart,
    /// - but only if the chart is not panned backward
    /// - and if app is in foreground
    /// - and if overrideApplicationState = false
    /// - parameters:
    ///     - overrideApplicationState : if true, then update will be done even if state is not .active
    @objc private func updateLabelsAndChart(overrideApplicationState: Bool = false) {

        // check that app is in foreground, but only if overrideApplicationState = false
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}

        // check if chart is currently panned back in time, in that case we don't update the labels
        guard !glucoseChartManager.chartIsPannedBackward else {return}

        // check that bgReadingsAccessor exists, otherwise return - this happens if updateLabelsAndChart is called from viewDidload at app launch
        guard let bgReadingsAccessor = bgReadingsAccessor else {return}

        // set minutesLabelOutlet.textColor to white, might still be red due to panning back in time
        self.minutesLabelOutlet.textColor = UIColor.white
        
        // get latest reading, doesn't matter if it's for an active sensor or not, but it needs to have calculatedValue > 0 / which means, if user would have started a new sensor, but didn't calibrate yet, and a reading is received, then there's not going to be a latestReading
        let latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 2, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if there's no readings, then give empty fields
        guard latestReadings.count > 0 else {
            valueLabelOutlet.text = "---"
            minutesLabelOutlet.text = ""
            diffLabelOutlet.text = ""
            return
        }

        // assign last reading
        let lastReading = latestReadings[0]
        // assign last but one reading
        let lastButOneReading = latestReadings.count > 1 ? latestReadings[1]:nil

        // start creating text for valueLabelOutlet, first the calculated value
        var calculatedValueAsString = lastReading.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        // if latestReading older dan 11 minutes, then it should be strikethrough
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11) {
            
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        } else {
            
            if !lastReading.hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading.slopeArrow()
            }
            
            // no strikethrough needed, but attributedText may still be set to strikethrough from previous period during which there was no recent reading. Always set it to nil here, this removes the strikethrough attribute
            valueLabelOutlet.attributedText = nil
            
            valueLabelOutlet.text = calculatedValueAsString
            
        }
        
        // set color, depending on value lower than low mark or higher than high mark
        if lastReading.calculatedValue <= UserDefaults.standard.lowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
            valueLabelOutlet.textColor = UIColor.red
        } else if lastReading.calculatedValue >= UserDefaults.standard.highMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
            valueLabelOutlet.textColor = "#a0b002".hexStringToUIColor()
        } else {
            // keep text colour
            valueLabelOutlet.textColor = UIColor.green
        }
        
        // get minutes ago and create text for minutes ago label
        let minutesAgo = -Int(lastReading.timeStamp.timeIntervalSinceNow) / 60
        let minutesAgoText = minutesAgo.description + " " + (minutesAgo == 1 ? Texts_Common.minute:Texts_Common.minutes) + " " + Texts_HomeView.ago
        
        minutesLabelOutlet.text = minutesAgoText
        
        // create delta text
        diffLabelOutlet.text = lastReading.unitizedDeltaString(previousBgReading: lastButOneReading, showUnit: true, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        // update the chart up to now
        updateChartWithResetEndDate()
        
    }
    
    /// when user clicks transmitter button, this will create and present the actionsheet, contents depend on type of transmitter and sensor status
    private func createAndPresentTransmitterButtonActionSheet() {
        // initialize list of actions
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
                    if UserDefaults.standard.cgmTransmitterDeviceAddress == nil {
                        listOfActions[Texts_HomeView.scanBluetoothDeviceActionTitle] = {(UIAlertAction) in self.userInitiatesStartScanning()}
                    } else {
                        listOfActions[Texts_HomeView.forgetBluetoothDeviceActionTitle] = {(UIAlertAction) in self.forgetDevice()}
                    }
                }
            }
        }
        
        // next action is to start or stop the sensor, can also be omitted depending on type of device - also not applicable for follower mode
        if let transmitterType = UserDefaults.standard.transmitterType {
            if transmitterType.allowManualSensorStart() && UserDefaults.standard.isMaster {
                // user needs to start and stop the sensor manually
                if activeSensor != nil {
                    listOfActions[Texts_HomeView.stopSensorActionTitle] = {(UIAlertAction) in self.stopSensor()}
                } else {
                    listOfActions[Texts_HomeView.startSensorActionTitle] = {(UIAlertAction) in self.startSensorAskUserForStarttime()}
                }
            }
        }
        
        // create and present new alertController of type actionsheet
        let actionSheet = UIAlertController(title: nil, message: nil, actions: listOfActions, cancelAction: (Texts_Common.Cancel, nil))
        
        // following is required for iPad, as explained here https://stackoverflow.com/questions/28089898/actionsheet-not-working-ipad
        // otherwise it crashes on iPad when clicking transmitter button
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
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
        if let deviceName = UserDefaults.standard.cgmTransmitterDeviceName {
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
        if let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo {
            textToShow += Texts_HomeView.transmitterBatteryLevel + " : " + transmitterBatteryInfo.description
            // add 1 newline with last connection timestamp
            textToShow += "\r\n\r\n"
        }
        
        // display textoToshow
        let alert = UIAlertController(title: Texts_HomeView.statusActionTitle, message: textToShow, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// user clicked start scanning action, this function will check if bluetooth is on (?) and if not yet scanning, start the scanning
    private func userInitiatesStartScanning() {
        
        // start the scanning, result of the startscanning will be in startScanningResult - this is not the result of the scanning itself. Scanning may have started successfully but maybe the peripheral is not yet connected, maybe it is
        if let startScanningResult = cgmTransmitter?.startScanning() {
            trace("in userInitiatesStartScanning, startScanningResult = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, startScanningResult.description())
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
                let alert = UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.scanBluetoothDeviceOngoing, actionHandler: nil)
                
                self.present(alert, animated: true, completion: nil)
                
            case .bluetoothNotPoweredOn( _):
                // bluetooth is not on, user should switch it on
                let alert = UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.bluetoothIsNotOn, actionHandler: nil)
                
                self.present(alert, animated: true, completion: nil)
                
            case .other(let reason):
                // other unknown error occured
                let alert = UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: "Error while starting scanning. Reason : " + reason, actionHandler: nil)
                
                self.present(alert, animated: true, completion: nil)
                
            }
        }
    }
    
    ///     - cgmTransmitter to nil, this disconnects also the existing transmitter
    ///     - UserDefaults.standard.transmitterBatteryInfo to nil
    ///     - UserDefaults.standard.lastdisConnectTimestamp to nil
    ///     - UserDefaults.standard.bluetoothDeviceAddress to nil
    ///     - UserDefaults.standard.bluetoothDeviceName to nil
    ///     -
    ///     - calls also initializeCGMTransmitter which recreated the cgmTransmitter property, depending on settings
    private func forgetDevice() {
        
        // set device address and name to nil in userdefaults
        UserDefaults.standard.cgmTransmitterDeviceAddress = nil
        UserDefaults.standard.cgmTransmitterDeviceName =  nil
        
        // setting cgmTransmitter to nil,  the deinit function of the currently used cgmTransmitter will be called, which will disconnect the device
        // set cgmTransmitter to nil, this will call the deinit function which will disconnect first
        cgmTransmitter = nil
        
        // by calling initializeCGMTransmitter, a new cgmTransmitter will be created, assuming it's not follower mode, and transmittertype is selected and if applicable transmitter id is set
        initializeCGMTransmitter()
        
        // reset also UserDefaults.standard.transmitterBatteryInfo
        UserDefaults.standard.transmitterBatteryInfo = nil
        
        // set lastdisconnecttimestamp to nil
        UserDefaults.standard.lastdisConnectTimestamp = nil
        
    }
    
    // stops the active sensor and sets sensorSerialNumber in UserDefaults to nil
    private func stopSensor() {
        
        if let activeSensor = activeSensor, let coreDataManager = coreDataManager {
            activeSensor.endDate = Date()
            coreDataManager.saveChanges()
        }
        // save the changes
        coreDataManager?.saveChanges()
        
        activeSensor = nil
        
        // reset also serialNubmer to nil
        UserDefaults.standard.sensorSerialNumber = nil
        
    }
    
    // start a new sensor, ask user for starttime
    private func startSensorAskUserForStarttime() {
        
        // craete datePickerViewData
        let datePickerViewData = DatePickerViewData(withMainTitle: Texts_HomeView.startSensorActionTitle, withSubTitle: nil, datePickerMode: .dateAndTime, date: Date(), minimumDate: nil, maximumDate: Date(), okButtonText: Texts_Common.Ok, cancelButtonText: Texts_Common.Cancel, onOkClick: {(date) in
            if let coreDataManager = self.coreDataManager {
                
                // set sensorStartTime
                let sensorStartTime = date
                self.activeSensor = Sensor(startDate: sensorStartTime, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                
                // save the newly created Sensor permenantly in coredata
                coreDataManager.saveChanges()
                
            }
        }, onCancelClick: nil)
        
        // if this is the first time user starts a sensor, give warning that time should be correct
        // if not the first them, then immediately open the timePickAlertController
        if (!UserDefaults.standard.startSensorTimeInfoGiven) {
            let alert = UIAlertController(title: Texts_HomeView.startSensorActionTitle, message: Texts_HomeView.startSensorTimeInfo, actionHandler: {
                
                // create and present pickerviewcontroller
                DatePickerViewController.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: self)
                
                // no need to display sensor start time info next sensor start
                UserDefaults.standard.startSensorTimeInfoGiven = true
                
            })
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            DatePickerViewController.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: self)
        }
        
    }
    
    private func valueLabelLongPressed(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            
            // vibrate so that user knows the long press is detected
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            
            // prevent screen lock
            UIApplication.shared.isIdleTimerDisabled = true

        }
    }
    
}

// MARK: - conform to CGMTransmitter protocol

/// conform to CGMTransmitterDelegate
extension RootViewController:CGMTransmitterDelegate {
    
    func getCGMTransmitter() -> CGMTransmitter? {
        return cgmTransmitter
    }
    
    func error(message: String) {
        
        let alert = UIAlertController(title: Texts_Common.warning, message: message, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func reset(successful: Bool) {
        
        // reset setting to false
        UserDefaults.standard.transmitterResetRequired = false
        
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
    
    func pairingFailed() {
        // this should be the consequence of the user not accepting the pairing request, there's no need to inform the user
        // invalidate transmitterPairingResponseTimer
        if let transmitterPairingResponseTimer = transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
    }
    
    func successfullyPaired() {
        
        // remove existing notification if any
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing])
        
        // invalidate transmitterPairingResponseTimer
        if let transmitterPairingResponseTimer = transmitterPairingResponseTimer {
            transmitterPairingResponseTimer.invalidate()
        }
        
        // inform user
        let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.transmitterPairingSuccessful, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func cgmTransmitterDidConnect(address:String?, name:String?) {
        // store address and name, if this is the first connect to a specific device, then this address and name will be used in the future to reconnect to the same device, without having to scan
        if let address = address, let name = name {
            UserDefaults.standard.cgmTransmitterDeviceAddress = address
            UserDefaults.standard.cgmTransmitterDeviceName =  name
        }
        
        // if the connect is a result of a user initiated start scanning, then display message that connection was successful
        if userDidInitiateScanning {
            userDidInitiateScanning = false
            // additional info for the user
            let alert = UIAlertController(title: Texts_HomeView.scanBluetoothDeviceActionTitle, message: Texts_HomeView.bluetoothDeviceConnectedInfo, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
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

            if UserDefaults.standard.cgmTransmitterDeviceAddress == nil, let cgmTransmitter = cgmTransmitter, let transmitterType  = UserDefaults.standard.transmitterType, transmitterType.startScanningAfterInit() {
                // bluetoothDeviceAddress = nil, means app hasn't connected before to the transmitter
                // cgmTransmitter != nil, means user has configured transmitter type and transmitterid
                // transmitterType.startScanningAfterInit() gives true, means it's ok to start the scanning
                // possibly scanning is already running, but that's ok if we call the startScanning function again
                _ = cgmTransmitter.startScanning()
            }

        @unknown default:
            break
        }
        
    }
    
    /// Transmitter is calling this delegate function to indicate that bluetooth pairing is needed. If the app is in the background, the user will be informed, after opening the app a pairing request will be initiated. if the app is in the foreground, the pairing request will be initiated immediately
    func cgmTransmitterNeedsPairing() {
        
        trace("transmitter needs pairing", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        if let timeStampLastNotificationForPairing = timeStampLastNotificationForPairing {
            
            // check timestamp of last notification, if too soon then return
            if Int(abs(timeStampLastNotificationForPairing.timeIntervalSinceNow)) < ConstantsBluetoothPairing.minimumTimeBetweenTwoPairingNotificationsInSeconds {
                return
            }
        }
        
        // set timeStampLastNotificationForPairing
        timeStampLastNotificationForPairing = Date()
        
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
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyInitiatePairing, closure: {
            
            // first of all reremove from application key manager
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitiatePairing)
            
            // first remove existing notification if any
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing])
            
            // if it was too long since notification was fired, then forget about it
            if Date() > maxTimeUserCanOpenApp {
                trace("in cgmTransmitterNeedsPairing, user opened the app too late", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.transmitterPairingTooLate, actionHandler: nil)
                
                self.present(alert, animated: true, completion: nil)
                
                return
            }
            
            // initiate the pairing
            self.cgmTransmitter?.initiatePairing()
            
        })
        
    }
    
    // Only MioaMiao will call this
    func newSensorDetected() {
        trace("new sensor detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        stopSensor()
    }
    
    // MioaMiao and Bubble will call this (and Blucon, maybe others in the future)
    func sensorNotDetected() {
        trace("sensor not detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NnotificationContent title
        notificationContent.title = Texts_Common.warning
        
        notificationContent.body = Texts_HomeView.sensorNotDetected
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable to Add sensor not detected Notification Request %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
    }
    
    /// - parameters:
    ///     - readings: first entry is the most recent
    func cgmTransmitterInfoReceived(glucoseData: inout [GlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorState: LibreSensorState?, sensorTimeInMinutes: Int?, firmware: String?, hardware: String?, hardwareSerialNumber: String?, bootloader: String?, sensorSerialNumber:String?) {
        
        trace("sensorstate %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorState?.description ?? "no sensor state found")
        trace("firmware %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, firmware ?? "no firmware version found")
        trace("bootloader %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, bootloader ?? "no bootloader  found")
        trace("hardwareSerialNumber %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, hardwareSerialNumber ?? "no serialNumber  found")
        trace("sensorSerialNumber %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorSerialNumber ?? "no sensorSerialNumber  found")
        trace("hardware %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, hardware ?? "no hardware version found")
        trace("transmitterBatteryInfo  %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, transmitterBatteryInfo?.description ?? 0)
        trace("sensor time in minutes  %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorTimeInMinutes?.description ?? "not received")
        trace("glucoseData size = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, glucoseData.count.description)
        
        // if received sensorSerialNumber not nil, and if value different from currently stored value, then store it
        if let sensorSerialNumber = sensorSerialNumber {
            if sensorSerialNumber != UserDefaults.standard.sensorSerialNumber {
                UserDefaults.standard.sensorSerialNumber = sensorSerialNumber
            }
        }
        
        // if received transmitterBatteryInfo not nil, then store it
        if let transmitterBatteryInfo = transmitterBatteryInfo {
            UserDefaults.standard.transmitterBatteryInfo = transmitterBatteryInfo
        }
        
        // process new readings
        processNewGlucoseData(glucoseData: &glucoseData, sensorTimeInMinutes: sensorTimeInMinutes)
    }
    
    
}

// MARK: - conform to UITabBarControllerDelegate protocol

/// conform to UITabBarControllerDelegate, want to receive info when user clicks specific tabs
extension RootViewController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        
        // check which tab is being clicked
        if let navigationController = viewController as? SettingsNavigationController, let coreDataManager = coreDataManager, let soundPlayer = soundPlayer {
            
            navigationController.configure(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
            
        } else if let navigationController = viewController as? BluetoothPeripheralNavigationController, let bluetoothPeripheralManager = bluetoothPeripheralManager, let coreDataManager = coreDataManager {

            navigationController.configure(coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
           
        }
    }
    
}

// MARK: - conform to UNUserNotificationCenterDelegate protocol

/// conform to UNUserNotificationCenterDelegate, for notifications
extension RootViewController:UNUserNotificationCenterDelegate {
    
    // called when notification created while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        if notification.request.identifier == ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            
            // request calibration
            requestCalibration(userRequested: false)
            
            /// remove applicationManagerKeyInitialCalibration from application key manager - there's no need to initiate the calibration via this closure
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitialCalibration)
            
            // call completionhandler to avoid that notification is shown to the user
            completionHandler([])
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected {
            
            // call completionhandler to show the notification even though the app is in the foreground, without sound
            completionHandler([.alert])
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForResetResult.transmitterResetResult {
            
            completionHandler([.alert])
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // so actually the app was in the foreground, at the  moment the Transmitter Class called the cgmTransmitterNeedsPairing function, there's no need to show the notification, we can immediately call back the cgmTransmitter initiatePairing function
            completionHandler([])
            cgmTransmitter?.initiatePairing()
            
            /// remove applicationManagerKeyInitiatePairing from application key manager - there's no need to initiate the pairing via this closure
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeyInitiatePairing)
            
        } else {
            
            // this will verify if it concerns an alert notification, if not pickerviewData will be nil
            if let pickerViewData = alertManager?.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) {
                
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
                
            }
        }
    }
    
    // called when user clicks a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        trace("userNotificationCenter didReceive", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        // call completionHandler when exiting function
        defer {
            // call completionhandler
            completionHandler()
        }
        
        if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            
            // nothing required, the requestCalibration function will be called as it's been added to ApplicationManager
            trace("     userNotificationCenter didReceive, user pressed calibration notification to open the app, requestCalibration should be called because closure is added in ApplicationManager.shared", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected {
            
            // if user clicks notification "sensor not detected", then show uialert with title and body
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.sensorNotDetected, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // nothing required, the pairing function will be called as it's been added to ApplicationManager in function cgmTransmitterNeedsPairing
            
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForResetResult.transmitterResetResult {
            
            // nothing required
            
        } else {
            
            // it's not an initial calibration request notification that the user clicked, by calling alertManager?.userNotificationCenter, we check if it was an alert notification that was clicked and if yes pickerViewData will have the list of alert snooze values
            if let pickerViewData = alertManager?.userNotificationCenter(center, didReceive: response) {
                
                trace("     userNotificationCenter didReceive, user pressed an alert notification to open the app", log: log, category: ConstantsLog.categoryRootView, type: .info)
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
                
            } else {
                // it as also not an alert notification that the user clicked, there might come in other types of notifications in the future
            }
        }
    }
}

// MARK: - conform to NightScoutFollowerDelegate protocol

extension RootViewController:NightScoutFollowerDelegate {
    
    func nightScoutFollowerInfoReceived(followGlucoseDataArray: inout [NightScoutBgReading]) {
        
        if let coreDataManager = coreDataManager, let bgReadingsAccessor = bgReadingsAccessor, let nightScoutFollowManager = nightScoutFollowManager {
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            if let lastReading = bgReadingsAccessor.last(forSensor: activeSensor) {
                timeStampLastBgReading = lastReading.timeStamp
            }
            
            // was a new reading created or not
            var newReadingCreated = false
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, let's create first the oldest, although it shouldn't matter in what order the readings are created
            for (_, followGlucoseData) in followGlucoseDataArray.enumerated().reversed() {
                
                if followGlucoseData.timeStamp > timeStampLastBgReading {
                    
                    // creata a new reading
                    _ = nightScoutFollowManager.createBgReading(followGlucoseData: followGlucoseData)
                    
                    // a new reading was created
                    newReadingCreated = true
                    
                    // set timeStampLastBgReading to new timestamp
                    timeStampLastBgReading = followGlucoseData.timeStamp
                    
                }
            }
            
            if newReadingCreated {
                
                trace("nightScoutFollowerInfoReceived, new reading(s) received", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                
                // save in core data
                coreDataManager.saveChanges()
                
                // update notification
                createBgReadingNotificationAndSetAppBadge()
                
                // update all text in  first screen
                updateLabelsAndChart(overrideApplicationState: false)
                
                // check alerts
                if let alertManager = alertManager {
                    alertManager.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds)
                }
                
                if let healthKitManager = healthKitManager {
                    healthKitManager.storeBgReadings()
                }
                
                if let bgReadingSpeaker = bgReadingSpeaker {
                    bgReadingSpeaker.speakNewReading()
                }
                
                bluetoothPeripheralManager?.sendLatestReading()
                
            }
        }
    }
}

extension RootViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.view != chartOutlet {
            return false
        }
        
        if gestureRecognizer.view != otherGestureRecognizer.view {
            return false
        }
        
        return true
        
    }
    
}
