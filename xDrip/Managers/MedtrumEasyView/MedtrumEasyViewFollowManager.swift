//
//  MedtrumEasyViewFollowManager.swift
//  xdrip
//
//  Copyright © 2025 xDrip4iOS. All rights reserved.
//

import AudioToolbox
import AVFoundation
import Foundation
import os

/// Instance of this class will do the follower functionality for Medtrum EasyView.
/// Just make an instance, it will listen to the settings, do the regular download if needed
class MedtrumEasyViewFollowManager: NSObject {

    // MARK: - Public Properties

    // MARK: - Private Properties

    /// To solve problem that sometimes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()

    /// For logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryMedtrumEasyViewFollowManager)

    /// Reference to CoreDataManager
    private var coreDataManager: CoreDataManager

    /// Reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor

    /// Delegate to pass back glucose data
    private(set) weak var followerDelegate: FollowerDelegate?

    /// AVAudioPlayer to use for background keep-alive
    private var audioPlayer: AVAudioPlayer?

    /// Constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create playsoundtimer
    private let applicationManagerKeyResumePlaySoundTimer = "MedtrumEasyViewFollowManager-ResumePlaySoundTimer"

    /// Constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - invalidate playsoundtimer
    private let applicationManagerKeySuspendPlaySoundTimer = "MedtrumEasyViewFollowManager-SuspendPlaySoundTimer"

    /// Closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?

    /// Timer for playsound (background keep-alive)
    private var playSoundTimer: RepeatingTimer?

    /// User ID from login response (cached in memory)
    private var medtrumUserId: Int?

    /// Last successfully fetched timestamp to avoid re-downloading old data
    private var lastFetchedTimestamp: Date?

    // MARK: - Initializer

