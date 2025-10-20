//
//  LibreLinkUpFollowManager.swift
//  xdrip
//
//  Created by Paul Plant on 26/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import AudioToolbox
import AVFoundation
import Foundation
import os

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class LibreLinkUpFollowManager: NSObject {
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreLinkUpFollowManager)
    
    /// reference to coredatamanager
    private var coreDataManager: CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private(set) weak var followerDelegate: FollowerDelegate?
    
    /// AVAudioPlayer to use
    private var audioPlayer: AVAudioPlayer?
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - create playsoundtimer
    private let applicationManagerKeyResumePlaySoundTimer = "LibreLinkUpFollowerManager-ResumePlaySoundTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground - invalidate playsoundtimer
    private let applicationManagerKeySuspendPlaySoundTimer = "LibreLinkUpFollowerManager-SuspendPlaySoundTimer"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    /// timer for playsound
    private var playSoundTimer: RepeatingTimer?
    
    /// http header array - need to append "version" key before making request
    /// https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#headers
    private let libreLinkUpRequestHeaders = ConstantsLibreLinkUp.libreLinkUpRequestHeaders
    
    /// keeps track of the api region in order to generate the correct URL
    private var libreLinkUpRegion: LibreLinkUpRegion?
    
    /// login auth ticket string
    private var libreLinkUpToken: String?
    
    /// login auth ticket expiry date as double
    private var libreLinkUpExpires: Double?
    
    /// User ID used to get connections (list of patient IDs)
    private var libreLinkUpId: String?
    
    /// Patient ID used to get graph data
    private var libreLinkUpPatientId: String?
    
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
        decoder.dateDecodingStrategy = .formatted(self.dateFormatter)
        return decoder
    }()
    
    // MARK: - initializer
    
    /// initializer
    public init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate) {
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        
        // initialize the LibreLinkUpRegion
        self.libreLinkUpRegion = .notConfigured
        self.libreLinkUpId = nil
        self.libreLinkUpPatientId = nil
        
        // run a quick check to see if the LibreLinkUp version stored in the constants file is newer than the one currently stored in the app. If it is, then update it. This will only happen if the user hasn't manually updated it before a new xDrip4iOS version is released.
        if ConstantsLibreLinkUp.libreLinkUpVersionDefault.compare(UserDefaults.standard.libreLinkUpVersion ?? "0.0.0", options: .numeric) == .orderedDescending {
            trace("in init, updating userdefaults LibreLinkUp version from '%{public}@' to '%{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, UserDefaults.standard.libreLinkUpVersion ?? "nil", ConstantsLibreLinkUp.libreLinkUpVersionDefault)
            
            UserDefaults.standard.libreLinkUpVersion = ConstantsLibreLinkUp.libreLinkUpVersionDefault
        }
        
        // set up audioplayer
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            // create audioplayer
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                
            } catch {
                trace("in init, exception while trying to create audoplayer, error = %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .error, error.localizedDescription)
            }
        }
        
        // call super.init
        super.init()
        
        // changing from follower to master or vice versa
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        // changing the follower data source
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        // setting LibreLinkUp username
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpEmail.rawValue, options: .new, context: nil)
        // setting LibreLinkUp password
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpPassword.rawValue, options: .new, context: nil)
        
        self.verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    // MARK: - public functions
    
    /// creates a bgReading for reading downloaded from LibreLinkUp
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    public func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        // set the device name in the BG Reading, especially useful for later uploading the Nightscout
        let deviceName = ConstantsHomeView.applicationName + " (LibreLinkUp)"
        
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
    
    /// download recent readings from LibreView, send result to delegate, and schedule new download
    @objc public func download() {
        trace("in download", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? .distantPast).timeIntervalSinceNow < -15 {
            trace("    setting nightscoutSyncRequired to true, this will also initiate a treatments/devicestatus sync", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
        
        guard !UserDefaults.standard.isMaster else {
            trace("    not follower", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            return
        }
        
        guard UserDefaults.standard.followerDataSourceType == .libreLinkUp || UserDefaults.standard.followerDataSourceType == .libreLinkUpRussia else {
            trace("    followerDataSourceType is not libreLinkUp", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            return
        }

        guard UserDefaults.standard.libreLinkUpEmail != nil else {
            trace("    libreLinkUpEmail is nil", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            return
        }

        guard UserDefaults.standard.libreLinkUpPassword != nil else {
            trace("    libreLinkUpPassword is nil", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            return
        }

        Task {
            do {
                // LibreLink follower based upon process outlined here:
                // https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2
                //
                // To get cgm data from the api it is required to fire at least three requests:
                //
                // 1. Login and retrieve JWT token
                // 2. With the token, then get connections of patients to get a patientId
                // 3. Retrieve cgm graph data of the specific patientId
                
                // this takes care of 1 and 2
                try await self.checkLoginAndConnections()
                
                // this takes care of 3
                if self.libreLinkUpToken != nil && self.libreLinkUpPatientId != nil {
                    guard let patientId = self.libreLinkUpPatientId else { return }
                    
                    // at this stage, we've now got a valid authentication token and we know the patientId we need to follow
                    let graphResponse = try await requestGraph(patientId: patientId)
                    
                    // before processing the glucoseMeasurement values, let's set up the sensor info in coredata so that we can show it to the user in the settings screen
                    // starting with LLU 4.12.0 this data sometimes isn't sent for some users so we'll try and use it if available and if not, just try to get it from the data.connection and if not, just continue as normal without throwing an error
                    if let startDate = graphResponse.data?.activeSensors?.first?.sensor?.a, let serialNumber = graphResponse.data?.activeSensors?.first?.sensor?.sn, serialNumber != "" {
                        setActiveSensorInfo(serialNumber: serialNumber, startDateAsDouble: startDate)
                        
                        // if no sensor info was found in data.activeSensor attributes, try and find it in the data.connection response
                    } else if let startDate = graphResponse.data?.connection?.sensor?.a, let serialNumber = graphResponse.data?.connection?.sensor?.sn, serialNumber != "" {
                        setActiveSensorInfo(serialNumber: serialNumber, startDateAsDouble: startDate)
                    } else {
                        // this will only happen if the account doesn't have an active sensor connected
                        // reset the data just in case it was previously stored
                        self.resetActiveSensorData()
                        
                        // for some reason no active sensor data was sent by the server. This seems to sometimes happen since LLU v4.12.0 for some users and for some (unknown) reason.
                        // instead of throwing an error, we'll just continue as normal and hide later (in the UI) the sensor information
                        trace("    in download, no active sensor data was returned by the server so just process the values if any", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
                    }
                    
                    // now let's tidy up the historical glucoseMeasurements (if it exists) into a nice array and then append the current glucoseMeasurement
                    let glucoseMeasurementsArray = (graphResponse.data?.graphData ?? []) + [graphResponse.data?.connection?.glucoseMeasurement]
                    
                    // make a quick check in case the graphResponse returns nil for both graphData and even the glucoseMeasurement attributes
                    // this can happen if somebody tries to read from a new account before they've even started uploading any sensor values to it
                    if glucoseMeasurementsArray.count > 0, glucoseMeasurementsArray[0] != nil {
                        trace("    in download, %{public}@ BG values downloaded", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, glucoseMeasurementsArray.count.description)
                        
                        // create an empty array of FollowerBgReading(s)
                        var followGlucoseDataArray = [FollowerBgReading]()
                        
                        self.processDownloadResponse(data: glucoseMeasurementsArray, followGlucoseDataArray: &followGlucoseDataArray)
                        
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
                    } else {
                        trace("    in download, no glucose values were downloaded. Nothing to process and send to the delegate.", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, glucoseMeasurementsArray.count.description)
                    }
                }
            } catch {
                // log the error that was thrown. As it doesn't have a specific handler, we'll assume no further actions are needed
                trace("    in download, error = %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .error, error.localizedDescription)
            }
            
            // rescheduling the timer must be done on the main actor
            // we do it here at the end of the function so that it is always rescheduled once a valid connection is established, irrespective of whether we get values.
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.scheduleNewDownload()
            }
        }
    }
    
    /// store the active sensor serial number and start date in userdefaults
    /// also calculate and store the max sensor age
    /// the serial number will be re-constructed to add the missing digits as needed
    private func setActiveSensorInfo(serialNumber: String, startDateAsDouble: Double) {
        
        guard serialNumber != "" else { return }
        
        UserDefaults.standard.activeSensorSerialNumber = serialNumber
        UserDefaults.standard.activeSensorStartDate = Date(timeIntervalSince1970: startDateAsDouble)
        UserDefaults.standard.activeSensorMaxSensorAgeInDays = UserDefaults.standard.libreLinkUpIs15DaySensor ? ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDaysLibrePlus : ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDays
        
        var activeSensorDescription = ""
        
        if serialNumber.range(of: #"^MH"#, options: .regularExpression) != nil {
            // 3MHxxxxxxxx
            // must be a Libre 2 or Libre 2 Plus sensor
            activeSensorDescription = "Libre 2"
            
        } else if serialNumber.range(of: #"^01"#, options: .regularExpression) != nil {
            // 301xxxxxxxx
            // must be a Libre 2 Plus sensor
            activeSensorDescription = "Libre 2 Plus"
            
        } else if serialNumber.range(of: #"^0[D-Z]"#, options: .regularExpression) != nil {
            // must be a Libre 3 (or Libre 3 Plus) sensor
            activeSensorDescription = "Libre 3"
            // overwrite and drop the last digit for L3 serial number: https://github.com/JohanDegraeve/xdripswift/issues/666
            UserDefaults.standard.activeSensorSerialNumber = String(serialNumber.dropLast())
        }
        
        UserDefaults.standard.activeSensorDescription = UserDefaults.standard.followerDataSourceType.fullDescription + " (" + activeSensorDescription + ")"
        
        return
    }
    
    /// if needed, perform a login request and retreive authentication token and expiry date. Then retreive the patient ID.
    private func checkLoginAndConnections() async throws {
        // if there is no authentication token or if the token expiry date is expired, then make a new login request
        if self.libreLinkUpToken == nil || (self.libreLinkUpExpires ?? 0) < (Date().toMillisecondsAsDouble() / 1000) || self.libreLinkUpPatientId == nil {
            trace("    in checkLoginAndConnections, auth token is nil or is expired so processing new login request", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            
            do {
                // let's process a login request to the server. If it is successful, then we will process a connections request to get the patient ID
                
                let requestLoginResponse = try await requestLogin()
                
                if requestLoginResponse.status == 2 {
                    throw LibreLinkUpFollowError.invalidCredentials
                }
                
                // if the response status = 4 then we'll the user needs to accept the latest Terms Of Use before we can get a valid response with the userID and other required information
                if requestLoginResponse.status == 4 {
                    throw LibreLinkUpFollowError.reAcceptNeeded
                }
                
                // when trying to do a login request with a URL that doesn't match the user's country/region, the json returned by the server with not contain the expected name-value pairs. It *will* contain two new ones: redirect and region.
                // for example, if we are trying to use the global/generic URL for a EU user and the LibreLinkUp server requires us to use a distinct region, we'll get:
                // - Login URL: https://api.libreview.io/llu/auth/login
                // - Login request response: {"status":0,"data":{"redirect":true,"region":"eu"}}
                // so if we always try and logon first with the generic URL, we should be able to use this redirect response to pull the correct region and then repeat the login request as needed. If it works without requiring a redirect, then we can just continue to use the generic/global URL.
                if let redirect = requestLoginResponse.data?.redirect, redirect, let region = requestLoginResponse.data?.region, !region.isEmpty {
                    let newRegion = LibreLinkUpRegion(from: region)
                    
                    trace("    in checkLoginAndConnections, redirect flag received. Switching region from '%{public}@' to '%{public}@' and calling again checkLoginAndConnections()", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, self.libreLinkUpRegion?.description ?? "nil", newRegion?.description ?? "nil")
                    
                    self.libreLinkUpRegion = newRegion
                    
                    try await self.checkLoginAndConnections()
                    
                    return
                }
                
                // so the login request seems to have worked. Let's mark sure we can get the user id, the auth token and it's expiry date
                guard let userId = requestLoginResponse.data?.user?.id, let token = requestLoginResponse.data?.authTicket?.token, let expires = requestLoginResponse.data?.authTicket?.expires
                else {
                    throw LibreLinkUpFollowError.missingPayLoad
                }
                
                // let's only update userdefaults if really necessary (i.e. if a new value is obtained, which it shouldn't be after the initial login has already been done)
                if let country = requestLoginResponse.data?.user?.country {
                    if UserDefaults.standard.libreLinkUpCountry != country {
                        UserDefaults.standard.libreLinkUpCountry = country
                    }
                }
                
                trace("    in checkLoginAndConnections, retrieved user id is: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, userId)
                
                trace("    in checkLoginAndConnections, token expires on: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, Date(timeIntervalSince1970: expires).description)
                
                // update the private vars
                self.libreLinkUpId = userId
                self.libreLinkUpToken = token
                self.libreLinkUpExpires = expires
                
                // update the coredata region to allow it to display in the rest of the UI - this will trigger a UI refresh of the settings screen
                UserDefaults.standard.libreLinkUpRegion = self.libreLinkUpRegion
                
                // we've got a successful login so let's reset to false all possible warning flags
                UserDefaults.standard.libreLinkUpPreventLogin = false
                UserDefaults.standard.libreLinkUpReAcceptNeeded = false
                
                // so now we've got a valid authenticated login so we can pull the patient ID from the connections endpoint
                // https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#get-connections
                
                if self.libreLinkUpPatientId == nil {
                    let connectionsResponse = try await requestConnections()
                    
                    guard let patientId = connectionsResponse.data?.first(where: { $0.patientId == userId })?.patientId ?? connectionsResponse.data?.first?.patientId else {
                        throw LibreLinkUpFollowError.invalidPatientId
                    }
                    
                    trace("    in checkLoginAndConnections, patient id is: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, patientId.description)
                    
                    self.libreLinkUpPatientId = patientId
                }
                
            } catch LibreLinkUpFollowError.reAcceptNeeded {
                trace("    in checkLoginAndConnections, login failed with status 4. New terms of use or privacy policy must be accepted first", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
                
                UserDefaults.standard.libreLinkUpReAcceptNeeded = true
                
                self.resetActiveSensorData()
                
            } catch LibreLinkUpFollowError.invalidCredentials {
                // we could just throw/cascade the same error back to the parent function and handle it there, but let's be redundant to make it clear what we're doing
                trace("    in checkLoginAndConnections, requestLogin threw and error and exited before login due to previous bad credentials. This will be reset when the user updates their user/password.", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
                
                // make sure we don't try and login again until the user updates their account info
                UserDefaults.standard.libreLinkUpPreventLogin = true
                
                self.resetActiveSensorData()
                
            } catch {
                // log the error that was thrown. As it doesn't have a specific handler, we'll assume no further actions are needed
                trace("    in checkLoginAndConnections, error = %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .error, error.localizedDescription)
            }
            
        } else {
            trace("    in checkLoginAndConnections, skipping as token and patient ID already exist", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        }
    }
    
    /// if needed, perform a login request and retreive authentication token and expiry date.
    /// based upon: https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#login
    /// - Parameters:
    ///     - none
    /// - Returns: Response<RequestLoginResponse>, a json object with the server response to the login request
    private func requestLogin() async throws -> Response<RequestLoginResponse> {
        if UserDefaults.standard.libreLinkUpPreventLogin {
            throw LibreLinkUpFollowError.invalidCredentials
        }
        
        // LibreLinkUpUp username, password and URL must exist for this function to be able to run.
        guard let libreLinkUpEmail = UserDefaults.standard.libreLinkUpEmail, let libreLinkUpPassword = UserDefaults.standard.libreLinkUpPassword else {
            throw LibreLinkUpFollowError.missingCredentials
        }
        
        trace("    in requestLogin, running login request", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        // create the authorization credentials
        guard let authCredentials = try? JSONSerialization.data(withJSONObject: [
            "email": libreLinkUpEmail,
            "password": libreLinkUpPassword,
        ]) else {
            throw LibreLinkUpFollowError.invalidCredentials
        }
        
        // if no region has been previously set, then use the generic login URL. This will give a valid 200 status code, but with no data payload except for a redirect flag and the correct region for the user account
        if self.libreLinkUpRegion == .notConfigured {
            trace("    in requestLogin, no region stored, will try and login with generic URL and see if we get redirected", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        }
        
        guard let loginUrl = self.libreLinkUpRegion?.urlLogin else {
            throw LibreLinkUpFollowError.urlErrorLogin
        }
        
        trace("    in requestLogin, processing login request with URL: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, loginUrl)
        
        guard let url = URL(string: loginUrl) else {
            throw LibreLinkUpFollowError.urlErrorLogin
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = authCredentials
        
        for (header, value) in self.libreLinkUpRequestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        // dynamically set the version number from userdefaults. This will allow the user to update the version number manually without waiting for an app update in case it is changed
        request.setValue(UserDefaults.standard.libreLinkUpVersion, forHTTPHeaderField: "version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        trace("    in requestLogin, server response status code: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, statusCode.description)
        
        trace("    in requestLogin, server response: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, String(data: data, encoding: String.Encoding.utf8) ?? "nil")
        
        if statusCode == 200 {
            return try self.decode(Response<RequestLoginResponse>.self, data: data)
        }
        
        // we shouldn't get to here but if we do it's because the login has failed, so let's ensure coredata values are nillified
        trace("    in requestLogin, unable to process response. Existing authentication data will be nillified", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        throw LibreLinkUpFollowError.decodingError
    }
    
    /// using valid authentication ticket, we can now request the connections to find the patient ID
    /// based upon: https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#get-connections
    /// - Parameters:
    ///     - none
    /// - Returns: Response<[RequestConnectionsResponse]>, an array of json objects with the server response to the connections request, each one will hold a patient id but we will just use the first one [0]
    private func requestConnections() async throws -> Response<[RequestConnectionsResponse]> {
        guard let connectionsUrl = self.libreLinkUpRegion?.urlConnections, let token = libreLinkUpToken else {
            throw LibreLinkUpFollowError.urlErrorConnections
        }
        
        trace("    in requestConnections, processing connections request with URL: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, connectionsUrl)
        
        guard let url = URL(string: connectionsUrl) else {
            throw LibreLinkUpFollowError.urlErrorConnections
        }
        
        // this is pretty much the same request as done in requestLogin()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue((self.libreLinkUpId ?? "").sha256(), forHTTPHeaderField: "Account-Id")
        
        for (header, value) in self.libreLinkUpRequestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        // dynamically set the version number from userdefaults. This will allow the user to update the version number manually without waiting for an app update in case it is changed
        request.setValue(UserDefaults.standard.libreLinkUpVersion, forHTTPHeaderField: "version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        trace("    in requestConnections, server response status code: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, statusCode.description)
        
        if statusCode == 200 {
            return try self.decode(Response<[RequestConnectionsResponse]>.self, data: data)
        }
        
        trace("    in requestConnections, unable to process response", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        throw LibreLinkUpFollowError.decodingError
    }
    
    /// using valid authentication ticket and the patient ID, we can now request the cgm data
    /// based upon: https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2#get-cgm-data
    /// - Parameters:
    ///     - patientId: needed to correctly generate the graph URL
    /// - Returns: Response<RequestGraphResponse>, a json object with the server response to the graph request
    private func requestGraph(patientId: String) async throws -> Response<RequestGraphResponse> {
        guard let token = self.libreLinkUpToken, self.libreLinkUpId != "", self.libreLinkUpPatientId != "" else {
            throw LibreLinkUpFollowError.missingLoginData
        }
        
        guard let graphURL = self.libreLinkUpRegion?.urlGraph(patientId: patientId) else {
            throw LibreLinkUpFollowError.urlErrorGraph
        }
        
        trace("    in requestGraph, URL: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, graphURL)
        
        guard let url = URL(string: graphURL) else {
            throw LibreLinkUpFollowError.urlErrorGraph
        }
        
        // this is pretty much the same request as done in loginRequest()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue((self.libreLinkUpId ?? "").sha256(), forHTTPHeaderField: "Account-Id")
        
        for (header, value) in self.libreLinkUpRequestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        // dynamically set the version number from userdefaults. This will allow the user to update the version number manually without waiting for an app update in case it is changed
        request.setValue(UserDefaults.standard.libreLinkUpVersion, forHTTPHeaderField: "version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        trace("    in requestGraph, server response status code: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, statusCode.description)
        
        if statusCode == 200 {
            // store the current timestamp as a successful server connection with valid login
            UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
            
            return try self.decode(Response<RequestGraphResponse>.self, data: data)
        }
        
        trace("    in requestGraph, unable to process response", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        throw LibreLinkUpFollowError.decodingError
    }
    
    /// generic decoding function for all JSON struct types
    private func decode<T: Decodable>(_ type: T.Type, data: Data) throws -> T {
        guard let jsonDecoder = jsonDecoder else {
            throw LibreLinkUpFollowError.decodingError
        }
        
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    /// clear the active sensor data from coredata (needed for UI)
    private func resetActiveSensorData() {
        UserDefaults.standard.activeSensorSerialNumber = nil
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorMaxSensorAgeInDays = nil
        UserDefaults.standard.libreLinkUpCountry = nil
        
        self.libreLinkUpToken = nil
        self.libreLinkUpId = nil
        self.libreLinkUpPatientId = nil
    }
    
    /// schedule new download with timer, when timer expires download() will be called
    private func scheduleNewDownload() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        
        trace("in scheduleNewDownload", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
        
        // schedule a timer for 60 seconds and assign it to a let property
        let downloadTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)
        
        // assign invalidateDownLoadTimerClosure to a closure that will invalidate the downloadTimer
        self.invalidateDownLoadTimerClosure = {
            downloadTimer.invalidate()
        }
    }
    
    /// process result from download
    /// - parameters:
    ///     - data : data as a struct defined to handle the server response for graph data
    ///     - followGlucoseDataArray : array input by caller, result will be in that array. Can be empty array. Array must be initialized to empty array by caller
    /// - returns: followGlucoseDataArray , possibly empty - first entry is the youngest
    private func processDownloadResponse(data: [RequestGraphResponseGlucoseMeasurement?], followGlucoseDataArray: inout [FollowerBgReading]) {
        // if data not nil then check if response is nil
        if !data.isEmpty {
            for element in data {
                guard let gm = element, let followGlucoseData = FollowerBgReading(entry: gm) else { continue }
                // insert entry chronologically sorted, first is the youngest
                if followGlucoseDataArray.isEmpty {
                    followGlucoseDataArray.append(followGlucoseData)
                } else {
                    var elementInserted = false
                    loop: for (index, existing) in followGlucoseDataArray.enumerated() {
                        if existing.timeStamp < followGlucoseData.timeStamp {
                            followGlucoseDataArray.insert(followGlucoseData, at: index)
                            elementInserted = true
                            break loop
                        }
                    }
                    if !elementInserted {
                        followGlucoseDataArray.append(followGlucoseData)
                    }
                }
            }
        } else {
            trace("    no glucose measurement elements to process", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .error)
        }
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
            print("not enabling suspension prevention as keep-alive type is:  \(UserDefaults.standard.followerBackgroundKeepAliveType.description)")
            
            return
        }
        
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal ? ConstantsSuspensionPrevention.intervalNormal : ConstantsSuspensionPrevention.intervalAggressive
        
        // create playSoundTimer depending on the keep-alive type selected
        self.playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval)), eventHandler: { [weak self] in
            guard let self = self else { return }
            // play the sound
            trace("in eventhandler checking if audioplayer exists", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info)
            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                trace("playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@", log: self.log, category: ConstantsLog.categoryLibreLinkUpFollowManager, type: .info, interval.description, UserDefaults.standard.followerDataSourceType.description, UserDefaults.standard.followerBackgroundKeepAliveType.description)
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
        if !UserDefaults.standard.isMaster && (UserDefaults.standard.followerDataSourceType == .libreLinkUp || UserDefaults.standard.followerDataSourceType == .libreLinkUpRussia) && UserDefaults.standard.libreLinkUpEmail != nil && UserDefaults.standard.libreLinkUpPassword != nil {
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
    
    deinit {
        // clean observers to avoid KVO crashes
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpEmail.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpPassword.rawValue)

        // stop keep-alive helpers
        disableSuspensionPrevention()

        // invalidate any pending download timer
        invalidateDownLoadTimerClosure?()
    }
    
    // MARK: - overriden function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.isMaster, UserDefaults.Key.followerDataSourceType, UserDefaults.Key.libreLinkUpEmail, UserDefaults.Key.libreLinkUpPassword:
                    
                    // change by user, should not be done within 200 ms
                    if self.keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) {
                        // re-allow login to be attempted if the user has changed data source type or other items
                        UserDefaults.standard.libreLinkUpPreventLogin = false
                        
                        // reset the token so that a new login process is forced when the download() function is later run
                        // this will also reset all activeSensor coredata values to update the UI
                        self.resetActiveSensorData()
                        
                        self.verifyUserDefaultsAndStartOrStopFollowMode()
                    }
                    
                default:
                    break
                }
            }
        }
    }
}

/// error throwing types for the follower
private enum LibreLinkUpFollowError: Error {
    case generalError
    case missingCredentials
    case urlError
    case reAcceptNeeded
    case invalidPatientId
    case invalidCredentials
    case decodingError
    case urlErrorLogin
    case urlErrorConnections
    case urlErrorGraph
    case missingLoginData
    case missingPayLoad
}

/// make a custom description property to correctly log the error types
extension LibreLinkUpFollowError: CustomStringConvertible {
    var description: String {
        switch self {
        case .generalError:
            return "General Error"
        case .missingCredentials:
            return "Missing Credentials"
        case .urlError:
            return "URL Error"
        case .reAcceptNeeded:
            return "User must re-accept LibreLinkUp conditions"
        case .invalidPatientId:
            return "Invalid patient ID"
        case .invalidCredentials:
            return "Invalid credentials (check 'Settings' > 'Connection Settings')"
        case .decodingError:
            return "Error decoding JSON response"
        case .urlErrorLogin:
            return "Invalid Login URL"
        case .urlErrorConnections:
            return "Invalid Connections URL"
        case .urlErrorGraph:
            return "Invalid Graph URL"
        case .missingLoginData:
            return "Missing login data"
        case .missingPayLoad:
            return "Either the user id or the authentication payload was missing or invalid"
        }
    }
}
