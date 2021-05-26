import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications
import SwiftCharts
import HealthKitUI
import AVFoundation
import PieCharts

/// viewcontroller for the home screen
final class RootViewController: UIViewController {
    
    // MARK: - Properties - Outlets and Actions for buttons and labels in home screen
    
    @IBOutlet weak var preSnoozeToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func preSnoozeToolbarButtonAction(_ sender: UIBarButtonItem) {
        // opens the SnoozeViewController, see storyboard
    }
    
    @IBOutlet weak var sensorToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func sensorToolbarButtonAction(_ sender: UIBarButtonItem) {
        createAndPresentSensorButtonActionSheet()
    }
    
    @IBOutlet weak var calibrateToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func calibrateToolbarButtonAction(_ sender: UIBarButtonItem) {
        
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), cgmTransmitter.isWebOOPEnabled() {
            
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.calibrationNotNecessary, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            
            trace("calibration : user clicked the calibrate button", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            requestCalibration(userRequested: true)
        }
        
    }
    
    
    @IBOutlet weak var screenLockToolbarButtonOutlet: UIBarButtonItem!
    
    @IBAction func screenLockToolbarButtonAction(_ sender: UIBarButtonItem) {
        screenLockAlert()
    }
    
    
    /// outlet for label that shows how many minutes ago and so on
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    
    /// outlet for label that shows difference with previous reading
    @IBOutlet weak var diffLabelOutlet: UILabel!
    
    /// outlet for the image of the screen lock symbol
    @IBOutlet weak var screenLockImageOutlet: UIImageView!
    
    /// outlet for label that shows the current reading
    @IBOutlet weak var valueLabelOutlet: UILabel!
    
    @IBAction func valueLabelLongPressGestureRecognizerAction(_ sender: UILongPressGestureRecognizer) {
        
        valueLabelLongPressed(sender)
        
    }
    
    
    /// outlet for chart
    @IBOutlet weak var chartOutlet: BloodGlucoseChartView!
    
    @IBOutlet weak var segmentedControlsView: UIView!
    
    /// outlets for chart time period selector
    @IBOutlet weak var segmentedControlChartHours: UISegmentedControl!
    
    @IBAction func chartHoursChanged(_ sender: Any) {
        
        // update the chart period in hours
        switch segmentedControlChartHours.selectedSegmentIndex
            {
            case 0:
                UserDefaults.standard.chartWidthInHours = 3
            case 1:
                UserDefaults.standard.chartWidthInHours = 5
            case 2:
                UserDefaults.standard.chartWidthInHours = 12
            case 3:
                UserDefaults.standard.chartWidthInHours = 24
            default:
                break
            }
        
    }
    
    // create a view outlet (with the statistics day control inside) so that we can show/hide it as necessary
    @IBOutlet weak var segmentedControlStatisticsDaysView: UIView!
    
    @IBOutlet weak var segmentedControlStatisticsDays: UISegmentedControl!
    
    @IBAction func statisticsDaysChanged(_ sender: Any) {
        
        // update the days to use for statistics calculations
        switch segmentedControlStatisticsDays.selectedSegmentIndex
            {
            case 0:
                UserDefaults.standard.daysToUseStatistics = 0
            case 1:
                UserDefaults.standard.daysToUseStatistics = 1
            case 2:
                UserDefaults.standard.daysToUseStatistics = 7
            case 3:
                UserDefaults.standard.daysToUseStatistics = 30
            case 4:
                UserDefaults.standard.daysToUseStatistics = 90
            default:
                break
            }
        
    }
    
    /// an optional spacer view that we use to separate the segmented controls from the nav bar if the statistics are not shown
    @IBOutlet weak var optionalSpacerView: UIView!
    