    /// Initializer
    public init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate) {
        // Initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate

        // Initialize user ID as nil
        self.medtrumUserId = nil

        // Set up audioplayer for background keep-alive
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            // Create audioplayer
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            } catch {
                trace("in init, exception while trying to create audioplayer, error = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error, error.localizedDescription)
            }
        }

        // Call super.init
        super.init()

        // Observe UserDefaults changes
        // Changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        // Changing the follower data source
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        // Setting Medtrum EasyView username
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewEmail.rawValue, options: .new, context: nil)
        // Setting Medtrum EasyView password
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewPassword.rawValue, options: .new, context: nil)
        // Setting Medtrum EasyView selected patient
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewSelectedPatientUid.rawValue, options: .new, context: nil)

        self.verifyUserDefaultsAndStartOrStopFollowMode()
    }

    // MARK: - Public Functions

    /// Creates a BgReading for reading downloaded from Medtrum EasyView
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    public func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        // Set the device name in the BG Reading, especially useful for later uploading to Nightscout
        let deviceName = ConstantsHomeView.applicationName + " (Medtrum EasyView)"

        // Create new bgReading
        let bgReading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.sgv, deviceName: deviceName, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)

        // Set calculatedValue
        bgReading.calculatedValue = followGlucoseData.sgv

        // Set calculatedValueSlope
        let (calculatedValueSlope, hideSlope) = self.findSlope()

        bgReading.calculatedValueSlope = calculatedValueSlope
        bgReading.hideSlope = hideSlope

        return bgReading
    }

    /// Download glucose data from Medtrum EasyView API
    @objc public func download() {
        trace("in download", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        // Check if follower mode is active
        guard !UserDefaults.standard.isMaster else {
            trace("    isMaster is true, not downloading", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return
        }

        // Check if Medtrum EasyView is selected as data source
        guard UserDefaults.standard.followerDataSourceType == .medtrumEasyView else {
            trace("    followerDataSourceType is not medtrumEasyView", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return
        }

        // Check if credentials exist
        guard UserDefaults.standard.medtrumEasyViewEmail != nil else {
            trace("    medtrumEasyViewEmail is nil", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return
        }

        guard UserDefaults.standard.medtrumEasyViewPassword != nil else {
            trace("    medtrumEasyViewPassword is nil", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return
        }

        Task {
            do {
                // Medtrum EasyView follower flow:
                // 1. Login and retrieve user ID (if not cached)
                // 2. Fetch monitor status with glucose data
                // 3. Process and deliver data to delegate

                // Step 1: Login if needed
                if self.medtrumUserId == nil {
                    let loginResponse = try await self.requestLogin()
                    self.medtrumUserId = loginResponse.uid
                    // need to cleanly unwrap because uid can technically be nil in a failed login response
                    if let uid = loginResponse.uid {
                        trace("    login successful, userId = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, uid.description)
                    }

                    // Cache user type
                    if let userType = loginResponse.user_type {
                        UserDefaults.standard.medtrumEasyViewUserType = userType
                        trace("    user type: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, userType)

                        // If caregiver account, fetch and cache connections
                        if userType == "M" {
                            trace("    caregiver account detected, fetching connections", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

                            do {
                                let connections = try await self.requestCaregiverConnections()

                                // Cache connections as JSON
                                if let jsonData = try? JSONEncoder().encode(connections) {
                                    UserDefaults.standard.medtrumEasyViewCachedConnections = jsonData
                                    UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = false
                                    trace("    cached %{public}@ patient connections", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, connections.count.description)

                                    // Handle patient selection with priority order
                                    let currentSelection = UserDefaults.standard.medtrumEasyViewSelectedPatientUid

                                    // Priority 1: Validate existing selection
                                    if currentSelection != 0 {
                                        // Check if currently selected patient still exists in the connections
                                        if !connections.contains(where: { $0.uid == currentSelection }) {
                                            // Previously selected patient no longer exists, reset to placeholder
                                            UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
                                            trace("    previously selected patient (UID: %{public}@) no longer exists, reset to placeholder", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, currentSelection.description)
                                        } else {
                                            trace("    keeping existing patient selection (UID: %{public}@)", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, currentSelection.description)
                                        }
                                    }
                                    // Priority 2: Auto-select single patient only if no selection
                                    else if connections.count == 1 {
                                        let singlePatient = connections[0]
                                        UserDefaults.standard.medtrumEasyViewSelectedPatientUid = singlePatient.uid
                                        trace("    auto-selected single patient: %{public}@ (UID: %{public}@)", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, singlePatient.displayName, singlePatient.uid.description)
                                        
                                        // Set the Follower Patient Name in the app. In case that there are several connections
                                        // we'll set this in the View Controller once a patient has been chosen
                                        UserDefaults.standard.followerPatientName = singlePatient.displayName
                                    }
                                }

                            } catch {
                                // Don't fail the entire download if connections fetch fails
                                // Keep using cached connections if available
                                UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = true
                                trace("    failed to fetch connections (will use cached): %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error, error.localizedDescription)
                            }
                        }
                    }
                }

                // Step 2: Fetch monitor data
                let selectedPatientUid = UserDefaults.standard.medtrumEasyViewSelectedPatientUid

                // For caregivers, require a patient to be selected before fetching data
                if UserDefaults.standard.medtrumEasyViewUserType == "M" && selectedPatientUid == 0 {
                    trace("    caregiver account with no patient selected, skipping data fetch", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                    return
                }

                // Use selected patient UID if caregiver mode and patient selected, otherwise use logged-in user
                let userIdToFetch = (UserDefaults.standard.medtrumEasyViewUserType == "M" && selectedPatientUid != 0) ?
                    selectedPatientUid : self.medtrumUserId
                if let userId = userIdToFetch {
                    let monitorResponse = try await self.requestMonitorStatus(userId: userId)

                    if let monitorData = monitorResponse.data {
                        trace("    monitor data downloaded successfully", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

                        // Step 3: Process glucose data
                        let followGlucoseDataArray = self.processGlucoseData(monitorData)

                        if !followGlucoseDataArray.isEmpty {
                            trace("    %{public}@ BG values processed", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, followGlucoseDataArray.count.description)

                            // Update last fetched timestamp to the most recent reading
                            // This ensures next fetch will only get newer data
                            if let mostRecent = followGlucoseDataArray.first {
                                self.lastFetchedTimestamp = mostRecent.timeStamp
                            }

                            // Dispatch to delegate on the main actor
                            let localCopy = followGlucoseDataArray
                            await MainActor.run { [weak self] in
                                guard let self = self else { return }
                                // Call delegate followerInfoReceived which will process the new readings
                                if let followerDelegate = self.followerDelegate {
                                    var array = localCopy
                                    followerDelegate.followerInfoReceived(followGlucoseDataArray: &array)
                                }
                            }
                        } else {
                            trace("    no glucose values were processed", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                        }
                    }
                }
            } catch MedtrumEasyViewFollowError.sessionExpired {
                trace("    session expired, will re-login on next download", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                self.medtrumUserId = nil
                self.lastFetchedTimestamp = nil  // Reset to fetch fresh data after re-login
                // Clear cached user type and connections
                UserDefaults.standard.medtrumEasyViewUserType = nil
                UserDefaults.standard.medtrumEasyViewCachedConnections = nil
                UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
                UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = false
            } catch MedtrumEasyViewFollowError.invalidCredentials {
                trace("    invalid credentials, preventing further login attempts", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error)
                UserDefaults.standard.medtrumEasyViewPreventLogin = true
                UserDefaults.standard.timeStampOfLastFollowerConnection = .distantPast
                self.medtrumUserId = nil
                // Clear cached user type and connections
                UserDefaults.standard.medtrumEasyViewUserType = nil
                UserDefaults.standard.medtrumEasyViewCachedConnections = nil
                UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
                UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = false
                self.lastFetchedTimestamp = nil  // Reset timestamp
            } catch MedtrumEasyViewFollowError.loginPreventedByUser {
                trace("    login prevented by user (invalid credentials previously detected)", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            } catch {
                // Log the error that was thrown
                trace("    in download, error = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error, error.localizedDescription)
            }

            // Rescheduling the timer must be done on the main actor
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.scheduleNewDownload()
            }
        }
    }

    // MARK: - Private Functions

    /// Find slope from last 2 readings
    private func findSlope() -> (calculatedValueSlope: Double, hideSlope: Bool) {
        var hideSlope = true
        var calculatedValueSlope = 0.0

        let last2Readings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading: last2Readings[1])
            calculatedValueSlope = slope
            hideSlope = hide
        }

        return (calculatedValueSlope, hideSlope)
    }

    /// Request login from Medtrum EasyView API
    /// - returns: Login response with user ID
    /// - throws: MedtrumEasyViewFollowError on failure
    private func requestLogin() async throws -> MedtrumEasyViewLoginResponse {
        trace("in requestLogin", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        // Check if login is prevented due to previous invalid credentials
        if UserDefaults.standard.medtrumEasyViewPreventLogin {
            throw MedtrumEasyViewFollowError.loginPreventedByUser
        }

        guard let email = UserDefaults.standard.medtrumEasyViewEmail,
              let password = UserDefaults.standard.medtrumEasyViewPassword else {
            throw MedtrumEasyViewFollowError.missingCredentials
        }

        // Build request body
        let loginRequest = MedtrumEasyViewLoginRequest(
            user_name: email,
            user_type: "P",
            password: password
        )

        guard let requestBody = try? JSONEncoder().encode(loginRequest) else {
            throw MedtrumEasyViewFollowError.invalidCredentials
        }

        // Build URL
        let urlString = ConstantsMedtrumEasyView.baseUrl + "/v3/api/v2.0/login"
        guard let url = URL(string: urlString) else {
            throw MedtrumEasyViewFollowError.networkError
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestBody

        // Add headers
        for (header, value) in ConstantsMedtrumEasyView.requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        trace("    in requestLogin, status code: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, statusCode.description)

        if statusCode == 200 {
            let loginResponse = try JSONDecoder().decode(MedtrumEasyViewLoginResponse.self, from: data)
            
            guard loginResponse.error == 0, let uid = loginResponse.uid, uid > 0 else {
                throw MedtrumEasyViewFollowError.invalidCredentials
            }
            
            // Login successful, reset prevent login flag
            UserDefaults.standard.medtrumEasyViewPreventLogin = false
            return loginResponse
        }

        throw MedtrumEasyViewFollowError.networkError
    }

    /// Request monitor status from Medtrum EasyView API
    /// - parameters:
    ///     - userId: User ID from login response
    /// - returns: Monitor status response with glucose data
    /// - throws: MedtrumEasyViewFollowError on failure
    private func requestMonitorStatus(userId: Int) async throws -> MedtrumEasyViewResponse<MedtrumEasyViewMonitorData> {
        trace("in requestMonitorStatus, userId = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, userId.description)

        let endTimestamp = Date().timeIntervalSince1970
        let startTimestamp: Double

        // Optimize: only fetch data since last successful fetch
        if let lastFetched = lastFetchedTimestamp {
            // Fetch from 2 minutes before last fetch to ensure no gaps (overlap is better than missing data)
            let overlapSeconds: Double = 120  // 2 minutes
            startTimestamp = lastFetched.timeIntervalSince1970 - overlapSeconds
        } else {
            // Initial fetch: get last 24 hours
            startTimestamp = endTimestamp - ConstantsMedtrumEasyView.maxTimeRangeSeconds
        }

        // Create param object
        let param = MedtrumEasyViewMonitorParam(ts: [startTimestamp, endTimestamp], tz: 0)

        // Encode to JSON then Base64
        guard let jsonData = try? JSONEncoder().encode(param),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MedtrumEasyViewFollowError.invalidResponse
        }

        let base64Param = Data(jsonString.utf8).base64EncodedString()

        // Build URL with Base64 query parameter
        let urlString = "\(ConstantsMedtrumEasyView.baseUrl)/api/v2.1/monitor/\(userId)/status?param=\(base64Param)"
        guard let url = URL(string: urlString) else {
            throw MedtrumEasyViewFollowError.networkError
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add headers
        for (header, value) in ConstantsMedtrumEasyView.requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        trace("    in requestMonitorStatus, status code: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, statusCode.description)

        // Check for session expiry
        if statusCode == 401 || statusCode == 403 {
            throw MedtrumEasyViewFollowError.sessionExpired
        }

        if statusCode == 200 {
            let monitorResponse = try JSONDecoder().decode(MedtrumEasyViewResponse<MedtrumEasyViewMonitorData>.self, from: data)

            // Check for session expiry via error code
            if monitorResponse.error == 4001 {
                throw MedtrumEasyViewFollowError.sessionExpired
            }

            if monitorResponse.error == 0 {
                // Update last successful connection timestamp
                UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
                return monitorResponse
            }
        }

        throw MedtrumEasyViewFollowError.networkError
    }

    /// Fetch list of connected patients for caregiver account
    /// - returns: Array of patient connections
    /// - throws: MedtrumEasyViewFollowError on failure
    private func requestCaregiverConnections() async throws -> [MedtrumEasyViewPatientConnection] {
        trace("in requestCaregiverConnections", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        let urlString = "\(ConstantsMedtrumEasyView.baseUrl)/v3/api/v2.1/monitor/connections?per_page=9999"
        guard let url = URL(string: urlString) else {
            throw MedtrumEasyViewFollowError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add headers
        for (header, value) in ConstantsMedtrumEasyView.requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        trace("    in requestCaregiverConnections, status code: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, statusCode.description)

        // Check for session expiry
        if statusCode == 401 || statusCode == 403 {
            throw MedtrumEasyViewFollowError.sessionExpired
        }

        if statusCode == 200 {
            let connectionsResponse = try JSONDecoder().decode(
                MedtrumEasyViewResponse<MedtrumEasyViewConnectionsData>.self,
                from: data
            )

            if connectionsResponse.error == 0, let connectionsData = connectionsResponse.data {
                trace("    found %{public}@ connected patients", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, connectionsData.items.count.description)
                return connectionsData.items
            }
        }

        throw MedtrumEasyViewFollowError.networkError
    }

    /// Process glucose data from monitor status response
    /// - parameters:
    ///     - data: Monitor data containing glucose readings
    /// - returns: Array of FollowerBgReading objects, sorted newest first
    private func processGlucoseData(_ data: MedtrumEasyViewMonitorData) -> [FollowerBgReading] {
        var readings: [FollowerBgReading] = []

        guard let chart = data.chart,
              let sgArray = chart.sg,
              !sgArray.isEmpty else {
            trace("    no glucose data in response", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return readings
        }

        // Check if glucose is in mmol/L
        let isInMmol = (chart.glucose_unit == "mmol/L")

        trace("    processing %{public}@ glucose entries, unit = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, sgArray.count.description, chart.glucose_unit ?? "unknown")

        // Process each glucose entry
        for entry in sgArray {
            // Create measurement from entry
            let measurement = MedtrumEasyViewGlucoseMeasurement(entry: entry)

            // Only process valid status codes
            // "C" = Current/Normal readings
            // Skip: "H" = Warmup, "IC" = InCalib, "NC" = NoCalib, "CE0"/"CE1" = Error
            if measurement.status != "C" {
                // Don't trace every skip, too verbose
                continue
            }

            // Validate timestamp is not in the future
            guard measurement.timestamp <= Date() else {
                trace("    skipping future timestamp: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, measurement.timestamp.description)
                continue
            }

            // Convert glucose value to mg/dL if needed
            let glucoseMgdl = isInMmol ? measurement.glucoseInMmol * ConstantsMedtrumEasyView.mmolToMgdlFactor : measurement.glucoseInMmol

            // Validate glucose value is reasonable
            guard glucoseMgdl >= 20 && glucoseMgdl <= 600 else {
                trace("    skipping invalid glucose value: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, glucoseMgdl.description)
                continue
            }

            // Create FollowerBgReading
            let reading = FollowerBgReading(timeStamp: measurement.timestamp, sgv: glucoseMgdl)
            readings.append(reading)
        }

        // Sort chronologically, newest first
        readings.sort { $0.timeStamp > $1.timeStamp }

        return readings
    }

    /// Schedule next download
    private func scheduleNewDownload() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }

        trace("in scheduleNewDownload", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        // Schedule a timer for 60 seconds
        let downloadTimer = Timer.scheduledTimer(timeInterval: ConstantsMedtrumEasyView.pollingIntervalSeconds, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)

        // Assign invalidateDownLoadTimerClosure to a closure that will invalidate the downloadTimer
        self.invalidateDownLoadTimerClosure = {
            downloadTimer.invalidate()
        }
    }
    
    // MARK: - Background Keep-Alive Functions
    
    /// disable suspension prevention by removing the closures from ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground and ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground
    private func disableSuspensionPrevention() {
        // stop the timer for now, might be already suspended but doesn't harm
        if let playSoundTimer = playSoundTimer {
            playSoundTimer.suspend()
        }
        
        // no need anymore to resume the player when coming in foreground
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer)
        
        // no need anymore to suspend the soundplayer when entering foreground, because it's not even resumed
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer)
    }
    
    /// launches timer that will regular play sound - this will be played only when app goes to background and only if the user wants to keep the app alive
    private func enableSuspensionPrevention() {
        // if keep-alive is not needed, then just return and do nothing
        if !UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
            trace("not enabling suspension prevention as keep-alive type is: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .debug, UserDefaults.standard.followerBackgroundKeepAliveType.description)
            return
        }
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal ? ConstantsSuspensionPrevention.intervalNormal : ConstantsSuspensionPrevention.intervalAggressive
        // create playSoundTimer depending on the keep-alive type selected
        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval)), eventHandler: { [weak self] in
            guard let self = self else { return }
            // play the sound
            trace("in eventhandler checking if audioplayer exists", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                trace("playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, interval.description, UserDefaults.standard.followerDataSourceType.description, UserDefaults.standard.followerBackgroundKeepAliveType.description)
                audioPlayer.play()
            }
        })
        // schedulePlaySoundTimer needs to be created when app goes to background
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer, closure: { [weak self] in
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
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer, closure: { [weak self] in
            guard let self = self else { return }
            if let playSoundTimer = self.playSoundTimer {
                playSoundTimer.suspend()
            }
        })
    }

    /// Verify UserDefaults and start or stop follower mode accordingly
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        // Check if we should be running
        let shouldRun = !UserDefaults.standard.isMaster &&
                       UserDefaults.standard.followerDataSourceType == .medtrumEasyView &&
                       UserDefaults.standard.medtrumEasyViewEmail != nil &&
                       UserDefaults.standard.medtrumEasyViewPassword != nil

        if shouldRun {
            // this will enable the suspension prevention sound playing if background keep-alive is needed
            // (i.e. not disabled and not using a heartbeat)
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                self.enableSuspensionPrevention()
            } else {
                self.disableSuspensionPrevention()
            }

            // Start downloading
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
    
    // MARK: - KVO Observer

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else {
            return
        }

        switch keyPathEnum {
        case .isMaster, .followerDataSourceType:
            if keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) {
                verifyUserDefaultsAndStartOrStopFollowMode()
            }

        case .medtrumEasyViewEmail, .medtrumEasyViewPassword:
            // Credentials changed, clear everything
            if keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) {
                trace("    credentials changed, resetting state", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                self.medtrumUserId = nil
                self.lastFetchedTimestamp = nil
                // Clear cached user type, connections, and selection
                UserDefaults.standard.medtrumEasyViewUserType = nil
                UserDefaults.standard.medtrumEasyViewCachedConnections = nil
                UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
                UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = false
                UserDefaults.standard.medtrumEasyViewPreventLogin = false
                verifyUserDefaultsAndStartOrStopFollowMode()
            }

        case .medtrumEasyViewSelectedPatientUid:
            // Selected patient changed, only reset user ID and timestamp to trigger refetch
            if keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) {
                trace("    selected patient changed, resetting user ID to trigger refetch", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                self.medtrumUserId = nil
                self.lastFetchedTimestamp = nil
                verifyUserDefaultsAndStartOrStopFollowMode()
            }

        default:
            break
        }
    }

    // MARK: - Deinit

    deinit {
        // Remove observers
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewEmail.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewPassword.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewSelectedPatientUid.rawValue)
        
        // stop keep-alive helpers
        disableSuspensionPrevention()

        // invalidate any pending download timer
        invalidateDownLoadTimerClosure?()
    }
}
