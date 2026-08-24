import Foundation
import os
import UIKit

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class NightscoutFollowManager: NSObject {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutFollowManager)
    
    /// when to do next download
    private var nextFollowDownloadTimeStamp: Date
    
    /// reference to coredatamanager
    private var coreDataManager: CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private(set) weak var followerDelegate: FollowerDelegate?

    /// The root-owned shared keep-alive engine; this follower reports operational state only and
    /// does not own silent-audio playback, replay timing, or application lifecycle callbacks.
    private let backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging

    /// Allows wiring tests to reconcile real manager state without starting follower networking.
    private let startsInitialDownload: Bool

    /// constant for cancelling an active foreground gap fill when the app backgrounds
    private let applicationManagerKeyCancelGapFill = "NightscoutFollowerManager-CancelGapFill"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    /// Keeps historical audit state and networking out of the live follower implementation.
    private lazy var followerGapFillService = NightscoutFollowerGapFillService(
        coreDataManager: coreDataManager,
        onHistoryMerged: { [weak self] result in
            self?.followerDelegate?.followerGapFillDidMergeHistory(result)
        }
    )

    /// Invalidates delayed post-download triggers when follower lifecycle or configuration changes.
    private var gapFillIntentGeneration = UUID()

    /// Distinguishes a genuine Nightscout follower start from an in-place settings refresh.
    private var wasNightscoutFollowerActive = false

    // MARK: - initializer
    
    /// initializer
    init(
        coreDataManager: CoreDataManager,
        followerDelegate: FollowerDelegate,
        backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging,
        startsInitialDownload: Bool = true
    ) {
        
        // initialize nextFollowDownloadTimeStamp to now, which is at the moment FollowManager is instantiated
        nextFollowDownloadTimeStamp = Date()
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.backgroundKeepAliveManager = backgroundKeepAliveManager
        self.startsInitialDownload = startsInitialDownload

        // call super.init
        super.init()

        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyCancelGapFill, closure: { [weak self] in
            self?.invalidateGapFillIntent()
        })
        
        // changing from follower to master or vice versa also requires ... attention
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        // changing the follower data source
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        // setting nightscout url also does require action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue, options: .new, context: nil)
        // changing the optional Nightscout port changes the effective site
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutPort.rawValue, options: .new, context: nil)
        // setting nightscout API_SECRET also does require action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue, options: .new, context: nil)
        // setting nightscout authentication token also does require action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue, options: .new, context: nil)
        // change value of nightscout enabled
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutEnabled.rawValue, options: .new, context: nil)
        // therapy ownership and status mode decide which historical resources are eligible
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.therapyDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutFollowType.rawValue, options: .new, context: nil)

        verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    // MARK: - public functions
    
    /// creates a bgReading for reading downloaded from Nightscout
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    public func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        
        // create new bgReading
        // using sgv as value for rawData because in some case these values are not available in Nightscout
        let bgReading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.sgv, deviceName: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

        // set calculatedValue
        bgReading.calculatedValue = followGlucoseData.sgv
        
        // set calculatedValueSlope
        let (calculatedValueSlope, hideSlope) = findSlope()
        bgReading.calculatedValueSlope = calculatedValueSlope
        bgReading.hideSlope = hideSlope
        
        return bgReading
        
    }
    
    /// - download recent readings from nightscout, send result to delegate, and schedule a new download unless heartbeat mode owns the polling cadence
    /// - no download is done if latest reading is less than 30 seconds old
    @objc public func download() {
        performDownload(fillGapsAfterSuccess: false)
    }

    /// Performs the normal current-data refresh and then requests one bounded historical audit.
    func refreshAfterForeground() {
        performDownload(fillGapsAfterSuccess: true)
    }

    private func performDownload(fillGapsAfterSuccess: Bool) {

        let requestedGapFillGeneration = fillGapsAfterSuccess ? gapFillIntentGeneration : nil
        
        trace("in download", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
        
        guard UserDefaults.standard.nightscoutEnabled else {
            trace("    nightscout not enabled", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
            return
        }
        
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            trace("    setting nightscoutSyncRequired to true, this will also initiate a treatments/devicestatus sync", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
            
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }

        guard !UserDefaults.standard.isMaster else {
            trace("    not follower", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
            return
        }
        
        guard UserDefaults.standard.followerDataSourceType == .nightscout else {
            trace("    followerDataSourceType is not nightscout", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
            return
        }

        // nightscout URl must be non-nil - could be that url is not valid, this is not checked here, the app will just retry every x minutes
        guard let nightscoutUrl = UserDefaults.standard.nightscoutUrl else {return}
        
        // maximum timeStamp to download initially set to 1 day back
        var timeStampOfFirstBgReadingToDowload = Date(timeIntervalSinceNow: TimeInterval(-Double(ConstantsFollower.maxiumDaysOfReadingsToDownload) * 24.0 * 3600.0))
        
        // check timestamp of lastest stored bgreading with calculated value, if more recent then use this as timeStampOfFirstBgReadingToDowload
        let latestBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true)
        if latestBgReadings.count > 0 {
            timeStampOfFirstBgReadingToDowload = max(latestBgReadings[0].timeStamp, timeStampOfFirstBgReadingToDowload)
        }
        
        // to handle case where a reading was already fetched by LoopFollowManger right before the call to this function. In that case there should already be a reading available, and it's not necessary to download from NS
        guard abs(timeStampOfFirstBgReadingToDowload.timeIntervalSinceNow) > 30.0 else {
            
            trace("    last reading is less than 30 seconds old, will not download now", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
            
            // schedule new download
            self.scheduleNewDownload()

            if let requestedGapFillGeneration {
                startGapFillIfForeground(for: requestedGapFillGeneration)
            }
            
            return
        }
        
        // use the fastest supported Nightscout upload cadence for the count upper bound so frequent Libre readings cannot be truncated
        // also use the last local timestamp as a server-side lower bound because the follower and uploader frequency settings may differ
        let minimumTimeBetweenTwoReadingsInSeconds = ConstantsNightscout.minimiumTimeBetweenTwoReadingsInMinutesFrequentUploads * 60.0
        let backfillTimeInterval = max(0.0, -timeStampOfFirstBgReadingToDowload.timeIntervalSinceNow)
        let count = Int(ceil(backfillTimeInterval / minimumTimeBetweenTwoReadingsInSeconds)) + 1
        
        // ceate endpoint to get latest entries
        guard let latestEntriesEndpoint = Endpoint.getEndpointForLatestNSEntries(hostAndScheme: nightscoutUrl, count: count, minimumTimeStamp: timeStampOfFirstBgReadingToDowload, token: UserDefaults.standard.nightscoutToken) else {
            trace("    Nightscout URL does not use a supported scheme, no download will be started", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error, troubleshooting: .standard(.follower(source: .nightscout, activity: .downloadFailed)))
            return
        }
        
        // create downloadTask and start download
        if let url = latestEntriesEndpoint.url {
            
            // Create Request - this way we can add authentication in follower mode in order to pull data from Nightscout sites with AUTH_DEFAULT_ROLES configured to deny read access
            var request = URLRequest(url: url)
            
            if let apiKey = UserDefaults.standard.nightscoutAPIKey {
                request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
                guard let self = self else { return }
                trace("in download, finished task", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
                
                // get array of FollowGlucoseData from json
                var followGlucoseDataArray = [FollowerBgReading]()
                let responseWasSuccessful = self.processDownloadResponse(data: data, urlResponse: response, error: error, followGlucoseDataArray: &followGlucoseDataArray)
                
                // Offer this typed success only so TroubleshootingLogStore can close a previously
                // recorded Nightscout failure. Healthy 15-second downloads are discarded centrally;
                // the readings actually accepted by the app are recorded later with their own times.
                trace(
                    "    finished download,  %{public}@ readings",
                    log: self.log,
                    category: ConstantsLog.categoryNightscoutFollowManager,
                    type: .info,
                    troubleshooting: responseWasSuccessful
                        ? .standard(.follower(source: .nightscout, activity: .downloadSucceeded(readingCount: followGlucoseDataArray.count)))
                        : nil,
                    followGlucoseDataArray.count.description
                )
                
                // Dispatch to delegate on the main actor (use a local copy for the inout parameter)
                let localCopy = followGlucoseDataArray
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // call delegate followerInfoReceived which will process the new readings
                    if let followerDelegate = self.followerDelegate {
                        var array = localCopy
                        followerDelegate.followerInfoReceived(followGlucoseDataArray: &array)
                    }
                    if responseWasSuccessful, let requestedGapFillGeneration {
                        self.startGapFillIfForeground(for: requestedGapFillGeneration)
                    }
                    // schedule new download
                    self.scheduleNewDownload()
                }
            })
            
            trace("in download, calling task.resume", log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info, troubleshooting: .detailed(.follower(source: .nightscout, activity: .downloadStarted)))
            task.resume()
            
        }

    }

    private func startGapFillIfForeground(for requestedGeneration: UUID, retryAfterForegroundTransition: Bool = true) {
        guard requestedGeneration == gapFillIntentGeneration else { return }
        if UIApplication.shared.applicationState == .background {
            guard retryAfterForegroundTransition else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startGapFillIfForeground(
                    for: requestedGeneration,
                    retryAfterForegroundTransition: false
                )
            }
            return
        }
        followerGapFillService.run(endingAt: Date())
    }

    private func invalidateGapFillIntent() {
        gapFillIntentGeneration = UUID()
        followerGapFillService.cancel()
    }
    
    // MARK: - private functions
    
    /// taken from xdripplus
    ///
    /// updates bgreading
    ///
    private func findSlope() -> (calculatedValueSlope: Double, hideSlope: Bool) {
        
        // init returnvalues
        var hideSlope = true
        var calculatedValueSlope = 0.0

        // get last readings
        let last2Readings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true)
        
        // if more thant 2 readings, calculate slope and hie
        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading:last2Readings[1])
            calculatedValueSlope = slope
            hideSlope = hide
        }

        return (calculatedValueSlope, hideSlope)
        
    }

    
    /// schedule new download with timer, when timer expires download() will be called
    private func scheduleNewDownload() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        // invalidate previous timer if any before scheduling a new one
        if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
            invalidateDownLoadTimerClosure()
            self.invalidateDownLoadTimerClosure = nil
        }
        trace("in scheduleNewDownload", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
        // schedule a timer for 15 seconds and assign it to a let property
        let downloadTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)
        // assign invalidateDownLoadTimerClosure to a closure that will invalidate the downloadTimer
        invalidateDownLoadTimerClosure = {
            downloadTimer.invalidate()
        }
    }
    
    /// process result from download from Nightscout
    /// - parameters:
    ///     - data : data as result from dataTask
    ///     - urlResponse : urlResponse as result from dataTask
    ///     - error : error as result from dataTask
    ///     - followGlucoseData : array input by caller, result will be in that array. Can be empty array. Array must be initialized to empty array by caller
    /// - returns: FollowGlucoseData , possibly empty - first entry is the youngest
    private func processDownloadResponse(data:Data?, urlResponse:URLResponse?, error:Error?, followGlucoseDataArray:inout [FollowerBgReading] ) -> Bool {
        
        // log info
        trace("in processDownloadResponse", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info)
        
        var responseWasValid = true

        // if error log an error
        if let error = error {
            trace("    failed to download, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error, troubleshooting: .standard(.follower(source: .nightscout, activity: .downloadFailed)), error.localizedDescription)
            return false
        }
        
        // if data not nil then check if response is nil
        if let data = data {
            /// if response not nil then process data
            if let urlResponse = urlResponse as? HTTPURLResponse {
                if urlResponse.statusCode == 200 {
                    
                    // store the current timestamp as a successful server response
                    UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
                        
                    // try json deserialization
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        
                        // it should be an array
                        if let array = json as? [Any] {
                            
                            // iterate through the entries and create glucoseData
                            for entry in array {

                                if let entry = entry as? [String:Any] {
                                    if let followGlucoseData = FollowerBgReading(json: entry) {
                                        
                                        // insert entry chronologically sorted, first is the youngest
                                        if followGlucoseDataArray.count == 0 {
                                            followGlucoseDataArray.append(followGlucoseData)
                                        } else {
                                            var elementInserted = false
                                            loop : for (index, element) in followGlucoseDataArray.enumerated() {
                                                if element.timeStamp < followGlucoseData.timeStamp {
                                                    followGlucoseDataArray.insert(followGlucoseData, at: index)
                                                    elementInserted = true
                                                    break loop
                                                }
                                            }
                                            if !elementInserted {
                                                followGlucoseDataArray.append(followGlucoseData)
                                            }
                                        }

                                    } else {
                                        responseWasValid = false
                                        trace("     failed to create glucoseData from a Nightscout entry", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
                                    }
                                } else {
                                    responseWasValid = false
                                    trace("     Nightscout response contained an invalid entry", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
                                }
                            }
                            
                        } else {
                            trace("     json deserialization failed, result is not a json array", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
                            return false
                        }
                        
                    } else {
                        trace("     json deserialization failed", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
                        return false
                    }
                    
                } else {
                    trace("     urlResponse.statusCode  is not 200 value = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error, troubleshooting: .standard(.follower(source: .nightscout, activity: .downloadFailed)), urlResponse.statusCode.description)
                    return false
                }
            } else {
                trace("    data is nil", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
                return false
            }
        } else {
            trace("    urlResponse is not HTTPURLResponse", log: self.log, category: ConstantsLog.categoryNightscoutFollowManager, type: .error)
            return false
        }
        return responseWasValid
    }
    
    /// Verifies applicable settings and starts or stops follower mode and its background keep-alive registration.
    private func verifyUserDefaultsAndStartOrStopFollowMode() {

        invalidateGapFillIntent()

        let isNightscoutFollowerActive = !UserDefaults.standard.isMaster
            && UserDefaults.standard.followerDataSourceType == .nightscout
            && UserDefaults.standard.nightscoutUrl != nil
            && UserDefaults.standard.nightscoutEnabled
        let isStartingNightscoutFollower = isNightscoutFollowerActive && !wasNightscoutFollowerActive
        wasNightscoutFollowerActive = isNightscoutFollowerActive

        if isNightscoutFollowerActive {
            
            backgroundKeepAliveManager.start(for: .nightscout)

            guard startsInitialDownload else { return }
            
            // do initial download, this will also schedule future downloads
            if isStartingNightscoutFollower {
                refreshAfterForeground()
            } else {
                download()
            }
            
        } else {
            
            backgroundKeepAliveManager.stop(for: .nightscout)
            
            // invalidate the downloadtimer
            if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
                invalidateDownLoadTimerClosure()
            }
        }
    }
    
    // MARK:- overriden function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.isMaster, UserDefaults.Key.followerDataSourceType, UserDefaults.Key.nightscoutUrl, UserDefaults.Key.nightscoutPort, UserDefaults.Key.nightscoutEnabled, UserDefaults.Key.nightscoutAPIKey, UserDefaults.Key.nightscoutToken, UserDefaults.Key.therapyDataSourceType, UserDefaults.Key.nightscoutFollowType:
                    
                    // change by user, should not be done within 200 ms
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        verifyUserDefaultsAndStartOrStopFollowMode()
                        
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutPort.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutEnabled.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.therapyDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutFollowType.rawValue)
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyCancelGapFill)
        invalidateDownLoadTimerClosure?()
        invalidateGapFillIntent()
        backgroundKeepAliveManager.stop(for: .nightscout)
    }
}
