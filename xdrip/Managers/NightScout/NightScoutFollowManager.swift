import Foundation
import os
import AVFoundation
import AudioToolbox

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class NightScoutFollowManager:NSObject {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightScoutFollowManager)
    
    /// when to do next download
    private var nextFollowDownloadTimeStamp:Date
    
    /// reference to coredatamanager
    private var coreDataManager:CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private (set) weak var nightScoutFollowerDelegate:NightScoutFollowerDelegate?
    
    /// AVAudioPlayer to use
    private var audioPlayer:AVAudioPlayer?
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create playsoundtimer
    private let applicationManagerKeyResumePlaySoundTimer = "NightScoutFollowerManager-ResumePlaySoundTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - invalidate playsoundtimer
    private let applicationManagerKeySuspendPlaySoundTimer = "NightScoutFollowerManager-SuspendPlaySoundTimer"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure:(() -> Void)?
    
    // timer for playsound
    private var playSoundTimer:RepeatingTimer?

    // MARK: - initializer
    
    /// initializer
    public init(coreDataManager:CoreDataManager, nightScoutFollowerDelegate:NightScoutFollowerDelegate) {
        
        // initialize nextFollowDownloadTimeStamp to now, which is at the moment FollowManager is instantiated
        nextFollowDownloadTimeStamp = Date()
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.nightScoutFollowerDelegate = nightScoutFollowerDelegate
        
        // creat audioplayer
        do {
            // set up url to create audioplayer
            let soundFileName = ConstantsSuspensionPrevention.soundFileName
            if let url = Bundle.main.url(forResource: soundFileName, withExtension: "")  {

                try audioPlayer = AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.play()
            }
            
        } catch let error {
            trace("in init, exception while trying to create audoplayer, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
        }

        // call super.init
        super.init()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 60 * 2.5 + 10, repeats: true) { (_) in
            self.verifyUserDefaultsAndStartOrStopFollowMode()
        }
        RunLoop.current.add(timer, forMode: .common)
        
        // changing from follower to master or vice versa also requires ... attention
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        // setting nightscout url also does require action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutUrl.rawValue, options: .new, context: nil)
        // change value of nightscout enabled
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutEnabled.rawValue, options: .new, context: nil)

        verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    // MARK: - public functions
    
    /// creates a bgReading for reading downloaded from NightScout
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    public func createBgReading(followGlucoseData:NightScoutBgReading) -> BgReading {
        // for dev : creation of BgReading is done in seperate static function. This allows to do the BgReading creation in other place, as is done also for readings received from a transmitter.
        
        // create new bgReading
        let bgReading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.unfiltered, filteredData: followGlucoseData.filtered, deviceName: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

        // set calculatedValue
        bgReading.calculatedValue = followGlucoseData.sgv
        
        // set calculatedValueSlope
        let (calculatedValueSlope, hideSlope) = findSlope()
        bgReading.calculatedValueSlope = calculatedValueSlope
        bgReading.hideSlope = hideSlope
        
        return bgReading
        
    }
    
    // MARK: - private functions
    
    /// taken from xdripplus
    ///
    /// updates bgreading
    ///
    private func findSlope() -> (calculatedValueSlope:Double, hideSlope:Bool) {
        
        // init returnvalues
        var hideSlope = true
        var calculatedValueSlope = 0.0

        // get last readings
        let last2Readings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if more thant 2 readings, calculate slope and hie
        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading:last2Readings[1]);
            calculatedValueSlope = slope
            hideSlope = hide
        }

        return (calculatedValueSlope, hideSlope)
        
    }

    
    /// download recent readings from nightScout, send result to delegate, and schedule new download
    @objc private func download() {
        
        trace("in download", log: self.log, type: .info)

        // nightscout URl must be non-nil - could be that url is not valid, this is not checked here, the app will just retry every x minutes
        guard var nightScoutUrl = UserDefaults.standard.nightScoutUrl else {return}
        
        // maximum timeStamp to download initially set to 1 day back
        var timeStampOfFirstBgReadingToDowload = Date(timeIntervalSinceNow: TimeInterval(-ConstantsFollower.maxiumDaysOfReadingsToDownload * 24 * 3600))
        
        // check timestamp of lastest stored bgreading with calculated value, if more recent then use this as timeStampOfFirstBgReadingToDowload
        let latestBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        if latestBgReadings.count > 0 {
            timeStampOfFirstBgReadingToDowload = max(latestBgReadings[0].timeStamp, timeStampOfFirstBgReadingToDowload)
        }
        
        // calculate count, which is a parameter in the nightscout API - divide by 60, worst case NightScout has a reading every minute, this can be the case for MiaoMiao
        let count = Int(-timeStampOfFirstBgReadingToDowload.timeIntervalSinceNow / 60 + 1)
        
        // get shared URLSession
        let sharedSession = URLSession.shared
        
        // ceate endpoint to get latest entries
        if nightScoutUrl.last == "/" {
            nightScoutUrl.removeLast()
        }
        let latestEntriesEndpoint = Endpoint.getEndpointForLatestNSEntries(hostAndScheme: nightScoutUrl, count: count, olderThan: timeStampOfFirstBgReadingToDowload)
        
        // create downloadTask and start download
        if let url = URL.init(string: latestEntriesEndpoint.url?.absoluteString.removingPercentEncoding ?? "") {
            
            let downloadTask = sharedSession.dataTask(with: url, completionHandler: { data, response, error in
                
                // get array of FollowGlucoseData from json
                var followGlucoseDataArray = [NightScoutBgReading]()
                self.processDownloadResponse(data: data, urlResponse: response, error: error, followGlucoseDataArray: &followGlucoseDataArray)
                
                trace("    finished download", log: self.log, type: .info)
                
                // call to delegate and rescheduling the timer must be done in main thread;
                DispatchQueue.main.sync {
                    
                    // call delegate nightScoutFollowerInfoReceived which will process the new readings
                    if let nightScoutFollowerDelegate = self.nightScoutFollowerDelegate {
                        nightScoutFollowerDelegate.nightScoutFollowerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)
                    }

                    // schedule new download
                    self.scheduleNewDownload(followGlucoseDataArray: &followGlucoseDataArray)

                }
                
            })
            
            downloadTask.resume()
        }

    }
    
    /// wel schedule new download with timer, when timer expires download() will be called
    /// - parameters:
    ///     - followGlucoseDataArray : array of FollowGlucoseData, first element is the youngest, can be empty. This is the data downloaded during previous download. This parameter is just there to get the timestamp of the latest reading, in order to calculate the next download time
    private func scheduleNewDownload(followGlucoseDataArray:inout [NightScoutBgReading]) {
        
//        trace("in scheduleNewDownload", log: self.log, type: .info)
//
//        // start with timestamp now + 5 minutes and 10 seconds
//        var nextFollowDownloadTimeStamp = Date(timeIntervalSinceNow: 5 * 60 + 10)
//
//        // followGlucoseDataArray.count > 0 then use the timestamp of the latest reading to calculate the next downloadtimestamp
//        if followGlucoseDataArray.count > 0 {
//            // use timestamp of latest stored reading + 5 minutes + 10 seconds
//            nextFollowDownloadTimeStamp = Date(timeInterval: 5 * 60 + 10, since: followGlucoseDataArray[0].timeStamp)
//            // now increase till next timestamp is bigger than now
//            while (nextFollowDownloadTimeStamp < Date()) {
//                nextFollowDownloadTimeStamp = Date(timeInterval: 5 * 60, since: nextFollowDownloadTimeStamp)
//            }
//        }
//
//        // schedule timer and assign it to a let property
//        let downloadTimer = Timer.scheduledTimer(timeInterval: nextFollowDownloadTimeStamp.timeIntervalSince1970 - Date().timeIntervalSince1970, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)
//        RunLoop.current.add(downloadTimer, forMode: .common)
//        // assign invalidateDownLoadTimerClosure to a closure that will invalidate the downloadTimer
//        invalidateDownLoadTimerClosure = {
//            downloadTimer.invalidate()
//        }
    }
    
    /// process result from download from NightScout
    /// - parameters:
    ///     - data : data as result from dataTask
    ///     - urlResponse : urlResponse as result from dataTask
    ///     - error : error as result from dataTask
    ///     - followGlucoseData : array input by caller, result will be in that array. Can be empty array. Array must be initialized to empty array by caller
    /// - returns: FollowGlucoseData , possibly empty - first entry is the youngest
    private func processDownloadResponse(data:Data?, urlResponse:URLResponse?, error:Error?, followGlucoseDataArray:inout [NightScoutBgReading] ) {
        
        // log info
        trace("in processDownloadResponse", log: self.log, type: .info)
        
        // if error log an error
        if let error = error {
            trace("    failed to download, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
            return
        }
        
        // if data not nil then check if response is nil
        if let data = data {
            /// if response not nil then process data
            if let urlResponse = urlResponse as? HTTPURLResponse {
                if urlResponse.statusCode == 200 {
                    
                    // convert data to String for logging purposes
                    var dataAsString = ""
                    if let aa = String(data: data, encoding: .utf8) {
                        dataAsString = aa
                    }
                    
                    // try json deserialization
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        
                        // it should be an array
                        if let array = json as? [Any] {
                            
                            // iterate through the entries and create glucoseData
                            for entry in array {

                                if let entry = entry as? [String:Any] {
                                    if let followGlucoseData = NightScoutBgReading(json: entry) {
                                        
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
                                        trace("     failed to create glucoseData, entry = %{public}@", log: self.log, type: .error, entry.description)
                                    }
                                }
                            }
                            
                        } else {
                            trace("     json deserialization failed, result is not a json array, data received = %{public}@", log: self.log, type: .error, dataAsString)
                        }
                        
                    } else {
                        trace("     json deserialization failed, data received = %{public}@", log: self.log, type: .error, dataAsString)
                    }
                    
                } else {
                    trace("     urlResponse.statusCode  is not 200 value = %{public}@", log: self.log, type: .error, urlResponse.statusCode.description)
                }
            } else {
                trace("    data is nil", log: self.log, type: .error)
            }
        } else {
            trace("    urlResponse is not HTTPURLResponse", log: self.log, type: .error)
        }
    }
    
    /// disable suspension prevention by removing the closures from ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground and ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground
    private func disableSuspensionPrevention() {
        
        // stop the timer for now, might be already suspended but doesn't harm
//        if let playSoundTimer = playSoundTimer {
//            playSoundTimer.suspend()
//        }
//
//        // no need anymore to resume the player when coming in foreground
//        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer)
//
//        // no need anymore to suspend the soundplayer when entering foreground, because it's not even resumed
//        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer)
        
    }
    
    /// launches timer that will regular play sound - this will be played only when app goes to background
    private func enableSuspensionPrevention() {
        
        // create playSoundTimer
//        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(ConstantsSuspensionPrevention.interval), eventHandler: {
//                // play the sound
//                if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
//                    audioPlayer.play()
//                }
//            })
//
//        // schedulePlaySoundTimer needs to be created when app goes to background
//        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer, closure: {
//            if let playSoundTimer = self.playSoundTimer {
//                playSoundTimer.resume()
//            }
//            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
//                audioPlayer.play()
//            }
//        })
//
//        // schedulePlaySoundTimer needs to be invalidated when app goes to foreground
//        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer, closure: {
//            if let playSoundTimer = self.playSoundTimer {
//                playSoundTimer.suspend()
//            }
//        })
    }
    
    /// verifies values of applicable UserDefaults and either starts or stops follower mode, inclusive call to enableSuspensionPrevention or disableSuspensionPrevention - also first download is started if applicable
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.nightScoutUrl != nil && UserDefaults.standard.nightScoutEnabled {
            
            // this will enable the suspension prevention sound playing
            enableSuspensionPrevention()
            
            // do initial download, this will also schedule future downloads
            download()
            
        } else {
            
            // disable the suspension prevention
            disableSuspensionPrevention()
            
            // invalidate the downloadtimer
            if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
                invalidateDownLoadTimerClosure()
            }
        }
    }
    
    // MARK:- observe function
    
    /// when user changes from master to follower or vice versa, processing is needed
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.isMaster, UserDefaults.Key.nightScoutUrl, UserDefaults.Key.nightScoutEnabled :
                    
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
    

}
