//
//  RootApplicationCoordinator.swift
//  xdrip
//
//  Created by Paul Plant on 12/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import UIKit
import CoreData
import os
import CoreBluetooth
import UserNotifications
import HealthKitUI
import AVFoundation
import WatchConnectivity
import SwiftUI
import WidgetKit
import AppIntents

/// Owns the long-lived application services previously created by RootViewController.
///
/// SwiftUI owns the complete root view hierarchy. This coordinator remains an NSObject because it
/// receives transmitter, follower, notification and UserDefaults callbacks, none of which require
/// a view-controller lifecycle.
@MainActor final class RootApplicationCoordinator: NSObject {
    
    // MARK: - Constants for ApplicationManager usage
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create updateLabelsAndChartTimer
    private let applicationManagerKeyCreateupdateLabelsAndChartTimer = "RootViewController-CreateupdateLabelsAndChartTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground
    private let applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeScreen = "RootViewController-InvalidateupdateLabelsAndChartTimerAndCloseSnoozeScreen"
    
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
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to update labels and chart
    private let applicationManagerKeyUpdateLabelsAndChart = "applicationManagerKeyUpdateLabelsAndChart"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - to do a Nightscout Treatment sync
    private let applicationManagerKeyStartNightscoutTreatmentSync = "applicationManagerKeyStartNightscoutTreatmentSync"
    
    
    // MARK: - Properties - other private properties
    
    /// for logging
    nonisolated private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// CoreDataManager to be used throughout the project
    private var coreDataManager: CoreDataManager?
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// Calibrator to be used for calibration, value will depend on transmitter type
    private var calibrator: Calibrator?
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor?
    
    /// CalibrationsAccessor instance
    private var calibrationsAccessor: CalibrationsAccessor?
    
    /// TreatmentEntryAccessor instance
    private var treatmentEntryAccessor: TreatmentEntryAccessor?
    
    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager?
    
    /// AlertManager instance
    private var alertManager: AlertManager?
    
    /// LoopManager instance
    private var loopManager: LoopManager?
    
    /// SoundPlayer instance
    private var soundPlayer: SoundPlayer?
    
    /// NightscoutFollowManager instance
    private var nightscoutFollowManager: NightscoutFollowManager?
    
    /// LibreLinkUpFollowManager instance
    private var libreLinkUpFollowManager: LibreLinkUpFollowManager?
    
    /// DexcomShareFollowManager instance
    private var dexcomShareFollowManager: DexcomShareFollowManager?

    /// MedtrumEasyViewFollowManager instance
    private var medtrumEasyViewFollowManager: MedtrumEasyViewFollowManager?

    /// LoopFollowManager instance
    private var loopFollowManager: LoopFollowManager?
    
    /// DexcomShareUploadManager instance
    private var dexcomShareUploadManager: DexcomShareUploadManager?
    
    /// CalendarManager instance
    private var calendarManager: CalendarManager?
    
    /// ContactImageManager  instance
    private var contactImageManager: ContactImageManager?
    
    /// HealthKit manager instance
    private var healthKitManager:HealthKitManager?
    
    /// BG post processing manager instance
    private var bgPostProcessingManager: BgPostProcessingManager?

    /// SensorNoiseManager instance
    private var sensorNoiseManager: SensorNoiseManager?
    
    /// reference to activeSensor
    private(set) var activeSensor:Sensor?
    
    /// reference to bgReadingSpeaker
    private var bgReadingSpeaker:BGReadingSpeaker?
    
    /// manages bluetoothPeripherals that this app knows
    private var bluetoothPeripheralManager: BluetoothPeripheralManager?
    
    /// statisticsManager instance
    private var statisticsManager: StatisticsManager?
    
    /// watchManager instance
    private var watchManager: WatchManager?
    
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

    /// True only when screen lock is using the full night layout. The keep-awake variant still
    /// locks interaction but deliberately leaves the normal home sections visible.
    private var screenLockUsesNightLayout = false
    
    /// initiate a Timer object that we will use keep the follower connection status updated every 30 seconds or so
    private var followerConnectionTimer: Timer?
    
    /// Last timestamp when a log line was produced by TransmitterReadSuccessManager
    private var transmitterReadSuccessTimeStampOfLastLogCreated: Date?

    /// Presentation state shared with the native SwiftUI home screen.
    ///
    /// The coordinator owns app services while this model calculates display values directly.
    private let rootHomeStateModel = RootHomeStateModel()

    /// Publishes the services needed by the native SwiftUI tabs after startup completes.
    private weak var rootTabStateModel: RootTabStateModel?

    private var hasStarted = false
    
    // MARK: - SwiftUI Lifecycle

    /// Runs the refresh work previously triggered by RootViewController's viewWillAppear and viewDidAppear.
    /// RootHomeTabView calls this whenever the Home tab becomes visible.
    func homeDidBecomeVisible() {
        
        // check if allowed to rotate to landscape view
        updateScreenRotationSettings()
        
        // viewWillAppear when user switches eg from Settings Tab to Home Tab - latest reading value
        // needs to be shown on the view, and the live chart should be returned to the real current time.
        updateLabelsAndChart(overrideApplicationState: true, forceReset: true)
        
        updatePumpAndAIDStatusViews()

        // display the data source info view if applicable
        updateDataSourceInfo()
        
        // update statistics related outlets
        updateStatistics(animate: true, overrideApplicationState: true)
        
        watchManager?.updateWatchApp(forceComplicationUpdate: false)
        
        // update the UI (chart + pump status) as soon as the app appears. We'll update it again in a couple of seconds
        // in case more data arrives in the meantime (i.e. follower/NS data etc)
        // we used to just wait two seconds, but some users thought that the app didn't work and then "caught up"
        // so it makes more sense to just update immediately.
        self.updateLabelsAndChart(overrideApplicationState: true)
        
        self.updatePumpAndAIDStatusViews()
        
        // let's run the data source info and chart update 1 second after the root view appears. This should give time for the follower modes to download and populate the info needed.
        // no animation is needed as in most cases, we're just refreshing and displaying what is already shown on screen so we want to keep this refresh invisible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            // if the user locks the screen before the update is called, then don't run the update
            if !self.screenIsLocked {
                self.updateDataSourceInfo()
            }
            
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            self.updatePumpAndAIDStatusViews()
        }
        
        self.updateSnoozeStatus()
        self.updatePostProcessingStatus()
        
