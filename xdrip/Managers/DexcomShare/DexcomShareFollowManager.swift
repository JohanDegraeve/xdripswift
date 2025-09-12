//
//  DexcomShareFollowManager.swift
//  xdrip
//
//  Created by Paul Plant on 4/9/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import AudioToolbox
import AVFoundation
import Foundation
import os

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class DexcomShareFollowManager: NSObject {
    // MARK: - public properties
    
    // MARK: - private properties
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDexcomShareFollowManager)
    
    /// reference to coredatamanager
    private var coreDataManager: CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private(set) weak var followerDelegate: FollowerDelegate?
    
    /// AVAudioPlayer to use
    private var audioPlayer: AVAudioPlayer?
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create playsoundtimer
    private let applicationManagerKeyResumePlaySoundTimer = "DexcomShareFollowerManager-ResumePlaySoundTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - invalidate playsoundtimer
    private let applicationManagerKeySuspendPlaySoundTimer = "DexcomShareFollowerManager-SuspendPlaySoundTimer"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    /// timer for playsound
    private var playSoundTimer: RepeatingTimer?
    
    /// dexcom share url to use, calculated property
    private var dexcomShareUrlString: String {
        return UserDefaults.standard.useUSDexcomShareurl ? ConstantsDexcomShare.usBaseShareUrl : ConstantsDexcomShare.nonUsBaseShareUrl
    }
    
    private var dexcomShareLoginPath: String = "/General/LoginPublisherAccountByName"
    
    private var dexcomShareSessionId: String?
    
    /// timestamp of last received reading. Used to scale the maxCount size when requesting data from Dexcom Share
    private var timeStampLastBgReading: Date?
    

    // MARK: - initializer
    
    /// initializer
    public init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate) {
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        
        // initialize the sessionId
        self.dexcomShareSessionId = nil
        self.timeStampLastBgReading = nil
        
        // set up audioplayer
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            // create audioplayer
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                
            } catch {
                trace("in init, exception while trying to create audoplayer, error = %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .error, error.localizedDescription)
            }
        }
        
        // call super.init
        super.init()
        
        // changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        // changing the follower data source
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        // setting Dexcom Share username
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue, options: .new, context: nil)
        // setting Dexcom Share password
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue, options: .new, context: nil)
        
        self.verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    // MARK: - public functions
    
    /// creates a bgReading for a reading downloaded from Dexcom Share
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    public func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        // set the device name in the BG Reading, especially useful for later uploading the Nightscout
        let deviceName = ConstantsHomeView.applicationName + " (Dexcom Share)"
        
        // create new bgReading
        let bgReading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.sgv, deviceName: deviceName, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)
        
        // set calculatedValue
        bgReading.calculatedValue = followGlucoseData.sgv
        
        // set calculatedValueSlope
        let (calculatedValueSlope, hideSlope) = self.findSlope()
        bgReading.calculatedValueSlope = calculatedValueSlope
        bgReading.hideSlope = hideSlope
        
        return bgReading
    }
    
    // MARK: - private functions
    
    private func findSlope() -> (calculatedValueSlope: Double, hideSlope: Bool) {
        // init returnvalues
        var hideSlope = true
        var calculatedValueSlope = 0.0
        
        // get last readings
        let last2Readings = self.bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if more thant 2 readings, calculate slope and hie
        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading: last2Readings[1])
            calculatedValueSlope = slope
            hideSlope = hide
        }
        
        return (calculatedValueSlope, hideSlope)
    }
    
    /// schedule new download with timer, when timer expires download() will be called
    private func scheduleNewDownload() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }

        // invalidate any previously scheduled download timer before creating a new one
        if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
            invalidateDownLoadTimerClosure()
            self.invalidateDownLoadTimerClosure = nil
        }

        trace("in scheduleNewDownload", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)

        // schedule a timer for 60 seconds and assign it to a let property
        let downloadTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)

        // assign invalidateDownLoadTimerClosure to a closure that will invalidate the downloadTimer
        self.invalidateDownLoadTimerClosure = {
            downloadTimer.invalidate()
        }
    }
    
    /// download recent readings from Dexcom Share, send result to delegate, and schedule new download
    @objc public func download() {
        trace("in download", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)

        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? .distantPast).timeIntervalSinceNow < -15 {
            trace("    setting nightscoutSyncRequired to true, this will also initiate a treatments/devicestatus sync", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }

        guard !UserDefaults.standard.isMaster else {
            trace("    not follower", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            return
        }

        guard UserDefaults.standard.followerDataSourceType == .dexcomShare else {
            trace("    followerDataSourceType is not Dexcom Share", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            return
        }

        guard let username = UserDefaults.standard.dexcomShareAccountName, let password = UserDefaults.standard.dexcomSharePassword else { return }

        Task { [weak self] in
            guard let self = self else { return }
            do {
                // try and download, if it returns nil it's because we need to login
                if (try? await self.downloadAndProcessEGVs()) == nil {
                    try await self.login(username: username, password: password)
                    _ = try await self.downloadAndProcessEGVs() // ignore returned array here; delegate call happens inside
                }
            } catch DexcomShareFollowError.sessionExpired {
                // re-login once and retry on expired session
                do {
                    try await self.login(username: username, password: password)
                    _ = try await self.downloadAndProcessEGVs()
                } catch {
                    trace("    in download, session expired and re-login failed: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .error, error.localizedDescription)
                }
            } catch {
                trace("    in download, error = %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .error, error.localizedDescription)
            }
            // rescheduling the timer must be done on the main actor
            // we do it here at the end of the function so that it is always rescheduled once a valid connection is established, irrespective of whether we get values.
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // schedule new download
                self.scheduleNewDownload()
            }
        }
    }
    
    private func login(username: String, password: String) async throws {
        guard let dexcomShareUrl = URL(string: dexcomShareUrlString) else {
            throw DexcomShareFollowError.urlError
        }
        
        let url = dexcomShareUrl.appendingPathComponent(dexcomShareLoginPath)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0", forHTTPHeaderField: "User-Agent")
        
        let httpBody = DexcomShareLoginRequest(accountName: username, applicationId: ConstantsDexcomShare.applicationId, password: password)
        
        request.httpBody = try JSONEncoder().encode(httpBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        trace("    in login, server response status code: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, statusCode.description)

        trace("    in login, server response: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, String(data: data, encoding: String.Encoding.utf8) ?? "nil")
        
        if statusCode >= 400 {
            throw DexcomShareFollowError.loginFailed
        }
        
        // the session ID is returned as plain text with quotation marks around it, so we need to
        // remove these characters -> \" <- to get the clean string out with just valid characters
        let sessionId = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        guard !sessionId.isEmpty else {
            throw DexcomShareFollowError.emptySessionID
        }
        
        // push the session id back up the stack
        self.dexcomShareSessionId = sessionId
    }
    
    private func downloadAndProcessEGVs() async throws -> [DexcomEGV]? {
        // let's check and adjust the minimum data we need to request,
        // there's no reason the hammer the servers for no reason
        
        // use the last 24 hours as maximum as per the community documentation
        let minutesBackMax = 24 * 60
        let maxCountMax = minutesBackMax / 5
        
        // set the default as just getting the last reading in the last 6 minutes
        var minutesBack = 6
        var maxCount = 1
        
        // using the snapshot method for thread-safety
        if let lastBgReading = bgReadingsAccessor.lastSnapshot(forSensor: nil) {
            let minutesSinceLastBgReading = Int((Date().timeIntervalSince1970 - lastBgReading.timeStamp.timeIntervalSince1970)/60)
            
            guard minutesSinceLastBgReading >= 5 else {
                trace("    last BG reading was %{public}@ minute(s) ago -> aborting fetch", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, minutesSinceLastBgReading)
                return []
            }
            
            // if more than 5 minutes since last reading, let's adjust the fetch window
            if minutesSinceLastBgReading > 9 {
                minutesBack = minutesSinceLastBgReading
                // with one reading every 5 minutes, cap at 24 hours (288 readings)
                maxCount = min(minutesSinceLastBgReading / 5, maxCountMax)
                
                trace("    last BG reading was %{public}@ minutes ago. Widening window to request %{public}@ previous readings to backfill", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, minutesSinceLastBgReading, maxCount)
            } else {
                trace("    no changes made, just going to pull the last %{public}@ readings", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, maxCount)
            }
        } else {
            // this will only usually happen if no BG readings are in core data,
            // in this case, let's just fetch 24 hours worth
            minutesBack = minutesBackMax
            maxCount = maxCountMax
            
            trace("    in downloadAndProcessEGVs, no previous BG values so will fetch 24 hours of data", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            trace("    no data found, pulling 24 hours", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
        }
        
        do {
            // try and fetch values based upon the number of "missing" readings since the last succesful fetch
            // this will usually not need adjusting and we'll just request the last 1 reading
            let glucoseMeasurementsArray = try await downloadLatestEGVs(minutes: minutesBack, maxCount: maxCount)
            
            // if no data is returned, do nothing
            if glucoseMeasurementsArray.isEmpty { return [] }
            
            var followGlucoseDataArray: [FollowerBgReading] = []
            
            followGlucoseDataArray.reserveCapacity(glucoseMeasurementsArray.count)
            
            for glucoseMeasurement in glucoseMeasurementsArray {
                guard let timeStamp = parseDexcomDate(dexcomDateString: glucoseMeasurement.ST)?.timeIntervalSince1970 ?? parseDexcomDate(dexcomDateString: glucoseMeasurement.DT)?.timeIntervalSince1970 else { continue }

                let sgv = Double(glucoseMeasurement.Value)
                
                let bgReading = FollowerBgReading(timeStamp: Date(timeIntervalSince1970: timeStamp), sgv: sgv)
                
                followGlucoseDataArray.append(bgReading)
            }
            
            // sort by newest first
            followGlucoseDataArray.sort { $0.timeStamp > $1.timeStamp }
            
            // Dispatch to delegate on the main actor (use a local copy for the inout parameter)
            let localCopy = followGlucoseDataArray
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // call delegate followerInfoReceived which will process the new readings
                if let followerDelegate = self.followerDelegate {
                    var array = localCopy
                    followerDelegate.followerInfoReceived(followGlucoseDataArray: &array)
                }
            }
            
            return glucoseMeasurementsArray
            
        } catch let err as NSError where err.code == 401 {
            throw DexcomShareFollowError.invalidCredentials
        }
    }
    
    private func downloadLatestEGVs(minutes: Int = 1440, maxCount: Int = 3) async throws -> [DexcomEGV] {
        guard let dexcomShareSessionId else { throw DexcomShareFollowError.noSessionID }
        guard let baseURL = URL(string: dexcomShareUrlString) else { throw DexcomShareFollowError.urlError }
        guard let componentsInitial = URLComponents(url: baseURL.appendingPathComponent("/Publisher/ReadPublisherLatestGlucoseValues"), resolvingAgainstBaseURL: false) else { throw DexcomShareFollowError.urlError }
        var components = componentsInitial
        
        components.queryItems = [
            .init(name: "sessionId", value: dexcomShareSessionId),
            .init(name: "minutes", value: String(minutes)),
            .init(name: "maxCount", value: String(maxCount))
        ]
        
        guard let url = components.url else { throw DexcomShareFollowError.urlError }
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Dexcom Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data() // POST with empty body per community examples
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // force re-login and retry once
            self.dexcomShareSessionId = nil
            throw DexcomShareFollowError.sessionExpired
        }
        
        // store the current timestamp as a successful server connection
        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
        
        return try JSONDecoder().decode([DexcomEGV].self, from: data)
    }
    
    
    /// disable suspension prevention by removing the closures from ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground and ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground
    private func disableSuspensionPrevention() {
        // stop the timer for now, might be already suspended but doesn't harm
        if let playSoundTimer = playSoundTimer {
            playSoundTimer.suspend()
        }
        
        // no need anymore to resume the player when coming in foreground
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: self.applicationManagerKeyResumePlaySoundTimer)
        
        // no need anymore to suspend the soundplayer when entering foreground, because it's not even resumed
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeySuspendPlaySoundTimer)
    }
    
    /// launches timer that will regular play sound - this will be played only when app goes to background and only if the user wants to keep the app alive
    private func enableSuspensionPrevention() {
        // if keep-alive is disabled or if using a heartbeat, then just return and do nothing
        if !UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
            trace("not enabling suspension prevention as keep-alive type is: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, UserDefaults.standard.followerBackgroundKeepAliveType.description)
            
            return
        }
        
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal ? ConstantsSuspensionPrevention.intervalNormal : ConstantsSuspensionPrevention.intervalAggressive
        
        // create playSoundTimer depending on the keep-alive type selected
        self.playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval)), eventHandler: { [weak self] in
            guard let self = self else { return }
            // play the sound
            trace("in eventhandler checking if audioplayer exists", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .info)
            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                trace("playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .info, interval.description, UserDefaults.standard.followerDataSourceType.description, UserDefaults.standard.followerBackgroundKeepAliveType.description)
                audioPlayer.play()
            }
        })
        
        // schedulePlaySoundTimer needs to be created when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: self.applicationManagerKeyResumePlaySoundTimer, closure: { [weak self] in
            guard let self = self else { return }
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                if let playSoundTimer = self.playSoundTimer {
                    playSoundTimer.resume()
                }
                if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
            }
        })
        
        // schedulePlaySoundTimer needs to be invalidated when app goes to foreground
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: self.applicationManagerKeySuspendPlaySoundTimer, closure: { [weak self] in
            guard let self = self else { return }
            if let playSoundTimer = self.playSoundTimer {
                playSoundTimer.suspend()
            }
        })
    }
    
    /// verifies values of applicable UserDefaults and either starts or stops follower mode, inclusive call to enableSuspensionPrevention or disableSuspensionPrevention - also first download is started if applicable
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.dexcomShareAccountName != nil && UserDefaults.standard.dexcomSharePassword != nil {
            // this will enable the suspension prevention sound playing if background keep-alive is needed
            // (i.e. not disabled and not using a heartbeat)
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                self.enableSuspensionPrevention()
            } else {
                self.disableSuspensionPrevention()
            }
            
            // do initial download, this will also schedule future downloads
            self.download()
                        
        } else {
            // disable the suspension prevention
            self.disableSuspensionPrevention()
            
            // invalidate the downloadtimer
            if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
                invalidateDownLoadTimerClosure()
            }
        }
    }
    
    private func parseDexcomDate(dexcomDateString: String) -> Date? {
        // "/Date(1426780716000-0700)/" or "/Date(1426784306000)/"
        // extract epoch millis before the optional offset
        let digits = dexcomDateString.filter { "-0123456789".contains($0) }
        // find leading integer (ms)
        if let range = digits.range(of: "^-?\\d+", options: .regularExpression) {
            let millisecondsString = String(digits[range])
            if let milliseconds = Double(millisecondsString) {
                return Date(timeIntervalSince1970: milliseconds / 1000)
            }
        }
        
        return nil
    }
    
    deinit {
        // remove UserDefaults observers to avoid KVO crashes
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue)
        
        // stop keep-alive helpers
        self.disableSuspensionPrevention()
        
        // invalidate any pending download timer
        self.invalidateDownLoadTimerClosure?()
    }
    
    // MARK: - overriden function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.isMaster, UserDefaults.Key.followerDataSourceType, UserDefaults.Key.dexcomShareAccountName, UserDefaults.Key.dexcomSharePassword:
                    
                    // change by user, should not be done within 200 ms
                    if self.keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        self.verifyUserDefaultsAndStartOrStopFollowMode()
                    }
                    
                default:
                    break
                }
            }
        }
    }
}

// MARK: - overriden function

/// error throwing types for the follower
private enum DexcomShareFollowError: Error {
    case loginFailed
    case emptySessionID
    case noSessionID
    case invalidCredentials
    case urlError
    case sessionExpired
}

/// make a custom description property to correctly log the error types
extension DexcomShareFollowError: CustomStringConvertible {
    var description: String {
        switch self {
        case .loginFailed:
            return "Login Failed"
        case .emptySessionID:
            return "Empty Session ID"
        case .noSessionID:
            return "No Session ID"
        case .invalidCredentials:
            return "Invalid credentials (check 'Settings' > 'Connection Settings')"
        case .urlError:
            return "URL Error"
        case .sessionExpired:
            return "Session Expired"
        }
    }
}
