import Foundation
import os
import UIKit

public class NightscoutSyncManager: NSObject, ObservableObject {
    
    // MARK: - public properties
    
    /// holds and persists the nightscout profile data
    var profile = NightscoutProfile()
    
    /// holds and persists the nightscout device status data
    var deviceStatus = NightscoutDeviceStatus()
    
    // MARK: - private properties
    
    /// set the shared userdefaults
    private let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    /// path for readings and calibrations
    private let nightscoutEntriesPath = "/api/v1/entries"
    
    /// path for treatments
    private let nightscoutTreatmentPath = "/api/v1/treatments"
    
    /// path for devicestatus
    private let nightscoutDeviceStatusPath = "/api/v1/devicestatus"
    
    /// path to test API Secret
    private let nightscoutAuthTestPath = "/api/v1/experiments/test"
    
    /// path for profile entries
    private let nightscoutProfilePath = "/api/v1/profile"
    
    /// for logging
    private var oslog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutSyncManager)
    
    /// BgReadingsAccessor instance
    private let bgReadingsAccessor: BgReadingsAccessor
    
    /// SensorsAccessor instance
    private let sensorsAccessor: SensorsAccessor
    
    /// CalibrationsAccessor instance
    private let calibrationsAccessor: CalibrationsAccessor
    
    /// TreatmentEntryAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    
    /// reference to coreDataManager
    private let coreDataManager: CoreDataManager
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = .init()
    
    /// in case errors occur like credential check error, then this closure will be called with title and message
    private let messageHandler: ((String, String) -> Void)?
    
    /// temp storage transmitterBatteryInfo, if changed then upload to Nightscout will be done
    private var latestTransmitterBatteryInfo: TransmitterBatteryInfo?
    
    /// temp storate uploader battery level, if changed then upload to Nightscout will be done
    private var latestUploaderBatteryLevel: Float?
    
    /// timestamp of the last actual sync (for global throttling)
    private var lastActualSyncTime: Date? = nil
    
    // Relaunch debouncing to avoid multiple immediate sync restarts
    private var relaunchScheduled: Bool = false
    private var lastRelaunchAt: Date = .distantPast
    private let relaunchDebounceInterval: TimeInterval = 1.0
    private let idleNightscoutSyncInterval: TimeInterval = 300 // 5 minutes cooldown when the last sync found no changes
    private var lastSyncHadChanges: Bool = true
    private var didUpdateProfileDuringLastSync: Bool = false
    private var didUpdateDeviceStatusDuringLastSync: Bool = false
    private var pendingForegroundSync: Bool = false
    private var lastBackgroundFollowerRefreshAt: Date = .distantPast
    private let backgroundFollowerRefreshCooldown: TimeInterval = 60
    
    /// - when was the sync of treatments with Nightscout started.
    /// - if nil then there's no sync running
    /// - if not nil then the value tells when nightscout sync was started, without having finished (otherwise it should be nil)
    private var nightscoutSyncStartTimeStamp: Date?
    
    /// if nightscoutSyncStartTimeStamp is not nil, and more than this TimeInterval from now, then we can assume nightscout sync has failed during a previous attempt
    ///
    /// normally nightscoutSyncStartTimeStamp should be nil if it failed, but it could be due to a coding error that the value is not reset to nil
    private let maxDurationNightscoutSync = TimeInterval(minutes: 1)
    
    /// a sync may have started, and while running, the user may have created a new treatment. In that case, a sync will not be restarted, but wait till the previous is finished. This variable is used to verify if a new sync is required after having finished one
    ///
    /// Must be read/written in main thread !!
    private var nightscoutSyncRequired = false
    
    /// dateFormatter to correctly decode the received timestamps into UTC
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    /// generic jsonDecoder to format correctly the timestamps
    private lazy var jsonDecoder: JSONDecoder? = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()
    
    // MARK: - initializer
    
    /// initializer
    /// - parameters:
    ///     - coreDataManager : needed to get latest readings
    ///     - messageHandler : to show the result of the sync to the user. this closure will be called with title and message
    init(coreDataManager: CoreDataManager, messageHandler: ((_ timessageHandlertle: String, _ message: String) -> Void)?) {
        // init properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        self.messageHandler = messageHandler
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // let's try and import the nightscout profile data if stored in userdefaults
        // we can do this as the profile isn't expected to change very often
        if let profileData = sharedUserDefaults?.object(forKey: "nightscoutProfile") as? Data, let nightscoutProfile = try? JSONDecoder().decode(NightscoutProfile.self, from: profileData) {
            self.profile = nightscoutProfile
        }
        
        deviceStatus.lastCheckedDate = .distantPast
        deviceStatus.updatedDate = .distantPast
        
        // add observers for nightscout settings which may require testing and/or start upload
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutPort.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutEnabled.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutUseSchedule.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutSchedule.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutSyncRequired.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerUploadDataToNightscout.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutFollowType.rawValue, options: .new, context: nil)
    }
    
    deinit {
        // remove KVO observers added in init to avoid crashes
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutPort.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutEnabled.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutUseSchedule.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutSchedule.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutSyncRequired.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerUploadDataToNightscout.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutFollowType.rawValue)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - public functions
    
    /// Public wrapper to allow external sync requests (e.g. after new BG reading)
    /// will always be forced to enact
    public func syncAllWithNightscout() {
        self.syncWithNightscout(overrideAppState: true)
    }
    
    /// uploads latest BgReadings, calibrations, active sensor and battery status to Nightscout, only if nightscout enabled, not master, url and key defined, if schedule enabled then check also schedule
    /// - parameters:
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect
    public func uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: Date?) {
        // check that Nightscout is enabled
        // and nightscoutURL exists
        guard UserDefaults.standard.nightscoutEnabled, UserDefaults.standard.nightscoutUrl != nil else { return }
        
        // check and exit without uploading BG values if any of the following conditions are true:
        // - follower mode but the follower source is also Nightscout
        // - follower mode but upload follower data to Nightscout if false
        // - master mode but upload master to Nightscout is false
        if (!UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .nightscout) || (!UserDefaults.standard.isMaster && !UserDefaults.standard.followerUploadDataToNightscout) || (UserDefaults.standard.isMaster && !UserDefaults.standard.masterUploadDataToNightscout) {
            return
        }
        
        // check that either the API_SECRET or Token exists, if both are nil then return
        if UserDefaults.standard.nightscoutAPIKey == nil && UserDefaults.standard.nightscoutToken == nil {
            return
        }
        
        // if schedule is on, check if upload is needed according to schedule
        if UserDefaults.standard.nightscoutUseSchedule {
            if let schedule = UserDefaults.standard.nightscoutSchedule {
                if !schedule.indicatesOn(forWhen: Date()) {
                    return
                }
            }
        }
        
        let minimumInterval = lastSyncHadChanges ? ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds : idleNightscoutSyncInterval
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -minimumInterval {
            trace("in uploadLatestBgReadings, setting nightscoutSyncRequired to true (minInterval=%{public}@ seconds, lastSyncHadChanges=%{public}@)", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, String(format: "%.0f", minimumInterval), String(lastSyncHadChanges))
            
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
        
        // upload readings
        uploadBgReadingsToNightscout(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        
        // upload calibrations
        uploadCalibrationsToNightscout()
        
        // upload activeSensor if needed
        if UserDefaults.standard.uploadSensorStartTimeToNS, let activeSensor = sensorsAccessor.fetchActiveSensor() {
            if !activeSensor.uploadedToNS {
                trace("n uploadLatestBgReadings, activeSensor not yet uploaded to NS", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                
                uploadActiveSensorToNightscout(sensor: activeSensor)
            }
        }
        
        // upload transmitter battery info if needed, also upload uploader battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UserDefaults.standard.transmitterBatteryInfo != latestTransmitterBatteryInfo || latestUploaderBatteryLevel != UIDevice.current.batteryLevel {
            if let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo {
                uploadTransmitterBatteryInfoToNightscout(transmitterBatteryInfo: transmitterBatteryInfo)
            }
        }
    }
    
    /// tries to delete any entries from Nightscout that are within 1 second either side of the timestamp that is passed (this should normally just be a single entry/reading)
    /// - parameters:
    ///     - timeStampOfBgReadingToDelete : the timestamp of the BG reading that we want to try and remove
    public func deleteBgReadingFromNightscout(timeStampOfBgReadingToDelete: Date) {
        // create a query that finds entries between 1 second before, and 1 second after, the timestamp
        let queries = [URLQueryItem(name: "find[dateString][$gte]", value: String(timeStampOfBgReadingToDelete.addingTimeInterval(-1).ISOStringFromDate())), URLQueryItem(name: "find[dateString][$lte]", value: String(timeStampOfBgReadingToDelete.addingTimeInterval(+1).ISOStringFromDate()))]
        
        // send a DELETE http request with the queryItems
        Task {
            do {
                let _ = try await nightscoutRequest(path: nightscoutEntriesPath,queryItems: queries,httpMethod: "DELETE",responseType: Data.self)
                // This is maybe redundant as Nightscout returns a successful result even if no entries were actually found/deleted
                trace("in deleteBgReadingFromNightscout, deleting BG reading/entry with timestamp %{public}@ from Nightscout", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, timeStampOfBgReadingToDelete.description)
            } catch {
                trace("in deleteBgReadingFromNightscout, failed to delete BG reading/entry with timestamp %{public}@ from Nightscout: %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, timeStampOfBgReadingToDelete.description, error.localizedDescription)
            }
        }
        
    }
    
    // MARK: - overriden functions
    
    /// when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.nightscoutUrl, UserDefaults.Key.nightscoutAPIKey, UserDefaults.Key.nightscoutToken, UserDefaults.Key.nightscoutPort:
                    // Reset deviceStatus and profile to empty when Nightscout connection settings change
                    deviceStatus = NightscoutDeviceStatus()
                    profile = NightscoutProfile()
                    // apikey or nightscout api key change is triggered by user, should not be done within 200 ms
                    if keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        // if master is set (or if we're in follower mode other than Nightscout and we want to upload to Nightscout), siteURL exists and either API_SECRET or a token is entered, then test credentials
                        if UserDefaults.standard.nightscoutUrl != nil && (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType != .nightscout && UserDefaults.standard.followerUploadDataToNightscout)) && (UserDefaults.standard.nightscoutAPIKey != nil || UserDefaults.standard.nightscoutToken != nil) {
                            testNightscoutCredentials { success, error in
                                DispatchQueue.main.async {
                                    self.callMessageHandler(withCredentialVerificationResult: success, error: error)
                                    if success {
                                        // set lastConnectionStatusChangeTimeStamp to as late as possible, to make sure that the most recent reading is uploaded if user is testing the credentials
                                        self.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: Date())
                                    } else {
                                        trace("in observeValue, Nightscout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                                    }
                                }
                            }
                        }
                    }
                    
                case UserDefaults.Key.nightscoutEnabled, UserDefaults.Key.nightscoutUseSchedule, UserDefaults.Key.nightscoutSchedule, UserDefaults.Key.followerUploadDataToNightscout:
                    
                    // if changing to enabled, then do a credentials test and if ok start upload, in case of failure don't give warning, that's the only difference with previous cases
                    if keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        // if master is set (or if we're in follower mode other than Nightscout and we want to upload to Nightscout), siteURL exists and either API_SECRET or a token is entered, then test credentials
                        if UserDefaults.standard.nightscoutUrl != nil && (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType != .nightscout && UserDefaults.standard.followerUploadDataToNightscout)) && (UserDefaults.standard.nightscoutAPIKey != nil || UserDefaults.standard.nightscoutToken != nil) {
                            testNightscoutCredentials { success, _ in
                                DispatchQueue.main.async {
                                    if success {
                                        // set lastConnectionStatusChangeTimeStamp to as late as possible, to make sure that the most recent reading is uploaded if user is testing the credentials
                                        self.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: Date())
                                        
                                    } else {
                                        trace("in observeValue, Nightscout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                                    }
                                }
                            }
                        }
                    }
                    
                case UserDefaults.Key.nightscoutSyncRequired:
                    
                    if keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        // if nightscoutSyncRequired didn't change to true then no further processing
                        guard UserDefaults.standard.nightscoutSyncRequired else { return }
                        
                        UserDefaults.standard.nightscoutSyncRequired = false
                        // Debounce and coalesce relaunch requests
                        DispatchQueue.main.async { [weak self] in
                            self?.scheduleNightscoutSyncRelaunch()
                        }
                    }
                    
                case UserDefaults.Key.nightscoutFollowType:
                    // nillify the deviceStatus to force a new sync/parse using the new model selected
                    deviceStatus = NightscoutDeviceStatus()
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.syncWithNightscout()
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - private functions
    
    /// synchronize all treatments and other information with Nightscout
    private func syncWithNightscout(overrideAppState: Bool = false) {
        if UIApplication.shared.applicationState == .background && !overrideAppState {
            trace("in syncWithNightscout, aborted because app is backgrounded and not overriden", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
            performBackgroundFollowerRefreshIfNeeded()
            pendingForegroundSync = true
            nightscoutSyncRequired = true
            return
        }
        
        pendingForegroundSync = false
        // Global throttle: do not allow sync more often than the minimum interval
        if let last = lastActualSyncTime, Date().timeIntervalSince(last) < ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            return
        }
        
        // Only update lastActualSyncTime after a real sync is about to start
        lastActualSyncTime = Date()
        
        // Ensure Core Data main-context objects are always accessed on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.syncWithNightscout()
            }
            return
        }
        // check that Nightscout is enabled
        // and nightscoutURL exists
        guard UserDefaults.standard.nightscoutEnabled, UserDefaults.standard.nightscoutUrl != nil else { return }
        
        updateProfile()
        
        updateDeviceStatus()
        
        // if sync already running, then set nightscoutSyncRequired to true
        // sync is running already, once stopped it will rerun
        if let nightscoutSyncStartTimeStamp = nightscoutSyncStartTimeStamp {
            if Date().timeIntervalSince(nightscoutSyncStartTimeStamp) < maxDurationNightscoutSync {
                // Coalesce multiple relaunch requests within same active sync window
                trace("in syncWithNightscout, previous sync still running. Marking required = true for coalesced relaunch", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
                nightscoutSyncRequired = true
                
                return
            }
        }
        
        // set nightscoutSyncStartTimeStamp to now, because nightscout sync will start
        nightscoutSyncStartTimeStamp = Date()
        
        /// to keep track if one of the downloads resulted in creation or update of treatments
        var treatmentsLocallyCreatedOrUpdated = false
        
        // get the latest treatments from the last maxTreatmentsDaysToUpload days
        // this includes treatments in with treatmentDeleted = true
        let treatmentsToSync = treatmentEntryAccessor.getLatestTreatments(limit: ConstantsNightscout.maxTreatmentsToUpload)
        
        // **************************************************************************************************
        // start with uploading treatments that are in status not uploaded and have no id yet (ie never uploaded to NS before) - and off course not deleted
        // **************************************************************************************************
        trace("in syncWithNightscout, calling uploadTreatmentsToNightscout", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
        
        uploadTreatmentsToNightscout(treatmentsToUpload: treatmentsToSync.filter { treatment in treatment.id == TreatmentEntry.EmptyId && !treatment.uploaded && !treatment.treatmentdeleted }) { nightscoutResult in
            
            trace("in syncWithNightscout, uploadTreatmentsToNightscout result = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, nightscoutResult.description())
            
            // possibly not running on main thread here
            DispatchQueue.main.async {
                // *********************************************************************
                // update treatments to nightscout
                // now filter on treatments that are in status not uploaded and have an id. These are treatments are already uploaded but need update @ Nightscout
                // *********************************************************************
                
                // create new array of treatmentEntries to update - they will be processed one by one, a processed element is removed from treatmentsToUpdate
                var treatmentsToUpdate = treatmentsToSync.filter { treatment in treatment.id != TreatmentEntry.EmptyId && !treatment.uploaded && !treatment.treatmentdeleted }
                
                if treatmentsToUpdate.count > 0 {
                    trace("in syncWithNightscout, uploadTreatmentsToNightscout, there are %{public}@ treatments to be updated", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, treatmentsToUpdate.count.description)
                }
                
                // function to update the treatments one by one, it will call itself after having updated an entry, to process the next entry or to proceed with the next step in the sync process
                func updateTreatment() {
                    if let treatmentToUpdate = treatmentsToUpdate.first {
                        // remove the treatment from the array, so it doesn't get processed again next run
                        treatmentsToUpdate.removeFirst()
                        
                        trace("in updateTreatment, calling updateTreatmentToNightscout", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                        
                        self.updateTreatmentToNightscout(treatmentToUpdate: treatmentToUpdate, completionHandler: { nightscoutResult in
                            
                            trace("in updateTreatment, updateTreatmentToNightscout result = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, nightscoutResult.description())
                            
                            // by calling updateTreatment(), the next treatment to update will be processed, or go to the next step in the sync process
                            // better to start in main thread
                            DispatchQueue.main.async {
                                updateTreatment()
                            }
                        })
                        
                    } else {
                        // *********************************************************************
                        // download treatments from nightscout
                        // *********************************************************************
                        trace("in updateTreatment, calling getLatestTreatmentsNSResponses", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
                        
                        self.getLatestTreatmentsNSResponses(treatmentsToSync: treatmentsToSync) { nightscoutResult in
                            
                            trace("in updateTreatment, getLatestTreatmentsNSResponses result = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, nightscoutResult.description())
                            
                            // if there's treatments created or updated, then set treatmentsLocallyCreatedOrUpdated to true
                            treatmentsLocallyCreatedOrUpdated = nightscoutResult.amountOfNewOrUpdatedTreatments() > 0
                            
                            DispatchQueue.main.async {
                                // *********************************************************************
                                // delete treatments
                                // *********************************************************************
                                // create new array of treatmentEntries to delete - they will be processed one by one, a processed element is removed from treatmentsToDelete
                                var treatmentsToDelete = treatmentsToSync.filter { treatment in treatment.treatmentdeleted && !treatment.uploaded }
                                
                                if treatmentsToDelete.count > 0 {
                                    trace("in updateTreatment, there are %{public}@ treatments to be deleted", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, treatmentsToDelete.count.description)
                                }
                                
                                // function to delete the treatments one by one, it will call itself after having deleted an entry, to process the next entry or to proceed with the next step in the sync process
                                func deleteTreatment() {
                                    if let treatmentToDelete = treatmentsToDelete.first {
                                        // remove the treatment from the array, so it doesn't get processed again next run
                                        treatmentsToDelete.removeFirst()
                                        
                                        trace("in deleteTreatment, calling deleteTreatmentAtNightscout", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                                        
                                        self.deleteTreatmentAtNightscout(treatmentToDelete: treatmentToDelete, completionHandler: { nightscoutResult in
                                            
                                            trace("in deleteTreatment, deleteTreatmentAtNightscout result = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, nightscoutResult.description())
                                            
                                            // by calling deleteTreatment(), the next treatment to delete will be processed, or go to the next step in the sync process
                                            // better to start in main thread
                                            DispatchQueue.main.async {
                                                // if delete was successful, then also uploaded attribute is changed in the treatment object, savechangesis required
                                                if nightscoutResult.successFull() {
                                                    self.coreDataManager.saveChanges()
                                                }
                                                
                                                deleteTreatment()
                                            }
                                        })
                                        
                                    } else {
                                        if treatmentsLocallyCreatedOrUpdated {
                                            UserDefaults.standard.nightscoutTreatmentsUpdateCounter = UserDefaults.standard.nightscoutTreatmentsUpdateCounter + 1
                                        }
                                        
                                        // this sync session has finished, set nightscoutSyncStartTimeStamp to nil
                                        self.nightscoutSyncStartTimeStamp = nil
                                        self.lastSyncHadChanges = treatmentsLocallyCreatedOrUpdated || self.didUpdateProfileDuringLastSync || self.didUpdateDeviceStatusDuringLastSync
                                        self.didUpdateProfileDuringLastSync = false
                                        self.didUpdateDeviceStatusDuringLastSync = false
                                        
                                        // ********************************************************************************************
                                        // next step in the sync process
                                        // sync again if necessary (user may have created or updated treatments while previous sync was running)
                                        // ********************************************************************************************
                                        if self.nightscoutSyncRequired {
                                            // set to false to avoid it starts again after having restarted it (unless off course it's set to true in another place by the time the sync has finished
                                            self.nightscoutSyncRequired = false
                                            // Schedule relaunch on main after short delay to avoid immediate recursion and allow UI/main-thread breathing room
                                            trace("in deleteTreatment, relaunching nightscoutsync (coalesced)", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                                self?.syncWithNightscout()
                                            }
                                        }
                                    }
                                }
                                
                                // call the function delete Treatment a first time
                                // it will call itself per Treatment to be deleted at Nightscout, or, if there aren't any to delete, it will continue with the next step
                                deleteTreatment()
                            }
                        }
                    }
                }
                
                // call the function update Treatment a first time
                // it will call itself per Treatment to be updated at Nightscout, or, if there aren't any to update, it will continue with the next step
                updateTreatment()
                
                // force the flag back to false to prevent the sync from stalling
                UserDefaults.standard.nightscoutSyncRequired = false
            }
        }
    }
    
    /// Schedules a Nightscout sync relaunch respecting debounce interval.
    private func scheduleNightscoutSyncRelaunch() {
        if Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.scheduleNightscoutSyncRelaunch()
            }
            return
        }
        if UIApplication.shared.applicationState == .background {
            trace("in scheduleNightscoutSyncRelaunch, app backgrounded, deferring until active", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
            performBackgroundFollowerRefreshIfNeeded()
            pendingForegroundSync = true
            nightscoutSyncRequired = true
            return
        }
        // If a relaunch is already scheduled or we've relaunched very recently, skip.
        if relaunchScheduled || Date().timeIntervalSince(lastRelaunchAt) < relaunchDebounceInterval {
            trace("in scheduleNightscoutSyncRelaunch, skipping (scheduled = %{public}@, sinceLast = %{public}@s)", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, relaunchScheduled.description, String(format: "%.2f", Date().timeIntervalSince(lastRelaunchAt)))
            return
        }
        relaunchScheduled = true
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.relaunchScheduled = false
            self.lastRelaunchAt = Date()
            trace("in scheduleNightscoutSyncRelaunch, performing relaunch", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
            self.syncWithNightscout()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    @objc private func handleAppDidBecomeActive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.pendingForegroundSync {
                self.pendingForegroundSync = false
                self.scheduleNightscoutSyncRelaunch()
            }
        }
    }

    /// Allows follower-mode downloads while backgrounded so Loop data stays fresh when BLE wakes the app.
    private func performBackgroundFollowerRefreshIfNeeded() {
        guard UserDefaults.standard.nightscoutFollowType != .none else { return }
        let now = Date()
        if now.timeIntervalSince(lastBackgroundFollowerRefreshAt) < backgroundFollowerRefreshCooldown {
            return
        }
        lastBackgroundFollowerRefreshAt = now
        trace("in performBackgroundFollowerRefreshIfNeeded, refreshing Nightscout follow data while backgrounded", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
        updateProfile()
        updateDeviceStatus()
    }
    
    /// check if a new profile update is required, see if the downloaded response is newer than the stored one and then import it if necessary
    private func updateProfile() {
        // if the user doesn't want to follow any type of AID system, just do nothing and return
        guard UserDefaults.standard.nightscoutFollowType != .none else { return }
        
        guard UserDefaults.standard.nightscoutUrl != nil else {
            trace("in updateProfile, nightscoutURL is nil", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
            return
        }
        
        // just check in case there is something wrong with the dates (i.e. a phone setting change)
        // if we detect this then reset the dates back to force a profile download and overwrite
        if profile.startDate > Date() || profile.updatedDate > Date() {
            profile.startDate = .distantPast
            profile.updatedDate = .distantPast
        }
        
        // only allow the update check to happen if it's been at least 30 seconds since the last one.
        // no need to update it too much as it doesn't generally change that often.
        if Date().timeIntervalSince(profile.updatedDate) < 30 {
            return
        }
        
        Task {
            do {
                let profileResponses: [NightscoutProfileResponse]? = try await nightscoutRequest(path: nightscoutProfilePath, responseType: [NightscoutProfileResponse].self)
                if let profileResponse = profileResponses?.first {
                    let newProfile = NightscoutProfile(from: profileResponse)
                    if newProfile.startDate > profile.startDate {
                        if profile.startDate == .distantPast {
                            trace("in updateProfile, no profile is stored yet. Importing Nightscout profile with date = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, profile.startDate.formatted(date: .abbreviated, time: .shortened))
                        } else {
                            trace("in updateProfile, found a newer Nightscout profile online with date = %{public}@, old profile date = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, newProfile.startDate.formatted(date: .abbreviated, time: .shortened), profile.startDate.formatted(date: .abbreviated, time: .shortened))
                        }
                        self.profile = newProfile
                        // Store in userdefaults for quick access
                        if let profileData = try? JSONEncoder().encode(newProfile) {
                            UserDefaults.standard.nightscoutProfile = profileData
                        }
                        await MainActor.run {
                            self.didUpdateProfileDuringLastSync = true
                        }
                    }
                }
            } catch {
                trace("in updateProfile, error = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
    }
    
    /// check if a new deviceStatus update is required, see if the downloaded response is newer than the stored one and then import it if necessary
    private func updateDeviceStatus() {
        guard UserDefaults.standard.nightscoutFollowType != .none else { return }
        guard UserDefaults.standard.nightscoutUrl != nil else {
            trace("in updateDeviceStatus, nightscoutURL is nil", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
            return
        }
        let currentDate = Date().addingTimeInterval(20)
        if deviceStatus.createdAt > currentDate || deviceStatus.updatedDate > currentDate || deviceStatus.lastLoopDate > currentDate {
            deviceStatus.createdAt = .distantPast
            deviceStatus.updatedDate = .distantPast
            deviceStatus.lastLoopDate = .distantPast
        }
        let previousDeviceStatusSignature = (createdAt: deviceStatus.createdAt, lastLoopDate: deviceStatus.lastLoopDate, id: deviceStatus.id)
        Task {
            do {
                let unifiedResponses: [NightscoutDeviceStatusResponse]? = try await nightscoutRequest(path: nightscoutDeviceStatusPath, responseType: [NightscoutDeviceStatusResponse].self)
                guard let unifiedResponses = unifiedResponses, let latest = unifiedResponses.sorted(by: { ($0.createdAt ?? "") > ($1.createdAt ?? "") }).first else {
                    trace("in updateDeviceStatus, no valid device status found in Nightscout response", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                    return
                }
                var deviceStatus = NightscoutDeviceStatus(from: latest)
                // --- Aggregate for most recent temp basal rate/duration, uploader battery, and pump battery from all entries (all systems) ---
                // 1. Temp basal rate/duration
                let tempBasalCandidates = unifiedResponses.compactMap { resp -> (rate: Double, duration: Int, date: Date)? in
                    // Trio: use openAPS.enacted only (not suggested)
                    if resp.device == "Trio", let enacted = resp.openAPS?.enacted,
                       let rate = enacted.rate, let duration = enacted.duration, let ts = enacted.timestamp,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
                    {
                        return (rate, duration, date)
                    }
                    // iAPS: use openAPS.suggested or enacted
                    if resp.device == "iAPS", let aps = resp.openAPS?.suggested ?? resp.openAPS?.enacted,
                       let rate = aps.rate, let duration = aps.duration, let ts = aps.timestamp,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
                    {
                        return (rate, duration, date)
                    }
                    // OpenAPS/AAPS: use openAPS.suggested or enacted
                    if let device = resp.device, device.starts(with: "openaps://") || device == "AAPS", let aps = resp.openAPS?.suggested ?? resp.openAPS?.enacted,
                       let rate = aps.rate, let duration = aps.duration, let ts = aps.timestamp,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
                    {
                        return (rate, duration, date)
                    }
                    // Loop: use loop.enacted
                    if let enacted = resp.loop?.enacted,
                       let rate = enacted.rate, let duration = enacted.duration, let ts = enacted.timestamp,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
                    {
                        return (rate, duration, date)
                    }
                    return nil
                }
                if let mostRecent = tempBasalCandidates.sorted(by: { $0.date > $1.date }).first {
                    deviceStatus.rate = mostRecent.rate
                    deviceStatus.duration = mostRecent.duration
                }
                
                // 2. Uploader battery (always from uploader.battery)
                let uploaderBatteryCandidates = unifiedResponses.compactMap { resp -> (percent: Int, date: Date)? in
                    if let percent = resp.uploader?.battery, let ts = resp.uploader?.timestamp,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
                    {
                        return (percent, date)
                    }
                    return nil
                }
                if let mostRecent = uploaderBatteryCandidates.sorted(by: { $0.date > $1.date }).first {
                    deviceStatus.uploaderBatteryPercent = mostRecent.percent
                }
                
                // 3. Pump battery (always from pump.battery.percent)
                let pumpBatteryCandidates = unifiedResponses.compactMap { resp -> (percent: Int, date: Date)? in
                    if let percent = resp.pump?.battery?.percent, let clock = resp.pump?.clock,
                       let date = ISO8601DateFormatter.withFractionalSeconds.date(from: clock) ?? ISO8601DateFormatter().date(from: clock)
                    {
                        return (percent, date)
                    }
                    return nil
                }
                if let mostRecent = pumpBatteryCandidates.sorted(by: { $0.date > $1.date }).first {
                    deviceStatus.pumpBatteryPercent = mostRecent.percent
                }
                let signatureChanged = deviceStatus.createdAt != previousDeviceStatusSignature.createdAt || deviceStatus.lastLoopDate != previousDeviceStatusSignature.lastLoopDate || deviceStatus.id != previousDeviceStatusSignature.id
                self.deviceStatus = deviceStatus
                self.deviceStatus.lastCheckedDate = .now
                self.deviceStatus.updatedDate = .now
                trace("in updateDeviceStatus, updated device status with createdAt = %{public}@. Last looping date = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, self.deviceStatus.createdAt.formatted(date: .abbreviated, time: .shortened), self.deviceStatus.lastLoopDate.formatted(date: .abbreviated, time: .shortened))
                trace("in updateDeviceStatus, deviceStatus data = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, String(describing: self.deviceStatus))
                await MainActor.run {
                    self.didUpdateDeviceStatusDuringLastSync = signatureChanged
                }
            } catch {
                self.deviceStatus.lastCheckedDate = .now
                trace("in updateDeviceStatus, error = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: - - download from Nightscout
    
    /// Gets the latest treatments from Nightscout, and do local sync: create new entries and update existing entries
    /// - parameters:
    ///     - completionHandler : handler that will be called with the result TreatmentNSResponse array
    ///     - treatmentsToSync : main goal of the function is not to upload, but to download. However the response will be used to verify if it has any of the treatments that has no id yet and also to verify if existing treatments have changed
    private func getLatestTreatmentsNSResponses(treatmentsToSync: [TreatmentEntry], completionHandler: @escaping (_ result: NightscoutResult) -> Void) {
        // query for treatments older than maxHoursTreatmentsToDownload
        let queries = [URLQueryItem(name: "find[created_at][$gte]", value: String(Date(timeIntervalSinceNow: TimeInterval(hours: -ConstantsNightscout.maxHoursTreatmentsToDownload)).ISOStringFromDate()))]
        
        /// treatments that are locally stored (and not marked as deleted), and that are not in the list of downloaded treatments will be locally deleted
        /// - only for latest treatments less than maxHoursTreatmentsToDownload old
        var didFindTreatmentInDownload = [Bool](repeating: false, count: treatmentsToSync.count)
        
        performHTTPRequest(path: nightscoutTreatmentPath, queries: queries, httpMethod: nil) { (data: Data?, nightscoutResult: NightscoutResult) in
            
            guard nightscoutResult.successFull() else {
                trace("in getLatestTreatmentsNSResponses, result is not success", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error)
                completionHandler(nightscoutResult)
                return
            }
            
            guard let data = data else {
                trace("in getLatestTreatmentsNSResponses, data is nil", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error)
                completionHandler(.failed)
                return
            }
            
            do {
                // Try to serialize the data
                if let treatmentNSResponses = try TreatmentNSResponse.arrayFromData(data) {
                    // Be sure to use the correct thread.
                    // Running in the completionHandler thread will result in issues.
                    self.coreDataManager.mainManagedObjectContext.performAndWait {
                        if treatmentNSResponses.count > 0 {
                            trace("in getLatestTreatmentsNSResponses, %{public}@ treatments downloaded", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, treatmentNSResponses.count.description)
                        }
                        
                        // newTreatmentsIfRequired will iterate through downloaded treatments and if any in it is not yet known then create an instance of TreatmentEntry for each new one
                        // amountOfNewTreatments is the amount of new TreatmentEntries, just for tracing
                        let amountOfNewTreatments = self.newTreatmentsIfRequired(treatmentNSResponses: treatmentNSResponses)
                        
                        if amountOfNewTreatments > 0 {
                            trace("in getLatestTreatmentsNSResponses, %{public}@ new treatmentEntries created", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, amountOfNewTreatments.description)
                        }
                        
                        // main goal of the function is not to upload, but to download. However the response from NS will be used to verify if it has any of the treatments that has no id yet in coredata
                        let amountMarkedAsUploaded = self.checkIfUploaded(forTreatmentEntries: treatmentsToSync, inTreatmentNSResponses: treatmentNSResponses)
                        
                        if amountMarkedAsUploaded > 0 {
                            trace("in getLatestTreatmentsNSResponses, %{public}@ treatmentEntries found in response which were not yet marked as uploaded", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, amountMarkedAsUploaded.description)
                        }
                        
                        let amountOfUpdatedTreatments = self.checkIfChangedAtNightscout(forTreatmentEntries: treatmentsToSync, inTreatmentNSResponses: treatmentNSResponses, didFindTreatmentInDownload: &didFindTreatmentInDownload)
                        
                        if amountOfUpdatedTreatments > 0 {
                            trace("in getLatestTreatmentsNSResponses, %{public}@ treatmentEntries found that were updated at NS and updated locally", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, amountOfUpdatedTreatments.description)
                        }
                        
                        // now for each treatmentEntry, less than maxHoursTreatmentsToDownload, check if it was found in the NS response
                        //    if not, it means it's been deleted at NS, also do the local deletion
                        //    only treatments that were successfully uploaded before
                        
                        // to  keep track of amount of locally deleted treatmentEntries
                        var amountOfLocallyDeletedTreatments = 0
                        
                        for (index, entry) in treatmentsToSync.enumerated() {
                            if abs(entry.date.timeIntervalSinceNow) < ConstantsNightscout.maxHoursTreatmentsToDownload * 3600.0 {
                                if !didFindTreatmentInDownload[index] && !entry.treatmentdeleted && entry.uploaded {
                                    entry.treatmentdeleted = true
                                    amountOfLocallyDeletedTreatments = amountOfLocallyDeletedTreatments + 1
                                }
                            }
                        }
                        
                        if amountOfLocallyDeletedTreatments > 0 {
                            trace("in getLatestTreatmentsNSResponses, %{public}@ treatmentEntries that were not found anymore at NS and deleted locally", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, amountOfLocallyDeletedTreatments.description)
                        }
                        
                        // Moved summary log here, after amountOfLocallyDeletedTreatments is computed
                        let totalActivity = amountOfNewTreatments + amountMarkedAsUploaded + amountOfUpdatedTreatments + amountOfLocallyDeletedTreatments
                        if totalActivity > 0 {
                            trace("in getLatestTreatmentsNSResponses, Nightscout sync summary: new = %{public}@, markedUploaded = %{public}@, updated = %{public}@, deleted = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, amountOfNewTreatments.description, amountMarkedAsUploaded.description, amountOfUpdatedTreatments.description, amountOfLocallyDeletedTreatments.description)
                        }
                        
                        self.coreDataManager.saveChanges()
                        
                        // call completion handler with success, if amount and/or amountOfNewTreatments > 0 then it's success with localchanges
                        completionHandler(.success(amountOfUpdatedTreatments + amountOfNewTreatments + amountOfLocallyDeletedTreatments))
                    }
                    
                } else {
                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                        trace("in getLatestTreatmentsNSResponses, JSON serialization failed. data = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, dataAsString)
                        
                        completionHandler(.failed)
                    }
                }
                
            } catch {
                trace("in getLatestTreatmentsNSResponses, error at JSONSerialization : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
                
                completionHandler(.failed)
            }
        }
    }
    
    /// Unified async/await Nightscout HTTP request function for all downloads/uploads/deletes.
    /// - Parameters:
    ///   - path: API path (e.g. /api/v1/entries)
    ///   - queryItems: URL query items
    ///   - httpMethod: GET/POST/PUT/DELETE (default GET)
    ///   - body: Optional HTTP body (for uploads)
    ///   - responseType: Decodable type to decode (optional)
    /// - Returns: Decoded response if responseType is provided, otherwise Data
    @discardableResult
    private func nightscoutRequest<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil, httpMethod: String = "GET", body: Data? = nil, responseType: T.Type? = nil) async throws -> T? {
        guard let baseUrl = UserDefaults.standard.nightscoutUrl else {
            throw NSError(domain: "Nightscout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nightscout URL not set"])
        }
        var urlComponents = URLComponents(string: baseUrl + path)
        if let queryItems = queryItems {
            urlComponents?.queryItems = queryItems
        }
        guard let url = urlComponents?.url else {
            throw NSError(domain: "Nightscout", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Nightscout URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let apiKey = UserDefaults.standard.nightscoutAPIKey {
            request.addValue(apiKey.sha1(), forHTTPHeaderField: "API-SECRET")
        }
        if let token = UserDefaults.standard.nightscoutToken {
            let sep = url.query == nil ? "?" : "&"
            request.url = URL(string: url.absoluteString + "\(sep)token=\(token)")
        }
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "Nightscout", code: 3, userInfo: [NSLocalizedDescriptionKey: "Nightscout request failed"])
        }
        
        if let responseType = responseType {
            // Special case: if T is Data, just return the raw data
            if responseType == Data.self, let raw = data as? T {
                return raw
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                return try decoder.decode(responseType, from: data)
            } catch {
                // Try to decode as a single object if not an array
                if let single = try? decoder.decode(T.self, from: data) {
                    return [single] as? T
                }
                throw error
            }
        }
        return nil
    }
    
    /// Backward-compatible callback-based HTTP request (replaces performHTTPRequest)
    private func performHTTPRequest(path: String, queries: [URLQueryItem], httpMethod: String?, completionHandler: @escaping ((Data?, NightscoutResult) -> Void)) {
        Task {
            do {
                let method = httpMethod ?? "GET"
                let data = try await nightscoutRequest(path: path, queryItems: queries, httpMethod: method, responseType: Data.self)
                completionHandler(data, .success(0))
            } catch {
                completionHandler(nil, .failed)
            }
        }
    }
    
    // MARK: - - upload to Nightscout
    
    /// upload battery level to nightscout
    /// - parameters:
    ///     - transmitterBatteryInfosensor: setransmitterBatteryInfosensornsor to upload
    private func uploadTransmitterBatteryInfoToNightscout(transmitterBatteryInfo: TransmitterBatteryInfo) {
        trace("in uploadTransmitterBatteryInfoToNightscout, preparing to upload transmitterBatteryInfo", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
        
        // enable battery monitoring on iOS device
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // https://testhdsync.herokuapp.com/api-docs/#/Devicestatus/addDevicestatuses
        let transmitterBatteryInfoAsKeyValue = transmitterBatteryInfo.batteryLevel
        
        // not very clear here how json should look alike. For dexcom it seems to work with "battery":"the battery level off the iOS device" and "batteryVoltage":"Dexcom voltage"
        // while for other devices like MM and Bubble, there's no batterVoltage but also a battery, so for this case I'm using "battery":"transmitter battery level", otherwise there's two "battery" keys which causes a crash - I'll hear if if it's not ok
        // first assign dataToUpload assuming the key for transmitter battery will be "battery" (ie it's not a dexcom)
        var dataToUpload = [
            "uploader": [
                "name": "transmitter",
                "battery": transmitterBatteryInfoAsKeyValue.value
            ]
        ] as [String: Any]
        
        // now check if the key for transmitter battery is not "battery" and if so reassign dataToUpload now with battery being the iOS devices battery level
        if transmitterBatteryInfoAsKeyValue.key != "battery" {
            dataToUpload = [
                "uploader": [
                    "name": "transmitter",
                    "battery": Int(UIDevice.current.batteryLevel * 100.0),
                    transmitterBatteryInfoAsKeyValue.key: transmitterBatteryInfoAsKeyValue.value
                ]
            ]
        }
        
        uploadData(dataToUpload: dataToUpload, httpMethod: nil, path: nightscoutDeviceStatusPath, completionHandler: {
            // sensor successfully uploaded, change value in coredata
            trace("in uploadTransmitterBatteryInfoToNightscout, transmitterBatteryInfo uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
            
            self.latestTransmitterBatteryInfo = transmitterBatteryInfo
            self.latestUploaderBatteryLevel = UIDevice.current.batteryLevel
            
        })
    }
    
    /// upload sensor to nightscout
    /// - parameters:
    ///     - sensor: sensor to upload
    private func uploadActiveSensorToNightscout(sensor: Sensor) {
        trace("in uploadActiveSensorToNightscout, preparing to upload activeSensor", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
        
        let dataToUpload = [
            "_id": sensor.id,
            "eventType": "Sensor Start",
            "created_at": sensor.startDate.ISOStringFromDate(),
            "enteredBy": ConstantsHomeView.applicationName
        ]
        
        uploadData(dataToUpload: dataToUpload, httpMethod: nil, path: nightscoutTreatmentPath, completionHandler: {
            // sensor successfully uploaded, change value in coredata
            trace("in uploadActiveSensorToNightscout, activeSensor uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
            
            DispatchQueue.main.async {
                sensor.uploadedToNS = true
                self.coreDataManager.saveChanges()
            }
        })
    }
    
    /// upload latest readings to nightscout
    /// - parameters:
    ///     - lastConnectionStatusChangeTimeStamp : if there's not been a disconnect in the last 5 minutes, then the latest reading will be uploaded only if the time difference with the latest but one reading is at least 5 minutes.
    private func uploadBgReadingsToNightscout(lastConnectionStatusChangeTimeStamp: Date?) {
        // get readings to upload, limit to x days, x = ConstantsNightscout.maxBgReadingsDaysToUpload
        var timeStamp = Date(timeIntervalSinceNow: TimeInterval(-ConstantsNightscout.maxBgReadingsDaysToUpload))
        
        if let timeStampLatestNightscoutUploadedBgReading = UserDefaults.standard.timeStampLatestNightscoutUploadedBgReading {
            if timeStampLatestNightscoutUploadedBgReading > timeStamp {
                timeStamp = timeStampLatestNightscoutUploadedBgReading
            }
        }
        
        // add 10 seconds because if Libre with smoothing is used, sometimes the older values reappear but with a slightly different timestamp
        // this caused readings being uploaded to NS with just a few seconds difference
        timeStamp = timeStamp.addingTimeInterval(10.0)
        
        let minimiumTimeBetweenTwoReadingsInMinutes = UserDefaults.standard.storeFrequentReadingsInNightscout ? ConstantsNightscout.minimiumTimeBetweenTwoReadingsInMinutesFrequentUploads : ConstantsNightscout.minimiumTimeBetweenTwoReadingsInMinutes
        
        // get latest readings, filter : minimiumTimeBetweenTwoReadingsInMinutes beteen two readings, except for the first if a dis/reconnect occured since the latest reading
        var bgReadingsToUpload = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStamp, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp, timeStampLastProcessedBgReading: timeStamp)
        
        if bgReadingsToUpload.count > 0 {
            trace("in uploadBgReadingsToNightscout, number of readings to upload : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, bgReadingsToUpload.count.description)
            
            // there's a limit of payload size to upload to Nightscout
            // if size is > maximum, then we'll have to call the upload function again, this variable will be used in completionHandler
            let callAgainNeeded = bgReadingsToUpload.count > ConstantsNightscout.maxReadingsToUpload
            
            if callAgainNeeded {
                trace("in uploadBgReadingsToNightscout, restricting readings to upload to %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, ConstantsNightscout.maxReadingsToUpload.description)
            }
            
            // limit the amount of readings to upload to avoid passing this limit
            // we start with the oldest readings
            bgReadingsToUpload = Array(bgReadingsToUpload.prefix(ConstantsNightscout.maxReadingsToUpload))
            
            // map readings to dictionaryRepresentation
            let bgReadingsDictionaryRepresentation = bgReadingsToUpload.map { $0.dictionaryRepresentationForNightscoutUpload() }
            
            // store the timestamp of the last reading to upload, here in the main thread, because we use a bgReading for it, which is retrieved in the main mangedObjectContext
            let timeStampLastReadingToUpload = bgReadingsToUpload.first?.timeStamp
            
            uploadData(dataToUpload: bgReadingsDictionaryRepresentation, httpMethod: nil, path: nightscoutEntriesPath, completionHandler: {
                // change timeStampLatestNightscoutUploadedBgReading
                if let timeStampLastReadingToUpload = timeStampLastReadingToUpload {
                    trace("in uploadBgReadingsToNightscout, in uploadBgReadingsToNightscout, upload succeeded, timeStampLatestNightscoutUploadedBgReading = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, timeStampLastReadingToUpload.formatted(date: .abbreviated, time: .standard))
                    
                    UserDefaults.standard.timeStampLatestNightscoutUploadedBgReading = timeStampLastReadingToUpload
                    
                    // callAgainNeeded means we've limit the amount of readings because size was too big
                    // if so a new upload is needed
                    if callAgainNeeded {
                        // do this in the main thread because the readings are fetched with the main mainManagedObjectContext
                        DispatchQueue.main.async {
                            self.uploadBgReadingsToNightscout(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
                        }
                    }
                }
            })
        } else {
            trace("in uploadBgReadingsToNightscout, no readings to upload", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
        }
    }
    
    /// common functionality to upload data to nightscout
    /// - parameters:
    ///     - dataToUpload : data to upload
    ///     - completionHandler : will be executed if upload was successful
    ///
    /// only used by functions to upload bg reading, calibrations, active sensor, battery status
    private func uploadData(dataToUpload: Any, httpMethod: String?, path: String, completionHandler: (() -> Void)?) {
        uploadDataAndGetResponse(dataToUpload: dataToUpload, httpMethod: httpMethod, path: path) { _, nightscoutResult in
            
            // completion handler to be called only if upload as successful
            if let completionHandler = completionHandler, nightscoutResult.successFull() {
                completionHandler()
            }
        }
    }
    
    /// common functionality to upload data to nightscout and get response
    /// - parameters:
    ///     - dataToUpload : data to upload
    ///     - path : the path (like /api/v1/treatments)
    ///     - httpMethod : method to use, default POST
    ///     - completionHandler : will be executed with the response Data? and NightscoutResult
    private func uploadDataAndGetResponse(dataToUpload: Any, httpMethod: String?, path: String, completionHandler: @escaping ((Data?, NightscoutResult) -> Void)) {
        do {
            // transform dataToUpload to json
            let dataToUploadAsJSON = try JSONSerialization.data(withJSONObject: dataToUpload, options: [])
            
            // trace size of data
            trace("in uploadDataAndGetResponse, size of data to upload : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, dataToUploadAsJSON.count.description)
            
            // trace data to upload as string in debug  mode
            if let dataToUploadAsJSONAsString = String(bytes: dataToUploadAsJSON, encoding: .utf8) {
                trace("in uploadDataAndGetResponse, data to upload : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, dataToUploadAsJSONAsString)
            }
            
            if let nightscoutURL = UserDefaults.standard.nightscoutUrl, let url = URL(string: nightscoutURL), var urlComponents = URLComponents(url: url.appendingPathComponent(path), resolvingAgainstBaseURL: false) {
                if UserDefaults.standard.nightscoutPort != 0 {
                    urlComponents.port = UserDefaults.standard.nightscoutPort
                }
                
                // if token not nil, then add also the token
                if let token = UserDefaults.standard.nightscoutToken {
                    let queryItems = [URLQueryItem(name: "token", value: token)]
                    urlComponents.queryItems = queryItems
                }
                
                if let url = urlComponents.url {
                    // Create Request
                    var request = URLRequest(url: url)
                    request.httpMethod = httpMethod ?? "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    if let apiKey = UserDefaults.standard.nightscoutAPIKey {
                        request.setValue(apiKey.sha1(), forHTTPHeaderField: "api-secret")
                    }
                    
                    // Create upload Task
                    let urlSessionUploadTask = URLSession.shared.uploadTask(with: request, from: dataToUploadAsJSON, completionHandler: { [weak self] data, response, error in
                        guard let self = self else {
                            completionHandler(data, .failed)
                            return
                        }
                        trace("in uploadDataAndGetResponse, finished upload", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
                        
                        var dataAsString = "NO DATA RECEIVED"
                        if let data = data {
                            if let text = String(bytes: data, encoding: .utf8) {
                                dataAsString = text
                            }
                        }
                        
                        // will contain result of nightscount sync
                        var nightscoutResult = NightscoutResult.success(0)
                        
                        // before leaving the function, call completionhandler with result
                        // also trace either debug or error, depending on result
                        defer {
                            if !nightscoutResult.successFull() {
                                trace("in uploadDataAndGetResponse, data received = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, dataAsString)
                                
                            } else {
                                // add data received in debug level
                                trace("in uploadDataAndGetResponse, data received = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, dataAsString)
                            }
                            
                            completionHandler(data, nightscoutResult)
                        }
                        
                        // error cases
                        if let error = error {
                            trace("in uploadDataAndGetResponse, failed to upload, error = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
                            
                            nightscoutResult = NightscoutResult.failed
                            
                            return
                        }
                        
                        // check that response is HTTPURLResponse and error code between 200 and 299
                        if let response = response as? HTTPURLResponse {
                            guard (200 ... 299).contains(response.statusCode) else {
                                // if the statuscode = 500 and if data has error code 66 then consider this as successful
                                // it seems to happen sometimes that an attempt is made to re-upload readings that were already uploaded (meaning with same id). That gives error 66
                                // in that case consider the upload as successful
                                if response.statusCode == 500 {
                                    do {
                                        if let data = data, let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                            // try to read description
                                            if let description = json["description"] as? [String: Any] {
                                                // try to read the code
                                                if let code = description["code"] as? Int {
                                                    if code == 66 {
                                                        trace("in uploadDataAndGetResponse, found code = 66, considering the upload as successful", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error)
                                                        
                                                        nightscoutResult = NightscoutResult.success(0)
                                                        
                                                        return
                                                    }
                                                }
                                            }
                                        }
                                        
                                    } catch {
                                        // json decode fails, upload will be considered as failed
                                        nightscoutResult = NightscoutResult.failed
                                        return
                                    }
                                }
                                
                                trace("in uploadDataAndGetResponse, failed to upload, statuscode = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, response.statusCode.description)
                                
                                nightscoutResult = NightscoutResult.failed
                                
                                return
                            }
                        } else {
                            trace("in uploadDataAndGetResponse, response is not HTTPURLResponse", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error)
                            
                            nightscoutResult = NightscoutResult.failed
                            
                            return
                        }
                        
                        // successful cases
                        nightscoutResult = NightscoutResult.success(0)
                    })
                    
                    trace("in uploadDataAndGetResponse, calling urlSessionUploadTask.resume", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
                    urlSessionUploadTask.resume()
                    
                } else {
                    // case where url is nil, which should normally not happen
                    completionHandler(nil, NightscoutResult.failed)
                }
                
            } else {
                // case where nightscoutURL is nil, which should normally not happen because nightscoutURL was checked before calling this function
                completionHandler(nil, NightscoutResult.failed)
            }
            
        } catch {
            trace("in uploadDataAndGetResponse, error : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, error.localizedDescription)
            
            completionHandler(nil, NightscoutResult.failed)
        }
    }
    
    /// Upload treatments to nightscout, receives the JSON response with the asigned id's and sets the id's in Coredata.
    /// - parameters:
    ///     - completionHandler : to be called after completion, takes NightscoutResult as argument
    ///     - treatmentsToUpload : Treatments to upload
    private func uploadTreatmentsToNightscout(treatmentsToUpload: [TreatmentEntry], completionHandler: @escaping (_ nightscoutResult: NightscoutResult) -> Void) {
        guard treatmentsToUpload.count > 0 else {
            trace("in uploadTreatmentsToNightscout, no treatments to upload", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug)
            
            completionHandler(NightscoutResult.success(0))
            
            return
        }
        
        trace("in uploadTreatmentsToNightscout, number of treatments to upload : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, treatmentsToUpload.count.description)
        
        // map treatments to dictionaryRepresentation
        let treatmentsDictionaryRepresentation = treatmentsToUpload.map { $0.dictionaryRepresentationForNightscoutUpload() }
        
        // The responsedata will contain, in serialized json, the treatments ids assigned by the server.
        uploadDataAndGetResponse(dataToUpload: treatmentsDictionaryRepresentation, httpMethod: nil, path: nightscoutTreatmentPath) { (responseData: Data?, result: NightscoutResult) in
            
            // if result of uploadDataAndGetResponse is not success then just return the result without further processing
            guard result.successFull() else {
                completionHandler(result)
                return
            }
            
            do {
                guard let responseData = responseData else {
                    trace("in uploadTreatmentsToNightscout, responseData is nil", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
                    
                    completionHandler(NightscoutResult.failed)
                    
                    return
                }
                
                // Try to serialize the data
                if let treatmentNSresponses = try TreatmentNSResponse.arrayFromData(responseData) {
                    // run in main thread because TreatmenEntry instances are craeted or updated
                    self.coreDataManager.mainManagedObjectContext.performAndWait {
                        let amount = self.checkIfUploaded(forTreatmentEntries: treatmentsToUpload, inTreatmentNSResponses: treatmentNSresponses)
                        
                        trace("in uploadTreatmentsToNightscout, %{public}@ treatmentEntries uploaded", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, amount.description)
                        
                        self.coreDataManager.saveChanges()
                        
                        // there's no treatmententries locally created or changed, so the amount in the result is 0
                        completionHandler(NightscoutResult.success(0))
                    }
                    
                } else {
                    if let responseDataAsString = String(bytes: responseData, encoding: .utf8) {
                        trace("in uploadTreatmentsToNightscout, JSON serialization failed. responseData = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, responseDataAsString)
                    }
                    
                    // json serialization failed, so call completionhandler with success = false
                    completionHandler(.failed)
                }
                
            } catch {
                trace("in uploadTreatmentsToNightscout, error at JSONSerialization : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
                
                completionHandler(.failed)
            }
        }
    }
    
    /// upload latest calibrations to nightscout
    /// - parameters:
    private func uploadCalibrationsToNightscout() {
        // get the calibrations from the last maxDaysToUpload days
        let calibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: Int(ConstantsNightscout.maxBgReadingsDaysToUpload.days), forSensor: nil)
        
        var calibrationsToUpload: [Calibration] = []
        if let timeStampLatestNightscoutUploadedCalibration = UserDefaults.standard.timeStampLatestNightscoutUploadedCalibration {
            // select calibrations that are more recent than the latest uploaded calibration
            calibrationsToUpload = calibrations.filter { $0.timeStamp > timeStampLatestNightscoutUploadedCalibration }
        } else {
            // or all calibrations if there is no previously uploaded calibration
            calibrationsToUpload = calibrations
        }
        
        if calibrationsToUpload.count > 0 {
            trace("in uploadCalibrationsToNightscout, number of calibrations to upload : %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, calibrationsToUpload.count.description)
            
            // map calibrations to dictionaryRepresentation
            // 2 records are uploaded to nightscout for each calibration: a cal record and a mbg record
            let calibrationsDictionaryRepresentation = calibrationsToUpload.map { $0.dictionaryRepresentationForCalRecordNightscoutUpload } + calibrationsToUpload.map { $0.dictionaryRepresentationForMbgRecordNightscoutUpload }
            
            // store the timestamp of the last calibration to upload, here in the main thread, because we use a Calibration for it, which is retrieved in the main mangedObjectContext
            let timeStampLastCalibrationToUpload = calibrationsToUpload.first?.timeStamp
            
            uploadData(dataToUpload: calibrationsDictionaryRepresentation, httpMethod: nil, path: nightscoutEntriesPath, completionHandler: {
                // change timeStampLatestNightscoutUploadedCalibration
                if let timeStampLastCalibrationToUpload = timeStampLastCalibrationToUpload {
                    trace("in uploadCalibrationsToNightscout, upload succeeded, setting timeStampLatestNightscoutUploadedCalibration to %{public}@", log: self.oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info, timeStampLastCalibrationToUpload.description(with: .current))
                    
                    UserDefaults.standard.timeStampLatestNightscoutUploadedCalibration = timeStampLastCalibrationToUpload
                }
            })
            
        } else {
            trace("in uploadCalibrationsToNightscout, no calibrations to upload", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
        }
    }
    
    // MARK: - - update Nightscout
    
    /// update one single treatment to nightscout
    /// - parameters:
    ///     - completionHandler : to be called after completion, takes NightscoutResult as argument
    ///     - treatmentToUpdate : Treatment to update
    private func updateTreatmentToNightscout(treatmentToUpdate: TreatmentEntry, completionHandler: @escaping (_ nightscoutResult: NightscoutResult) -> Void) {
        trace("in updateTreatmentsToNightscout", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
        
        // treatmentToUpdate as dictionary
        var treatmentToUploadToNightscoutAsDictionary = treatmentToUpdate.dictionaryRepresentationForNightscoutUpload()
        
        // check if there's other treatmenentries that have the same id and if yes add them to treatmentToUploadToNightscout
        // filter on items that have treatmentdeleted to false
        // in case the treatmentToUpdate would not yet have been uploaded to NS, then the id will be an empty string and split will return a zero length array. Check that first
        var otherTreatmentEntries: [TreatmentEntry] = []
        let treatmentToUpdateIdSplitted = treatmentToUpdate.id.split(separator: "-")
        if treatmentToUpdateIdSplitted.count > 0 {
            otherTreatmentEntries = treatmentEntryAccessor.getTreatments(thatContainId: String(treatmentToUpdateIdSplitted[0])).filter { treatment in !treatment.treatmentdeleted }
        }
        
        // iterate through otherTreatmentEntries with the same starting id (ie id that starts with same string ad treatment to delete)
        for otherTreatmentEntry in otherTreatmentEntries {
            // no need to add treatmentToUpdate. This is also in the list otherTreatmentEntries
            if otherTreatmentEntry.id != treatmentToUpdate.id {
                switch otherTreatmentEntry.treatmentType {
                case .Insulin:
                    treatmentToUploadToNightscoutAsDictionary["insulin"] = otherTreatmentEntry.value
                case .Carbs:
                    treatmentToUploadToNightscoutAsDictionary["carbs"] = otherTreatmentEntry.value
                case .Exercise:
                    treatmentToUploadToNightscoutAsDictionary["duration"] = otherTreatmentEntry.value
                case .BgCheck:
                    treatmentToUploadToNightscoutAsDictionary["glucose"] = otherTreatmentEntry.value
                    treatmentToUploadToNightscoutAsDictionary["units"] = ConstantsNightscout.mgDlNightscoutUnitString
                    treatmentToUploadToNightscoutAsDictionary["glucoseType"] = "Finger" + String(!UserDefaults.standard.bloodGlucoseUnitIsMgDl ? ": " + otherTreatmentEntry.value.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + Texts_Common.mmol : "")
                default:
                    break
                }
            }
        }
        
        uploadDataAndGetResponse(dataToUpload: treatmentToUploadToNightscoutAsDictionary, httpMethod: "PUT", path: nightscoutTreatmentPath) { (_: Data?, nightscoutResult: NightscoutResult) in
            self.coreDataManager.mainManagedObjectContext.performAndWait {
                if nightscoutResult.successFull() {
                    treatmentToUpdate.uploaded = true
                    self.coreDataManager.saveChanges()
                }
            }
            completionHandler(nightscoutResult)
        }
    }
    
    // MARK: - - delete from Nightscout
    
    /// delete one single treatment at nightscout
    /// - parameters:
    ///     - completionHandler : to be called after completion, takes NightscoutResult as argument
    ///     - treatmentToDelete : Treatment to delete
    private func deleteTreatmentAtNightscout(treatmentToDelete: TreatmentEntry, completionHandler: @escaping (_ nightscoutResult: NightscoutResult) -> Void) {
        trace("in deleteTreatmentAtNightscout", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .info)
        
        // before deleting, check first if there's treatmenentries that have the same id (id sthat starts with same string) and if yes add them to treatmentToUploadToNightscout
        // filter on items that have treatmentdeleted to false (except if treatmentToDelete)
        // check if there's other treatmenentries that have the same id and if yes add them to treatmentToUploadToNightscout
        // filter on items that have treatmentdeleted to false
        var otherTreatmentEntries: [TreatmentEntry] = []
        let treatmentToDeleteIdSplitted = treatmentToDelete.id.split(separator: "-")
        if treatmentToDeleteIdSplitted.count > 0 {
            otherTreatmentEntries = treatmentEntryAccessor.getTreatments(thatContainId: String(treatmentToDeleteIdSplitted[0])).filter { treatment in !treatment.treatmentdeleted || (treatment.treatmentdeleted && treatment.id == treatmentToDelete.id) }
        }
        
        // if otherTreatmentEntries size > 1, then the treatmentToDelete will not be deleted, but an update will be sent to Nightscout, with the other treatments with same starting id, in this update, and wihtout the treatment to be deleted
        // as a result, the treatmentToDelete will be deleted at Nightscout
        if otherTreatmentEntries.count > 1 {
            // so we won't send a delete, but an update with other (remaining) entries in it
            // this will represent the update as dictionary
            var treatmentToUpdateAsDictionary: [String: Any]?
            
            // iterate through otherTreatmentEntries with the same starting id (ie id that starts with same string as treatment to delete)
            for otherTreatmentEntry in otherTreatmentEntries {
                // no need to add treatmentToDelete.
                if otherTreatmentEntry.id != treatmentToDelete.id {
                    // if there was already another treatmentEntry, then add it; otherwise create one
                    if treatmentToUpdateAsDictionary != nil {
                        treatmentToUpdateAsDictionary?[otherTreatmentEntry.treatmentType.nightscoutFieldname()] = otherTreatmentEntry.value
                    } else {
                        treatmentToUpdateAsDictionary = otherTreatmentEntry.dictionaryRepresentationForNightscoutUpload()
                    }
                }
            }
            
            // send update to NS
            if let treatmentToUpdateAsDictionary = treatmentToUpdateAsDictionary {
                uploadDataAndGetResponse(dataToUpload: treatmentToUpdateAsDictionary, httpMethod: "PUT", path: nightscoutTreatmentPath) { (_: Data?, nightscoutResult: NightscoutResult) in
                    self.coreDataManager.mainManagedObjectContext.performAndWait {
                        if nightscoutResult.successFull() {
                            treatmentToDelete.uploaded = true
                            self.coreDataManager.saveChanges()
                        }
                    }
                    completionHandler(nightscoutResult)
                }
                return
            }
        }
        
        // there's no other treatmentEntries with the same id, so it's ok to delete it
        
        // check that id exists, if not then it's never been uploaded, and so makes no sense to delete
        guard treatmentToDelete.id != TreatmentEntry.EmptyId && treatmentToDelete.id.count > 0 else {
            completionHandler(.success(0))
            return
        }
        
        performHTTPRequest(path: nightscoutTreatmentPath + "/" + treatmentToDelete.id.split(separator: "-")[0], queries: [], httpMethod: "DELETE", completionHandler: { (_: Data?, nightscoutResult: NightscoutResult) in
            self.coreDataManager.mainManagedObjectContext.performAndWait {
                if nightscoutResult.successFull() {
                    treatmentToDelete.uploaded = true
                    self.coreDataManager.saveChanges()
                }
            }
            completionHandler(nightscoutResult)
        })
    }
    
    // MARK: - private helper functions
    
    private func testNightscoutCredentials(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        // don't run the test if one of the authentication methods is missing. This can happen because the user has input the URL but hasn't added auth yet.
        if UserDefaults.standard.nightscoutAPIKey == nil && UserDefaults.standard.nightscoutToken == nil {
            return
        }
        
        Task { [weak self] in
            guard let self = self else {
                completion(false, NSError(domain: "", code: -999, userInfo: [NSLocalizedDescriptionKey: "NightscoutSyncManager deallocated"]))
                return
            }
            do {
                _ = try await self.nightscoutRequest(
                    path: self.nightscoutAuthTestPath,
                    httpMethod: "GET",
                    responseType: Data.self
                )
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
    }
    
    /// Verifies for each treatmentEntriy, that is already uploaded, if any of the attributes has different values and if yes updates the TreatmentEntry locally
    /// - parameters:
    ///     - forTreatmentEntries : treatmentEntries to check if they have new values
    ///     - inTreatmentNSResponses : responses downloaded from NS, in which to search for the treatmentEntries
    /// - returns:amount of locally updated treatmentEntries
    ///
    /// - !! does not save to coredata
    /// - while the function iterates through treatmentEntries, didFindTreatmentInDownload will be updated and corresponding value will be set to true if a treatment is found at NS
    private func checkIfChangedAtNightscout(forTreatmentEntries treatmentEntries: [TreatmentEntry], inTreatmentNSResponses treatmentNSResponses: [TreatmentNSResponse], didFindTreatmentInDownload: inout [Bool]) -> Int {
        // used to trace how many new treatmenEntries are locally updated
        var amountOfUpdatedTreatmentEntries = 0
        
        // iterate through treatmentEntries
        for (index, treatmentEntry) in treatmentEntries.enumerated() {
            // only handle treatmentEntries that are already uploaded
            if treatmentEntry.uploaded && treatmentEntry.id != TreatmentEntry.EmptyId {
                for treatmentNSResponse in treatmentNSResponses {
                    // iterate through treatmentEntries
                    // find matching id
                    if treatmentNSResponse.id == treatmentEntry.id {
                        // found the treatment in NS response, set didFindTreatmentInDownload to true for that treatment
                        didFindTreatmentInDownload[index] = true
                        
                        var treatmentUpdated = false
                        
                        // check value, type and date. If NS has any difference, then update locally
                        
                        if treatmentNSResponse.value != treatmentEntry.value {
                            treatmentUpdated = true
                            treatmentEntry.value = treatmentNSResponse.value
                        }
                        
                        if treatmentNSResponse.eventType != treatmentEntry.treatmentType {
                            treatmentUpdated = true
                            treatmentEntry.treatmentType = treatmentNSResponse.eventType
                        }
                        
                        if treatmentNSResponse.createdAt.toMillisecondsAsInt64() != treatmentEntry.date.toMillisecondsAsInt64() {
                            treatmentUpdated = true
                            treatmentEntry.date = treatmentNSResponse.createdAt
                        }
                        
                        if treatmentUpdated {
                            amountOfUpdatedTreatmentEntries = amountOfUpdatedTreatmentEntries + 1
                            trace("in checkIfChangedAtNightscout, localupdate done for treatment with date %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, treatmentNSResponse.createdAt.toStringForTrace(timeStyle: .long, dateStyle: .long))
                        }
                        
                        break
                    }
                }
            }
        }
        
        return amountOfUpdatedTreatmentEntries
    }
    
    /// Verifies for each treatmentEntriy, if not yet uploaded and if empty id, then  if there is a matching  treatmentNSResponses and if yes reads the id (for new treatmentEntries) from the treatmentNSResponse and stores in the treatmentEntry
    /// - parameters:
    ///     - forTreatmentEntries : treatmentEntries to check if they are uploaded
    ///     - inTreatmentNSResponses : responses downloaded from NS, in which to search for the treatmentEntries
    /// - returns:amount of new  treatmentEntries found
    ///
    /// - !! does not save to coredata
    private func checkIfUploaded(forTreatmentEntries treatmentEntries: [TreatmentEntry], inTreatmentNSResponses treatmentNSResponses: [TreatmentNSResponse]) -> Int {
        // used to trace how many new treatmenEntries are created
        var amountOfNewTreatmentEntries = 0
        
        for treatmentEntry in treatmentEntries {
            if !treatmentEntry.uploaded && treatmentEntry.id == TreatmentEntry.EmptyId {
                for treatmentNSResponse in treatmentNSResponses {
                    if treatmentNSResponse.matchesTreatmentEntry(treatmentEntry) {
                        // Found the treatment
                        treatmentEntry.uploaded = true
                        
                        // Sets the id
                        treatmentEntry.id = treatmentNSResponse.id
                        
                        amountOfNewTreatmentEntries = amountOfNewTreatmentEntries + 1
                        
                        trace("in checkIfUploaded, set uploaded to true for TreatmentEntry with date %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, treatmentNSResponse.createdAt.toStringForTrace(timeStyle: .full, dateStyle: .long))
                        
                        break
                    }
                }
            }
        }
        
        return amountOfNewTreatmentEntries
    }
    
    /// filters on treatments that are net yet known, and for those creates a TreatMentEntry
    /// - parameters:
    ///     - treatmentNSResponses : array of TreatmentNSResponse
    /// - returns: number of newly created TreatmentEntry's
    ///
    /// !! new treatments are stored in coredata after calling this function - no saveChanges to coredata is done here in this function
    private func newTreatmentsIfRequired(treatmentNSResponses: [TreatmentNSResponse]) -> Int {
        // returnvalue
        var numberOfNewTreatments = 0
        
        for treatmentNSResponse in treatmentNSResponses {
            if !treatmentEntryAccessor.existsTreatmentWithId(treatmentNSResponse.id) {
                if treatmentNSResponse.asNewTreatmentEntry(nsManagedObjectContext: coreDataManager.mainManagedObjectContext) != nil {
                    numberOfNewTreatments = numberOfNewTreatments + 1
                    
                    trace("in newTreatmentsIfRequired, new treatmentEntry created with id %{public}@ and date %{public}@", log: oslog, category: ConstantsLog.categoryNightscoutSyncManager, type: .debug, treatmentNSResponse.id, treatmentNSResponse.createdAt.toStringForTrace(timeStyle: .long, dateStyle: .long))
                }
            }
        }
        
        return numberOfNewTreatments
    }
    
    private func callMessageHandler(withCredentialVerificationResult success: Bool, error: Error?) {
        // define the title text
        var title = TextsNightscout.verificationSuccessfulAlertTitle
        if !success {
            title = TextsNightscout.verificationErrorAlertTitle
        }
        
        // define the message text
        var message = TextsNightscout.verificationSuccessfulAlertBody
        if !success {
            if let error = error {
                message = error.localizedDescription
            } else {
                message = "unknown error" // shouldn't happen
            }
        }
        
        // call messageHandler
        if let messageHandler = messageHandler {
            messageHandler(title, message)
        }
    }
    
    /// generic decoding function for all JSON struct types
    private func decode<T: Decodable>(_ type: T.Type, data: Data) throws -> T {
        guard let jsonDecoder = jsonDecoder else {
            throw NightscoutSyncError.decodingError
        }
        
        return try jsonDecoder.decode(T.self, from: data)
    }
}

// MARK: - NightscoutResult

/// nightscout result
private enum NightscoutResult: Equatable {
    /// successful up or download with NS, with amount of locally updated or downloaded treatments
    case success(Int)
    
    /// failed up or download with NS
    case failed
    
    func description() -> String {
        switch self {
        case .success(let amount):
            return "success - \(amount) treatment entries locally stored or updated"
            
        case .failed:
            return "failed"
        }
    }
    
    /// returns result as bool, allows to check if successful or not without looking at details
    func successFull() -> Bool {
        switch self {
        case .success:
            return true
        case .failed:
            return false
        }
    }
    
    func amountOfNewOrUpdatedTreatments() -> Int {
        switch self {
        case .failed:
            return 0
            
        case .success(let amount):
            return amount
        }
    }
}

// MARK: - NightscoutSyncError

/// error throwing types for the follower
private enum NightscoutSyncError: Error {
    case generalError
    case missingCredentials
    case urlError
    case decodingError
    case missingPayLoad
}

// MARK: CustomStringConvertible

/// make a custom description property to correctly log the error types
extension NightscoutSyncError: CustomStringConvertible {
    var description: String {
        switch self {
        case .generalError:
            return "General Error"
        case .missingCredentials:
            return "Missing Credentials"
        case .urlError:
            return "URL Error"
        case .decodingError:
            return "Error decoding JSON response"
        case .missingPayLoad:
            return "Either the user id or the authentication payload was missing or invalid"
        }
    }
}
