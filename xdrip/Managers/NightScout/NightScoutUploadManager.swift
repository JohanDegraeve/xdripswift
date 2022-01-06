import Foundation
import os
import UIKit

public class NightScoutUploadManager:NSObject {
    
    // MARK: - properties
    
    /// path for readings and calibrations
    private let nightScoutEntriesPath = "/api/v1/entries"
    
    /// path for treatments
    private let nightScoutTreatmentPath = "/api/v1/treatments"
    
    /// path for devicestatus
    private let nightScoutDeviceStatusPath = "/api/v1/devicestatus"
    
    /// path to test API Secret
    private let nightScoutAuthTestPath = "/api/v1/experiments/test"

    /// for logging
    private var oslog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightScoutUploadManager)
    
    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor
    
    /// SensorsAccessor instance
    private let sensorsAccessor: SensorsAccessor
    
    /// CalibrationsAccessor instance
    private let calibrationsAccessor: CalibrationsAccessor
    
    /// reference to coreDataManager
    private let coreDataManager: CoreDataManager
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// in case errors occur like credential check error, then this closure will be called with title and message
    private let messageHandler:((String, String) -> Void)?
    
    /// temp storage transmitterBatteryInfo, if changed then upload to NightScout will be done
    private var latestTransmitterBatteryInfo: TransmitterBatteryInfo?
    
    /// temp storate uploader battery level, if changed then upload to NightScout will be done
    private var latestUploaderBatteryLevel: Float?
    
    // MARK: - initializer
    
    /// initializer
    /// - parameters:
    ///     - coreDataManager : needed to get latest readings
    ///     - messageHandler : in case errors occur like credential check error, then this closure will be called with title and message
    ///     - checkIfDisReConnectAfterTimeStampFunction : function to verify if there's been a disconnect or reconnect after the timestamp of the given reading
    init(coreDataManager: CoreDataManager, messageHandler:((_ title:String, _ message:String) -> Void)?) {
        
        // init properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        self.messageHandler = messageHandler
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        
        super.init()
        
        // add observers for nightscout settings which may require testing and/or start upload
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutAPIKey.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutPort.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutEnabled.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutUseSchedule.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutSchedule.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue, options: .new, context: nil)
    }
    
    // MARK: - public functions
    
    /// uploads latest BgReadings to NightScout, only if nightscout enabled, not master, url and key defined, if schedule enabled then check also schedule
    /// - parameters:
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect
    public func upload(lastConnectionStatusChangeTimeStamp: Date?) {
                
        // check that NightScout is enabled
        guard UserDefaults.standard.nightScoutEnabled else {return}
        
        // check that master is enabled
        guard UserDefaults.standard.isMaster else {return}
        
        // check that the URL exists
        guard let _ = UserDefaults.standard.nightScoutUrl else {return}
        
        // check that either the API_SECRET or Token exists, if both are nil then return
        if UserDefaults.standard.nightScoutAPIKey == nil && UserDefaults.standard.nightscoutToken == nil {
            return
        }
        
        // if schedule is on, check if upload is needed according to schedule
        if UserDefaults.standard.nightScoutUseSchedule {
            if let schedule = UserDefaults.standard.nightScoutSchedule {
                if !schedule.indicatesOn(forWhen: Date()) {
                    return
                }
            }
        }
        
        // upload readings
        uploadBgReadingsToNightScout(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        
        // upload calibrations
        uploadCalibrationsToNightScout()
        
        // upload activeSensor if needed
        if UserDefaults.standard.uploadSensorStartTimeToNS, let activeSensor = sensorsAccessor.fetchActiveSensor() {
            
            if !activeSensor.uploadedToNS  {

                trace("in upload, activeSensor not yet uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)

                uploadActiveSensorToNightScout(sensor: activeSensor)

            }
        }
        
        // upload transmitter battery info if needed, also upload uploader battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UserDefaults.standard.transmitterBatteryInfo != latestTransmitterBatteryInfo || latestUploaderBatteryLevel != UIDevice.current.batteryLevel {
            
            if let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo {

                uploadTransmitterBatteryInfoToNightScout(transmitterBatteryInfo: transmitterBatteryInfo)

            }
            
        }
        
    }
    
    // MARK: - overriden functions
    
    // when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                case UserDefaults.Key.nightScoutUrl, UserDefaults.Key.nightScoutAPIKey, UserDefaults.Key.nightscoutToken, UserDefaults.Key.nightScoutPort :
                    // apikey or nightscout api key change is triggered by user, should not be done within 200 ms
                    
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // if master is set, siteURL exists and either API_SECRET or a token is entered, then test credentials
                        if UserDefaults.standard.nightScoutUrl != nil && UserDefaults.standard.isMaster && (UserDefaults.standard.nightScoutAPIKey != nil || UserDefaults.standard.nightscoutToken != nil) {
                            
                            testNightScoutCredentials({ (success, error) in
                                DispatchQueue.main.async {
                                    self.callMessageHandler(withCredentialVerificationResult: success, error: error)
                                    if success {
                                        
                                        // set lastConnectionStatusChangeTimeStamp to as late as possible, to make sure that the most recent reading is uploaded if user is testing the credentials
                                        self.upload(lastConnectionStatusChangeTimeStamp: Date())
                                        
                                    } else {
                                        trace("in observeValue, NightScout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                                    }
                                }
                            })
                        }
                    }
                    
                case UserDefaults.Key.nightScoutEnabled, UserDefaults.Key.nightScoutUseSchedule, UserDefaults.Key.nightScoutSchedule :
                    
                    // if changing to enabled, then do a credentials test and if ok start upload, in case of failure don't give warning, that's the only difference with previous cases
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // if master is set, siteURL exists and either API_SECRET or a token is entered, then test credentials
                        if UserDefaults.standard.nightScoutUrl != nil && UserDefaults.standard.isMaster && (UserDefaults.standard.nightScoutAPIKey != nil || UserDefaults.standard.nightscoutToken != nil) {
                            
                            testNightScoutCredentials({ (success, error) in
                                DispatchQueue.main.async {
                                    if success {
                                        
                                        // set lastConnectionStatusChangeTimeStamp to as late as possible, to make sure that the most recent reading is uploaded if user is testing the credentials
                                        self.upload(lastConnectionStatusChangeTimeStamp: Date())
                                        
                                    } else {
                                        trace("in observeValue, NightScout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                                    }
                                }
                            })
                        }
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - private helper functions
    
    /// upload battery level to nightscout
    /// - parameters:
    ///     - transmitterBatteryInfosensor: setransmitterBatteryInfosensornsor to upload
    private func uploadTransmitterBatteryInfoToNightScout(transmitterBatteryInfo: TransmitterBatteryInfo) {
        
        trace("in uploadTransmitterBatteryInfoToNightScout, transmitterBatteryInfo not yet uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        // enable battery monitoring on iOS device
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // https://testhdsync.herokuapp.com/api-docs/#/Devicestatus/addDevicestatuses
        let transmitterBatteryInfoAsKeyValue = transmitterBatteryInfo.batteryLevel
        
        // not very clear here how json should look alike. For dexcom it seems to work with "battery":"the battery level off the iOS device" and "batteryVoltage":"Dexcom voltage"
        // while for other devices like MM and Bubble, there's no batterVoltage but also a battery, so for this case I'm using "battery":"transmitter battery level", otherwise there's two "battery" keys which causes a crash - I'll hear if if it's not ok
        // first assign dataToUpload assuming the key for transmitter battery will be "battery" (ie it's not a dexcom)
        var dataToUpload = [
            "uploader" : [
                "name" : "transmitter",
                "battery" : transmitterBatteryInfoAsKeyValue.value
            ]
        ] as [String : Any]
        
        // now check if the key for transmitter battery is not "battery" and if so reassign dataToUpload now with battery being the iOS devices battery level
        if transmitterBatteryInfoAsKeyValue.key != "battery" {
            dataToUpload = [
                "uploader" : [
                    "name" : "transmitter",
                    "battery" : Int(UIDevice.current.batteryLevel * 100.0),
                    transmitterBatteryInfoAsKeyValue.key : transmitterBatteryInfoAsKeyValue.value
                ]
            ]
        }
        
        
        uploadData(dataToUpload: dataToUpload, traceString: "uploadTransmitterBatteryInfoToNightScout", path: nightScoutDeviceStatusPath, completionHandler: {
        
            // sensor successfully uploaded, change value in coredata
            trace("in uploadTransmitterBatteryInfoToNightScout, transmitterBatteryInfo uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
            
            self.latestTransmitterBatteryInfo = transmitterBatteryInfo
            
            self.latestUploaderBatteryLevel = UIDevice.current.batteryLevel

        })
        
    }

    /// upload sensor to nightscout
    /// - parameters:
    ///     - sensor: sensor to upload
    private func uploadActiveSensorToNightScout(sensor: Sensor) {
        
        trace("in uploadActiveSensorToNightScout, activeSensor not yet uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        let dataToUpload = [
            "_id": sensor.id,
            "eventType": "Sensor Start",
            "created_at": sensor.startDate.ISOStringFromDate(),
            "enteredBy": ConstantsHomeView.applicationName
        ]
        
        uploadData(dataToUpload: dataToUpload, traceString: "uploadActiveSensorToNightScout", path: nightScoutTreatmentPath, completionHandler: {
            
            // sensor successfully uploaded, change value in coredata
            trace("in uploadActiveSensorToNightScout, activeSensor uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
            
            DispatchQueue.main.async {
                
                sensor.uploadedToNS = true
                self.coreDataManager.saveChanges()

            }
            
        })
        
    }
    
    /// upload latest readings to nightscout
    /// - parameters:
    private func uploadBgReadingsToNightScout(lastConnectionStatusChangeTimeStamp: Date?) {
        
        trace("in uploadBgReadingsToNightScout", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        // get readings to upload, limit to x days, x = ConstantsNightScout.maxDaysToUpload
        var timeStamp = Date(timeIntervalSinceNow: TimeInterval(-Double(ConstantsNightScout.maxDaysToUpload) * 24.0 * 60.0 * 60.0))
        
        if let timeStampLatestNightScoutUploadedBgReading = UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading {
            if timeStampLatestNightScoutUploadedBgReading > timeStamp {
                timeStamp = timeStampLatestNightScoutUploadedBgReading
            }
        }
        
        // get latest readings, filter : minimiumTimeBetweenTwoReadingsInMinutes beteen two readings, except for the first if a dis/reconnect occured since the latest reading
        var bgReadingsToUpload = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStamp, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: ConstantsNightScout.minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp, timeStampLastProcessedBgReading: timeStamp)
        
        if bgReadingsToUpload.count > 0 {
            trace("    number of readings to upload : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, bgReadingsToUpload.count.description)
            
            // there's a limit of payload size to upload to NightScout
            // if size is > maximum, then we'll have to call the upload function again, this variable will be used in completionHandler
            let callAgainNeeded = bgReadingsToUpload.count > ConstantsNightScout.maxReadingsToUpload
            
            if callAgainNeeded {
                trace("    restricting readings to upload to %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, ConstantsNightScout.maxReadingsToUpload.description)
            }

            // limit the amount of readings to upload to avoid passing this limit
            // we start with the oldest readings
            bgReadingsToUpload = bgReadingsToUpload.suffix(ConstantsNightScout.maxReadingsToUpload)
            
            // map readings to dictionaryRepresentation
            let bgReadingsDictionaryRepresentation = bgReadingsToUpload.map({$0.dictionaryRepresentationForNightScoutUpload})
            
            // store the timestamp of the last reading to upload, here in the main thread, because we use a bgReading for it, which is retrieved in the main mangedObjectContext
            let timeStampLastReadingToUpload = bgReadingsToUpload.first != nil ? bgReadingsToUpload.first!.timeStamp : nil
            
            uploadData(dataToUpload: bgReadingsDictionaryRepresentation, traceString: "uploadBgReadingsToNightScout", path: nightScoutEntriesPath, completionHandler: {
                
                // change timeStampLatestNightScoutUploadedBgReading
                if let timeStampLastReadingToUpload = timeStampLastReadingToUpload {
                    
                    trace("    in uploadBgReadingsToNightScout, upload succeeded, setting timeStampLatestNightScoutUploadedBgReading to %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, timeStampLastReadingToUpload.description(with: .current))
                    
                    UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading = timeStampLastReadingToUpload
                    
                    // callAgainNeeded means we've limit the amount of readings because size was too big
                    // if so a new upload is needed
                    if callAgainNeeded {
                        
                        // do this in the main thread because the readings are fetched with the main mainManagedObjectContext
                        DispatchQueue.main.async {
                        
                            self.uploadBgReadingsToNightScout(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
                            
                        }
                        
                    }
                    
                }
                
            })
            
        } else {
            trace("    no readings to upload", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        }
        
    }
    
    /// upload latest calibrations to nightscout
    /// - parameters:
    private func uploadCalibrationsToNightScout() {
        
        trace("in uploadCalibrationsToNightScout", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        // get the calibrations from the last maxDaysToUpload days
        let calibrations = calibrationsAccessor.getLatestCalibrations(howManyDays: ConstantsNightScout.maxDaysToUpload, forSensor: nil)
        
        var calibrationsToUpload: [Calibration] = []
        if let timeStampLatestNightScoutUploadedCalibration = UserDefaults.standard.timeStampLatestNightScoutUploadedCalibration {
            // select calibrations that are more recent than the latest uploaded calibration
            calibrationsToUpload = calibrations.filter({$0.timeStamp > timeStampLatestNightScoutUploadedCalibration })
        }
        else {
            // or all calibrations if there is no previously uploaded calibration
            calibrationsToUpload = calibrations
        }
        
        if calibrationsToUpload.count > 0 {
            trace("    number of calibrations to upload : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, calibrationsToUpload.count.description)
            
            // map calibrations to dictionaryRepresentation
            // 2 records are uploaded to nightscout for each calibration: a cal record and a mbg record
            let calibrationsDictionaryRepresentation = calibrationsToUpload.map({$0.dictionaryRepresentationForCalRecordNightScoutUpload}) + calibrationsToUpload.map({$0.dictionaryRepresentationForMbgRecordNightScoutUpload})
            
            // store the timestamp of the last calibration to upload, here in the main thread, because we use a Calibration for it, which is retrieved in the main mangedObjectContext
            let timeStampLastCalibrationToUpload = calibrationsToUpload.first != nil ? calibrationsToUpload.first!.timeStamp : nil

            uploadData(dataToUpload: calibrationsDictionaryRepresentation, traceString: "uploadCalibrationsToNightScout", path: nightScoutEntriesPath, completionHandler: {
                
                // change timeStampLatestNightScoutUploadedCalibration
                if let timeStampLastCalibrationToUpload = timeStampLastCalibrationToUpload {
                    
                    trace("    in uploadCalibrationsToNightScout, upload succeeded, setting timeStampLatestNightScoutUploadedCalibration to %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, timeStampLastCalibrationToUpload.description(with: .current))
                    
                    UserDefaults.standard.timeStampLatestNightScoutUploadedCalibration = timeStampLastCalibrationToUpload
                    
                }
                
            })
            
        } else {
            trace("    no calibrations to upload", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        }
        
    }
    
    /// common functionality to upload data to nightscout
    /// - parameters:
    ///     - dataToUpload : data to upload
    ///     - traceString : trace will start with this string, to distinguish between different uploads that may be ongoing simultaneously
    ///     - completionHandler : will be executed if upload was successful
    private func uploadData(dataToUpload: Any, traceString: String, path: String, completionHandler: (() -> ())?) {
        
        trace("in uploadData, %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, traceString)
        
        do {
            
            // transform dataToUpload to json
            let dateToUploadAsJSON = try JSONSerialization.data(withJSONObject: dataToUpload, options: [])

            trace("    size of data to upload : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, dateToUploadAsJSON.count.description)

            if let nightscoutURL = UserDefaults.standard.nightScoutUrl, let url = URL(string: nightscoutURL), var uRLComponents = URLComponents(url: url.appendingPathComponent(path), resolvingAgainstBaseURL: false) {

                if UserDefaults.standard.nightScoutPort != 0 {
                    uRLComponents.port = UserDefaults.standard.nightScoutPort
                }
                
                // if token not nil, then add also the token
                if let token = UserDefaults.standard.nightscoutToken {
                    let queryItems = [URLQueryItem(name: "token", value: token)]
                    uRLComponents.queryItems = queryItems
                }
                
                if let url = uRLComponents.url {
                    
                    // Create Request
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    if let apiKey = UserDefaults.standard.nightScoutAPIKey {
                        request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
                    }
                    
                    // Create upload Task
                    let task = URLSession.shared.uploadTask(with: request, from: dateToUploadAsJSON, completionHandler: { (data, response, error) -> Void in
                        
                        trace("in uploadData, finished task", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                        
                        // if ends without success then log the data
                        var success = false
                        defer {
                            if !success {
                                if let data = data {
                                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                                        trace("    in uploadData, %{public}@, data = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString, dataAsString)
                                    }
                                    
                                }
                            } else {
                                
                                // successful case, call completionhandler
                                if let completionHandler = completionHandler {
                                    completionHandler()
                                }

                            }
                        }
                        
                        // error cases
                        if let error = error {
                            trace("    in uploadData, %{public}@, failed to upload, error = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString, error.localizedDescription)
                            return
                        }
                        
                        // check that response is HTTPURLResponse and error code between 200 and 299
                        if let response = response as? HTTPURLResponse {
                            guard (200...299).contains(response.statusCode) else {
                                
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
                                                        
                                                        trace("    in uploadData, found code = 66, considering the upload as successful", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString)
                                                        
                                                        success = true
                                                        
                                                        return
                                                        
                                                    }
                                                    
                                                }
                                                
                                            }
                                            
                                        }

                                    } catch {
                                            // json decode fails, upload will be considered as failed
                                    }
                                    
                                }
                                                            
                                trace("    in uploadData, %{public}@, failed to upload, statuscode = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString, response.statusCode.description)
                                
                                return
                                
                            }
                        } else {
                            trace("    in uploadData, %{public}@, response is not HTTPURLResponse", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString)
                        }
                        
                        // successful cases
                        success = true
                        
                    })
                    
                    trace("in uploadData, calling task.resume", log: oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                    task.resume()
                    
                }
                
                
                
         }
            
        } catch let error {
            trace("     in uploadData, %{public}@, error : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, error.localizedDescription, traceString)
        }

    }
    
    private func testNightScoutCredentials(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        // don't run the test if one of the authentication methods is missing. This can happen because the user has input the URL but hasn't added auth yet.
        if UserDefaults.standard.nightScoutAPIKey == nil && UserDefaults.standard.nightscoutToken == nil {
            return
        }
        
        if let nightscoutURL = UserDefaults.standard.nightScoutUrl, let url = URL(string: nightscoutURL), var uRLComponents = URLComponents(url: url.appendingPathComponent(nightScoutAuthTestPath), resolvingAgainstBaseURL: false) {
            
            if UserDefaults.standard.nightScoutPort != 0 {
                uRLComponents.port = UserDefaults.standard.nightScoutPort
            }
            
            if let url = uRLComponents.url {

                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField:"Content-Type")
                request.setValue("application/json", forHTTPHeaderField:"Accept")
                
                // if the API_SECRET is present, then hash it and pass it via http header. If it's missing but there is a token, then send this as plain text to allow the authentication check.
                if let apiKey = UserDefaults.standard.nightScoutAPIKey {
                    
                    request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
                    
                } else if let token = UserDefaults.standard.nightscoutToken {
                    
                    request.setValue(token, forHTTPHeaderField:"api-secret")
                    
                }
                
                let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                    
                    trace("in testNightScoutCredentials, finished task", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                    
                    if let error = error {
                        completion(false, error)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse ,
                       httpResponse.statusCode != 200, let data = data {
                        completion(false, NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: String.Encoding.utf8)!]))
                    } else {
                        completion(true, nil)
                    }
                })
                
                trace("in testNightScoutCredentials, calling task.resume", log: oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                task.resume()

            }
            
            
        }
    }
    
    private func callMessageHandler(withCredentialVerificationResult success:Bool, error:Error?) {
        
        // define the title text
        var title = Texts_NightScoutTestResult.verificationSuccessfulAlertTitle
        if !success {
            title = Texts_NightScoutTestResult.verificationErrorAlertTitle
        }
        
        // define the message text
        var message = Texts_NightScoutTestResult.verificationSuccessfulAlertBody
        if !success {
            if let error = error {
                message = error.localizedDescription
            } else {
                message = "unknown error"// shouldn't happen
            }
        }

        // call messageHandler
        if let messageHandler = messageHandler {
            messageHandler(title, message)
        }
        
    }
    
}