    /// outlets for statistics view
    @IBOutlet weak var statisticsView: UIView!
    @IBOutlet weak var pieChartOutlet: PieChart!
    @IBOutlet weak var lowStatisticLabelOutlet: UILabel!
    @IBOutlet weak var inRangeStatisticLabelOutlet: UILabel!
    @IBOutlet weak var highStatisticLabelOutlet: UILabel!
    @IBOutlet weak var averageStatisticLabelOutlet: UILabel!
    @IBOutlet weak var a1CStatisticLabelOutlet: UILabel!
    @IBOutlet weak var cVStatisticLabelOutlet: UILabel!
    @IBOutlet weak var lowTitleLabelOutlet: UILabel!
    @IBOutlet weak var inRangeTitleLabelOutlet: UILabel!
    @IBOutlet weak var highTitleLabelOutlet: UILabel!
    @IBOutlet weak var averageTitleLabelOutlet: UILabel!
    @IBOutlet weak var a1cTitleLabelOutlet: UILabel!
    @IBOutlet weak var cvTitleLabelOutlet: UILabel!
    @IBOutlet weak var lowLabelOutlet: UILabel!
    @IBOutlet weak var highLabelOutlet: UILabel!
    @IBOutlet weak var pieChartLabelOutlet: UILabel!
    @IBOutlet weak var timePeriodLabelOutlet: UILabel!
    @IBOutlet weak var activityMonitorOutlet: UIActivityIndicatorView!
    
    
    /// clock view
    @IBOutlet weak var clockView: UIView!
    @IBOutlet weak var clockLabelOutlet: UILabel!
        
    
    @IBAction func chartPanGestureRecognizerAction(_ sender: UIPanGestureRecognizer) {
        
        guard let glucoseChartManager = glucoseChartManager else {return}
        
        glucoseChartManager.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: {
            
            // user has been panning, if chart is panned backward, then need to set valueLabel to value of latest chartPoint shown in the chart, and minutesAgo text to timeStamp of latestChartPoint
            if glucoseChartManager.chartIsPannedBackward {
                
                if let lastChartPointEarlierThanEndDate = glucoseChartManager.lastChartPointEarlierThanEndDate, let chartAxisValueDate = lastChartPointEarlierThanEndDate.x as? ChartAxisValueDate  {
                    
                    // valueLabel text should not be strikethrough (might still be strikethrough in case latest reading is older than 10 minutes
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
                    
                    self.valueLabelOutlet.attributedText = attributedString
                    
                    // don't show anything in diff outlet
                    self.diffLabelOutlet.text = ""
                    
                } else {
                    
                    // this would only be the case if there's no readings withing the shown timeframe
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
        glucoseChartManager?.handleUIGestureRecognizer(recognizer: sender, chartOutlet: chartOutlet, completionHandler: nil)
        
    }
    
    @IBOutlet var chartLongPressGestureRecognizerOutlet: UILongPressGestureRecognizer!
    
    // MARK: - Constants for ApplicationManager usage
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create updateLabelsAndChartTimer
    private let applicationManagerKeyCreateupdateLabelsAndChartTimer = "RootViewController-CreateupdateLabelsAndChartTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground
    private let applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController = "RootViewController-InvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - initial calibration
    private let applicationManagerKeyInitialCalibration = "RootViewController-InitialCalibration"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground -  isIdleTimerDisabled
    private let applicationManagerKeyIsIdleTimerDisabled = "RootViewController-isIdleTimerDisabled"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - trace that app goes to background
    private let applicationManagerKeyTraceAppGoesToBackGround = "applicationManagerKeyTraceAppGoesToBackGround"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - trace that app goes to background
    private let applicationManagerKeyTraceAppGoesToForeground = "applicationManagerKeyTraceAppGoesToForeground"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillTerminate - trace that app goes to background
    private let applicationManagerKeyTraceAppWillTerminate = "applicationManagerKeyTraceAppWillTerminate"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - to clean GlucoseChartManager memory
    private let applicationManagerKeyCleanMemoryGlucoseChartManager = "applicationManagerKeyCleanMemoryGlucoseChartManager"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to initialize the glucoseChartManager and update labels and chart
    private let applicationManagerKeyUpdateLabelsAndChart = "applicationManagerKeyUpdateLabelsAndChart"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to dismiss screenLockAlertController
    private let applicationManagerKeyDismissScreenLockAlertController = "applicationManagerKeyDismissScreenLockAlertController"
    
    // MARK: - Properties - other private properties
    
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
    
    /// LoopManager instance
    private var loopManager:LoopManager?
    
    /// SoundPlayer instance
    private var soundPlayer:SoundPlayer?
    
    /// nightScoutFollowManager instance
    private var nightScoutFollowManager:NightScoutFollowManager?
    
    /// dexcomShareUploadManager instance
    private var dexcomShareUploadManager:DexcomShareUploadManager?
    
    /// WatchManager instance
    private var watchManager: WatchManager?
    
    /// healthkit manager instance
    private var healthKitManager:HealthKitManager?
    
    /// reference to activeSensor
    private var activeSensor:Sensor?
    
    /// reference to bgReadingSpeaker
    private var bgReadingSpeaker:BGReadingSpeaker?
    
    /// manages bluetoothPeripherals that this app knows
    private var bluetoothPeripheralManager: BluetoothPeripheralManager?
    
    /// - manage glucose chart
    /// - will be nillified each time the app goes to the background, to avoid unnecessary ram usage (which seems to cause app getting killed)
    /// - will be reinitialized each time the app comes to the foreground
    private var glucoseChartManager: GlucoseChartManager?
    
    /// statisticsManager instance
    private var statisticsManager: StatisticsManager?
    
    /// dateformatter for minutesLabelOutlet, when user is panning the chart
    private let dateTimeFormatterForMinutesLabelWhenPanning: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = ConstantsGlucoseChart.dateFormatLatestChartPointWhenPanning
        
        return dateFormatter
    }()
    
    /// housekeeper instance
    private var houseKeeper: HouseKeeper?
    
    /// current value of webOPEnabled, if nil then it means no cgmTransmitter connected yet , false is used as value
    /// - used to detect changes in the value
    ///
    /// in fact it will never be used with a nil value, except when connecting to a cgm transmitter for the first time
    private var webOOPEnabled: Bool?
    
    /// current value of nonFixedSlopeEnabled, if nil then it means no cgmTransmitter connected yet , false is used as value
    /// - used to detect changes in the value
    ///
    /// in fact it will never be used with a nil value, except when connecting to a cgm transmitter for the first time
    private var nonFixedSlopeEnabled: Bool?
    
    /// when was the last notification created with bgreading, setting to 1 1 1970 initially to avoid having to unwrap it
    private var timeStampLastBGNotification = Date(timeIntervalSince1970: 0)
    
    /// to hold the current state of the screen keep-alive
    private var screenIsLocked: Bool = false
    
    /// date formatter for the clock view
    private var clockDateFormatter = DateFormatter()
    
    /// initiate a Timer object that we will use later to keep the clock view updated if the user activates the screen lock
    private var clockTimer: Timer?
    
    /// UIAlertController to use when user chooses to lock the screen. Defined here so we can dismiss it when app goes to the background
    private var screenLockAlertController: UIAlertController?
    
    // MARK: - overriden functions
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // never seen it triggered, copied that from Loop
        glucoseChartManager?.cleanUpMemory()
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // viewWillAppear when user switches eg from Settings Tab to Home Tab - latest reading value needs to be shown on the view, and also update minutes ago etc.
        updateLabelsAndChart(overrideApplicationState: true)
        
        // show the statistics view as required. If not, hide it and show the spacer view to keep segmentedControlChartHours separated a bit more away from the main Tab bar
        if !screenIsLocked {
            statisticsView.isHidden = !UserDefaults.standard.showStatistics
        }
        segmentedControlStatisticsDaysView.isHidden = !UserDefaults.standard.showStatistics
        optionalSpacerView.isHidden = UserDefaults.standard.showStatistics
        
        if inRangeStatisticLabelOutlet.text == "-" {
            activityMonitorOutlet.isHidden = true
        } else {
            activityMonitorOutlet.isHidden = false
        }
        
        // update statistics related outlets
        updateStatistics(animatePieChart: true, overrideApplicationState: true)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set up the clock view
        clockDateFormatter.dateStyle = .none
        clockDateFormatter.timeStyle = .short
        clockDateFormatter.dateFormat = "HH:mm"
        clockLabelOutlet.font = ConstantsUI.clockLabelFontSize
        clockLabelOutlet.textColor = ConstantsUI.clockLabelColor
        
        
        // ensure the screen lock icon color as per constants file and also the screen layout
        screenLockImageOutlet.tintColor = ConstantsUI.screenLockIconColor
        screenLockUpdate(enabled: false)
        
        
        // this is to force update of userdefaults that are also stored in the shared user defaults
        // these are used by the today widget. After a year or so (september 2021) this can all be deleted
        UserDefaults.standard.urgentLowMarkValueInUserChosenUnit = UserDefaults.standard.urgentLowMarkValueInUserChosenUnit
        UserDefaults.standard.urgentHighMarkValueInUserChosenUnit = UserDefaults.standard.urgentHighMarkValueInUserChosenUnit
        UserDefaults.standard.lowMarkValueInUserChosenUnit = UserDefaults.standard.lowMarkValueInUserChosenUnit
        UserDefaults.standard.highMarkValueInUserChosenUnit = UserDefaults.standard.highMarkValueInUserChosenUnit
        UserDefaults.standard.bloodGlucoseUnitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        
        // set the localized text of the segmented controls
        segmentedControlChartHours.setTitle("3" + Texts_Common.hourshort, forSegmentAt: 0)
        segmentedControlChartHours.setTitle("6" + Texts_Common.hourshort, forSegmentAt: 1)
        segmentedControlChartHours.setTitle("12" + Texts_Common.hourshort, forSegmentAt: 2)
        segmentedControlChartHours.setTitle("24" + Texts_Common.hourshort, forSegmentAt:3)
        
        segmentedControlStatisticsDays.setTitle(Texts_Common.todayshort, forSegmentAt: 0)
        segmentedControlStatisticsDays.setTitle("24" + Texts_Common.hourshort, forSegmentAt: 1)
        segmentedControlStatisticsDays.setTitle("7" + Texts_Common.dayshort, forSegmentAt: 2)
        segmentedControlStatisticsDays.setTitle("30" + Texts_Common.dayshort, forSegmentAt:3)
        segmentedControlStatisticsDays.setTitle("90" + Texts_Common.dayshort, forSegmentAt:4)
               
        // update the segmented control of the chart hours
        switch UserDefaults.standard.chartWidthInHours
            {
            case 3:
                segmentedControlChartHours.selectedSegmentIndex = 0
            case 6:
                segmentedControlChartHours.selectedSegmentIndex = 1
            case 12:
                segmentedControlChartHours.selectedSegmentIndex = 2
            case 24:
                segmentedControlChartHours.selectedSegmentIndex = 3
            default:
                break
            }
        
        
        // update the segmented control of the statistics days
         switch UserDefaults.standard.daysToUseStatistics
             {
             case 0:
                segmentedControlStatisticsDays.selectedSegmentIndex = 0
             case 1:
                segmentedControlStatisticsDays.selectedSegmentIndex = 1
             case 7:
                segmentedControlStatisticsDays.selectedSegmentIndex = 2
             case 30:
                segmentedControlStatisticsDays.selectedSegmentIndex = 3
             case 90:
                segmentedControlStatisticsDays.selectedSegmentIndex = 4
             default:
                 break
             }
        
                
        // format the segmented control of the chart hours if possible (should normally be ok)
        if #available(iOS 13.0, *) {
            
            // set the basic formatting. We basically want it to dissapear into the background
            segmentedControlChartHours.backgroundColor = ConstantsUI.segmentedControlBackgroundColor
            segmentedControlChartHours.tintColor = ConstantsUI.segmentedControlBackgroundColor
            segmentedControlChartHours.layer.borderWidth = ConstantsUI.segmentedControlBorderWidth

            
            // format the unselected segments
            segmentedControlChartHours.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlNormalTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.normal)
            
            // format the selected segment
            segmentedControlChartHours.selectedSegmentTintColor = ConstantsUI.segmentedControlSelectedTintColor
            
            segmentedControlChartHours.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlSelectedTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.selected)
        
        }
        
        
        // format the segmented control of the chart hours if possible (should normally be ok)
        if #available(iOS 13.0, *) {
            
            // set the basic formatting. We basically want it to dissapear into the background
            segmentedControlStatisticsDays.backgroundColor = ConstantsUI.segmentedControlBackgroundColor
            
            segmentedControlStatisticsDays.tintColor = ConstantsUI.segmentedControlBackgroundColor
            
            segmentedControlStatisticsDays.layer.borderWidth = ConstantsUI.segmentedControlBorderWidth

            
            // format the unselected segments
            segmentedControlStatisticsDays.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlNormalTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.normal)
            
            // format the selected segment
            segmentedControlStatisticsDays.selectedSegmentTintColor = ConstantsUI.segmentedControlSelectedTintColor
            
            segmentedControlStatisticsDays.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: ConstantsUI.segmentedControlSelectedTextColor, NSAttributedString.Key.font: ConstantsUI.segmentedControlFont], for:.selected)
            
        }
        
        // if a RTL localization is in use (such as arabic), then correctly align the low (<x) and high (>x) label outlets towards the centre of the (now reversed) horizontal stack views
        if UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == UIUserInterfaceLayoutDirection.rightToLeft {
            lowLabelOutlet.textAlignment = .right
            lowTitleLabelOutlet.textAlignment = .left
            highLabelOutlet.textAlignment = .right
            highTitleLabelOutlet.textAlignment = .left
        } else {
            lowLabelOutlet.textAlignment = .left
            lowTitleLabelOutlet.textAlignment = .right
            highLabelOutlet.textAlignment = .left
            highTitleLabelOutlet.textAlignment = .right
        }
        
        
        // enable or disable the buttons 'sensor' and 'calibrate' on top, depending on master or follower
        changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            
            self.setupApplicationData()
            
            // housekeeper should be non nil here, kall housekeeper
            self.houseKeeper?.doAppStartUpHouseKeeping()
            
            // update label texts, minutes ago, diff and value
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            // update statistics related outlets
            self.updateStatistics(animatePieChart: true, overrideApplicationState: true)
            
            // create badge counter
            self.createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
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
        // changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)

        // see if the user has changed the chart x axis timescale
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.KeysCharts.chartWidthInHours.rawValue, options: .new, context: nil)
        
        // see if the user has changed the statistic days to use
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.daysToUseStatistics.rawValue, options: .new, context: nil)
        
        // bg reading notification and badge, and multiplication factor
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInNotification.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInAppBadge.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.multipleAppBadgeValueWith10.rawValue, options: .new, context: nil)
        // also update of unit requires update of badge
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
        
        // high mark , low mark , urgent high mark, urgent low mark. change requires redraw of graph
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentLowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.lowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.highMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentHighMarkValue.rawValue, options: .new, context: nil)

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
        
        // setup self as delegate for tabbarcontroller
        self.tabBarController?.delegate = self
        
        // setup the timer logic for updating the view regularly
        setupUpdateLabelsAndChartTimer()
        
        // setup AVAudioSession
        setupAVAudioSession()
        
        // user may have activated the screen lock function so that the screen stays open, when going back to background, set isIdleTimerDisabled back to false and update the UI so that it's ready to come to foreground when required.
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyIsIdleTimerDisabled, closure: {
            
            UIApplication.shared.isIdleTimerDisabled = false
            
            self.screenLockUpdate(enabled: false)
            
        })
        
        // add tracing when app goes from foreground to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyTraceAppGoesToBackGround, closure: {trace("Application did enter background", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        // add tracing when app comes to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyTraceAppGoesToForeground, closure: {trace("Application will enter foreground", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        // add tracing when app will terminaten - this only works for non-suspended apps, probably (not tested) also works for apps that crash in the background
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeyTraceAppWillTerminate, closure: {trace("Application will terminate", log: self.log, category: ConstantsLog.categoryRootView, type: .info)})
        
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyCleanMemoryGlucoseChartManager, closure: {
            
            self.glucoseChartManager?.cleanUpMemory()
            
        })
        
        // reinitialise glucose chart and also to update labels and chart
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyUpdateLabelsAndChart, closure: {
            
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            // update statistics related outlets
            self.updateStatistics(animatePieChart: false)
            
        })
        
        
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyDismissScreenLockAlertController, closure: {

            self.dismissScreenLockAlertController()
            
        })
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In RootViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = SnoozeViewController.SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In RootViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
        
        case SnoozeViewController.SegueIdentifiers.RootViewToSnoozeView:
            
            guard let vc = segue.destination as? SnoozeViewController else {
                
                fatalError("In RootViewController, prepare for segue, viewcontroller is not SnoozeViewController" )
                
            }
            
            // configure view controller
            vc.configure(alertManager: alertManager)
            
        }
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
    
    // creates activeSensor, bgreadingsAccessor, calibrationsAccessor, NightScoutUploadManager, soundPlayer, dexcomShareUploadManager, nightScoutFollowManager, alertManager, healthKitManager, bgReadingSpeaker, bluetoothPeripheralManager, watchManager, housekeeper
    private func setupApplicationData() {
        
        // setup Trace
        Trace.initialize(coreDataManager: coreDataManager)
        
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
        
        // instanstiate Housekeeper
        houseKeeper = HouseKeeper(coreDataManager: coreDataManager)
        
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
        
        // setup healthkitmanager
        healthKitManager = HealthKitManager(coreDataManager: coreDataManager)
        
        // setup bgReadingSpeaker
        bgReadingSpeaker = BGReadingSpeaker(sharedSoundPlayer: soundPlayer, coreDataManager: coreDataManager)
        
        // setup loopManager
        loopManager = LoopManager(coreDataManager: coreDataManager)
        
        // setup dexcomShareUploadManager
        dexcomShareUploadManager = DexcomShareUploadManager(bgReadingsAccessor: bgReadingsAccessor, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        /// will be called by BluetoothPeripheralManager if cgmTransmitterType changed and/or webOOPEnabled value changed
        /// - function to be used in BluetoothPeripheralManager init function, and also immediately after having initiliazed BluetoothPeripheralManager (it will not get called from within BluetoothPeripheralManager because didSet function is not called from init
        let cgmTransmitterInfoChanged = {
            
            // if cgmTransmitter not nil then reassign calibrator and set UserDefaults.standard.transmitterTypeAsString
            if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
                
                // reassign calibrator, even if the type of calibrator would not change
                self.calibrator = self.getCalibrator(cgmTransmitter: cgmTransmitter)
                
                // check if webOOPEnabled changed and if yes stop the sensor
                if let webOOPEnabled = self.webOOPEnabled, webOOPEnabled != cgmTransmitter.isWebOOPEnabled() {
                    
                    trace("in cgmTransmitterInfoChanged, webOOPEnabled value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.isWebOOPEnabled().description)
                    
                    self.stopSensor()
                    
                }
                
                // check if nonFixedSlopeEnabled changed and if yes stop the sensor
                if let nonFixedSlopeEnabled = self.nonFixedSlopeEnabled, nonFixedSlopeEnabled != cgmTransmitter.isNonFixedSlopeEnabled() {
                    
                    trace("in cgmTransmitterInfoChanged, nonFixedSlopeEnabled value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.isNonFixedSlopeEnabled().description)
                    
                    self.stopSensor()
                    
                }
                
                // check if the type of sensor supported by the cgmTransmitterType  has changed, if yes stop the sensor
                if let currentTransmitterType = UserDefaults.standard.cgmTransmitterType, currentTransmitterType.sensorType() != cgmTransmitter.cgmTransmitterType().sensorType() {
                    
                    trace("in cgmTransmitterInfoChanged, sensorType value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.cgmTransmitterType().sensorType().rawValue)
                    
                    self.stopSensor()
                    
                }
                
                // assign the new value of webOOPEnabled
                self.webOOPEnabled = cgmTransmitter.isWebOOPEnabled()
                
                // assign the new value of nonFixedSlopeEnabled
                self.nonFixedSlopeEnabled = cgmTransmitter.isNonFixedSlopeEnabled()
                
                // change value of UserDefaults.standard.transmitterTypeAsString
                UserDefaults.standard.cgmTransmitterTypeAsString = cgmTransmitter.cgmTransmitterType().rawValue
                
                // for testing only - for testing make sure there's a transmitter connected,
                // eg a bubble or mm, not necessarily (better not) installed on a sensor
                // CGMMiaoMiaoTransmitter.testRange(cGMTransmitterDelegate: self)
                
            }
            
        }
        
        // setup bluetoothPeripheralManager
        bluetoothPeripheralManager = BluetoothPeripheralManager(coreDataManager: coreDataManager, cgmTransmitterDelegate: self, uIViewController: self, cgmTransmitterInfoChanged: cgmTransmitterInfoChanged)
        
        // to initialize UserDefaults.standard.transmitterTypeAsString
        cgmTransmitterInfoChanged()
        
        // setup alertmanager
        alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        
        // setup watchmanager
        watchManager = WatchManager(coreDataManager: coreDataManager)
        
        // initialize glucoseChartManager
        glucoseChartManager = GlucoseChartManager(chartLongPressGestureRecognizer: chartLongPressGestureRecognizerOutlet, coreDataManager: coreDataManager)
        
        // initialize statisticsManager
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager)
        
        // initialize chartGenerator in chartOutlet
        self.chartOutlet.chartGenerator = { [weak self] (frame) in
            return self?.glucoseChartManager?.glucoseChartWithFrame(frame)?.view
        }
        
    }
    
    /// process new glucose data received from transmitter.
    /// - parameters:
    ///     - glucoseData : array with new readings
    ///     - sensorTimeInMinutes : should be present only if it's the first reading(s) being processed for a specific sensor and is needed if it's a transmitterType that returns true to the function canDetectNewSensor
    private func processNewGlucoseData(glucoseData: inout [GlucoseData], sensorTimeInMinutes: Int?) {
        
        // unwrap calibrationsAccessor and coreDataManager and cgmTransmitter
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = coreDataManager, let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter() else {
            
            trace("in processNewGlucoseData, calibrationsAccessor or coreDataManager or cgmTransmitter is nil", log: log, category: ConstantsLog.categoryRootView, type: .error)
            
            return
            
        }
        
        if activeSensor == nil {
            
            if let sensorTimeInMinutes = sensorTimeInMinutes, cgmTransmitter.cgmTransmitterType().canDetectNewSensor() {
                
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
        
        guard glucoseData.count > 0 else {
            
            trace("glucoseData.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            return
            
        }
        
        // also for cases where calibration is not needed, we go through this code
        if let activeSensor = activeSensor, let calibrator = calibrator, let bgReadingsAccessor = bgReadingsAccessor {
            
            trace("calibrator = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, calibrator.description())
            
            // initialize help variables
            var lastCalibrationsForActiveSensorInLastXDays = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
            let lastCalibrationForActiveSensor = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            
            
            
            // next is only if smoothing is enabled, and if there's at least 11 minutes of readings in the glucoseData array, which will normally only be the case for Libre with MM/Bubble
            // if that's the case then delete following existing BgReading's
            //  - younger than 11 minutes : why, because some of the Libre transmitters return readings of the last 15 minutes for every minute, we don't go further than 11 minutes because these readings are not so well smoothed
            //  - younger than the latest calibration : becuase if recalibration is used, then it might be difficult if there's been a recent calibration, to delete and recreate a reading with an earlier timestamp
            //  - younger or equal in age than the oldest reading in the GlucoseData array
            // why :
            //    - in case of Libre, using transmitters like Bubble, MM, .. the 16 most recent readings in GlucoseData are smoothed (done in LibreDataParser if smoothing is enabled)
            //    - specifically the reading at position 5, 6, 7....10 are well smoothed (because they are based on per minute readings of the last 15 minutes, inclusive 5 minutes before and 5 minutes after) we'll use
            //
            //  we will remove the BgReading's and then re-add them using smoothed values
            // so we'll define the timestamp as of when readings should be deleted
            // younger than 11 minutes
            
            // start defining timeStampToDelete as of when existing BgReading's will be deleted
            // this value is also used to verify that glucoseData Array has enough readings
            var timeStampToDelete = Date(timeIntervalSinceNow: -60.0 * (Double)(ConstantsLibreSmoothing.readingsToDeleteInMinutes))
            
            // now check if we'll delete readings
            // there must be a glucoseData.last, here assigning lastGlucoseData just to unwrap it
            // checking lastGlucoseData.timeStamp < timeStampToDelete guarantees the oldest reading is older than the one we'll delete, so we're sur we have enough readings in glucoseData to refill the BgReadings
            if let lastGlucoseData = glucoseData.last, lastGlucoseData.timeStamp < timeStampToDelete, UserDefaults.standard.smoothLibreValues {
                
                // older than the timestamp of the latest reading
                if let last = glucoseData.last {
                    timeStampToDelete = max(timeStampToDelete, last.timeStamp)
                }
                
                // older than the timestamp of the latest calibration (would only be applicable if recalibration is used)
                if let lastCalibrationForActiveSensor = lastCalibrationForActiveSensor {
                    timeStampToDelete = max(timeStampToDelete, lastCalibrationForActiveSensor.timeStamp)
                }
                
                // there should be one reading per minute for the period that we want to delete readings, otherwise we may not be able to fill up a gap that is created by deleting readings, because the next readings are per 15 minutes. This will typically happen the first time the app runs (or reruns), the first range of readings is only 16 readings not enough to fill up a gap of more than 20 minutes
                // we calculate the number of minutes between timeStampToDelete and now, use the result as index in glucoseData, the timestamp of that element is a number of minutes away from now, that number should be equal to index (as we expect one reading per minute)
                // if that's not the case add 1 minute to timeStampToDelete
                // repeat this until reached
                let checkTimeStampToDelete = { (glucoseData: [GlucoseData]) -> Bool in
                    
                    // just to avoid infinite loop
                    if timeStampToDelete > Date() {return true}
                    
                    let minutes = Int(abs(timeStampToDelete.timeIntervalSince(Date())/60.0))
                    
                    if minutes < glucoseData.count {
                        
                        if abs(glucoseData[minutes].timeStamp.timeIntervalSince(timeStampToDelete)) > 1.0 {
                            // increase timeStampToDelete with 5 minutes, this is in the assumption that ConstantsSmoothing.readingsToDeleteInMinutes is not more than 21, by reducing to 16 we should never have a gap because there's always minimum 16 values per minute
                            timeStampToDelete = timeStampToDelete.addingTimeInterval(1.0 * 60)
                            
                            return false
                            
                        }
                        
                        return true
                        
                    } else {
                        // should never come here
                        // increase timeStampToDelete with 5 minutes
                        timeStampToDelete = timeStampToDelete.addingTimeInterval(1.0 * 60)
                        
                        return false
                    }
                    
                }
                
                // repeat the function checkTimeStampToDelete until timeStampToDelete is high enough so that we delete only bgReading's without creating a gap that can't be filled in
                while !checkTimeStampToDelete(glucoseData) {}
                
                // get the readings to be deleted - delete also non-calibrated readings
                let lastBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStampToDelete, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                
                // delete them
                for reading in lastBgReadings {
                    
                    coreDataManager.mainManagedObjectContext.delete(reading)
                    
                    coreDataManager.saveChanges()
                    
                }
                
                // as we're deleting readings, glucoseChartPoints need to be updated, otherwise we keep seeing old values
                // this is the easiest way to achieve it
                glucoseChartManager?.cleanUpMemory()
                
            }
            
            // was a new reading created or not ?
            var newReadingCreated = false
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            if let lastReading = bgReadingsAccessor.last(forSensor: nil) {
                timeStampLastBgReading = lastReading.timeStamp
            }
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, we need to start with the oldest
            for (index, glucose) in glucoseData.enumerated().reversed() {
                
                // we only add new glucose values if 5 minutes - 10 seconds younger than latest already existing reading, or, if it's the latest, it needs to be just younger
                let checktimestamp = Date(timeInterval: 5.0 * 60.0 - 10.0, since: timeStampLastBgReading)
                
                // timestamp of glucose being processed must be higher (ie more recent) than checktimestamp except if it's the last one (ie the first in the array), because there we don't care if it's less than 5 minutes different with the last but one
                if (glucose.timeStamp > checktimestamp || ((index == 0) && (glucose.timeStamp > timeStampLastBgReading))) {
                    
                    // check on glucoseLevelRaw > 0 because I've had a case where a faulty sensor was giving negative values
                    if glucose.glucoseLevelRaw > 0 {
                        
                        // get latest3BgReadings
                        var latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false)
                        
                        let newReading = calibrator.createNewBgReading(rawData: glucose.glucoseLevelRaw, timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: self.getCGMTransmitterDeviceName(for: cgmTransmitter), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            
                            trace("new reading created, timestamp = %{public}@, calculatedValue = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, newReading.timeStamp.description(with: .current), newReading.calculatedValue.description.replacingOccurrences(of: ".", with: ","))
                            
                        }
                        
                        // save the newly created bgreading permenantly in coredata
                        coreDataManager.saveChanges()
                        
                        // a new reading was created
                        newReadingCreated = true
                        
                        // set timeStampLastBgReading to new timestamp
                        timeStampLastBgReading = glucose.timeStamp
                        
                        
                    } else {
                        
                        trace("reading skipped, rawValue <= 0, looks like a faulty sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                    }
                    
                }
                
            }
            
            // if a new reading is created, create either initial calibration request or bgreading notification - upload to nightscout and check alerts
            if newReadingCreated {
                
                // only if no webOOPEnabled : if no two calibration exist yet then create calibration request notification, otherwise a bgreading notification and update labels
                if firstCalibrationForActiveSensor == nil && lastCalibrationForActiveSensor == nil && !cgmTransmitter.isWebOOPEnabled() {
                    
                    // there must be at least 2 readings
                    let latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
                    
                    if latestReadings.count > 1 {

                        trace("calibration : two readings received, no calibrations exist yet and not weboopenabled, request calibation to user", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

                        createInitialCalibrationRequest()
                        
                    }
                    
                } else {
                    
                    // check alerts, create notification, set app badge
                    checkAlertsCreateNotificationAndSetAppBadge()
                    
                    // update all text in  first screen
                    updateLabelsAndChart(overrideApplicationState: false)
                    
                    // update statistics related outlets
                    updateStatistics(animatePieChart: false)
                    
                }
                
                nightScoutUploadManager?.upload(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                healthKitManager?.storeBgReadings()
                
                bgReadingSpeaker?.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                dexcomShareUploadManager?.upload(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                loopManager?.share()
                
            }
        }
        
    }
    
    /// closes the SnoozeViewController if it is being presented now
    private func closeSnoozeViewController() {
        
        if let presentedViewController = self.presentedViewController {
            
            if let snoozeViewController = presentedViewController as? SnoozeViewController {
                
                snoozeViewController.dismiss(animated: true, completion: nil)
                
            }
        }
        
    }
    
    /// used by observevalue for UserDefaults.KeysCharts
    private func evaluateUserDefaultsChange(keyPathEnumCharts: UserDefaults.KeysCharts) {
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnumCharts {
        
        case UserDefaults.KeysCharts.chartWidthInHours, UserDefaults.KeysCharts.chartTimeAxisLabelFormat :
            
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnumCharts.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        }
        
        switch keyPathEnumCharts {
        
        case UserDefaults.KeysCharts.chartWidthInHours:
            
            // redraw chart is necessary
            if let glucoseChartManager = glucoseChartManager {
                
                glucoseChartManager.updateGlucoseChartPoints(endDate: glucoseChartManager.endDate, startDate: glucoseChartManager.endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours)), chartOutlet: chartOutlet, completionHandler: nil)

            }
            
        default:
            break
            
        }
        
    }
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        
        // first check keyValueObserverTimeKeeper
        switch keyPathEnum {
        
        case UserDefaults.Key.isMaster, UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.daysToUseStatistics :
            
            // transmittertype change triggered by user, should not be done within 200 ms
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        default:
            break
            
        }
        
        switch keyPathEnum {
        
        case UserDefaults.Key.isMaster :
            
            changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
            
            // no sensor needed in follower mode, stop it
            stopSensor()
            
        case UserDefaults.Key.showReadingInNotification:
            if !UserDefaults.standard.showReadingInNotification {
                // remove existing notification if any
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
                
            }
            
        case UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl:
            
            // if showReadingInAppBadge = false, means user set it from true to false
            // set applicationIconBadgeNumber to 0. This will cause removal of the badge counter, but als removal of any existing notification on the screen
            if !UserDefaults.standard.showReadingInAppBadge {
                
                UIApplication.shared.applicationIconBadgeNumber = 0
                
            }
            
            // this will trigger update of app badge, will also create notification, but as app is most likely in foreground, this won't show up
            createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
        case UserDefaults.Key.urgentLowMarkValue, UserDefaults.Key.lowMarkValue, UserDefaults.Key.highMarkValue, UserDefaults.Key.urgentHighMarkValue:
            
            // redraw chart is necessary
            updateChartWithResetEndDate()

        case UserDefaults.Key.daysToUseStatistics:
            
            // refresh statistics calculations/view is necessary
            updateStatistics(animatePieChart: true, overrideApplicationState: false)

        default:
            break
            
        }
    }
    
    // MARK:- observe function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {return}
        
        if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
            
            evaluateUserDefaultsChange(keyPathEnum: keyPathEnum)
            
        } else if let keyPathEnumCharts = UserDefaults.KeysCharts(rawValue: keyPath) {
            
            evaluateUserDefaultsChange(keyPathEnumCharts: keyPathEnumCharts)
            
        }
        
    }
    
    // MARK: - View Methods
    
    /// Configure View, only stuff that is independent of coredata
    private func setupView() {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        	
        // set texts for buttons on top
        preSnoozeToolbarButtonOutlet.title = Texts_HomeView.snoozeButton
        sensorToolbarButtonOutlet.title = Texts_HomeView.sensor
        calibrateToolbarButtonOutlet.title = Texts_HomeView.calibrationButton
        
        chartLongPressGestureRecognizerOutlet.delegate = self
        chartPanGestureRecognizerOutlet.delegate = self
        
        // at this moment, coreDataManager is not yet initialized, we're just calling here prerender and reloadChart to show the chart with x and y axis and gridlines, but without readings. The readings will be loaded once coreDataManager is setup, after which updateChart() will be called, which will initiate loading of readings from coredata
        self.chartOutlet.reloadChart()
        
    }
    
    // MARK: - private helper functions
    
    /// creates notification
    private func createNotification(title: String?, body: String?, identifier: String, sound: UNNotificationSound?) {
        
        // Create Notification Content
        let notificationContent = UNMutableNotificationContent()
        
        // Configure NotificationContent title
        if let title = title {
            notificationContent.title = title
        }
        
        // Configure NotificationContent body
        if let body = body {
            notificationContent.body = body
        }
        
        // configure sound
        if let sound = sound {
            notificationContent.sound = sound
        }
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable to create notification %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            }
        }
        
    }
    
    /// will update the chart with endDate = currentDate
    private func updateChartWithResetEndDate() {
        
        glucoseChartManager?.updateGlucoseChartPoints(endDate: Date(), startDate: nil, chartOutlet: chartOutlet, completionHandler: nil)
        
    }
    
    /// launches timer that will do regular screen updates - and adds closure to ApplicationManager : when going to background, stop the timer, when coming to foreground, restart the timer
    ///
    /// should be called only once immediately after app start, ie in viewdidload
    private func setupUpdateLabelsAndChartTimer() {
        
        // set timeStampAppLaunch to now
        UserDefaults.standard.timeStampAppLaunch = Date()
        
        // this is the actual timer
        var updateLabelsAndChartTimer:Timer?
        
        // create closure to invalide the timer, if it exists
        let invalidateUpdateLabelsAndChartTimer = {
            
            if let updateLabelsAndChartTimer = updateLabelsAndChartTimer {
                
                updateLabelsAndChartTimer.invalidate()
                
            }
            
            updateLabelsAndChartTimer = nil
            
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
        
        // when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeViewController, closure: {
            
            // this is for the case that the snoozeViewController is shown. If not removed, then if user opens alert notification, the alert snooze wouldn't be shown
            // that's why, close the snoozeViewController
            self.closeSnoozeViewController()
            
            // updateLabelsAndChartTimer needs to be invalidated when app goes to background
            invalidateUpdateLabelsAndChartTimer()
            
        })
        
    }
    
    /// opens an alert, that requests user to enter a calibration value, and calibrates
    /// - parameters:
    ///     - userRequested : if true, it's a requestCalibration initiated by user clicking on the calibrate button in the homescreen
    private func requestCalibration(userRequested:Bool) {
        
        // unwrap calibrationsAccessor, coreDataManager , bgReadingsAccessor
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = self.coreDataManager, let bgReadingsAccessor = self.bgReadingsAccessor else {
            
            trace("in requestCalibration, calibrationsAccessor or coreDataManager or bgReadingsAccessor is nil, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .error)
            
            return
            
        }
        
        // check that there's an active cgmTransmitter (not necessarily connected, just one that is created and configured with shouldconnect = true)
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter else {
            
            trace("in requestCalibration, calibrationsAccessor or cgmTransmitter is nil, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.theresNoCGMTransmitterActive, actionHandler: nil), animated: true, completion: nil)
            
            return
        }
        
        // check if sensor active and if not don't continue
        guard let activeSensor = activeSensor else {
            
            trace("in requestCalibration, there is no active sensor, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.startSensorBeforeCalibration, actionHandler: nil), animated: true, completion: nil)
            
            return
            
        }
        
        // if it's a user requested calibration, but there's no calibration yet, then give info and return - first calibration will be requested by app via notification
        if calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) == nil && userRequested {
            
            self.present(UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.thereMustBeAreadingBeforeCalibration, actionHandler: nil), animated: true, completion: nil)
            
            return
        }
        
        // assign deviceName, needed in the closure when creating alert. As closures can create strong references (to bluetoothTransmitter in this case), I'm fetching the deviceName here
        let deviceName = bluetoothTransmitter.deviceName
        
        // let alert = UIAlertController(title: "test title", message: "test message", keyboardType: .numberPad, text: nil, placeHolder: "...", actionTitle: nil, cancelTitle: nil, actionHandler: {_ in }, cancelHandler: nil)
        let alert = UIAlertController(title: Texts_Calibrations.enterCalibrationValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: nil, placeHolder: "...", actionTitle: nil, cancelTitle: nil, actionHandler: {
            (text:String) in
            
            guard let valueAsDouble = text.toDouble() else {
                self.present(UIAlertController(title: Texts_Common.warning, message: Texts_Common.invalidValue, actionHandler: nil), animated: true, completion: nil)
                return
            }
            
            let valueAsDoubleConvertedToMgDl = valueAsDouble.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
            var latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true)
            
            var latestCalibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            
            if let calibrator = self.calibrator {
                
                if latestCalibrations.count == 0 {
                    
                    trace("calibration : initial calibration, creating two calibrations", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                    
                    // calling initialCalibration will create two calibrations, they are returned also but we don't need them
                    _ = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDoubleConvertedToMgDl, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDoubleConvertedToMgDl, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
                } else {
                    
                    // it's not the first calibration
                    if let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) {

                        trace("calibration : creating calibrations", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                        // calling createNewCalibration will create a new  calibration, it is returned but we don't need it
                        _ = calibrator.createNewCalibration(bgValue: valueAsDoubleConvertedToMgDl, lastBgReading: latestReadings[0], sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        
                    }
                    
                }
                
                // this will store the newly created calibration(s) in coredata
                coreDataManager.saveChanges()
                
                // initiate upload to NightScout, if needed
                if let nightScoutUploadManager = self.nightScoutUploadManager {
                    nightScoutUploadManager.upload(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                }
                
                // initiate upload to Dexcom Share, if needed
                if let dexcomShareUploadManager = self.dexcomShareUploadManager {
                    dexcomShareUploadManager.upload(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                }
                
                // update labels
                self.updateLabelsAndChart(overrideApplicationState: false)
                
                // bluetoothPeripherals (M5Stack, ..) should receive latest reading with calculated value
                self.bluetoothPeripheralManager?.sendLatestReading()
                
                // watchManager should process new reading
                self.watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
                
                // send also to loopmanager, not interesting for loop probably, but the data is also used for today widget
                self.loopManager?.share()
                
            }
            
        }, cancelHandler: nil)
        
        // present the alert
        self.present(alert, animated: true, completion: nil)
        
    }
    
    /// this is just some functionality which is used frequently
    private func getCalibrator(cgmTransmitter: CGMTransmitter) -> Calibrator {
        
        let cgmTransmitterType = cgmTransmitter.cgmTransmitterType()
        
        switch cgmTransmitterType {
        
        case .dexcomG4, .dexcomG5, .dexcomG6:
            
            trace("in getCalibrator, calibrator = DexcomCalibrator", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            return DexcomCalibrator()
            
        case .miaomiao, .GNSentry, .Blucon, .Bubble, .Droplet1, .blueReader, .watlaa, .Libre2, .Atom:
            
            if cgmTransmitter.isWebOOPEnabled() {
                
                // received values are already calibrated
                
                trace("in getCalibrator, calibrator = NoCalibrator", log: log, category: ConstantsLog.categoryRootView, type: .info)
                
                return NoCalibrator()
                
            } else if cgmTransmitter.isNonFixedSlopeEnabled() {
                
                // no oop web, non-fixed slope
                
                trace("in getCalibrator, calibrator = Libre1NonFixedSlopeCalibrator", log: log, category: ConstantsLog.categoryRootView, type: .info)
                
                return Libre1NonFixedSlopeCalibrator()
                
            } else {
                
                // no oop web, fixed slope
                
                trace("in getCalibrator, calibrator = Libre1Calibrator", log: log, category: ConstantsLog.categoryRootView, type: .info)
                
                return Libre1Calibrator()
                
            }
            
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
        
        createNotification(title: Texts_Calibrations.calibrationNotificationRequestTitle, body: Texts_Calibrations.calibrationNotificationRequestBody, identifier: ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest, sound: UNNotificationSound(named: UNNotificationSoundName("")))
        
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
    /// - parameters:
    ///     - if overrideShowReadingInNotification then badge counter will be set (if enabled off course) with function UIApplication.shared.applicationIconBadgeNumber. To be used if badge counter is  to be set eg when UserDefaults.standard.showReadingInAppBadge is changed
    private func createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: Bool) {
        
        // bgReadingsAccessor should not be nil at all, but let's not create a fatal error for that, there's already enough checks for it
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            return
        }
        
        // get lastReading, with a calculatedValue - no check on activeSensor because in follower mode there is no active sensor
        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // if there's no reading for active sensor with calculated value , then no reason to continue
        if lastReading.count == 0 {
            
            trace("in createBgReadingNotificationAndSetAppBadge, lastReading.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            // remove the application badge number. Possibly an old reading is still shown.
            UIApplication.shared.applicationIconBadgeNumber = 0
            
            return
        }
        
        // if reading is older than 4.5 minutes, then also no reason to continue - this may happen eg in case of follower mode
        if Date().timeIntervalSince(lastReading[0].timeStamp) > 4.5 * 60 {
            
            trace("in createBgReadingNotificationAndSetAppBadge, timestamp of last reading > 4.5 * 60", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            // remove the application badge number. Possibly the previous value is still shown
            UIApplication.shared.applicationIconBadgeNumber = 0
            
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
        // and also if last notification was long enough ago (longer than UserDefaults.standard.notificationInterval), except if there would have been a disconnect since previous notification (simply because I like getting a new reading with a notification by disabling/reenabling bluetooth
        if UserDefaults.standard.showReadingInNotification && !overrideShowReadingInNotification && (abs(timeStampLastBGNotification.timeIntervalSince(Date())) > Double(UserDefaults.standard.notificationInterval) * 60.0 || lastConnectionStatusChangeTimeStamp().timeIntervalSince(timeStampLastBGNotification) > 0) {
            
            // Create Notification Content
            let notificationContent = UNMutableNotificationContent()
            
            // set value in badge if required
            if UserDefaults.standard.showReadingInAppBadge {
                
                // rescale if unit is mmol
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                    readingValueForBadge = readingValueForBadge.mgdlToMmol().round(toDecimalPlaces: 1)
                } else {
                    readingValueForBadge = readingValueForBadge.round(toDecimalPlaces: 0)
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
            
            // set timeStampLastBGNotification to now
            timeStampLastBGNotification = Date()
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
        
        // if glucoseChartManager not nil, then check if panned backward and if so then don't update the chart
        if let glucoseChartManager = glucoseChartManager  {
            // check that app is in foreground, but only if overrideApplicationState = false
            // check if chart is currently panned back in time, in that case we don't update the labels
            guard !glucoseChartManager.chartIsPannedBackward else {return}
        }
        
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}
        
        // check that bgReadingsAccessor exists, otherwise return - this happens if updateLabelsAndChart is called from viewDidload at app launch
        guard let bgReadingsAccessor = bgReadingsAccessor else {return}
        
        // set minutesLabelOutlet.textColor to white, might still be red due to panning back in time
        self.minutesLabelOutlet.textColor = UIColor.white
        
        // get latest reading, doesn't matter if it's for an active sensor or not, but it needs to have calculatedValue > 0 / which means, if user would have started a new sensor, but didn't calibrate yet, and a reading is received, then there's not going to be a latestReading
        let latestReadings = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // if there's no readings, then give empty fields and make sure the text isn't styled with strikethrough
        guard latestReadings.count > 0 else {
            
            valueLabelOutlet.textColor = UIColor.darkGray
            minutesLabelOutlet.text = ""
            diffLabelOutlet.text = ""
                
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: "---")
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
            return
        }
        
        // assign last reading
        let lastReading = latestReadings[0]
        
        // assign last but one reading
        let lastButOneReading = latestReadings.count > 1 ? latestReadings[1]:nil
        
        // start creating text for valueLabelOutlet, first the calculated value
        var calculatedValueAsString = lastReading.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        // if latestReading is older than 11 minutes, then it should be strikethrough
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60.0 * 11) {
            
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        } else {
            
            if !lastReading.hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading.slopeArrow()
            }
            
            // no strikethrough needed, but attributedText may still be set to strikethrough from previous period during which there was no recent reading.
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        }
        
        // to make follow code a bit more readable
        let mgdl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // if data is stale (over 11 minutes old), show it as gray colour to indicate that it isn't current
        // if not, then set color, depending on value lower than low mark or higher than high mark
        // set both HIGH and LOW BG values to red as previous yellow for hig is now not so obvious due to in-range colour of green.
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11) {
            valueLabelOutlet.textColor = UIColor.lightGray
        } else if lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) >= UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) || lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) <= UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) {
            // BG is higher than urgentHigh or lower than urgentLow objectives
            valueLabelOutlet.textColor = UIColor.red
        } else if lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) >= UserDefaults.standard.highMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) || lastReading.calculatedValue.bgValueRounded(mgdl: mgdl) <= UserDefaults.standard.lowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: mgdl).bgValueRounded(mgdl: mgdl) {
            // BG is between urgentHigh/high and low/urgentLow objectives
            valueLabelOutlet.textColor = UIColor.yellow
        } else {
            // BG is between high and low objectives so considered "in range"
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
    private func createAndPresentSensorButtonActionSheet() {
        
        // initialize list of actions
        var listOfActions = [UIAlertAction]()
        
        // first action is to show the status
        let sensorStatusAction = UIAlertAction(title: Texts_HomeView.statusActionTitle, style: .default) { (UIAlertAction) in
            self.showStatus()
        }
        listOfActions.append(sensorStatusAction)
        
        // next action is to start or stop the sensor, can also be omitted depending on type of device - also not applicable for follower mode
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() {
            if cgmTransmitter.cgmTransmitterType().allowManualSensorStart() && UserDefaults.standard.isMaster {
                // user needs to start and stop the sensor manually
                var startStopAction: UIAlertAction
                
                if activeSensor != nil {
                    startStopAction = UIAlertAction(title: Texts_HomeView.stopSensorActionTitle, style: .default) { (UIAlertAction) in
                        trace("in createAndPresentSensorButtonActionSheet, user clicked stop sensor, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                        self.stopSensor()
                    }
                } else {
                    startStopAction = UIAlertAction(title: Texts_HomeView.startSensorActionTitle, style: .default) { (UIAlertAction) in
                        self.startSensorAskUserForStarttime()
                    }
                }
                
                listOfActions.append(startStopAction)
            }
        }

        let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: nil)
        listOfActions.append(cancelAction)
        
        // create and present new alertController of type actionsheet
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for action in listOfActions {
            actionSheet.addAction(action)
        }
        
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
    
    /// stops the active sensor and sets sensorSerialNumber in UserDefaults to nil
    private func stopSensor() {
        
        if let activeSensor = activeSensor, let coreDataManager = coreDataManager {
            activeSensor.endDate = Date()
            coreDataManager.saveChanges()
        }
        // save the changes
        coreDataManager?.saveChanges()
        
        activeSensor = nil
        
    }
    
    /// start a new sensor, ask user for starttime
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
            
            screenLockAlert(overrideScreenIsLocked: true)
            
        }
    }
    
    private func getCGMTransmitterDeviceName(for cgmTransmitter: CGMTransmitter) -> String? {
        
        if let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter {
            return bluetoothTransmitter.deviceName
        }
        
        return nil
        
    }
    
    /// enables or disables the buttons on top of the screen
    private func changeButtonsStatusTo(enabled: Bool) {
        
        if enabled {
            sensorToolbarButtonOutlet.enable()
            calibrateToolbarButtonOutlet.enable()
        } else {
            sensorToolbarButtonOutlet.disable()
            calibrateToolbarButtonOutlet.disable()
        }
        
    }
    
    /// call alertManager.checkAlerts, and calls createBgReadingNotificationAndSetAppBadge with overrideShowReadingInNotification true or false, depending if immediate notification was created or not
    private func checkAlertsCreateNotificationAndSetAppBadge() {
        
        // unwrap alerts and check alerts
        if let alertManager = alertManager {
            
            // check if an immediate alert went off that shows the current reading
            if alertManager.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds) {
                
                // an immediate alert went off that shows the current reading
                
                // possibily the app is in the foreground now
                // if user would have opened SnoozeViewController now, then close it, otherwise the alarm picker view will not be shown
                closeSnoozeViewController()
                
                // only update badge is required, (if enabled offcourse)
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
                
            } else {
                
                // update notification and app badge
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: false)
                
            }
            
        }
        
    }
    
    // a long function just to get the timestamp of the last disconnect or reconnect. If not known then returns 1 1 1970
    private func lastConnectionStatusChangeTimeStamp() -> Date  {
        
        // this is actually unwrapping of optionals, goal is to get date of last disconnect/reconnect - all optionals should exist so it doesn't matter what is returned true or false
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter, let bluetoothPeripheral = self.bluetoothPeripheralManager?.getBluetoothPeripheral(for: bluetoothTransmitter), let lastConnectionStatusChangeTimeStamp = bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp else {return Date(timeIntervalSince1970: 0)}
        
        return lastConnectionStatusChangeTimeStamp
        
    }
    
    
    // helper function to calculate the statistics and update the pie chart and label outlets
    private func updateStatistics(animatePieChart: Bool = false, overrideApplicationState: Bool = false) {
        
        // don't calculate statis if app is not running in the foreground
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}
        
        // if the user doesn't want to see the statistics, then just return without doing anything
        if !UserDefaults.standard.showStatistics {
            return
        }
        
        // declare constants/variables
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        var daysToUseStatistics: Int = 0
        var fromDate: Date = Date()
        
        // get the maximum number of calculation days requested by the user
        daysToUseStatistics = UserDefaults.standard.daysToUseStatistics
        
        // if the user has selected 0 (to chose "today") then set the fromDate to the previous midnight
        if daysToUseStatistics == 0 {
            fromDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
        } else {
            fromDate = Date(timeIntervalSinceNow: -3600.0 * 24.0 * Double(daysToUseStatistics))
        }
        
        
        // let's clean up statistics UI before calling the Statistics Manager
        // we'll also show the activity monitor and change the statistics label colors to gray
        if self.averageStatisticLabelOutlet.text == "-" {
            self.activityMonitorOutlet.isHidden = true
        } else {
            self.activityMonitorOutlet.isHidden = false
        }
        
        self.pieChartOutlet.clear()
        self.pieChartLabelOutlet.text = ""
        
        self.lowStatisticLabelOutlet.textColor = UIColor.lightGray
        self.lowStatisticLabelOutlet.text = "-"
        self.inRangeStatisticLabelOutlet.textColor = UIColor.lightGray
        self.inRangeStatisticLabelOutlet.text = "-"
        self.highStatisticLabelOutlet.textColor = UIColor.lightGray
        self.highStatisticLabelOutlet.text = "-"
        self.averageStatisticLabelOutlet.text = "-"
        self.a1CStatisticLabelOutlet.text = "-"
        self.cVStatisticLabelOutlet.text = "-"
        self.timePeriodLabelOutlet.text = "- - -"
        
        
        // statisticsManager will calculate the statistics in background thread and call the callback function in the main thread
        statisticsManager?.calculateStatistics(fromDate: fromDate, toDate: nil, callback: { statistics in
            
            // set the title labels to their correct localization
            self.lowTitleLabelOutlet.text = Texts_Common.lowStatistics
            self.inRangeTitleLabelOutlet.text = Texts_Common.inRangeStatistics
            self.highTitleLabelOutlet.text = Texts_Common.highStatistics
            self.averageTitleLabelOutlet.text = Texts_Common.averageStatistics
            self.a1cTitleLabelOutlet.text = Texts_Common.a1cStatistics
            self.cvTitleLabelOutlet.text = Texts_Common.cvStatistics
            
            
            // set the low/high "label" labels with the low/high user values that the user has chosen to use
            self.lowLabelOutlet.text = "(<" + (isMgDl ? Int(statistics.lowLimitForTIR).description : statistics.lowLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            self.highLabelOutlet.text = "(>" + (isMgDl ? Int(statistics.highLimitForTIR).description : statistics.highLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            
            
            // set all label outlets with the correctly formatted calculated values
            self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
            self.lowStatisticLabelOutlet.text = Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
            self.inRangeStatisticLabelOutlet.text = Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
            self.highStatisticLabelOutlet.text = Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            self.averageStatisticLabelOutlet.text = (isMgDl ? Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0)).description : statistics.averageStatisticValue.round(toDecimalPlaces: 1).description) + (isMgDl ? " mg/dl" : " mmol/l")
            
            if UserDefaults.standard.useIFCCA1C {
                self.a1CStatisticLabelOutlet.text = Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0)).description + " mmol"
            } else {
                self.a1CStatisticLabelOutlet.text = statistics.a1CStatisticValue.round(toDecimalPlaces: 1).description + "%"
            }
            
            self.cVStatisticLabelOutlet.text = Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)).description + "%"
            
            // show number of days calculated under the pie chart
            switch daysToUseStatistics {
            case 0:
                self.timePeriodLabelOutlet.text = Texts_Common.today
                
            case 1:
                self.timePeriodLabelOutlet.text = "24 " + Texts_Common.hours
                
            default:
                self.timePeriodLabelOutlet.text = statistics.numberOfDaysUsed.description + " " + Texts_Common.days
            }
            
            
            // disable the chart animation if it's just a normal update, enable it if the call comes from didAppear()
            if animatePieChart {
                self.pieChartOutlet.animDuration = ConstantsStatistics.pieChartAnimationSpeed
            } else {
                self.pieChartOutlet.animDuration = 0
            }
            
            // we want to calculate how many hours have passed since midnight so that we can decide if we should show the easter egg. The user will almost always be in range at 01hrs in the morning so we don't want to show it until mid-morning or midday so that there is some sense of achievement
            let currentHoursSinceMidnight = Calendar.current.dateComponents([.hour], from: Calendar(identifier: .gregorian).startOfDay(for: Date()), to: Date()).hour!
            
            
            self.activityMonitorOutlet.isHidden = true
            
            // if the user is 100% in range, show the easter egg and make them smile
            if statistics.inRangeStatisticValue < 100 {
                
                // set the reference angle of the pie chart to ensure that the in range slice is centered
                self.pieChartOutlet.referenceAngle = 90.0 - (1.8 * CGFloat(statistics.inRangeStatisticValue))
                
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: Double(statistics.inRangeStatisticValue), color: ConstantsStatistics.pieChartInRangeSliceColor),
                    PieSliceModel(value: Double(statistics.lowStatisticValue), color: ConstantsStatistics.pieChartLowSliceColor),
                    PieSliceModel(value: Double(statistics.highStatisticValue), color: ConstantsStatistics.pieChartHighSliceColor)
                ]
                
                self.pieChartLabelOutlet.text = ""
                
            } else if ConstantsStatistics.showInRangeEasterEgg && ((Double(currentHoursSinceMidnight) >= ConstantsStatistics.minimumHoursInDayBeforeShowingEasterEgg) || (UserDefaults.standard.daysToUseStatistics > 0)) {
                
                // if we want to show easter eggs check if one of the following two conditions is true:
                //      - at least 16 hours (for example) have passed since midnight if the user is showing only Today and is still 100% in range
                //      - if the user is showing >= 1 full days and they are still 100% in range
                // the idea is to avoid that the easter egg appears after just a few minutes of being in range (at 00:15hrs for example) as this has no merit.
                
                // open up the inside of the chart so that we can fit the smiley face in
                self.pieChartOutlet.innerRadius = 16
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                ]
                
                self.pieChartLabelOutlet.font = UIFont.boldSystemFont(ofSize: 26)
                self.pieChartLabelOutlet.text = "😎"
                
            } else {
                
                // the easter egg isn't wanted so just show a green circle at 100%
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                ]
                
                self.pieChartLabelOutlet.text = ""
                
            }
            
        })
    }
    
    /// swaps status from locked to unlocked or vice versa, and creates alert to inform user
    /// - parameters:
    ///     - overrideScreenIsLocked : if true, then screen will be locked even if it's already locked. If false, then status swaps from locked to unlocked or unlocked to locked
    private func screenLockAlert(overrideScreenIsLocked: Bool = false) {
        
        if !screenIsLocked || overrideScreenIsLocked {
            
            trace("screen lock : user clicked the lock button or long pressed the value", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            // lock and update the screen
            self.screenLockUpdate(enabled: true)
            
            // create uialertcontroller to inform user
            screenLockAlertController = UIAlertController(title: Texts_HomeView.screenLockTitle, message: Texts_HomeView.screenLockInfo, preferredStyle: .alert)

            // create buttons for uialertcontroller
            let OKAction = UIAlertAction(title: Texts_Common.Ok, style: .default) {
                (action:UIAlertAction!) in
                
                // set screenLockAlertController to nil because this variable is used when app comes to foreground, to check if alert is still presented
                self.screenLockAlertController = nil
                
            }

            // add buttons to the alert
            screenLockAlertController!.addAction(OKAction)

            // show alert
            self.present(screenLockAlertController!, animated: true, completion:nil)
            
            // schedule timer to dismiss the uialert controller after some time, in case user doesn't click ok
            Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(dismissScreenLockAlertController), userInfo: nil, repeats:false)
            
        } else {
            
            trace("screen lock : user clicked the unlock button", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            // this means the user has clicked the button whilst the screen look in already in place so let's turn the function off
            self.screenLockUpdate(enabled: false)
            
        }
        
    }
    
    
    /// this function will run when the user wants the screen to lock, or whenever the view appears and it will set up the screen correctly for each mode
    private func screenLockUpdate(enabled: Bool = true) {

        if enabled {
            
            // set screen lock icon color to value defined in constants file
            screenLockImageOutlet.isHidden = false
            
            // set the value label font size to big
            valueLabelOutlet.font = ConstantsUI.valueLabelFontSizeScreenLock
            
            // set the clock label font size to big (force ConstantsUI implementation)
            clockLabelOutlet.font = ConstantsUI.clockLabelFontSize
            
            // set clock label color
            clockLabelOutlet.textColor = ConstantsUI.clockLabelColor
            
            // set the toolbar button text to "Unlock"
            screenLockToolbarButtonOutlet.title = Texts_HomeView.unlockButton
            
            // de-clutter the screen. Hide the statistics view, controls and show the clock view
            statisticsView.isHidden = true
            segmentedControlsView.isHidden = true
            optionalSpacerView.isHidden = true
            clockView.isHidden = false
            
            // set the format for the clock view and update it to show the current time
            updateClockView()
            
            // set a timer instance to update the clock view label every second
            clockTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateClockView), userInfo: nil, repeats:true)

            // prevent screen dim/lock
            UIApplication.shared.isIdleTimerDisabled = true
            
            // set the private var so that we can track the screen lock activation within the RootViewController
            screenIsLocked = true
            
            trace("screen lock : screen lock / keep-awake enabled", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
        } else {

            // hide the lock image, but the value font size back to normal
            screenLockImageOutlet.isHidden = true
            valueLabelOutlet.font = ConstantsUI.valueLabelFontSizeNormal
            
            // set the toolbar button text to "Lock"
            screenLockToolbarButtonOutlet.title = Texts_HomeView.lockButton

            // hide
            statisticsView.isHidden = !UserDefaults.standard.showStatistics
            segmentedControlsView.isHidden = false
            optionalSpacerView.isHidden = UserDefaults.standard.showStatistics
            clockView.isHidden = true
            
            // destroy the timer instance so that it doesn't keep using resources
            clockTimer?.invalidate()
            
            // make sure that the screen lock is deactivated
            UIApplication.shared.isIdleTimerDisabled = false
            
            trace("screen lock / keep-awake disabled", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            screenIsLocked = false
            
        }
    }
    
    
    /// update the label in the clock view every time this function is called
    @objc private func updateClockView() {
        self.clockLabelOutlet.text = clockDateFormatter.string(from: Date())
    }

    /// checks if screenLockAlertController is not nil and if not dismisses the presentedViewController
    @objc private func dismissScreenLockAlertController() {
        
        // possibly screenLockAlertController is still on the screen which would happen if user chooses to lock the screen but brings the app to the background before clicking ok
        if self.screenLockAlertController != nil {
            
            self.presentedViewController?.dismiss(animated: false, completion: nil)
            
            self.screenLockAlertController = nil
            
        }

    }
    
}


