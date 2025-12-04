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

    /// Patient UID when following as caregiver (nil if patient account)
    private var caregiverPatientUserId: Int?

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
        // Setting follower patient name (used for caregiver mode)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerPatientName.rawValue, options: .new, context: nil)

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
                    trace("    login successful, userId = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, loginResponse.uid.description)

                    // Check if caregiver mode (patient name configured)
                    if let patientName = UserDefaults.standard.followerPatientName, !patientName.isEmpty {
                        trace("    caregiver mode detected, patient name = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, patientName)

                        let connections = try await self.requestCaregiverConnections()

                        if let patientUid = self.findPatientUid(in: connections) {
                            self.caregiverPatientUserId = patientUid
                            trace("    using patient UID = %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, patientUid.description)
                        } else {
                            trace("    ERROR: could not find patient with name '%{public}@'", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error, patientName)
                            throw MedtrumEasyViewFollowError.invalidResponse
                        }
                    } else {
                        // Patient account mode - use logged-in user's ID
                        self.caregiverPatientUserId = nil
                        trace("    patient mode (no patient name configured)", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                    }
                }

                // Step 2: Fetch monitor data
                // Use caregiverPatientUserId if set, otherwise use medtrumUserId
                let userIdToFetch = self.caregiverPatientUserId ?? self.medtrumUserId
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
                self.caregiverPatientUserId = nil
                self.lastFetchedTimestamp = nil  // Reset to fetch fresh data after re-login
            } catch MedtrumEasyViewFollowError.invalidCredentials {
                trace("    invalid credentials, preventing further login attempts", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error)
                UserDefaults.standard.medtrumEasyViewPreventLogin = true
                self.medtrumUserId = nil
                self.caregiverPatientUserId = nil
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

            if loginResponse.error == 0, loginResponse.uid > 0 {
                // Login successful, reset prevent login flag
                UserDefaults.standard.medtrumEasyViewPreventLogin = false
                return loginResponse
            } else {
                // Login failed due to invalid credentials
                throw MedtrumEasyViewFollowError.invalidCredentials
            }
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

    /// Find patient UID by matching configured patient name
    /// - parameter connections: Array of patient connections
    /// - returns: Patient UID if found, nil otherwise
    private func findPatientUid(in connections: [MedtrumEasyViewPatientConnection]) -> Int? {
        guard let patientName = UserDefaults.standard.followerPatientName,
              !patientName.isEmpty else {
            return nil
        }

        // Case-insensitive match on real_name
        let patient = connections.first { connection in
            connection.real_name.lowercased() == patientName.lowercased()
        }

        if let patient = patient {
            trace("    matched patient '%{public}@' with UID %{public}@", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info, patient.real_name, patient.uid.description)
        } else {
            trace("    could not find patient with name '%{public}@'", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .error, patientName)
        }

        return patient?.uid
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

    /// Verify UserDefaults and start or stop follower mode accordingly
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        trace("in verifyUserDefaultsAndStartOrStopFollowMode", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        // Check if we should be running
        let shouldRun = !UserDefaults.standard.isMaster &&
                       UserDefaults.standard.followerDataSourceType == .medtrumEasyView &&
                       UserDefaults.standard.medtrumEasyViewEmail != nil &&
                       UserDefaults.standard.medtrumEasyViewPassword != nil

        if shouldRun {
            trace("    starting Medtrum EasyView follower mode", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

            // Start background keep-alive if needed
            createPlaySoundTimer()

            // Start downloading
            download()
        } else {
            trace("    stopping Medtrum EasyView follower mode", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

            // Stop download timer
            invalidateDownLoadTimerClosure?()

            // Stop background keep-alive
            stopPlaySoundTimer()
        }
    }

    // MARK: - Background Keep-Alive Functions

    /// Create and start the play sound timer for background keep-alive
    private func createPlaySoundTimer() {
        // Only create if background keep-alive is enabled
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .disabled else {
            trace("    background keep-alive is disabled", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
            return
        }

        trace("in createPlaySoundTimer", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)

        // Stop existing timer if any
        stopPlaySoundTimer()

        // Add closures for app lifecycle events
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyResumePlaySoundTimer, closure: { [weak self] in
            self?.createPlaySoundTimer()
        })

        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeySuspendPlaySoundTimer, closure: { [weak self] in
            self?.stopPlaySoundTimer()
            self?.createPlaySoundTimer()
        })

        // Create repeating timer
        scheduleNewPlaySoundTimerRun()
    }

    /// Schedule a new play sound timer run
    private func scheduleNewPlaySoundTimerRun() {
        // Determine interval based on keep-alive type
        var interval = 30

        switch UserDefaults.standard.followerBackgroundKeepAliveType {
        case .disabled:
            return
        case .normal:
            interval = ConstantsSuspensionPrevention.intervalNormal
        case .aggressive:
            interval = ConstantsSuspensionPrevention.intervalAggressive
        case .heartbeat:
            return
        }

        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval)), eventHandler: { [weak self] in
            self?.playSound()
        })

        playSoundTimer?.resume()
    }

    /// Play silent sound to keep app alive in background
    private func playSound() {
        guard let audioPlayer = self.audioPlayer else { return }

        audioPlayer.play()
    }

    /// Stop the play sound timer
    private func stopPlaySoundTimer() {
        playSoundTimer?.suspend()
        playSoundTimer = nil
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

        case .medtrumEasyViewEmail, .medtrumEasyViewPassword, .followerPatientName:
            // Credentials or patient name changed, reset state
            if keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) {
                trace("    credentials or patient name changed, resetting state", log: self.log, category: ConstantsLog.categoryMedtrumEasyViewFollowManager, type: .info)
                self.medtrumUserId = nil
                self.caregiverPatientUserId = nil
                self.lastFetchedTimestamp = nil  // Reset to fetch full 24 hours on next download
                UserDefaults.standard.medtrumEasyViewPreventLogin = false
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
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerPatientName.rawValue)

        // Clean up timers
        invalidateDownLoadTimerClosure?()
        stopPlaySoundTimer()
    }
}
