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
    
    /// reference to coreDataManager
    private let coreDataManager: CoreDataManager
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// in case errors occur like credential check error, then this closure will be called with title and message
    private let messageHandler:((String, String) -> Void)?
    
    // MARK: - initializer
    
    /// initializer
    /// - parameters:
    ///     - coreDataManager : needed to get latest readings
    ///     - messageHandler : in case errors occur like credential check error, then this closure will be called with title and message
    init(coreDataManager: CoreDataManager, messageHandler:((_ title:String, _ message:String) -> Void)?) {
        
        // init properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.messageHandler = messageHandler
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        
        super.init()
        
        // add observers for nightscout settings which may require testing and/or start upload
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutAPIKey.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutUrl.rawValue, options: .new, context: nil)
    }
    
    // MARK: - public functions
    
    /// uploads latest BgReadings to NightScout
    public func upload() {
        
        // check if NightScout is enabled
        guard UserDefaults.standard.nightScoutEnabled else {return}
        
        // check if master is enabled
        guard UserDefaults.standard.isMaster else {return}
        
        // check if siteUrl and apiKey exist
        guard let siteURL = UserDefaults.standard.nightScoutUrl, let apiKey = UserDefaults.standard.nightScoutAPIKey else {return}
        
        // if schedule is on, check if upload is needed according to schedule
        if UserDefaults.standard.nightScoutUseSchedule {
            if let schedule = UserDefaults.standard.nightScoutSchedule {
                if !schedule.indicatesOn(forWhen: Date()) {
                    return
                }
            }
        }
        
        // upload readings
        uploadBgReadingsToNightScout(siteURL: siteURL, apiKey: apiKey)
        
        // upload activeSensor if needed
        if UserDefaults.standard.uploadSensorStartTimeToNS, let activeSensor = sensorsAccessor.fetchActiveSensor() {
            
            if !activeSensor.uploadedToNS  {

                trace("in upload, activeSensor not yet uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)

                uploadActiveSensorToNightScout(siteURL: siteURL, apiKey: apiKey, sensor: activeSensor)

            }
        }
        
    }
    
    // MARK: - overriden functions
    
    // when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                case UserDefaults.Key.nightScoutUrl, UserDefaults.Key.nightScoutAPIKey :
                    // apikey or nightscout api key change is triggered by user, should not be done within 200 ms
                    
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // if apiKey and siteURL are set and if master then test credentials
                        if let apiKey = UserDefaults.standard.nightScoutAPIKey, let siteUrl = UserDefaults.standard.nightScoutUrl, UserDefaults.standard.isMaster {
                            
                            testNightScoutCredentials(apiKey: apiKey, siteURL: siteUrl, { (success, error) in
                                DispatchQueue.main.async {
                                    self.callMessageHandler(withCredentialVerificationResult: success, error: error)
                                    if success {
                                        self.upload()
                                    } else {
                                        trace("in observeValue, NightScout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                                    }
                                }
                            })
                        }
                    }
                    
                case UserDefaults.Key.nightScoutEnabled :
                    
                    // if changing to enabled, then do a credentials test and if ok start upload, in case of failure don't give warning, that's the only difference with previous cases
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        if UserDefaults.standard.nightScoutEnabled {
                            
                            // if apiKey and siteURL are set and if master then test credentials
                            if let apiKey = UserDefaults.standard.nightScoutAPIKey, let siteUrl = UserDefaults.standard.nightScoutUrl, UserDefaults.standard.isMaster {
                                
                                testNightScoutCredentials(apiKey: apiKey, siteURL: siteUrl, { (success, error) in
                                    DispatchQueue.main.async {
                                        if success {
                                            self.upload()
                                        } else {
                                            trace("in observeValue, NightScout credential check failed", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
                                        }
                                    }
                                })
                            }
                        }
                    }

                default:
                    break
                }
            }
        }
    }
    
    // MARK: - private helper functions
    
    /// upload sensor to nightscout
    /// - parameters:
    ///     - siteURL : nightscout site url
    ///     - apiKey : nightscout api key
    ///     - sensor: sensor to upload
    private func uploadActiveSensorToNightScout(siteURL:String, apiKey:String, sensor: Sensor) {
        
        trace("in uploadActiveSensorToNightScout, activeSensor not yet uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        let dataToUpload = [
            "_id": sensor.id,
            "eventType": "Sensor Start",
            "created_at": sensor.startDate.ISOStringFromDate(),
            "enteredBy": "xDrip iOS"
        ]

        uploadData(dataToUpload: dataToUpload, traceString: "uploadActiveSensorToNightScout", siteURL: siteURL, path: nightScoutTreatmentPath, apiKey: apiKey, completionHandler: {
        
            // sensor successfully uploaded, change value in coredata
            trace("in uploadActiveSensorToNightScout, activeSensor uploaded to NS", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
            sensor.uploadedToNS = true
            self.coreDataManager.saveChanges()

        })
        
    }

    /// upload latest readings to nightscout
    /// - parameters:
    ///     - siteURL : nightscout site url
    ///     - apiKey : nightscout api key
    private func uploadBgReadingsToNightScout(siteURL:String, apiKey:String) {
        
        trace("in uploadBgReadingsToNightScout", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        
        // get readings to upload, limit to x days, x = ConstantsNightScout.maxDaysToUpload
        var timeStamp = Date(timeIntervalSinceNow: TimeInterval(-ConstantsNightScout.maxDaysToUpload*24*60*60))
        
        if let timeStampLatestNightScoutUploadedBgReading = UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading {
            if timeStampLatestNightScoutUploadedBgReading > timeStamp {
                timeStamp = timeStampLatestNightScoutUploadedBgReading
            }
        }
        
        let bgReadingsToUpload = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStamp, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        if bgReadingsToUpload.count > 0 {
            trace("    number of readings to upload : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, bgReadingsToUpload.count.description)
            
            // map readings to dictionaryRepresentation
            let bgReadingsDictionaryRepresentation = bgReadingsToUpload.map({$0.dictionaryRepresentationForNightScoutUpload})
            
            uploadData(dataToUpload: bgReadingsDictionaryRepresentation, traceString: "uploadBgReadingsToNightScout", siteURL: siteURL, path: nightScoutEntriesPath, apiKey: apiKey, completionHandler: {
                
                // change timeStampLatestNightScoutUploadedBgReading
                if let lastReading = bgReadingsToUpload.first {
                    trace("    in uploadBgReadingsToNightScout, upload succeeded, setting timeStampLatestNightScoutUploadedBgReading to %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, lastReading.timeStamp.description(with: .current))
                    UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading = lastReading.timeStamp
                }
                
            })
            
        } else {
            trace("    no readings to upload", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info)
        }
        
    }
    
    /// common functionality to upload data to nightscout
    /// - parameters:
    ///     - dataToUpload : data to upload
    ///     - traceString : trace will start with this string, to distinguish between different uploads that may be ongoing simultaneously
    ///     - completionHandler : will be executed if upload was successful
    ///     - siteURL : nightscout site url
    ///     - apiKey : nightscout api key
    private func uploadData(dataToUpload: Any, traceString: String, siteURL: String, path:String, apiKey: String, completionHandler: (() -> ())?) {
        
        trace("in uploadData, %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, traceString)
        
        do {
            
            // transform dataToUpload to json
            let dateToUploadAsJSON = try JSONSerialization.data(withJSONObject: dataToUpload, options: [])
            
            // get shared URLSession
            let sharedSession = URLSession.shared
            
            if let url = URL(string: siteURL) {
                
                // create upload url
                let uploadURL = url.appendingPathComponent(path)
                
                // Create Request
                var request = URLRequest(url: uploadURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(apiKey.sha1(), forHTTPHeaderField: "api-secret")
                
                // Create upload Task
                let dataTask = sharedSession.uploadTask(with: request, from: dateToUploadAsJSON, completionHandler: { (data, response, error) -> Void in
                    
                    trace("    in upload, %{public}@, uploadTask completionHandler", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, traceString)
                    
                    // if ends without success then log the data
                    var success = false
                    defer {
                        if !success {
                            if let data = data {
                                if let dataAsString = String(bytes: data, encoding: .utf8) {
                                    trace("    in uploadData, %{public}@, data = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString, dataAsString)
                                }
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
                            trace("    in uploadData, %{public}@, failed to upload, statuscode = %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString, response.statusCode.description)
                            return
                        }
                    } else {
                        trace("    in uploadData, %{public}@, response is not HTTPURLResponse", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .error, traceString)
                    }
                    
                    // successful cases,
                    success = true
                    
                    // call completionhandler
                    if let completionHandler = completionHandler {
                        completionHandler()
                    }
                    
                })
                dataTask.resume()
            }
            
        } catch let error {
            trace("     in uploadData, %{public}@, error : %{public}@", log: self.oslog, category: ConstantsLog.categoryNightScoutUploadManager, type: .info, error.localizedDescription, traceString)
        }

    }
    
    private func testNightScoutCredentials(apiKey:String, siteURL:String, _ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        if let url = URL(string: siteURL) {
            let testURL = url.appendingPathComponent(nightScoutAuthTestPath)
            
            var request = URLRequest(url: testURL)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("application/json", forHTTPHeaderField:"Accept")
            request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
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
            task.resume()
        }
    }
    
    private func callMessageHandler(withCredentialVerificationResult success:Bool, error:Error?) {
        
        // define the title text
        var title = Texts_NightScoutTestResult.verificationSuccessFulAlertTitle
        if !success {
            title = Texts_NightScoutTestResult.verificationErrorAlertTitle
        }
        
        // define the message text
        var message = Texts_NightScoutTestResult.verificationSuccessFulAlertBody
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