// MARK: - conform to CGMTransmitter protocol

/// conform to CGMTransmitterDelegate
extension RootViewController: CGMTransmitterDelegate {
    
    func newSensorDetected() {
        trace("new sensor detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        stopSensor()
    }
    
    func sensorNotDetected() {
        trace("sensor not detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        createNotification(title: Texts_Common.warning, body: Texts_HomeView.sensorNotDetected, identifier: ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected, sound: nil)
        
    }
    
    func cgmTransmitterInfoReceived(glucoseData: inout [GlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorTimeInMinutes: Int?) {
        
        trace("transmitterBatteryInfo %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, transmitterBatteryInfo?.description ?? "not received")
        trace("sensor time in minutes %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorTimeInMinutes?.description ?? "not received")
        trace("glucoseData size = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, glucoseData.count.description)
        
        // if received transmitterBatteryInfo not nil, then store it
        if let transmitterBatteryInfo = transmitterBatteryInfo {
            UserDefaults.standard.transmitterBatteryInfo = transmitterBatteryInfo
        }
        
        // process new readings
        processNewGlucoseData(glucoseData: &glucoseData, sensorTimeInMinutes: sensorTimeInMinutes)
        
    }
    
    func errorOccurred(xDripError: XdripError) {
        
        if xDripError.priority == .HIGH {
            
            createNotification(title: Texts_Common.warning, body: xDripError.errorDescription, identifier: ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError, sound: nil)
            
        }
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
extension RootViewController: UNUserNotificationCenterDelegate {
    
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
            
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // so actually the app was in the foreground, at the  moment the Transmitter Class called the cgmTransmitterNeedsPairing function, there's no need to show the notification, we can immediately call back the cgmTransmitter initiatePairing function
            completionHandler([])
            bluetoothPeripheralManager?.initiatePairing()
            
            // this will verify if it concerns an alert notification, if not pickerviewData will be nil
        } else if let pickerViewData = alertManager?.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) {
            
            
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
        }  else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForVolumeTest {
            
            // user is testing iOS Sound volume in the settings. Only the sound should be played, the alert itself will not be shown
            completionHandler([.sound])
            
        } else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError {
            
            // call completionhandler to show the notification even though the app is in the foreground, without sound
            completionHandler([.alert])
            
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

            // get lastReading, ignore sensor as this should be nil because this is follower mode
            if let lastReading = bgReadingsAccessor.last(forSensor: nil) {
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
                
                // update all text in  first screen
                updateLabelsAndChart(overrideApplicationState: false)
                
                // update statistics related outlets
                updateStatistics(animatePieChart: false)
                
                // check alerts, create notification, set app badge
                checkAlertsCreateNotificationAndSetAppBadge()
                
                if let healthKitManager = healthKitManager {
                    healthKitManager.storeBgReadings()
                }
                
                if let bgReadingSpeaker = bgReadingSpeaker {
                    bgReadingSpeaker.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                }
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                // ask watchManager to process new reading, ignore last connection change timestamp because this is follower mode, there is no connection to a transmitter
                watchManager?.processNewReading(lastConnectionStatusChangeTimeStamp: nil)
                
                // send also to loopmanager, not interesting for loop probably, but the data is also used for today widget
                self.loopManager?.share()
                
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
