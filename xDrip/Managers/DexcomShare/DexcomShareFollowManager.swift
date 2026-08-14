//
//  DexcomShareFollowManager.swift
//  xdrip
//
//  Created by Paul Plant on 4/9/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import Foundation
import os

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class DexcomShareFollowManager: NSObject {
    // MARK: - public properties
    
    // MARK: - private properties

    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = .init()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDexcomShareFollowManager)
    
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
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    private var dexcomShareSessionId: String?
    
    /// timestamp of last received reading. Used to scale the maxCount size when requesting data from Dexcom Share
    private var timeStampLastBgReading: Date?
    
    // MARK: - initializer/de-initializer
    
    /// initializes a new DexcomShareFollowManager instance.
    /// - Parameters:
    ///     - coreDataManager: The CoreDataManager instance for BG reading storage.
    ///     - followerDelegate: The delegate to receive BG reading updates.
    init(
        coreDataManager: CoreDataManager,
        followerDelegate: FollowerDelegate,
        backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging,
        startsInitialDownload: Bool = true
    ) {
        // clear failed login timestamp on init to always immediately allow a new login attempt
        UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.backgroundKeepAliveManager = backgroundKeepAliveManager
        self.startsInitialDownload = startsInitialDownload
        
        // initialize the sessionId
        self.dexcomShareSessionId = nil
        self.timeStampLastBgReading = nil
        trace("Session ID cleared on init", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
        
        // call super.init
        super.init()
        
        // add observers
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue, options: .new, context: nil)
        
        self.verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    /// Deinitializer. Removes observers, stops background keep-alive, and invalidates timers.
    deinit {
        // remove UserDefaults observers to avoid KVO crashes
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue)
        
        backgroundKeepAliveManager.stop(for: .dexcomShare)
        
        // invalidate any pending download timer
        self.invalidateDownLoadTimerClosure?()
    }
    
    // MARK: - public functions

    public func logIn() {
        trace(
            "user requested Dexcom Share login",
            log: log,
            category: ConstantsLog.categoryDexcomShareFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .dexcomShare, activity: .loginStarted))
        )
        UserDefaults.standard.dexcomShareManuallyLoggedOut = false
        UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
        FollowerSessionState.shared.update(.loggingIn, for: .dexcomShare)
        verifyUserDefaultsAndStartOrStopFollowMode()
    }

    public func logOut() {
        trace(
            "Dexcom Share logged out",
            log: log,
            category: ConstantsLog.categoryDexcomShareFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .dexcomShare, activity: .loggedOut))
        )
        UserDefaults.standard.dexcomShareManuallyLoggedOut = true
        invalidateDownLoadTimerClosure?()
        invalidateDownLoadTimerClosure = nil
        backgroundKeepAliveManager.stop(for: .dexcomShare)
        dexcomShareSessionId = nil
        FollowerSessionState.shared.update(.loggedOut, for: .dexcomShare)
    }
    
    /// Creates a BgReading object from a FollowerBgReading (Dexcom Share download).
    /// - Parameters
    ///     - followGlucoseData: The glucose data from Dexcom Share.
    /// - Returns: A new BgReading (not saved in Core Data).
    public func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        // Trace creation of BgReading
        trace("Creating BgReading for timestamp: %{public}@, sgv: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, String(describing: followGlucoseData.timeStamp), String(describing: followGlucoseData.sgv))
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
    
    /// Calculates the slope and whether to hide it based on the last two BG readings.
    /// - Returns: Tuple of (slope value, hideSlope flag).
    private func findSlope() -> (calculatedValueSlope: Double, hideSlope: Bool) {
        // init returnvalues
        var hideSlope = true
        var calculatedValueSlope = 0.0
        
        // get last readings
        let last2Readings = self.bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true)
        
        // if more thant 2 readings, calculate slope and hie
        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading: last2Readings[1])
            calculatedValueSlope = slope
            hideSlope = hide
        }
        
        return (calculatedValueSlope, hideSlope)
    }
    
    /// Schedule new download with timer, when timer expires download() will be called
    private func scheduleNewDownload() {
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut,
              UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        
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
    
    /// Downloads recent readings from Dexcom Share, sends result to delegate, and schedules the next download.
    @objc public func download() {
        trace("in download. Current session ID: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .detailed(.follower(source: .dexcomShare, activity: .downloadStarted)), String(describing: self.dexcomShareSessionId))
        
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? .distantPast).timeIntervalSinceNow < -15 {
            trace("    setting nightscoutSyncRequired to true, this will also initiate a treatments/devicestatus sync", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
        guard !UserDefaults.standard.isMaster else {
            trace("    not follower, returning", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            return
        }
        guard UserDefaults.standard.followerDataSourceType == .dexcomShare else {
            trace("    followerDataSourceType is not Dexcom Share", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            return
        }
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else {
            FollowerSessionState.shared.update(.loggedOut, for: .dexcomShare)
            return
        }
        
        let username = UserDefaults.standard.dexcomShareAccountName
        let password = UserDefaults.standard.dexcomSharePassword
        guard let username, let password else {
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // try and download, if it returns nil it's because we need to login
                if (try? await self.downloadAndProcessEGVs(force: true)) == nil {
                    FollowerSessionState.shared.update(.loggingIn, for: .dexcomShare)
                    try await self.login(username: username, password: password)
                    // The delegate receives the readings inside downloadAndProcessEGVs.
                    _ = try await self.downloadAndProcessEGVs(force: true)
                }
            } catch DexcomShareFollowError.sessionExpired {
                // re-login once and retry on expired session
                trace("    in download, session expired, re-logging in", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .info, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .sessionExpired)))
                do {
                    try await self.login(username: username, password: password)
                    _ = try await self.downloadAndProcessEGVs(force: true)
                } catch {
                    trace("    in download, session expired and re-login failed: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .error, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .loginFailed)), error.localizedDescription)
                }
            } catch {
                trace("    in download, error = %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .error, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .downloadFailed)), error.localizedDescription)
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
    
    /// Attempts login for the Dexcom Share account, trying all regions if necessary.
    /// - Parameters:
    ///     - username: Dexcom Share account username
    ///     - password: Dexcom Share account password
    /// - Throws: DexcomShareFollowError if login fails for all regions
    private func login(username: String, password: String) async throws {
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }
        trace(
            "Dexcom Share login started",
            log: log,
            category: ConstantsLog.categoryDexcomShareFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .dexcomShare, activity: .loginStarted))
        )

        // If a region is already stored, try only that region
        let storedRegion = UserDefaults.standard.dexcomShareRegion
        if storedRegion != .none {
            do {
                try await self.loginToRegion(region: storedRegion, username: username, password: password)
                trace("    in login, login successful using stored region: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .detailed(.follower(source: .dexcomShare, activity: .loginSucceeded)), storedRegion.description)
                return
            } catch {
                guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }
                trace("    in login, login failed using stored region: %{public}@, trying again with the other regions. Error: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, storedRegion.description, error.localizedDescription)
            }
        } else {
            trace("    in login, no previous stored DexcomShareRegion was found", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
        }
        
        // persist the error so that we can use it outside of the for loop
        var lastError: Error = DexcomShareFollowError.loginFailed
        
        // The stored region didn't work or there wasn't one stored, so try the other
        // regions (except the one we just tried) in order until one succeeds
        for region in DexcomShareRegion.allCases {
            guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }
            if region != .none && region != storedRegion {
                trace("    in login, attempting login to region: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .detailed(.follower(source: .dexcomShare, activity: .loginStarted)), region.description)
                do {
                    try await self.loginToRegion(region: region, username: username, password: password)
                    // On success, store the working region and clear the timestamp
                    UserDefaults.standard.dexcomShareRegion = region
                    UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
                    trace("    in login, login succeeded to region: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .detailed(.follower(source: .dexcomShare, activity: .loginSucceeded)), region.description)
                    return
                } catch {
                    guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }
                    trace("    in login, login failed for region: %{public}@, error: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, region.description, error.localizedDescription)
                    lastError = error
                }
            }
        }
        
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }

        // If all fail, clear the region and set loginFailedTimestamp
        UserDefaults.standard.dexcomShareRegion = .none
        UserDefaults.standard.dexcomShareLoginFailedTimestamp = Date()
        FollowerSessionState.shared.update(.loggedOut, for: .dexcomShare)
        trace("    in login, all region login attempts failed, setting loginFailedTimestamp. Error: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .loginFailed)), lastError.localizedDescription)
        throw lastError
    }
    
    /// Attempts login for a specific Dexcom Share region. Called from the main login() function.
    /// 2-step login process as per https://github.com/LoopKit/dexcom-share-client-swift/blob/dev/ShareClient/ShareClient.swift
    /// - Parameters:
    ///     - region: The DexcomShareRegion to try
    ///     - username: Dexcom Share account username
    ///     - password: Dexcom Share account password
    /// - Throws: DexcomShareFollowError if login fails for this region
    private func loginToRegion(region: DexcomShareRegion, username: String, password: String) async throws {
        // Step 1/2 - AUTH: Authenticate to get accountId
        var authRequest = URLRequest(url: region.baseURL.appendingPathComponent(ConstantsDexcomShare.dexcomShareFollowAuthPath))
        authRequest.httpMethod = "POST"
        authRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        authRequest.addValue("Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0", forHTTPHeaderField: "User-Agent")
        
        let authBody: [String: String] = ["accountName": username, "password": password, "applicationId": region.applicationID]
        authRequest.httpBody = try JSONSerialization.data(withJSONObject: authBody, options: [])
        
        let (authData, authResponse) = try await URLSession.shared.data(for: authRequest)
        let authStatusCode = (authResponse as? HTTPURLResponse)?.statusCode ?? 0
        
        if authStatusCode >= 400 {
            throw DexcomShareFollowError.authFailed
        }
        
        let accountId = (String(data: authData, encoding: .utf8) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if accountId.isEmpty {
            throw DexcomShareFollowError.authFailed
        }
        
        // Step 2/2 - LOGIN: Login by accountId
        var loginRequest = URLRequest(url: region.baseURL.appendingPathComponent(ConstantsDexcomShare.dexcomShareFollowLoginPath))
        loginRequest.httpMethod = "POST"
        loginRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.addValue("Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0", forHTTPHeaderField: "User-Agent")
        
        let loginBody: [String: String] = ["accountId": accountId, "password": password, "applicationId": region.applicationID]
        loginRequest.httpBody = try JSONSerialization.data(withJSONObject: loginBody, options: [])
        
        let (loginData, loginResponse) = try await URLSession.shared.data(for: loginRequest)
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { throw CancellationError() }
        let loginStatusCode = (loginResponse as? HTTPURLResponse)?.statusCode ?? 0
        
        if loginStatusCode >= 400 {
            throw DexcomShareFollowError.loginFailed
        }

        // the server can accept the accountId, return status 200 but with a dummy/failed session ID of "00000000-..."
        // so we need to check for this and if we found it, treat it also as a failed login.
        let sessionId = (String(data: loginData, encoding: .utf8) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if sessionId.isEmpty || sessionId == ConstantsDexcomShare.failedSessionId {
            throw DexcomShareFollowError.loginFailed
        }
        
        // we're now sucessfully logged in, so set the sessionId
        self.dexcomShareSessionId = sessionId
        FollowerSessionState.shared.update(.loggedIn, for: .dexcomShare)
    }
    
    /// Downloads and processes EGVs (glucose values) from Dexcom Share.
    /// - Parameters
    ///     - force: if true, bypasses the recent failed login timestamp check and always fetches
    /// - Returns: Array of DexcomEGV or nil if login is required
    /// - Throws: DexcomShareFollowError on error
    private func downloadAndProcessEGVs(force: Bool = false) async throws -> [DexcomEGV]? {
        // let's check and adjust the minimum data we need to request,
        // there's no reason the hammer the servers for no reason
        
        // use the last 24 hours as maximum as per the community documentation
        let minutesBackMax = 24 * 60
        let maxCountMax = minutesBackMax / 5
        
        // set the default as just getting the last reading in the last 6 minutes
        var minutesBack = 6
        var maxCount = 1
        
        // using the snapshot method for thread-safety
        // Dexcom Share fetch sizing must use the latest stored source reading,
        // not the latest visible downstream reading. This keeps the backfill
        // window stable when faster follower readings are reduced to 5 minutes.
        if let lastBgReading = bgReadingsAccessor.lastSnapshot(forSensor: nil, includingSuppressed: true) {
            let minutesSinceLastBgReading = Int((Date().timeIntervalSince1970 - lastBgReading.timeStamp.timeIntervalSince1970) / 60)
            
            if !force {
                guard minutesSinceLastBgReading >= 5 else {
                    trace("    in downloadAndProcessEGVs, last BG reading was %{public}@ minute(s) ago -> aborting fetch", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, minutesSinceLastBgReading)
                    return []
                }
            }
            
            // if more than 5 minutes since last reading, let's adjust the fetch window
            if minutesSinceLastBgReading > 9 {
                minutesBack = minutesSinceLastBgReading
                // with one reading every 5 minutes, cap at 24 hours (288 readings)
                maxCount = min(minutesSinceLastBgReading / 5, maxCountMax)
                trace("    in downloadAndProcessEGVs, last BG reading was %{public}@ minutes ago. Widening window to request %{public}@ previous readings to backfill", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, minutesSinceLastBgReading, maxCount)
            } else {
                trace("    in downloadAndProcessEGVs, no changes made, just going to pull the last %{public}@ readings", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, maxCount)
            }
        } else {
            // this will only usually happen if no BG readings are in core data,
            // in this case, let's just fetch 24 hours worth
            minutesBack = minutesBackMax
            maxCount = maxCountMax
            trace("    in downloadAndProcessEGVs, no previous BG values so will fetch 24 hours of data", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
            trace("    in downloadAndProcessEGVs,no data found, pulling 24 hours", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug)
        }
        
        do {
            // try and fetch values based upon the number of "missing" readings since the last succesful fetch
            // this will usually not need adjusting and we'll just request the last 1 reading
            let glucoseMeasurementsArray = try await downloadLatestEGVs(minutes: minutesBack, maxCount: maxCount)
            
            // if no data is returned, do nothing
            if glucoseMeasurementsArray.isEmpty {
                trace("    in downloadAndProcessEGVs, no glucose values returned", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .noReadings)))
                return []
            }
            
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
                guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { return }
                // call delegate followerInfoReceived which will process the new readings
                if let followerDelegate = self.followerDelegate {
                    var array = localCopy
                    followerDelegate.followerInfoReceived(followGlucoseDataArray: &array)
                }
            }
            trace("    in downloadAndProcessEGVs, download succeeded with %{public}d readings", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, troubleshooting: .standard(.follower(source: .dexcomShare, activity: .downloadSucceeded(readingCount: glucoseMeasurementsArray.count))), glucoseMeasurementsArray.count)
            return glucoseMeasurementsArray
        } catch let error as NSError where error.code == 401 {
            throw DexcomShareFollowError.invalidCredentials
        }
    }
    
    /// Downloads the latest EGVs from Dexcom Share for the given time window and count.
    /// - Parameters:
    ///     - minutes: how many minutes back to fetch.
    ///     - maxCount: maximum number of readings to fetch.
    /// - Returns: array of DexcomEGV.
    /// - Throws: DexcomShareFollowError on error.
    private func downloadLatestEGVs(minutes: Int = 1440, maxCount: Int = 3) async throws -> [DexcomEGV] {
        guard let dexcomShareSessionId else { throw DexcomShareFollowError.noSessionID }
        guard UserDefaults.standard.dexcomShareRegion != .none else { throw DexcomShareFollowError.noRegion }
        
        let region = UserDefaults.standard.dexcomShareRegion
        
        guard let componentsInitial = URLComponents(url: region.baseURL.appendingPathComponent(ConstantsDexcomShare.dexcomShareFollowLatestGlucoseValuesPath), resolvingAgainstBaseURL: false) else { throw DexcomShareFollowError.urlError }
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
        guard !UserDefaults.standard.dexcomShareManuallyLoggedOut else { return [] }
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            self.dexcomShareSessionId = nil
            FollowerSessionState.shared.update(.loggingIn, for: .dexcomShare)
            throw DexcomShareFollowError.sessionExpired
        }
        
        // store the current timestamp as a successful server connection
        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
        FollowerSessionState.shared.update(.loggedIn, for: .dexcomShare)
        
        do {
            return try JSONDecoder().decode([DexcomEGV].self, from: data)
        } catch {
            throw error
        }
    }
    
    /// Verifies settings and either starts or stops follower mode and its background keep-alive registration.
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.dexcomShareAccountName != nil && UserDefaults.standard.dexcomSharePassword != nil && !UserDefaults.standard.dexcomShareManuallyLoggedOut {
            FollowerSessionState.shared.update(.loggingIn, for: .dexcomShare)
            backgroundKeepAliveManager.start(for: .dexcomShare)

            guard startsInitialDownload else { return }
            
            // do initial download, this will also schedule future downloads
            self.download()
            
        } else {
            FollowerSessionState.shared.update(.loggedOut, for: .dexcomShare)
            backgroundKeepAliveManager.stop(for: .dexcomShare)
            
            // invalidate the downloadtimer
            if let invalidateDownLoadTimerClosure = invalidateDownLoadTimerClosure {
                invalidateDownLoadTimerClosure()
            }
            // Clear session and notify delegate with empty data
            self.dexcomShareSessionId = nil
            if let followerDelegate = self.followerDelegate {
                var emptyArray: [FollowerBgReading] = []
                followerDelegate.followerInfoReceived(followGlucoseDataArray: &emptyArray)
            }
        }
    }
    
    /// Parses a Dexcom date string (e.g. "/Date(1426780716000-0700)/") into a Date object.
    /// - Parameters
    ///     - dexcomDateString: The Dexcom date string.
    /// - Returns: Date if parsing succeeds, nil otherwise.
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
    
    // MARK: - overriden function
    
    /// Observes UserDefaults changes and triggers state reset if relevant keys change.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.dexcomShareAccountName, UserDefaults.Key.dexcomSharePassword:
                    trace("Dexcom Share credentials changed; logging out", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .info)
                    self.logOut()
                    UserDefaults.standard.dexcomShareRegion = .none
                    UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
                    UserDefaults.standard.timeStampOfLastFollowerConnection = nil

                case UserDefaults.Key.isMaster, UserDefaults.Key.followerDataSourceType:
                    trace("UserDefaults key changed: %{public}@", log: self.log, category: ConstantsLog.categoryDexcomShareFollowManager, type: .debug, keyPathEnum.rawValue)
                    // change by user, should not be done within 200 ms
                    if self.keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        // reset all login information so that we provoke a new intent
                        self.dexcomShareSessionId = nil
                        UserDefaults.standard.dexcomShareRegion = .none
                        UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
                        self.verifyUserDefaultsAndStartOrStopFollowMode()
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - DexcomShareFollowError

/// error throwing types for the follower
private enum DexcomShareFollowError: Error {
    case authFailed
    case loginFailed
    case emptySessionID
    case noSessionID
    case invalidCredentials
    case urlError
    case sessionExpired
    case noRegion
}

// MARK: CustomStringConvertible

/// make a custom description property to correctly log the error types
extension DexcomShareFollowError: CustomStringConvertible {
    var description: String {
        switch self {
        case .authFailed:
            return "Authorization Failed"
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
        case .noRegion:
            return "No region has been set/detected"
        }
    }
}