        IntentDonationManager.shared.donate(intent: GlucoseIntent())
    }

    /// Starts application services once the SwiftUI root state is available.
    func start(rootTabStateModel: RootTabStateModel) {
        guard !hasStarted else { return }

        hasStarted = true
        self.rootTabStateModel = rootTabStateModel
        startServices()
    }

    /// Recreates the established application manager graph after Core Data is ready, then publishes
    /// only the references required by the SwiftUI root. This remains separate from view creation so
    /// selecting or rebuilding a tab cannot restart application services.
    private func startServices() {
        
        // Run a quick check to see if the currently stored followerDataSourceType is now on the ignore list
        // if so, then reset back to Nightscout. This is unlikely to ever happen, but it *is* possible.
        let storedType = UserDefaults.standard.followerDataSourceType
        if !FollowerDataSourceType.allEnabledCases.contains(storedType) {
            UserDefaults.standard.followerDataSourceType = .nightscout
            trace("in startServices, reset followerDataSourceType from newly ignored %{public}@ to %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, storedType.description, UserDefaults.standard.followerDataSourceType.description)
        }
        
        // from 5.2.0 the showTarget userdefault will be deprecated
        // showTarget will not be checked by the app any more, it will use targetMarkValue
        // targetMarkValue == 0 for disabled (hide) or targetMarkValue > 0 for enabled (show)
        if !UserDefaults.standard.showTarget {
            UserDefaults.standard.targetMarkValueInUserChosenUnit = 0
        }
        
        // ensure the screen layout
        screenLockUpdate(enabled: false)
        
        // this is to force update of userdefaults that are also stored in the shared user defaults
        // these are used by the today widget. After a year or so (september 2021) this can all be deleted
        UserDefaults.standard.urgentLowMarkValueInUserChosenUnit = UserDefaults.standard.urgentLowMarkValueInUserChosenUnit
        UserDefaults.standard.urgentHighMarkValueInUserChosenUnit = UserDefaults.standard.urgentHighMarkValueInUserChosenUnit
        UserDefaults.standard.lowMarkValueInUserChosenUnit = UserDefaults.standard.lowMarkValueInUserChosenUnit
        UserDefaults.standard.highMarkValueInUserChosenUnit = UserDefaults.standard.highMarkValueInUserChosenUnit
        UserDefaults.standard.bloodGlucoseUnitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
                
        // on 10Jan2025 the chart width options were changed from 3/5/12/24 to 3/5/8/12
        // this is just a quick check to catch any users that had 24 selected when they updated
        // NOTE: The UI showed 3/6/12/24, but it was actually using 3/5/12/24 for 4 years and nobody noticed the missing hour :)
        if UserDefaults.standard.chartWidthInHours == 24 {
            UserDefaults.standard.chartWidthInHours = 12
        }
        
        // enable or disable the sensor management button on top, depending on master or follower
        changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
        
        // nillify the active sensor start date on start-up
        UserDefaults.standard.activeSensorStartDate = nil
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            
            self.setupApplicationData()

            if let coreDataManager = self.coreDataManager,
               let bgReadingsAccessor = self.bgReadingsAccessor,
               let calibrationsAccessor = self.calibrationsAccessor,
               let treatmentEntryAccessor = self.treatmentEntryAccessor,
               let alertManager = self.alertManager,
               let bgPostProcessingManager = self.bgPostProcessingManager,
               let sensorNoiseManager = self.sensorNoiseManager,
               let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
               let soundPlayer = self.soundPlayer,
               let nightscoutSyncManager = self.nightscoutSyncManager {
                self.rootHomeStateModel.configure(
                    bgReadingsAccessor: bgReadingsAccessor,
                    treatmentEntryAccessor: treatmentEntryAccessor,
                    nightscoutSyncManager: nightscoutSyncManager,
                    bluetoothPeripheralManager: bluetoothPeripheralManager,
                    alertManager: alertManager,
                    bgPostProcessingManager: bgPostProcessingManager
                )

                self.rootTabStateModel?.configure(
                    coreDataManager: coreDataManager,
                    bgReadingsAccessor: bgReadingsAccessor,
                    calibrationsAccessor: calibrationsAccessor,
                    treatmentEntryAccessor: treatmentEntryAccessor,
                    alertManager: alertManager,
                    bgPostProcessingManager: bgPostProcessingManager,
                    sensorNoiseManager: sensorNoiseManager,
                    bluetoothPeripheralManager: bluetoothPeripheralManager,
                    soundPlayer: soundPlayer,
                    nightscoutSyncManager: nightscoutSyncManager,
                    rootHomeStateModel: self.rootHomeStateModel,
                    rootHomeActions: self.makeRootHomeActions(),
                    activeSensorProvider: { [weak self] in self?.activeSensor },
                    transmitterProvider: { [weak self] in self?.bluetoothPeripheralManager?.getCGMTransmitter() },
                    startSensor: { [weak self] startDate, sensorCode in
                        self?.startSensorFromManagementView(startDate: startDate, sensorCode: sensorCode)
                    },
                    stopSensor: { [weak self] in
                        self?.stopSensorFromManagementView()
                    },
                    submitCalibration: { [weak self] value in
                        self?.submitCalibrationFromManagementView(value)
                    },
                    updateScreenLock: { [weak self] overrideCurrentState, nightMode in
                        self?.updateScreenLock(overrideCurrentState: overrideCurrentState, nightMode: nightMode) ?? false
                    },
                    sensorProvider: self
                )
            }

            // housekeeper should be non nil here, kall housekeeper
            self.houseKeeper?.doAppStartUpHouseKeeping()
            
            // update label texts, minutes ago, diff and value
            self.updateLabelsAndChart(overrideApplicationState: true)
            
            // update the mini-chart
            self.updateMiniChart()
            
            // update data source info
            self.updateDataSourceInfo()
            
            // update statistics related outlets
            self.updateStatistics(animate: true, overrideApplicationState: true)
            
            // create badge counter
            self.createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
            // if licenseinfo not yet accepted, show license info with only ok button
            if !UserDefaults.standard.licenseInfoAccepted {
                
                self.presentAlert(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress) {
                    // set licenseInfoAccepted to true
                    UserDefaults.standard.licenseInfoAccepted = true

                    // create info screen about transmitters
                    self.presentAlert(title: Texts_HomeView.info, message: Texts_HomeView.transmitterInfo)
                }
                
            }
            
            // launch Nightscout sync
            self.setNightscoutSyncRequiredToTrue(forceNow: true)
            
            self.updateLiveActivityAndWidgets(forceRestart: false)
            
        })
        
        // observe setting changes
        // changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        
        // see if the user has changed the chart x axis timescale
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.KeysCharts.chartWidthInHours.rawValue, options: .new, context: nil)
        
        // have the mini-chart hours been changed?
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.miniChartHoursToShow.rawValue, options: .new, context: nil)
        
        // showing or hiding the mini-chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showMiniChart.rawValue, options: .new, context: nil)
        
        // showing or hiding the statistics view
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showStatistics.rawValue, options: .new, context: nil)
        
        // showing or hiding the treatments on the chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showTreatmentsOnChart.rawValue, options: .new, context: nil)

        // showing or hiding the original BG readings on the chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showOriginalBGReadings.rawValue, options: .new, context: nil)

        // showing or hiding the sensor noise bands on the main chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showSensorNoiseOnChart.rawValue, options: .new, context: nil)

        // changing how strictly stored sensor noise values are interpreted
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.sensorNoiseSensitivity.rawValue, options: .new, context: nil)
        
        // see if the user has changed the statistic days to use
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.daysToUseStatistics.rawValue, options: .new, context: nil)
        
        // bg reading notification and badge, and multiplication factor
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInNotification.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showReadingInAppBadge.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.multipleAppBadgeValueWith10.rawValue, options: .new, context: nil)
        // also update of unit requires update of badge
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
        // update show clock value for the screen lock function
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showClockWhenScreenIsLocked.rawValue, options: .new, context: nil)
        // if live action type is updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.liveActivityType.rawValue, options: .new, context: nil)
        
        // high mark , low mark , urgent high mark, urgent low mark. change requires redraw of chart
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentLowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.lowMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.highMarkValue.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.urgentHighMarkValue.rawValue, options: .new, context: nil)
        
        // add observer for nightscoutTreatmentsUpdateCounter, to reload the chart whenever a treatment is added or updated or deleted changes
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutTreatmentsUpdateCounter.rawValue, options: .new, context: nil)
        
        // add observer for stopActiveSensor, this will reset the active sensor to nil when the user disconnects an intergrated transmitter/sensor (e.g. Libre 2 Direct). This will help ensure that the data source info is updated/disabled until a new sensor is started.
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.stopActiveSensor.rawValue, options: .new, context: nil)
        
        // add observer for followerKeepAliveType, to reset the app badge notification if in follower mode and keep-alive is set to disabled
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
        
        // add observer for the last heartbeat timestamp in order to update the UI
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.timeStampOfLastHeartBeat.rawValue, options: .new, context: nil)
        
        // force the snooze icon status to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.updateSnoozeStatus.rawValue, options: .new, context: nil)
        
        // if the snooze all until data changes, update the UI
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.snoozeAllAlertsUntilDate.rawValue, options: .new, context: nil)
        
        // if bg post processing settings change, update the toolbar status
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.enableAdjustment.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.enableSmoothing.rawValue, options: .new, context: nil)
        
        // if the user changes master or follower source identity details, clear
        // any post processing state so it does not carry over to a different source
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpEmail.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpPassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerPatientName.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewEmail.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewPassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewSelectedPatientUid.rawValue, options: .new, context: nil)
        
        // if the Nightscout Follower type changes, update the UI
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutFollowType.rawValue, options: .new, context: nil)
        
        // if the Nightscout device status changes, update the UI
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatus.rawValue, options: .new, context: nil)
        
        // if the widget standby options change, update the widget data
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.allowStandByHighContrast.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.forceStandByBigNumbers.rawValue, options: .new, context: nil)
        
        // if the snooze all until data changes, update the UI
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.snoozeAllAlertsUntilDate.rawValue, options: .new, context: nil)
        
        // if bg post processing changes, update the chart
        NotificationCenter.default.addObserver(self, selector: #selector(handleBgPostProcessingDidUpdate), name: Notification.Name(ConstantsNotifications.NotificationIdentifierForBgPostProcessing.bgPostProcessingDidUpdate), object: nil)
        
        // setup delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self
        
        // check if app is allowed to send local notification and if not ask it
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            switch notificationSettings.authorizationStatus {
            case .notDetermined, .denied:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
                    if let error = error {
                        trace("in startServices, request notification authorization failed : %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
                    }
                }
            default:
                break
            }
        }
        
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
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyTraceAppGoesToBackGround, closure: {
            if UserDefaults.standard.isMaster {
                trace("Application did enter background, master mode", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            } else {
                trace("Application did enter background, follower background keep-alive type: %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, UserDefaults.standard.followerBackgroundKeepAliveType.description)
                
                self.followerConnectionTimer?.invalidate()
                self.followerConnectionTimer = nil
            }
            
            if self.screenIsLocked {
                self.screenLockUpdate(enabled: false)
            }

            self.publishRootHomeState()
        })
        
        // add tracing when app comes to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyTraceAppGoesToForeground, closure: {
            trace("Application will enter foreground", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
        })
        
        // add tracing when app will terminate - this only works for non-suspended apps, probably (not tested) also works for apps that crash in the background
        ApplicationManager.shared.addClosureToRunWhenAppWillTerminate(key: applicationManagerKeyTraceAppWillTerminate, closure: {
            // force the live activity to end if it exists to prevent it becoming "orphaned" and unclosable by the app
            Task { await LiveActivityManager.shared.endAllActivities() }
            
            trace("*******************************************************************", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            trace("*** Application will terminate, likely force-closed by the user ***", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            trace("*******************************************************************", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
        })
        
        // update the home screen when returning to the foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyUpdateLabelsAndChart, closure: {
            // if view is appeared, view did appear will not get called when app moves to the foreground
            // so need to donate here
            IntentDonationManager.shared.donate(intent: GlucoseIntent())
            
            self.updateSnoozeStatus()
            
            // update the connection status immediately (this will give the user a visual feedback that the connection was lost in the background if they have disabled keep-alive)
            self.setFollowerConnectionAndHeartbeatStatus()
            
            // Schedule a call to updateLabelsAndChart when the app comes to the foreground, with a delay of 0.5 seconds. Because the application state is not immediately to .active, as a result, updates may not happen - especially the synctreatments may not happen because this may depend on the application state - by making a call just half a second later, when the status is surely = .active, the UI updates will be done correctly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateLabelsAndChart(overrideApplicationState: true)
                self.updateMiniChart()
                self.updateDataSourceInfo()
                // update statistics related outlets
                self.updateStatistics(animate: true)
                // check and see if we need to restart the live activity in case the user dismissed it from the lock screen
                // the app cannot restart the activity from the background so let's check it now
                // we'll also take advantage to restart the live activity when the user brings the app to the foregroud
                self.updateLiveActivityAndWidgets(forceRestart: true)
                self.updatePumpAndAIDStatusViews()
            }
        })
        
        
        // launch nightscout treatment sync whenever the app comes to the foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyStartNightscoutTreatmentSync, closure: {
            self.setNightscoutSyncRequiredToTrue(forceNow: false)
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
    
    // creates activeSensor, bgreadingsAccessor, calibrationsAccessor, NightscoutSyncManager, soundPlayer, dexcomShareUploadManager, nightscoutFollowManager, alertManager, healthKitManager, bgReadingSpeaker, bluetoothPeripheralManager, calendarManager, housekeeper, contactImageManager
    private func setupApplicationData() {
        
        // setup Trace
        Trace.initialize(coreDataManager: coreDataManager)
        
        // if coreDataManager is nil then there's no reason to continue
        guard let coreDataManager = coreDataManager else {
            fatalError("in setupApplicationData, coreDataManager == nil")
        }

        migrateStoredAlertSnoozePeriodsToReducedOptionsIfNeeded(coreDataManager: coreDataManager)
        
        // get currently active sensor
        activeSensor = SensorsAccessor.init(coreDataManager: coreDataManager).fetchActiveSensor()
        
        // instantiate bgReadingsAccessor
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            fatalError("in setupApplicationData, failed to initialize bgReadings")
        }
        
        // instantiate calibrations
        calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        
        // instanstiate Housekeeper
        houseKeeper = HouseKeeper(coreDataManager: coreDataManager)
        
        // setup nightscout synchronizer
        nightscoutSyncManager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: { (title:String, message:String) in
            self.presentAlert(title: title, message: message)
        })
        
        // instantiate treatment entry accessor
        treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        
        // setup SoundPlayer
        soundPlayer = SoundPlayer()
        
        // setup FollowManager
        guard let soundPlayer = soundPlayer else { fatalError("in setupApplicationData, this looks very in appropriate, shame")}
        
        // setup nightscoutmanager
        nightscoutFollowManager = NightscoutFollowManager(coreDataManager: coreDataManager, followerDelegate: self)
        
        // setup libreLinkUpFollowManager
        libreLinkUpFollowManager = LibreLinkUpFollowManager(coreDataManager: coreDataManager, followerDelegate: self)
        
        // setup dexcomShareFollowManager
        dexcomShareFollowManager = DexcomShareFollowManager(coreDataManager: coreDataManager, followerDelegate: self)

        // setup medtrumEasyViewFollowManager
        medtrumEasyViewFollowManager = MedtrumEasyViewFollowManager(coreDataManager: coreDataManager, followerDelegate: self)

        // setup loop follow manager
        loopFollowManager = LoopFollowManager(coreDataManager: coreDataManager, followerDelegate: self)
        
        // setup healthkitmanager
        healthKitManager = HealthKitManager(coreDataManager: coreDataManager)
        
        // setup bgPostProcessingManager
        bgPostProcessingManager = BgPostProcessingManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager, healthKitManager: healthKitManager)

        // setup sensor noise manager and refresh persisted values for the current algorithm version
        sensorNoiseManager = SensorNoiseManager(coreDataManager: coreDataManager, bgReadingsAccessor: bgReadingsAccessor)
        sensorNoiseManager?.update(activeSensor: activeSensor)
        
        // setup bgReadingSpeaker
        bgReadingSpeaker = BGReadingSpeaker(sharedSoundPlayer: soundPlayer, coreDataManager: coreDataManager)
        
        // Some App Store builds cannot support the OS-AID shared app group, so do not start
        // LoopManager and reset any persisted selection from an earlier build.
        if Bundle.main.disableLoopShare {
            UserDefaults.standard.loopShareType = .disabled
        } else {
            // setup loopManager
            loopManager = LoopManager(
                coreDataManager: coreDataManager,
                activeSensorIsAnubisProvider: { [weak self] in
                    self?.bluetoothPeripheralManager?.getCGMTransmitter()?.isAnubisG6() ?? false
                }
            )
        }
        
        // setup dexcomShareUploadManager
        dexcomShareUploadManager = DexcomShareUploadManager(bgReadingsAccessor: bgReadingsAccessor, messageHandler: { (title:String, message:String) in
            self.presentAlert(title: title, message: message)
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
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                }
                
                // check if nonFixedSlopeEnabled changed and if yes stop the sensor
                if let nonFixedSlopeEnabled = self.nonFixedSlopeEnabled, nonFixedSlopeEnabled != cgmTransmitter.isNonFixedSlopeEnabled() {
                    trace("in cgmTransmitterInfoChanged, nonFixedSlopeEnabled value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.isNonFixedSlopeEnabled().description)
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                }
                
                // check if cgmTransmitterType has changed, if yes reset transmitterBatteryInfo
                if let currentTransmitterType = UserDefaults.standard.cgmTransmitterType, currentTransmitterType != cgmTransmitter.cgmTransmitterType() {
                    UserDefaults.standard.transmitterBatteryInfo = nil
                }
                
                // check if the type of sensor supported by the cgmTransmitterType  has changed, if yes stop the sensor
                if let currentTransmitterType = UserDefaults.standard.cgmTransmitterType, currentTransmitterType.sensorType() != cgmTransmitter.cgmTransmitterType().sensorType() {
                    trace("in cgmTransmitterInfoChanged, sensorType value changed to %{public}@, will stop the sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info, cgmTransmitter.cgmTransmitterType().sensorType().rawValue)
                    
                    self.stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
                }
                
                // assign the new value of webOOPEnabled
                self.webOOPEnabled = cgmTransmitter.isWebOOPEnabled()
                
                // assign the new value of nonFixedSlopeEnabled
                self.nonFixedSlopeEnabled = cgmTransmitter.isNonFixedSlopeEnabled()
                
                // change value of UserDefaults.standard.transmitterTypeAsString
                UserDefaults.standard.cgmTransmitterTypeAsString = cgmTransmitter.cgmTransmitterType().rawValue
                
                // Algorithm and transmitter identity changes can alter whether
                // BG adjustment is still allowed for the active master source.
                self.bgPostProcessingManager?.refreshSourceContext()
            }
            
        }
        
        // setup bluetoothPeripheralManager
        bluetoothPeripheralManager = BluetoothPeripheralManager(coreDataManager: coreDataManager, cgmTransmitterDelegate: self, messageHandler: { title, message in
            self.presentAlert(title: title, message: message)
        }, heartBeatFunction: {
            self.loopFollowManager?.getReading()
            self.nightscoutFollowManager?.download()
            self.libreLinkUpFollowManager?.download()
            self.dexcomShareFollowManager?.download()
            self.medtrumEasyViewFollowManager?.download()
        }, cgmTransmitterInfoChanged: cgmTransmitterInfoChanged)
        
        // to initialize UserDefaults.standard.transmitterTypeAsString
        cgmTransmitterInfoChanged()
        
        // setup alertmanager
        alertManager = AlertManager(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        
        // setup calendarManager
        calendarManager = CalendarManager(coreDataManager: coreDataManager)
        
        // setup contactImageManager
        contactImageManager = ContactImageManager(coreDataManager: coreDataManager)
        
        // initialize statisticsManager
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager)
        
        // initialize watchManager
        watchManager = WatchManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager!)
        
    }

    /// TEMPORARY MIGRATION: remove this function and its UserDefaults flag after the reduced
    /// snooze-duration options have shipped for a couple of versions.
    ///
    /// Existing AlertType records may contain a duration that the consolidated picker no longer
    /// offers. Each unsupported value is rounded down to the nearest supported duration so an
    /// upgrade never silently lengthens an alarm's configured snooze. Values below the new
    /// 15-minute minimum are clamped to 15 minutes because no lower supported option exists.
    private func migrateStoredAlertSnoozePeriodsToReducedOptionsIfNeeded(coreDataManager: CoreDataManager) {
        let userDefaults = UserDefaults.standard
        guard !userDefaults.didMigrateAlertSnoozePeriodsToReducedOptions else { return }

        let supportedDurations = ConstantsAlerts.snoozeValueMinutes
        guard let minimumDuration = supportedDurations.first else { return }

        let context = coreDataManager.mainManagedObjectContext
        var migrationSucceeded = false
        var migratedCount = 0

        context.performAndWait {
            do {
                let alertTypes: [AlertType] = try context.fetch(AlertType.fetchRequest())

                for alertType in alertTypes {
                    let storedDuration = Int(alertType.snoozeperiod)
                    guard !supportedDurations.contains(storedDuration) else { continue }

                    let migratedDuration = supportedDurations.last(where: { $0 <= storedDuration }) ?? minimumDuration
                    alertType.snoozeperiod = Int16(migratedDuration)
                    migratedCount += 1
                }

                if context.hasChanges {
                    try context.save()
                }

                migrationSucceeded = true
            } catch {
                trace(
                    "in migrateStoredAlertSnoozePeriodsToReducedOptionsIfNeeded, migration failed: %{public}@",
                    log: log,
                    category: ConstantsLog.categoryRootView,
                    type: .error,
                    error.localizedDescription
                )
            }
        }

        guard migrationSucceeded else { return }

        userDefaults.didMigrateAlertSnoozePeriodsToReducedOptions = true
        trace(
            "in migrateStoredAlertSnoozePeriodsToReducedOptionsIfNeeded, migrated %{public}d alert snooze periods",
            log: log,
            category: ConstantsLog.categoryRootView,
            type: .info,
            migratedCount
        )
    }
    
    /// process new glucose data received from transmitter.
    /// - parameters:
    ///     - glucoseData : array with new readings
    ///     - sensorAge : should be present only if it's the first reading(s) being processed for a specific sensor and is needed if it's a transmitterType that returns true to the function canDetectNewSensor
    private func processNewGlucoseData(glucoseData: inout [GlucoseData], sensorAge: TimeInterval?) {
        // unwrap calibrationsAccessor and coreDataManager and cgmTransmitter
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = coreDataManager, let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter() else {
            trace("in processNewGlucoseData, calibrationsAccessor or coreDataManager or cgmTransmitter is nil", log: log, category: ConstantsLog.categoryRootView, type: .error)
            return
        }
        
        if activeSensor == nil {
            if let sensorAge = sensorAge, cgmTransmitter.cgmTransmitterType().canDetectNewSensor() {
                // no need to send to transmitter, because we received processNewGlucoseData, so transmitter knows the sensor already
                self.startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: Date(timeIntervalSinceNow: -sensorAge), sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: false)
            }
        }
        
        guard glucoseData.count > 0 else {
            trace("in processNewGlucoseData, glucoseData.count = 0", log: log, category: ConstantsLog.categoryRootView, type: .info)
            return
        }
        
        // also for cases where calibration is not needed, we go through this code
        if let activeSensor = activeSensor, let calibrator = calibrator, let bgReadingsAccessor = bgReadingsAccessor {
            trace("in processNewGlucoseData, calibrator = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, calibrator.description())
            
            // initialize help variables
            var lastCalibrationsForActiveSensorInLastXDays = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
            let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor)
            let lastCalibrationForActiveSensor = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            
            /// used if loopdelay > 0, to check if there was a recent calibration. If so then no readings are added in glucoseData array for a period of loopdelay + an amount of minutes
            let timeStampLastCalibrationForActiveSensor = lastCalibrationForActiveSensor != nil ? lastCalibrationForActiveSensor!.timeStamp : Date(timeIntervalSince1970: 0)
            
            // was a new reading created or not ?
            var newReadingCreated = false
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            if let lastReading = bgReadingsAccessor.last(forSensor: nil, includingSuppressed: true) {
                timeStampLastBgReading = lastReading.timeStamp
            }
            
            let duplicateReadingWindow = TimeInterval(minutes: 2.5)
            let oldestIncomingTimeStamp = glucoseData.map { $0.timeStamp }.min()
            let newestIncomingTimeStamp = glucoseData.map { $0.timeStamp }.max()
            var existingBgReadingsInIncomingRange = [BgReading]()
            
            if let oldestIncomingTimeStamp = oldestIncomingTimeStamp, let newestIncomingTimeStamp = newestIncomingTimeStamp {
                existingBgReadingsInIncomingRange = bgReadingsAccessor.getBgReadings(from: oldestIncomingTimeStamp.addingTimeInterval(-duplicateReadingWindow), to: newestIncomingTimeStamp.addingTimeInterval(duplicateReadingWindow), on: coreDataManager.mainManagedObjectContext, includingSuppressed: true)
            }
            
            /// in case loopdelay > 0, this will be used to share with Loop
            /// - it will contain the full range off per minute readings (in stead of filtered by 5 minutes
            /// - reset to empty array
            if let loopManager = loopManager {
                loopManager.glucoseData = [GlucoseData]()
            }
            
            // initialize latest3BgReadings
            var latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false, includingSuppressed: true)
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, we need to start with the oldest
            for (index, glucose) in glucoseData.enumerated().reversed() {
                // we only add new glucose values if 5 minutes - 10 seconds younger than latest already existing reading, or, if it's the latest, it needs to be just younger
                let checktimestamp = Date(timeInterval: 5.0 * 60.0 - 10.0, since: timeStampLastBgReading)
                let existingReadingInSameSlot = existingBgReadingsInIncomingRange.contains { abs($0.timeStamp.timeIntervalSince(glucose.timeStamp)) <= duplicateReadingWindow }
                
                // Backfill can arrive after a newer live reading has already been stored.
                // Accept older samples only when they fill an empty 5-minute slot.
                let isHistoricalGapFill = glucose.timeStamp <= checktimestamp && !existingReadingInSameSlot
                
                // timestamp of glucose being processed must be higher (ie more recent) than checktimestamp except if it's the last one (ie the first in the array), because there we don't care if it's less than 5 minutes different with the last but one
                // adding 10 seconds to timeStampLastBgReading to handle case of G7, with backfills, because the array contains two times the same reading with a timestamp difference of a few seconds
                if (glucose.timeStamp > checktimestamp || ((index == 0) && (glucose.timeStamp > timeStampLastBgReading.addingTimeInterval(10))) || isHistoricalGapFill) {
                    // check on glucoseLevelRaw > 0 because I've had a case where a faulty sensor was giving negative values
                    if glucose.glucoseLevelRaw > 0 {
                        var last3ReadingsForNewReading = latest3BgReadings
                        
                        if isHistoricalGapFill {
                            last3ReadingsForNewReading = Array(existingBgReadingsInIncomingRange.filter { $0.timeStamp < glucose.timeStamp }.reversed().prefix(3))
                        }
                        
                        let newReading = calibrator.createNewBgReading(rawData: glucose.glucoseLevelRaw, timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &last3ReadingsForNewReading, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: self.getCGMTransmitterDeviceName(for: cgmTransmitter), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

                        if let backfilledAt = glucose.backfilledAt ?? (isHistoricalGapFill ? Date() : nil),
                           backfilledAt.timeIntervalSince(glucose.timeStamp) > ConstantsBloodGlucose.minimumSecondsToConsiderAsBackfillDelay {
                            newReading.backfilledAt = backfilledAt
                        }
                        
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            trace("in processNewGlucoseData, new reading created, timestamp = %{public}@, calculatedValue = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, newReading.timeStamp.description(with: .current), newReading.calculatedValue.description.replacingOccurrences(of: ".", with: ","))
                        }
                        
                        // save the newly created bgreading permenantly in coredata
                        coreDataManager.saveChanges()
                        
                        // a new reading was created
                        newReadingCreated = true
                        
                        // set timeStampLastBgReading to new timestamp
                        if glucose.timeStamp > timeStampLastBgReading {
                            timeStampLastBgReading = glucose.timeStamp
                        }
                        
                        existingBgReadingsInIncomingRange.append(newReading)
                        existingBgReadingsInIncomingRange.sort { $0.timeStamp < $1.timeStamp }
                        
                        // reset latest3BgReadings
                        latest3BgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: false, includingSuppressed: true)
                        
                        if let loopManager = loopManager, LoopManager.loopDelay() > 0 && abs(Date().timeIntervalSince(timeStampLastCalibrationForActiveSensor)) > LoopManager.loopDelay() + TimeInterval(minutes: 5.5) {
                            loopManager.glucoseData.insert(GlucoseData(timeStamp: newReading.timeStamp, glucoseLevelRaw: round(newReading.finalValue), slopeOrdinal: newReading.slopeOrdinal(), slopeName: newReading.slopeName), at: 0)
                        }
                    } else {
                        trace("in processNewGlucoseData, reading skipped, rawValue <= 0, looks like a faulty sensor", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                    }
                } else if let loopManager = loopManager, LoopManager.loopDelay() > 0 && glucose.glucoseLevelRaw > 0 && abs(Date().timeIntervalSince(timeStampLastCalibrationForActiveSensor)) >  LoopManager.loopDelay() + TimeInterval(minutes: 5.5) {
                    // loopdelay > 0, LoopManager will use loopShareGoucoseData
                    // create a reading just to be able to fill up loopShareGoucoseData, to have them per minute
                    
                    let newReading = calibrator.createNewBgReading(rawData: glucose.glucoseLevelRaw, timeStamp: glucose.timeStamp, sensor: activeSensor, last3Readings: &latest3BgReadings, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibrationForActiveSensor, lastCalibration: lastCalibrationForActiveSensor, deviceName: self.getCGMTransmitterDeviceName(for: cgmTransmitter), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                    
                    loopManager.glucoseData.insert(GlucoseData(timeStamp: newReading.timeStamp, glucoseLevelRaw: round(newReading.finalValue), slopeOrdinal: newReading.slopeOrdinal(), slopeName: newReading.slopeName), at: 0)
                    
                    // delete the newReading, otherwise it stays in coredata and we would end up with per minute readings
                    coreDataManager.mainManagedObjectContext.delete(newReading)
                }
            }
            
            // if a new reading is created, create either initial calibration request or bgreading notification - upload to nightscout and check alerts
            if newReadingCreated {
                _ = bgPostProcessingManager?.processLatestReadings()
                sensorNoiseManager?.update(activeSensor: activeSensor)

                // Publish the final stored value before optional downstream consumers perform their work.
                updateLiveActivityAndWidgets(forceRestart: false)
                
                // only if no webOOPEnabled and overruleIsWebOOPEnabled false : if no two calibration exist yet then create calibration request notification, otherwise a bgreading notification and update labels
                if firstCalibrationForActiveSensor == nil && lastCalibrationForActiveSensor == nil && (!cgmTransmitter.isWebOOPEnabled() && !cgmTransmitter.overruleIsWebOOPEnabled()) {
                    // there must be at least 2 readings
                    let latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true, includingSuppressed: true)
                    
                    if latestReadings.count > 1 {
                        trace("in processNewGlucoseData, calibration : two readings received, no calibrations exist yet and not web oopenabled, request calibation to user", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                        
                        createInitialCalibrationRequest()
                    }
                } else {
                    // check alerts, create notification, set app badge
                    checkAlertsCreateNotificationAndSetAppBadge()
                    rootHomeStateModel.invalidateCharts()
                    
                    // update all text in  first screen
                    updateLabelsAndChart(overrideApplicationState: false)
                    
                    updatePumpAndAIDStatusViews()
                    
                    // update mini-chart
                    updateMiniChart()
                    
                    // update statistics related outlets
                    updateStatistics(animate: false)
                    
                    // update data source info
                    updateDataSourceInfo()
                }
                
                // Always run the normal latest-reading Nightscout upload path.
                // If post processing is also rewriting a recent BG tail, the
                // sync manager serializes the overlap and runs this direct
                // upload immediately afterwards.
                nightscoutSyncManager?.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                nightscoutSyncManager?.syncAllWithNightscout()
                
                healthKitManager?.storeBgReadings()
                
                bgReadingSpeaker?.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                dexcomShareUploadManager?.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                calendarManager?.processNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                contactImageManager?.processNewReading()
                
                loopManager?.share()
                
                watchManager?.updateWatchApp(forceComplicationUpdate: false)
            }
        }
    }
    
    /// closes the SwiftUI snooze screen if it is currently visible
    private func closeSnoozeScreen() {
        rootTabStateModel?.dismissSnooze()
    }
    
    /// used by observevalue for UserDefaults.KeysCharts
    private func evaluateUserDefaultsChange(keyPathEnumCharts: UserDefaults.KeysCharts) {
        // first check keyValueObserverTimeKeeper
        switch keyPathEnumCharts {
        case UserDefaults.KeysCharts.chartWidthInHours :
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnumCharts.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
        }
        
        switch keyPathEnumCharts {
        case UserDefaults.KeysCharts.chartWidthInHours:
            publishRootHomeState()
        }
    }
    
    /// used by observevalue for UserDefaults.Key
    private func evaluateUserDefaultsChange(keyPathEnum: UserDefaults.Key) {
        // first check keyValueObserverTimeKeeper
        switch keyPathEnum {
        case UserDefaults.Key.isMaster, UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.followerBackgroundKeepAliveType, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.daysToUseStatistics, UserDefaults.Key.showMiniChart, UserDefaults.Key.activeSensorStartDate :
            // transmittertype change triggered by user, should not be done within 200 ms
            if !keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                return
            }
            
        default:
            break
        }
        
        switch keyPathEnum {
        case UserDefaults.Key.isMaster:
            changeButtonsStatusTo(enabled: UserDefaults.standard.isMaster)
            bgPostProcessingManager?.refreshSourceContext()
            
            guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() else {break}
            
            // need to check this in order to disable live activities in follower mode
            updateLiveActivityAndWidgets(forceRestart: false)
            
            // no sensor needed in follower mode, stop it
            stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: false)
            
        case UserDefaults.Key.showReadingInNotification:
            if !UserDefaults.standard.showReadingInNotification {
                // remove existing notification if any
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ConstantsNotifications.NotificationIdentifierForBgReading.bgReadingNotificationRequest])
            }
            
        case UserDefaults.Key.multipleAppBadgeValueWith10, UserDefaults.Key.showReadingInAppBadge, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.followerBackgroundKeepAliveType:
            // if showReadingInAppBadge = false, means user set it from true to false
            // set the app badge to 0. This will cause removal of the badge counter, but also removal of any existing notification on the screen
            if !UserDefaults.standard.showReadingInAppBadge || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled) {
                // applicationIconBadgeNumber has been deprecated for iOS17 but as we currently have a minimum deployment target of iOS15, let's add a conditional check
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
            
            // make sure that any pending (i.e. already scheduled in the future) missed reading notifications are removed
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ConstantsNotifications.NotificationIdentifiersForAlerts.missedReadingAlert])
            }
            
            // also update Watch App with the new values. (Only really needed for unit change between mg/dl and mmol/l)
            watchManager?.updateWatchApp(forceComplicationUpdate: false)
            
            // this will trigger update of app badge, will also create notification, but as app is most likely in foreground, this won't show up
            createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            
            updateLiveActivityAndWidgets(forceRestart: false)
            
        case UserDefaults.Key.liveActivityType, UserDefaults.Key.allowStandByHighContrast, UserDefaults.Key.forceStandByBigNumbers:
            // check and configure the live activity and widgets if applicable
            updateLiveActivityAndWidgets(forceRestart: false)
            
        case UserDefaults.Key.nightscoutFollowType:
            // check and configure the live activity if applicable
            updateLiveActivityAndWidgets(forceRestart: false)
            
            watchManager?.updateWatchApp(forceComplicationUpdate: false)
            
        case UserDefaults.Key.urgentLowMarkValue, UserDefaults.Key.lowMarkValue, UserDefaults.Key.highMarkValue, UserDefaults.Key.urgentHighMarkValue, UserDefaults.Key.nightscoutTreatmentsUpdateCounter:
            // redraw chart is necessary
            updateChartWithResetEndDate()
            
            // redraw mini-chart
            updateMiniChart()
            
            // update Watch App with the new objective values
            watchManager?.updateWatchApp(forceComplicationUpdate: false)
            
            updateLiveActivityAndWidgets(forceRestart: false)
            
        case UserDefaults.Key.showMiniChart:
            publishRootHomeState()
            
        case UserDefaults.Key.miniChartHoursToShow:
            // redraw mini-chart
            updateMiniChart()
            
        case UserDefaults.Key.daysToUseStatistics, UserDefaults.Key.showStatistics:
            updateStatistics(animate: false, overrideApplicationState: false)
            
        case UserDefaults.Key.showTreatmentsOnChart:
            updateChartWithResetEndDate()

        case UserDefaults.Key.showOriginalBGReadings:
            rootHomeStateModel.invalidateCharts()

        case UserDefaults.Key.showSensorNoiseOnChart:
            updateChartWithResetEndDate()

        case UserDefaults.Key.sensorNoiseSensitivity:
            publishRootHomeState()
            updateChartWithResetEndDate()

        case UserDefaults.Key.showClockWhenScreenIsLocked:
            // refresh screenLock function if it is currently activated in order to show/hide the clock as requested
            if screenIsLocked {
                screenLockUpdate(enabled: true)
            }
            
        case UserDefaults.Key.stopActiveSensor:
            // if stopActiveSensor wasn't changed to true then no further processing
            if UserDefaults.standard.stopActiveSensor {
                sensorStopDetected()
                UserDefaults.standard.activeSensorStartDate = nil
                updateDataSourceInfo()
                UserDefaults.standard.stopActiveSensor = false
            }
            
        case UserDefaults.Key.timeStampOfLastHeartBeat:
            updateDataSourceInfo()
            
        case UserDefaults.Key.updateSnoozeStatus:
            updateSnoozeStatus()
            
        case UserDefaults.Key.enableAdjustment, UserDefaults.Key.enableSmoothing:
            updatePostProcessingStatus()
            
        case UserDefaults.Key.followerDataSourceType,
             UserDefaults.Key.nightscoutUrl,
             UserDefaults.Key.nightscoutToken,
             UserDefaults.Key.nightscoutAPIKey,
             UserDefaults.Key.libreLinkUpEmail,
             UserDefaults.Key.libreLinkUpPassword,
             UserDefaults.Key.followerPatientName,
             UserDefaults.Key.dexcomShareAccountName,
             UserDefaults.Key.dexcomSharePassword,
             UserDefaults.Key.medtrumEasyViewEmail,
             UserDefaults.Key.medtrumEasyViewPassword,
             UserDefaults.Key.medtrumEasyViewSelectedPatientUid:
            bgPostProcessingManager?.refreshSourceContext()
            
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
    
    // MARK: - SwiftUI Home Actions

    private func presentAlert(
        title: String,
        message: String,
        action: @escaping () -> Void = {}
    ) {
        rootTabStateModel?.presentAlert(title: title, message: message, action: action)
    }

    private func presentPicker(_ pickerViewData: PickerViewData) {
        rootTabStateModel?.presentPicker(pickerViewData)
    }

    private func makeRootHomeActions() -> RootHomeActions {
        RootHomeActions(
            originalGlucosePeekActivated: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            },
            toggleExpandedAIDInfo: { [weak self] in
                guard UserDefaults.standard.nightscoutFollowType != .none else { return }

                UserDefaults.standard.nightscoutFollowShowExpandedInfo.toggle()
                self?.updatePumpAndAIDStatusViews()
            },
            refreshPumpAndLoopStatus: { [weak self] in
                self?.publishRootHomeState()
            },
            statisticsDaysChanged: { [weak self] days in
                self?.setStatisticsDaysFromRootHome(days)
            },
            cycleStatisticsType: { [weak self] in
                self?.cycleTimeInRangeTypeFromRootHome()
            },
            hideFollowerUrl: { [weak self] in
                self?.rootHomeStateModel.hideFollowerURL()
            }
        )
    }

    private func setStatisticsDaysFromRootHome(_ days: Int) {
        UserDefaults.standard.daysToUseStatistics = days

        updateStatistics(animate: false, overrideApplicationState: false)
        publishRootHomeState()
    }

    private func cycleTimeInRangeTypeFromRootHome() {
        let previousTimeInRangeType = UserDefaults.standard.timeInRangeType

        if previousTimeInRangeType == TimeInRangeType.allCases.last {
            UserDefaults.standard.timeInRangeType = .standardRange
        } else {
            UserDefaults.standard.timeInRangeType = TimeInRangeType(rawValue: previousTimeInRangeType.rawValue + 1) ?? .tightRange
        }

        updateStatistics(animate: false, overrideApplicationState: false)
        publishRootHomeState()
    }

    private func publishRootHomeState() {
        guard hasStarted else { return }

        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.publishRootHomeState()
            }

            return
        }

        rootHomeStateModel.refresh(
            activeSensor: activeSensor,
            isScreenLocked: screenIsLocked,
            usesScreenLockNightLayout: screenLockUsesNightLayout
        )
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
    /// - parameters:
    private func updateChartWithResetEndDate() {
        rootHomeStateModel.resetChartsToNow()
    }

    /// switch the main chart between the normal post processed view and a
    /// temporary original-only view while the adjustments button is held down
    private func setShowOriginalGlucoseChartPointsOnly(_ showOriginalGlucoseChartPointsOnly: Bool) {
        rootHomeStateModel.invalidateCharts()
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
        
        // call scheduleUpdateLabelsAndChartTimer function now so that it starts immediately after app launch
        updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()
        
        // updateLabelsAndChartTimer needs to be created when app comes back from background to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyCreateupdateLabelsAndChartTimer, closure: {
            updateLabelsAndChartTimer = createAndScheduleUpdateLabelsAndChartTimer()
            
            // reset the chart when coming to the foreground if the user has selected that option
            // if they hadn't selected, then just refresh anyway because it seems to prevent the "empty chart" that sometimes happens
            self.updateLabelsAndChart(overrideApplicationState: true, forceReset: UserDefaults.standard.allowMainChartAutoReset)
        })
        
        // when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyInvalidateupdateLabelsAndChartTimerAndCloseSnoozeScreen, closure: {
            // If the snooze screen is visible when the app backgrounds, close it so
            // the alert snooze picker can still be shown when the app reopens.
            self.closeSnoozeScreen()
            
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
            
            presentAlert(title: Texts_HomeView.info, message: Texts_HomeView.theresNoCGMTransmitterActive)
            
            return
        }
        
        // check if sensor active and if not don't continue
        guard let activeSensor = activeSensor else {
            trace("in requestCalibration, there is no active sensor, no further processing", log: log, category: ConstantsLog.categoryRootView, type: .info)
            
            presentAlert(title: Texts_HomeView.info, message: Texts_HomeView.startSensorBeforeCalibration)
            
            return
        }
        
        // if it's a user requested calibration, but there's no calibration yet, then give info and return - first calibration will be requested by app via notification
        // cgmTransmitter.overruleIsWebOOPEnabled() : that means it's a transmitter that gives calibrated values (ie doesn't need to be calibrated) but it can use calibration
        if calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) == nil && userRequested && !cgmTransmitter.overruleIsWebOOPEnabled() {
            presentAlert(title: Texts_HomeView.info, message: Texts_HomeView.thereMustBeAreadingBeforeCalibration)
            
            return
        }
        
        // assign deviceName, needed in the closure when creating alert. As closures can create strong references (to bluetoothTransmitter in this case), I'm fetching the deviceName here
        let deviceName = bluetoothTransmitter.deviceName
        
        rootTabStateModel?.presentTextInput(
            title: Texts_Calibrations.enterCalibrationValue,
            placeholder: "...",
            usesDecimalKeyboard: !UserDefaults.standard.bloodGlucoseUnitIsMgDl
        ) { text in
            guard let valueAsDouble = text.toDouble() else {
                self.presentAlert(title: Texts_Common.warning, message: Texts_Common.invalidValue)
                return
            }

            if let errorMessage = self.submitCalibrationValue(
                valueAsDouble,
                calibrationsAccessor: calibrationsAccessor,
                coreDataManager: coreDataManager,
                bgReadingsAccessor: bgReadingsAccessor,
                cgmTransmitter: cgmTransmitter,
                activeSensor: activeSensor,
                deviceName: deviceName
            ) {
                self.presentAlert(title: Texts_Common.warning, message: errorMessage)
            }
        }
    }

    private func submitCalibrationValue(
        _ valueAsDouble: Double,
        calibrationsAccessor: CalibrationsAccessor,
        coreDataManager: CoreDataManager,
        bgReadingsAccessor: BgReadingsAccessor,
        cgmTransmitter: CGMTransmitter,
        activeSensor: Sensor,
        deviceName: String?
    ) -> String? {
        trace("calibration : value %{public}@ entered by user", log: self.log, category: ConstantsLog.categoryRootView, type: .info, valueAsDouble.description)

        let valueAsDoubleConvertedToMgDl = valueAsDouble.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        var latestReadings = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true, includingSuppressed: true)
        var latestCalibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)

        guard let calibrator = self.calibrator else {
            return Texts_HomeView.sensorManagementCalibrationUnavailable
        }

        if latestCalibrations.count == 0 {
            trace("calibration : initial calibration, creating two calibrations", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            let (calibration, _) = calibrator.initialCalibration(firstCalibrationBgValue: valueAsDoubleConvertedToMgDl, firstCalibrationTimeStamp: Date(timeInterval: -(5*60), since: Date()), secondCalibrationBgValue: valueAsDoubleConvertedToMgDl, sensor: activeSensor, lastBgReadingsWithCalculatedValue0AndForSensor: &latestReadings, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

            if let calibration = calibration {
                cgmTransmitter.calibrate(calibration: calibration)
                self.alertManager?.snooze(alertKind: .fastdrop, snoozePeriodInMinutes: 9, response: nil)
                self.alertManager?.snooze(alertKind: .fastrise, snoozePeriodInMinutes: 9, response: nil)
            }
        } else if let firstCalibrationForActiveSensor = calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) {
            trace("calibration : creating calibration", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            if let calibration = calibrator.createNewCalibration(bgValue: valueAsDoubleConvertedToMgDl, lastBgReading: latestReadings.count > 0 ? latestReadings[0] : nil, sensor: activeSensor, lastCalibrationsForActiveSensorInLastXDays: &latestCalibrations, firstCalibration: firstCalibrationForActiveSensor, deviceName: deviceName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext) {
                cgmTransmitter.calibrate(calibration: calibration)
                self.alertManager?.snooze(alertKind: .fastdrop, snoozePeriodInMinutes: 9, response: nil)
                self.alertManager?.snooze(alertKind: .fastrise, snoozePeriodInMinutes: 9, response: nil)
            }
        }

        coreDataManager.saveChanges()
        sensorNoiseManager?.update(activeSensor: activeSensor)

        if let nightscoutSyncManager = self.nightscoutSyncManager {
            nightscoutSyncManager.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
        }

        if let dexcomShareUploadManager = self.dexcomShareUploadManager {
            dexcomShareUploadManager.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
        }

        self.updateLabelsAndChart(overrideApplicationState: false)
        self.bluetoothPeripheralManager?.sendLatestReading()
        self.calendarManager?.processNewReading(lastConnectionStatusChangeTimeStamp: self.lastConnectionStatusChangeTimeStamp())
        self.loopManager?.share()

        return nil
    }
    
    /// this is just some functionality which is used frequently
    private func getCalibrator(cgmTransmitter: CGMTransmitter) -> Calibrator {
        let cgmTransmitterType = cgmTransmitter.cgmTransmitterType()
        
        // initialize return value
        var calibrator: Calibrator = NoCalibrator()
        
        switch cgmTransmitterType {            
        case .dexcom:
            if cgmTransmitter.isWebOOPEnabled() {
                // received values are already calibrated
                calibrator = NoCalibrator()
            } else if cgmTransmitter.isNonFixedSlopeEnabled() {
                // no oop web, fixed slope
                // should not occur, because Dexcom should have nonFixedSlopeEnabled false
                //  if true for dexcom, then someone has set this to true but didn't create a non-fixed slope calibrator
                fatalError("cgmTransmitter.isNonFixedSlopeEnabled returns true for dexcom but there's no NonFixedSlopeCalibrator for Dexcom")
            } else {
                // no oop web, no fixed slope
                calibrator = DexcomCalibrator()
            }
            
        case .dexcomG7:
            // received values are already calibrated
            calibrator = NoCalibrator()
            
        case .miaomiao, .Bubble, .Libre2:
            if cgmTransmitter.isWebOOPEnabled() {
                // received values are already calibrated
                calibrator = NoCalibrator()
            } else if cgmTransmitter.isNonFixedSlopeEnabled() {
                // no oop web, non-fixed slope
                return Libre1NonFixedSlopeCalibrator()
            } else {
                // no oop web, fixed slope
                calibrator = Libre1Calibrator()
            }

        case .medtrumTouchCareNano:
            // Values arrive already calibrated to mg/dL — the transmitter applies the Medtrum per-sensor
            // calibration factor decoded from each packet, so xDrip should not run its own calibrator.
            calibrator = NoCalibrator()

        }
        
        trace("in getCalibrator, calibrator = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, calibrator.description())
        
        return calibrator
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
        guard let bgReadingsAccessor = bgReadingsAccessor else { return }
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
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
        var readingValueForBadge = lastReading[0].finalValue
        // values lower dan 12 are special values, don't show anything
        guard readingValueForBadge > 12 else { return }
        // high limit to 400
        if readingValueForBadge >= 400.0 { readingValueForBadge = 400.0 }
        // low limit to 40
        if readingValueForBadge <= 40.0 { readingValueForBadge = 40.0 }
        
        // check if notification on home screen is enabled in the settings
        // and also if last notification was long enough ago (longer than UserDefaults.standard.notificationInterval), except if there would have been a disconnect since previous notification (simply because I like getting a new reading with a notification by disabling/reenabling bluetooth
        if UserDefaults.standard.showReadingInNotification && !overrideShowReadingInNotification && (abs(timeStampLastBGNotification.timeIntervalSince(Date())) > Double(UserDefaults.standard.notificationInterval) * 60.0) {
            // Create Notification Content
            let notificationContent = UNMutableNotificationContent()
            
            // set value in badge if required and also only if master, or when background keep alive is enabled for followers
            if UserDefaults.standard.showReadingInAppBadge && (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster &&  UserDefaults.standard.followerBackgroundKeepAliveType != .disabled)) {
                
                // rescale if unit is mmol
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                    readingValueForBadge = readingValueForBadge.mgDlToMmol().round(toDecimalPlaces: 1)
                } else {
                    readingValueForBadge = readingValueForBadge.round(toDecimalPlaces: 0)
                }
                
                notificationContent.badge = NSNumber(value: readingValueForBadge.rawValue)
            }
            
            // Configure notificationContent title, which is bg value in correct unit, add also slopeArrow if !hideSlope and finally the difference with previous reading, if there is one
            var calculatedValueAsString = lastReading[0].unitizedString(unitIsMgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            
            if !lastReading[0].hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading[0].slopeArrow()
            }
            
            if lastReading.count > 1 {
                //calculatedValueAsString = calculatedValueAsString // + "      " + lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: true, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                
                notificationContent.body = lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: true, highGranularity: true, mgDl: isMgDl)
            } else {
                // must set a body otherwise notification doesn't show up on iOS10
                notificationContent.body = " "
            }
            
            notificationContent.title = calculatedValueAsString
            
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
            
        } else {
            // notification shouldn't be shown, but maybe the badge counter. Here the badge value needs to be shown in another way and also only if master, or when background keep alive is enabled for followers
            
            if UserDefaults.standard.showReadingInAppBadge && (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType != .disabled)) {
                
                // rescale of unit is mmol
                readingValueForBadge = readingValueForBadge.mgDlToMmol(mgDl: isMgDl)
                
                // if unit is mmol and if value needs to be multiplied by 10, then multiply by 10
                if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.multipleAppBadgeValueWith10 {
                    readingValueForBadge = readingValueForBadge * 10.0
                }
                
                UIApplication.shared.applicationIconBadgeNumber = Int(round(readingValueForBadge))
            }
        }
    }
    
    @objc private func handleBgPostProcessingDidUpdate() {
        updateLabelsAndChart(overrideApplicationState: true, forceReset: true)
        updatePostProcessingStatus()
        watchManager?.updateWatchApp(forceComplicationUpdate: true)
        updateLiveActivityAndWidgets(forceRestart: false)
    }
    
    /// - updates the labels and the chart
    /// - but only if the chart is not panned backward
    /// - and if app is in foreground
    /// - and if overrideApplicationState = false
    /// - parameters:
    ///     - overrideApplicationState : if true, then update will be done even if state is not .active
    ///     - forceReset : if true, then force the update to be done even if the main chart is panned back in time (used for the double tap gesture). This will also rescale the chart y-axis.
    @objc private func updateLabelsAndChart(overrideApplicationState: Bool = false, forceReset: Bool = false) {
        setNightscoutSyncRequiredToTrue(forceNow: false)
        
        // this is not really the nicest place to do this, but it works well
        // take advantage of the timer execution to update the AID status views
        updatePumpAndAIDStatusViews()
        
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}

        if forceReset {
            rootHomeStateModel.resetChartsToNow()
        }
        
        // force a snooze status update to see if the current snooze status has changed in the last minutes
        updateSnoozeStatus()
        
        publishRootHomeState()

    }
    
    /// if the user has chosen to show the mini-chart, then update it. If not, just return without doing anything.
    private func updateMiniChart() {
        publishRootHomeState()
    }
    
    private func getCGMTransmitterDeviceName(for cgmTransmitter: CGMTransmitter) -> String? {
        if let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter {
            return bluetoothTransmitter.deviceName
        }
        
        return nil
    }
    
    /// enables or disables the sensor management button on top of the screen
    private func changeButtonsStatusTo(enabled: Bool) {
        publishRootHomeState()
    }
    
    /// call alertManager.checkAlerts, and calls createBgReadingNotificationAndSetAppBadge with overrideShowReadingInNotification true or false, depending if immediate notification was created or not
    private func checkAlertsCreateNotificationAndSetAppBadge() {
        // unwrap alerts and check alerts
        if let alertManager = alertManager {
            createNotificationImages()
            
            // check if an immediate alert went off that shows the current reading
            if alertManager.checkAlerts(maxAgeOfLastBgReadingInSeconds: ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds) {
                // an immediate alert went off that shows the current reading
                
                // possibly the app is in the foreground now
                // if user has the snooze screen open now, then close it, otherwise the alarm picker view will not be shown
                closeSnoozeScreen()
                
                // only update badge is required, (if enabled offcourse)
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: true)
            } else {
                // update notification and app badge
                createBgReadingNotificationAndSetAppBadge(overrideShowReadingInNotification: false)
            }
        }
    }
    
    /// a long function just to get the timestamp of the last disconnect or reconnect. If not known then returns 1 1 1970
    /// - Returns: a timestamp of the last disconnect/reconnect
    private func lastConnectionStatusChangeTimeStamp() -> Date  {
        // this is actually unwrapping of optionals, goal is to get date of last disconnect/reconnect - all optionals should exist so it doesn't matter what is returned true or false
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter, let bluetoothPeripheral = self.bluetoothPeripheralManager?.getBluetoothPeripheral(for: bluetoothTransmitter), let lastConnectionStatusChangeTimeStamp = bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp else {return Date(timeIntervalSince1970: 0)}
        
        return lastConnectionStatusChangeTimeStamp
    }
    
    
    /// helper function to calculate statistics and publish them into the SwiftUI home state
    /// - Parameters:
    ///   - animate: requests animation where the current statistics presentation supports it
    ///   - overrideApplicationState: if true, it will update the statistics even if the app is, for example, in the background
    private func updateStatistics(animate: Bool = false, overrideApplicationState: Bool = false) {
        // don't calculate statis if app is not running in the foreground
        guard UIApplication.shared.applicationState == .active || overrideApplicationState else {return}
        
        defer {
            publishRootHomeState()
        }

        // if the user doesn't want to see the statistics, then just return without doing anything
        if !UserDefaults.standard.showStatistics {
            return
        }
        
        // declare constants/variables
        let daysToUseStatistics = UserDefaults.standard.daysToUseStatistics
        let fromDate: Date
        
        // if the user has selected 0 (to chose "today") then set the fromDate to the previous midnight
        if daysToUseStatistics == 0 {
            fromDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
        } else {
            fromDate = Date(timeIntervalSinceNow: -3600.0 * 24.0 * Double(daysToUseStatistics))
        }

        rootHomeStateModel.setStatisticsLoading()
        statisticsManager?.calculateStatistics(fromDate: fromDate, toDate: nil) { [weak self] statistics in
            self?.rootHomeStateModel.updateStatistics(statistics, days: daysToUseStatistics)
        }
        return
    }
    
    /// swaps status from locked to unlocked or vice versa
    /// - Parameters:
    ///   - overrideCurrentState: if true, then screen will be locked even if it's already locked. If false, then status swaps from locked to unlocked or unlocked to locked
    ///   - nightMode: when true this parameter will be passed to screenLockUpdate and will activate the selected night screen features
    /// - returns: true if screen lock was enabled
    private func updateScreenLock(overrideCurrentState: Bool, nightMode: Bool) -> Bool {
        if !screenIsLocked || overrideCurrentState {
            trace("screen lock : user clicked the lock button or long pressed the value", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            screenLockUpdate(enabled: true, nightMode: nightMode)
            return true
        } else {
            trace("screen lock : user clicked the unlock button", log: self.log, category: ConstantsLog.categoryRootView, type: .info)

            screenLockUpdate(enabled: false, nightMode: nightMode)
            return false
        }
    }
    
    /// this function will run when the user wants the screen to lock, or whenever the view appears and it will set up the screen correctly for each mode
    /// - parameters :
    ///     - enabled : when true this will force the screen to lock
    ///     - nightMode : when false, this will enable a simple screen lock without changing the UI - useful for keeping the screen open on your desk. True will bring the full screen lock changes to the UI
    private func screenLockUpdate(enabled: Bool = true, nightMode: Bool = true) {
        defer {
            publishRootHomeState()
        }

        if enabled {
            screenLockUsesNightLayout = nightMode

            // play "peek" so that user knows that the screen lock has been activated.
            // we use a soft, short vibration so that it isn't too noisy at night when selected.
            AudioServicesPlaySystemSound(1519)

            if nightMode && UserDefaults.standard.showClockWhenScreenIsLocked {
                rootHomeStateModel.updateClock()
            }
            
            // prevent screen dim/lock
            UIApplication.shared.isIdleTimerDisabled = true
            
            // set the private var so that the coordinator can track the screen lock activation state
            screenIsLocked = true
            
            trace("screen lock : screen lock / keep-awake enabled. Night mode set to '%{public}@'. Dimming type set to '%{public}@'", log: self.log, category: ConstantsLog.categoryRootView, type: .info, nightMode.description, UserDefaults.standard.screenLockDimmingType.description)
        } else {
            screenLockUsesNightLayout = false
            
            // make sure that the screen lock is deactivated
            UIApplication.shared.isIdleTimerDisabled = false
            
            trace("screen lock / keep-awake disabled", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
            
            // set the flag to false. This must be done before we update the views
            screenIsLocked = false
            
            updateDataSourceInfo()
            
            updatePumpAndAIDStatusViews()
        }
    }
    
    /// update the label in the clock view every time this function is called
    @objc private func updateClockView() {
        rootHomeStateModel.updateClock()
        publishRootHomeState()
    }
    
    /// update the data source information view and also the sensor progress view (if needed)
    private func updateDataSourceInfo() {
        defer {
            publishRootHomeState()
        }

        // check if there is an active sensor connected via cgmTransmitter in master mode
        // if so, then use this value to override/set the coredata activeSensorStartDate
        if let startDate = activeSensor?.startDate {
            UserDefaults.standard.activeSensorStartDate = startDate
        }
        
        // check if there is a transmitter connected (needed as Dexcom will only connect briefly every 5 minutes)
        // if there is a transmitter connected, pull the current maxSensorAgeInDays and store in in UserDefaults
        if let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let maxDays = cgmTransmitter.maxSensorAgeInDays() {
            UserDefaults.standard.activeSensorMaxSensorAgeInDays = maxDays
            UserDefaults.standard.activeSensorDescription = cgmTransmitter.cgmTransmitterType().detailedDescription()
        }

        // The state model owns all visible sensor and data-source formatting. The controller keeps
        // only the source metadata and follower timer maintenance that other app services use.
        setFollowerConnectionAndHeartbeatStatus()
        return
    }
    
    /// this should be called when the data source view is refreshed or when called by the followerConnectionTimer object
    @objc private func setFollowerConnectionAndHeartbeatStatus() {
        defer {
            publishRootHomeState()
        }

        // if in master mode, hide the connection status and destroy the timer if it was initialized
        // (for example if the user just changed from follower to master)
        if UserDefaults.standard.isMaster {
            if followerConnectionTimer != nil {
                followerConnectionTimer?.invalidate()
                followerConnectionTimer = nil
            }
            
            return
            
        } else {
            // we're in follower mode so if the timer isn't initialized, then let's start it
            if followerConnectionTimer == nil {
                // set a timer instance to update the connection status for follower modes
                followerConnectionTimer = Timer.scheduledTimer(timeInterval: ConstantsFollower.secondsUsedByFollowerConnectionTimer, target: self, selector: #selector(setFollowerConnectionAndHeartbeatStatus), userInfo: nil, repeats: true)
            }
        }
        
        // if the last heartbeat timestamp is newer than 'x' seconds ago, then show a valid heartbeat icon. If not, show the heartbeat as (temporarily) disconnected
        // if not using a heartbeat (or if we fail to get 'x') then just keep the existing defaults
        if UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
            if let bluetoothPeripherals = bluetoothPeripheralManager?.bluetoothPeripherals {
                // loop through all bluetoothPeripherals
                for bluetoothPeripheral in bluetoothPeripherals {
                    // using bluetoothPeripheralType here so that whenever bluetoothPeripheralType is extended with new cases, we don't forget to handle them
                    switch bluetoothPeripheral.bluetoothPeripheralType() {
                    case .Libre3HeartBeatType:
                        UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning = ConstantsHeartBeat.secondsUntilHeartBeatDisconnectWarningLibre3
                    case .DexcomG7HeartBeatType:
                        UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning = ConstantsHeartBeat.secondsUntilHeartBeatDisconnectWarningDexcomG7
                    case .OmniPodHeartBeatType:
                        UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning = ConstantsHeartBeat.secondsUntilHeartBeatDisconnectWarningOmniPod
                    default:
                        break
                    }
                }
            }
        }
    }
    
    
    /// if allowed set the main screen rotation settings
    fileprivate func updateScreenRotationSettings() {
        // if allowed, then permit the SwiftUI Home tab to rotate left/right to show the landscape view
        if UserDefaults.standard.allowScreenRotation {
            AppDelegate.supportedOrientations = .allButUpsideDown
        } else {
            AppDelegate.supportedOrientations = .portrait
        }
    }
    
    /// - creates a new sensor and assigns it to activeSensor
    /// - if sendToTransmitter is true then sends startSensor command to transmitter (ony useful for Firefly)
    /// - saves to coredata
    private func startSensor(cGMTransmitter: CGMTransmitter?, sensorStarDate: Date, sensorCode: String?, coreDataManager: CoreDataManager, sendToTransmitter: Bool) {
        // create active sensor
        let newSensor = Sensor(startDate: sensorStarDate, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        
        bgPostProcessingManager?.handleSourceContextChanged()
        
        // save the newly created Sensor permenantly in coredata
        coreDataManager.saveChanges()
        
        // send to transmitter
        if let cGMTransmitter = cGMTransmitter, sendToTransmitter {
            cGMTransmitter.startSensor(sensorCode: sensorCode, startDate: sensorStarDate)
        }
        
        // update the activeSensorDescription. Needed as otherwise it won't get done for Libre after an algorithm change
        if let cgmTransmitter = cGMTransmitter {
            UserDefaults.standard.activeSensorDescription = cgmTransmitter.cgmTransmitterType().detailedDescription()
        }
        
        // assign activeSensor to newSensor
        activeSensor = newSensor
        sensorNoiseManager?.update(activeSensor: newSensor)
    }
    
    private func stopSensor(cGMTransmitter: CGMTransmitter?, sendToTransmitter: Bool) {
        // create stopDate
        let stopDate = Date()
        
        // send stop sensor command to transmitter, don't check if there's an activeSensor in coredata or not, never know that there's a desync between coredata and transmitter
        if let cGMTransmitter = cGMTransmitter, sendToTransmitter {
            cGMTransmitter.stopSensor(stopDate: stopDate)
        }
        
        // no need to further continue if activeSensor = nil, and at the same time, unwrap coredataManager
        guard let activeSensor = activeSensor, let coreDataManager = coreDataManager else { return }
        
        // set endDate of activeSensor to stopDate
        activeSensor.endDate = stopDate
        
        // nillify all active sensor data in userdefaults. This helps to prevent the sensor view UI from displaying old data.
        UserDefaults.standard.maxSensorAgeInDays = 0
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorDescription = nil
        
        // save changes to coreData
        coreDataManager.saveChanges()
        
        // asign nil to activeSensor
        self.activeSensor = nil
        
        // now that the activeSensor object has been destroyed, update (hide) the data source info
        updateDataSourceInfo()
    }
    
    private func startSensorFromManagementView(startDate: Date, sensorCode: String?) {
        guard let coreDataManager = coreDataManager, let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() else { return }

        startSensor(cGMTransmitter: cgmTransmitter, sensorStarDate: startDate, sensorCode: sensorCode, coreDataManager: coreDataManager, sendToTransmitter: true)
        updateDataSourceInfo()
        updateLabelsAndChart(overrideApplicationState: false)
    }

    private func stopSensorFromManagementView() {
        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter() else { return }

        stopSensor(cGMTransmitter: cgmTransmitter, sendToTransmitter: true)
        updateLabelsAndChart(overrideApplicationState: false)
    }

    private func submitCalibrationFromManagementView(_ valueAsDouble: Double) -> String? {
        guard let calibrationsAccessor = calibrationsAccessor, let coreDataManager = self.coreDataManager, let bgReadingsAccessor = self.bgReadingsAccessor else {
            return Texts_HomeView.sensorManagementCalibrationUnavailable
        }

        guard let cgmTransmitter = self.bluetoothPeripheralManager?.getCGMTransmitter(), let bluetoothTransmitter = cgmTransmitter as? BluetoothTransmitter else {
            return Texts_HomeView.theresNoCGMTransmitterActive
        }

        guard let activeSensor = activeSensor else {
            return Texts_HomeView.startSensorBeforeCalibration
        }

        if cgmTransmitter.isWebOOPEnabled() && !cgmTransmitter.overruleIsWebOOPEnabled() {
            return Texts_HomeView.calibrationNotNecessary
        }

        if calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: activeSensor) == nil && !cgmTransmitter.overruleIsWebOOPEnabled() {
            return Texts_HomeView.thereMustBeAreadingBeforeCalibration
        }

        return submitCalibrationValue(
            valueAsDouble,
            calibrationsAccessor: calibrationsAccessor,
            coreDataManager: coreDataManager,
            bgReadingsAccessor: bgReadingsAccessor,
            cgmTransmitter: cgmTransmitter,
            activeSensor: activeSensor,
            deviceName: bluetoothTransmitter.deviceName
        )
    }
    
    /// check if the conditions are correct to start a live activity, update it, or end it
    /// also update the widget data stored in user defaults
    private func updateLiveActivityAndWidgets(forceRestart: Bool) {
        if let bgReadingsAccessor = self.bgReadingsAccessor {
            
            let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            
            // create two simple arrays to send to the live activiy. One with the bg values in mg/dL and another with the corresponding timestamps
            // this is needed due to the not being able to pass structs that are not codable/hashable
            let hoursOfBgReadingsToSend: Double = 12
            
            let allBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date().addingTimeInterval(-3600 * hoursOfBgReadingsToSend), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
            
            // Live Activities have maximum payload size of 4kB.
            // This value is selected by testing how much we can send before getting the "Payload maximum size exceeded" error.
            let maxNumberOfReadings = 260
            
            // If there are more readings than we can send to the Live Activity, downsample the values to fit.
            let bgReadings = allBgReadings.count > maxNumberOfReadings
            ? (0 ..< maxNumberOfReadings).map { allBgReadings[$0 * allBgReadings.count / maxNumberOfReadings] }
            : allBgReadings
            
            if bgReadings.count > 0 {
                var slopeOrdinal: Int = 0
                var deltaValueInUserUnit: Double = 0
                var bgReadingValues: [Double] = []
                var bgReadingDates: [Date] = []
                
                // add delta if available
                if bgReadings.count > 1 {
                    var previousValueInUserUnit: Double = bgReadings[1].finalValue.mgDlToMmol(mgDl: isMgDl)
                    var actualValueInUserUnit: Double = bgReadings[0].finalValue.mgDlToMmol(mgDl: isMgDl)
                    
                    // if the values are in mmol/L, then round them to the nearest decimal point in order to get the same precision out of the next operation
                    if !isMgDl {
                        previousValueInUserUnit = (previousValueInUserUnit * 10).rounded() / 10
                        actualValueInUserUnit = (actualValueInUserUnit * 10).rounded() / 10
                    }
                    
                    deltaValueInUserUnit = actualValueInUserUnit - previousValueInUserUnit
                    slopeOrdinal = bgReadings[0].slopeOrdinal()
                }
                
                for bgReading in bgReadings {
                    bgReadingValues.append(bgReading.finalValue)
                    bgReadingDates.append(bgReading.timeStamp)
                }
                
                let dataSourceDescription = UserDefaults.standard.isMaster ? UserDefaults.standard.activeSensorDescription ?? "" : UserDefaults.standard.followerDataSourceType.fullDescription
                var sensorNoiseStateRawValue: Int?

                if UserDefaults.standard.isMaster,
                   let activeSensor,
                   activeSensor.noiseAlgorithmVersion == ConstantsSensorNoise.algorithmVersion,
                   let latestReadingAt = activeSensor.noiseLatestReadingAt {
                    let readingAge = Date().timeIntervalSince(latestReadingAt)

                    if readingAge >= -TimeInterval(minutes: 5),
                       readingAge <= ConstantsSensorNoise.rootWarningFreshness {
                        let rawSensorNoiseState = SensorNoiseState(rawValue: activeSensor.noiseStateRaw) ?? .collecting
                        sensorNoiseStateRawValue = Int(
                            ConstantsSensorNoise.displayState(
                                rawState: rawSensorNoiseState,
                                shortTermNoise: activeSensor.shortTermNoise?.doubleValue,
                                longTermNoise: activeSensor.longTermNoise?.doubleValue,
                                sensitivity: UserDefaults.standard.sensorNoiseSensitivity
                            ).rawValue
                        )
                    }
                }
                
                // set up the AID status values if applicable. If not needed, then we'll send nil dates which will then be ignored by the Live Activity
                var deviceStatusCreatedAt: Date?
                var deviceStatusLastLoopDate: Date?
                
                if let deviceStatus = nightscoutSyncManager?.deviceStatus as? NightscoutDeviceStatus, UserDefaults.standard.nightscoutEnabled, UserDefaults.standard.nightscoutFollowType != .none, deviceStatus.createdAt != .distantPast {
                    deviceStatusCreatedAt = deviceStatus.createdAt
                    deviceStatusLastLoopDate = deviceStatus.lastLoopDate
                }
                
                // show the live activity if we're in master mode or (follower with a heartbeat) and only if the user has requested to show it
                // if we should show it, then let's continue processing the lastReading array to create a valid contentState
                if (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat)) && UserDefaults.standard.liveActivityType != .disabled {
                    // create the contentState that will update the dynamic attributes of the Live Activity Widget
                    let contentState = XDripWidgetAttributes.ContentState( bgReadingValues: bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeOrdinal: slopeOrdinal, deltaValueInUserUnit: deltaValueInUserUnit, urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue, lowLimitInMgDl: UserDefaults.standard.lowMarkValue, highLimitInMgDl: UserDefaults.standard.highMarkValue, urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue, liveActivityType: UserDefaults.standard.liveActivityType, dataSourceDescription: dataSourceDescription, followerPatientName: !UserDefaults.standard.isMaster ? UserDefaults.standard.followerPatientName : nil, sensorNoiseStateRawValue: sensorNoiseStateRawValue, deviceStatusCreatedAt: deviceStatusCreatedAt, deviceStatusLastLoopDate: deviceStatusLastLoopDate)
                    
                    LiveActivityManager.shared.update(contentState: contentState, forceRestart: forceRestart)
                } else {
                    Task { await LiveActivityManager.shared.endAllActivities() }
                }
                
                // update the widget data stored in user defaults
                let bgReadingDatesAsDouble = bgReadingDates.map { date in
                    date.timeIntervalSince1970
                }
                
                let widgetSharedUserDefaultsModel = WidgetSharedUserDefaultsModel(bgReadingValues: bgReadingValues, bgReadingDatesAsDouble: bgReadingDatesAsDouble, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, slopeOrdinal: slopeOrdinal, deltaValueInUserUnit: deltaValueInUserUnit, urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue, lowLimitInMgDl: UserDefaults.standard.lowMarkValue, highLimitInMgDl: UserDefaults.standard.highMarkValue, urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue, dataSourceDescription: dataSourceDescription, followerPatientName: !UserDefaults.standard.isMaster ? UserDefaults.standard.followerPatientName : nil, deviceStatusCreatedAt: deviceStatusCreatedAt, deviceStatusLastLoopDate: deviceStatusLastLoopDate, allowStandByHighContrast: UserDefaults.standard.allowStandByHighContrast, forceStandByBigNumbers: UserDefaults.standard.forceStandByBigNumbers)
                
                // store the model in the shared user defaults using a name that is uniquely specific to this copy of the app as installed on
                // the user's device - this allows several copies of the app to be installed without cross-contamination of widget data
                if let widgetData = try? JSONEncoder().encode(widgetSharedUserDefaultsModel) {
                    UserDefaults.storeInSharedUserDefaults(value: widgetData, forKey: "widgetSharedUserDefaults.\(Bundle.main.mainAppBundleIdentifier)")
                }
            } else {
                Task { await LiveActivityManager.shared.endAllActivities() }
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    /// store notification glucose chart images in the app container documents folder
    private func createNotificationImages() {
        // create a small thumbnail glucose chart image to show in the standard iOS notification banner
        createNotificationImage(glucoseChartType: .notificationImageThumbnail)
        
        /// create an image based upon a glucose chart view and save it to the app container documents directory
        /// - Parameter glucoseChartType: the type of glucose chart type we want to generate (i.e. thumbnail or full notification chart)
        func createNotificationImage(glucoseChartType: GlucoseChartType) {
            if let bgReadingsAccessor = self.bgReadingsAccessor {
                let bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date().addingTimeInterval(-3600 * glucoseChartType.hoursToShow(liveActivityType: .normal)), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
                
                if bgReadings.count > 0 {
                    var bgReadingValues: [Double] = []
                    var bgReadingDates: [Date] = []
                    
                    for bgReading in bgReadings {
                        bgReadingValues.append(bgReading.finalValue)
                        bgReadingDates.append(bgReading.timeStamp)
                    }
                    
                    // create a chart view with just bg reading values and dates
                    let glucoseChartView = GlucoseChartView(glucoseChartType: glucoseChartType, bgReadingValues: bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue, lowLimitInMgDl: UserDefaults.standard.lowMarkValue, highLimitInMgDl: UserDefaults.standard.highMarkValue, urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue, liveActivityType: .normal, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                    
                    // render the glucose chart view as an image object
                    guard let notificationImage = ImageRenderer(content: glucoseChartView).uiImage else { return }
                    
                    // try and save the image to the documents directory in the app container
                    if let imageToSave = notificationImage.pngData() {
                        let fileUrl = URL.documentsDirectory.appendingPathComponent("\(glucoseChartType.filename()).png")
                        try? imageToSave.write(to: fileUrl)
                    }
                }
            }
        }
    }
    
    // updates the toolbar UI to show the current snooze status of the app
    private func updateSnoozeStatus() {
        publishRootHomeState()
    }
    
    private func updatePostProcessingStatus() {
        publishRootHomeState()
    }
    
    private func setNightscoutSyncRequiredToTrue(forceNow: Bool) {
        if forceNow || (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
    }
    
    private func updatePumpAndAIDStatusViews() {
        publishRootHomeState()
    }
}

// MARK: - conform to CGMTransmitter protocol

/// conform to CGMTransmitterDelegate
extension RootApplicationCoordinator: @preconcurrency CGMTransmitterDelegate {
    func sensorStopDetected() {
        trace("sensor stop detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        bgPostProcessingManager?.handleSourceContextChanged()
        
        stopSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sendToTransmitter: false)
        
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorDescription = nil
    }
    
    func newSensorDetected(sensorStartDate: Date?) {
        trace("new sensor detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        bgPostProcessingManager?.handleSourceContextChanged()
        
        // stop sensor, self.bluetoothPeripheralManager?.getCGMTransmitter() can be nil in case of Libre2, because new sensor is detected via NFC call which usually happens before the transmitter connection is made (and so before cGMTransmitter is assigned a new value)
        stopSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sendToTransmitter: false)
        
        // if sensorStartDate is given, then unwrap coreDataManager and startSensor
        if let sensorStartDate = sensorStartDate, let coreDataManager = coreDataManager {
            // use sensorCode nil, in the end there will be no start sensor command sent to the transmitter because we just received the sensorStartTime from the transmitter, so it's already started
            startSensor(cGMTransmitter: self.bluetoothPeripheralManager?.getCGMTransmitter(), sensorStarDate: sensorStartDate, sensorCode: nil, coreDataManager: coreDataManager, sendToTransmitter: false)
            
            UserDefaults.standard.activeSensorStartDate = sensorStartDate
        }
    }
    
    func sensorNotDetected() {
        trace("sensor not detected", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        createNotification(title: Texts_Common.warning, body: Texts_HomeView.sensorNotDetected, identifier: ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected, sound: nil)
    }
    
    func cgmTransmitterInfoReceived(glucoseData: inout [GlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorAge: TimeInterval?) {
        trace("in cgmTransmitterInfoReceived, transmitterBatteryInfo %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, transmitterBatteryInfo?.description ?? "not received")
        trace("in cgmTransmitterInfoReceived, sensor time in days %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, sensorAge?.days.round(toDecimalPlaces: 1).description ?? "not received")
        trace("in cgmTransmitterInfoReceived, glucoseData array size = %{public}@ values", log: log, category: ConstantsLog.categoryRootView, type: .info, glucoseData.count.description)
        
        // if received transmitterBatteryInfo not nil, then store it
        if let transmitterBatteryInfo = transmitterBatteryInfo {
            UserDefaults.standard.transmitterBatteryInfo = transmitterBatteryInfo
        }
        
        // list readings
        for (index, glucose) in glucoseData.enumerated() {
            trace("in cgmTransmitterInfoReceived, glucoseData %{public}@, value = %{public}@, timestamp = %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .debug, String(format: "%02d", index), glucose.glucoseLevelRaw.round(toDecimalPlaces: 3).description, glucose.timeStamp.toStringForTrace(timeStyle: .long, dateStyle: .none))
        }
        
        // let's check to ensure that the sensor is not within the minimum warm-up time as defined in ConstantsMaster
        var supressReadingIfSensorIsWarmingUp: Bool = false
        
        if let sensorAgeInSeconds = sensorAge {
            let secondsUntilWarmUpComplete = (ConstantsMaster.minimumSensorWarmUpRequiredInMinutes * 60) - sensorAgeInSeconds
            
            if secondsUntilWarmUpComplete > 0 {
                supressReadingIfSensorIsWarmingUp = true
                
                trace("in cgmTransmitterInfoReceived, sensor is still warming up. BG reading processing will remain suppressed for another %{public}@ minutes. (%{public}@ minutes warm-up required).", log: log, category: ConstantsLog.categoryRootView, type: .info, Int(secondsUntilWarmUpComplete/60).description, ConstantsMaster.minimumSensorWarmUpRequiredInMinutes.description)
            }
        }
        
        // process new readings if sensor is not still warming up
        if !supressReadingIfSensorIsWarmingUp {
            processNewGlucoseData(glucoseData: &glucoseData, sensorAge: sensorAge)
            
            // now try and log a transmitter read success line to the trace files.
            // this will only happen once per hour after launching the app
            if let activeSensor = activeSensor, let bgReadingsAccessor = bgReadingsAccessor, let transmitterReadSuccessDisplay = TransmitterReadSuccessManager(bgReadingsAccessor: bgReadingsAccessor).getReadSuccessForLogs(forSensor: activeSensor, notBefore: nil, timeStampOfLastLogCreated: transmitterReadSuccessTimeStampOfLastLogCreated), transmitterReadSuccessDisplay.expected24h > 0 {
                let success24h: Double = transmitterReadSuccessDisplay.success24h
                
                // Compute how much history we actually have (after cutoff, capped to 24h)
                let now = Date()
                let hoursAvailable: Double = {
                    guard let earliest = transmitterReadSuccessDisplay.earliestTimestampInLast24h else { return 0 }
                    return min(24.0, max(0, now.timeIntervalSince(earliest) / 3600.0))
                }()
                
                // Decide the window label to use
                let gap = transmitterReadSuccessDisplay.nominalGapInSeconds
                let fullExpected24h = Int(floor((24.0 * 3600.0) / Double(gap)))
                let label: String = (transmitterReadSuccessDisplay.expected24h >= fullExpected24h) ? "24h" : String(format: "~%.0fh", hoursAvailable)
                
                trace("in cgmTransmitterInfoReceived, transmitter Read Success: %{public}@ percent over the last %{public}@. %{public}@ missed readings from %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, Int(success24h.round(toDecimalPlaces: 2)).description, label, (transmitterReadSuccessDisplay.expected24h - transmitterReadSuccessDisplay.actual24h).description, transmitterReadSuccessDisplay.expected24h.description)
                
                transmitterReadSuccessTimeStampOfLastLogCreated = .now
            } else {
                trace("in cgmTransmitterInfoReceived, cannot calculate hourly transmitter read success", log: log, category: ConstantsLog.categoryRootView, type: .debug)
            }
        }
    }
    
    func errorOccurred(xDripError: XdripError) {
        if xDripError.priority == .HIGH {
            
            createNotification(title: Texts_Common.warning, body: xDripError.errorDescription, identifier: ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError, sound: nil)
        }
    }
}

// MARK: - conform to UNUserNotificationCenterDelegate protocol

/// conform to UNUserNotificationCenterDelegate, for notifications
extension RootApplicationCoordinator: @preconcurrency UNUserNotificationCenterDelegate {
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
            completionHandler([.banner, .list])
        } else if notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            
            // so actually the app was in the foreground, at the  moment the Transmitter Class called the cgmTransmitterNeedsPairing function, there's no need to show the notification, we can immediately call back the cgmTransmitter initiatePairing function
            completionHandler([])
            bluetoothPeripheralManager?.initiatePairing()
            // this will verify if it concerns an alert notification, if not pickerviewData will be nil
        } else if let pickerViewData = alertManager?.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) {
            presentPicker(pickerViewData)
        }  else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForVolumeTest {
            // user is testing iOS Sound volume in the settings. Only the sound should be played, the alert itself will not be shown
            completionHandler([.sound, .list])
        } else if notification.request.identifier == ConstantsNotifications.notificationIdentifierForxCGMTransmitterDelegatexDripError {
            // call completionhandler to show the notification even though the app is in the foreground, without sound
            completionHandler([.banner, .list])
        }
    }
    
    // called when user clicks a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // call completionHandler when exiting function
        defer {
            // call completionhandler
            completionHandler()
        }
        
        if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifiersForCalibration.initialCalibrationRequest {
            // nothing required, the requestCalibration function will be called as it's been added to ApplicationManager
            trace("in userNotificationCenter didReceive, user pressed calibration notification to open the app, requestCalibration should be called because closure is added in ApplicationManager.shared", log: log, category: ConstantsLog.categoryRootView, type: .info)
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForSensorNotDetected.sensorNotDetected {
            // if user clicks notification "sensor not detected", then show uialert with title and body
            presentAlert(title: Texts_Common.warning, message: Texts_HomeView.sensorNotDetected)
        } else if response.notification.request.identifier == ConstantsNotifications.NotificationIdentifierForTransmitterNeedsPairing.transmitterNeedsPairing {
            // nothing required, the pairing function will be called as it's been added to ApplicationManager in function cgmTransmitterNeedsPairing
        } else {
            // it's not an initial calibration request notification that the user clicked, by calling alertManager?.userNotificationCenter, we check if it was an alert notification that was clicked and if yes pickerViewData will have the list of alert snooze values
            if let pickerViewData = alertManager?.userNotificationCenter(center, didReceive: response) {
                trace("in userNotificationCenter didReceive, user pressed an alert notification to open the app", log: log, category: ConstantsLog.categoryRootView, type: .info)
                presentPicker(pickerViewData)
            } else {
                // it as also not an alert notification that the user clicked, there might come in other types of notifications in the future
            }
        }
    }
}

// MARK: - conform to FollowerDelegate protocol

extension RootApplicationCoordinator: @preconcurrency FollowerDelegate {
    func followerInfoReceived(followGlucoseDataArray: inout [FollowerBgReading]) {
        if let coreDataManager = coreDataManager, let bgReadingsAccessor = bgReadingsAccessor { //}, let followManager = (UserDefaults.standard.followerDataSourceType == .nightscout ? self.nightscoutFollowManager : self.libreLinkUpFollowManager) {

            let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            
            // assign value of timeStampLastBgReading
            var timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            
            // get lastReading, ignore sensor as this should be nil because this is follower mode
            // When follower post processing is reducing faster source data down to
            // 5 minute output, new follower readings must still be compared against
            // the latest stored source reading here. Otherwise a suppressed source
            // reading could look "missing" and get recreated on the next download.
            if let lastReading = bgReadingsAccessor.last(forSensor: nil, includingSuppressed: true) {
                timeStampLastBgReading = lastReading.timeStamp
                
                trace("in followerInfoReceived, timeStampLastBgReading = %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info, timeStampLastBgReading.toStringForTrace(timeStyle: .long, dateStyle: .long))
            }
            
            let previousTimeStampLastBgReading = timeStampLastBgReading
            
            var firstCreatedBgReadingTimeStamp: Date?
            
            // iterate through array, elements are ordered by timestamp, first is the youngest, let's create first the oldest, although it shouldn't matter in what order the readings are created
            for (_, followGlucoseData) in followGlucoseDataArray.enumerated().reversed() {
                if followGlucoseData.timeStamp > timeStampLastBgReading {
                    trace("in followerInfoReceived, creating new bgreading: value = %{public}@ %{public}@, timestamp =  %{public}@", log: self.log, category: ConstantsLog.categoryRootView, type: .info,  followGlucoseData.sgv.mgDlToMmol(mgDl: isMgDl).bgValueToString(mgDl: isMgDl), isMgDl ? Texts_Common.mgdl : Texts_Common.mmol, followGlucoseData.timeStamp.toStringForTrace(timeStyle: .long, dateStyle: .long))
                    
                    // create a new reading
                    // we'll need to check which should be the active followerManager to know where to call the function
                    switch UserDefaults.standard.followerDataSourceType {
                    case .nightscout:
                        if let followManager = nightscoutFollowManager {
                            _ = followManager.createBgReading(followGlucoseData: followGlucoseData)
                        }

                    case .libreLinkUp, .libreLinkUpRussia:
                        if let followManager = libreLinkUpFollowManager {
                            _ = followManager.createBgReading(followGlucoseData: followGlucoseData)
                        }

                    case .dexcomShare:
                        if let followManager = dexcomShareFollowManager {
                            _ = followManager.createBgReading(followGlucoseData: followGlucoseData)
                        }

                    case .medtrumEasyView:
                        if let followerManager = medtrumEasyViewFollowManager {
                            _ = followerManager.createBgReading(followGlucoseData: followGlucoseData)
                        }

                    }
                    if firstCreatedBgReadingTimeStamp == nil {
                        firstCreatedBgReadingTimeStamp = followGlucoseData.timeStamp
                    }
                    
                    // set timeStampLastBgReading to new timestamp
                    timeStampLastBgReading = followGlucoseData.timeStamp
                }
            }
            
            if firstCreatedBgReadingTimeStamp != nil {
                trace("in followerInfoReceived, new reading(s) successfully created", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                
                // save in core data
                coreDataManager.saveChanges()
                
                if UserDefaults.standard.followerBackgroundKeepAliveType == .disabled, let firstCreatedBgReadingTimeStamp = firstCreatedBgReadingTimeStamp {
                    let processingStartDateOverride = previousTimeStampLastBgReading.timeIntervalSince1970 > 0 ? previousTimeStampLastBgReading.addingTimeInterval(-1.0) : firstCreatedBgReadingTimeStamp
                    if let bgPostProcessingManager = bgPostProcessingManager {
                        _ = bgPostProcessingManager.processBgReadings(
                            processingStartDateOverride: processingStartDateOverride,
                            allowHistoricalDownstreamRewrite: bgPostProcessingManager.hasActiveDownstreamPostProcessing()
                        )
                    }
                } else {
                    _ = bgPostProcessingManager?.processLatestReadings()
                }

                // Publish the final stored value before optional downstream consumers perform their work.
                updateLiveActivityAndWidgets(forceRestart: false)

                rootHomeStateModel.invalidateCharts()

                // update all text in  first screen
                updateLabelsAndChart(overrideApplicationState: false)

                // update the mini-chart
                updateMiniChart()

                // update statistics related outlets
                updateStatistics(animate: false)

                // update data source info
                updateDataSourceInfo()
                
                // if we're downloading follower data from something other
                // than Nightscout, then let's upload it to Nightscout
                // (this will only happen if we're not following Nightscout
                // and if the user has requested to upload follower BG values
                // to Nightscout
                // Use the same Nightscout upload decision path in follower mode.
                // The manager can safely no-op when nothing new needs uploading,
                // and it avoids RootView having to predict whether a previous
                // post processing pass already covered the newest reading.
                nightscoutSyncManager?.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                
                // check alerts, create notification, set app badge
                checkAlertsCreateNotificationAndSetAppBadge()
                
                healthKitManager?.storeBgReadings()
                
                if let bgReadingSpeaker = bgReadingSpeaker {
                    bgReadingSpeaker.speakNewReading(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp())
                }
                
                bluetoothPeripheralManager?.sendLatestReading()
                
                // ask calendarManager to process new reading, ignore last connection change timestamp because this is follower mode, there is no connection to a transmitter
                calendarManager?.processNewReading(lastConnectionStatusChangeTimeStamp: nil)
                
                contactImageManager?.processNewReading()
                
                loopManager?.share()
                
                watchManager?.updateWatchApp(forceComplicationUpdate: false)
            }
        }
    }
}

// MARK: - conform to ActiveSensorProviding protocol

extension RootApplicationCoordinator: @preconcurrency ActiveSensorProviding { }
