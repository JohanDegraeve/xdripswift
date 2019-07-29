import Foundation
import os

class DexcomShareUploadManager:NSObject {
 
    // MARK: - private properties
    
    /// path for login
    private let loginPath = "/General/LoginPublisherAccountByName"
    
    /// path for upload readings
    private let postReceiverEgvRecordsPath = "Publisher/PostReceiverEgvRecords"
    
    /// path for start remote monitoring session
    private let startRemoteMonitoringSessionPath = "Publisher/StartRemoteMonitoringSession"
    
    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// in case errors occurs or other informational message to be shown to the user,  like credential check error, then this closure will be called with title and message
    private let messageHandler:((String, String) -> Void)?
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDexcomShareUploadManager)

    /// dexcom share url to use, calculated property
    private var dexcomShareUrl:String {
        if UserDefaults.standard.useUSDexcomShareurl {
            return ConstantsDexcomShare.usBaseShareUrl
        } else {
            return ConstantsDexcomShare.nonUsBaseShareUrl
        }
    }
    
    /// session id retrieved during login, and to be used for uplaods
    private var dexcomShareSessionId:String?
    
    // MARK: - initializer
    
    /// initializer
    /// - parameters:
    ///     - bgReadingsAccessor : needed to get latest readings
    ///     - messageHandler : in case errors occurs or other informational message to be shown to the user,  like credential check error, then this closure will be called with title and message
    init(bgReadingsAccessor:BgReadingsAccessor, messageHandler:((_ title:String, _ message:String) -> Void)?) {
        
        // init properties
        self.bgReadingsAccessor = bgReadingsAccessor
        self.messageHandler = messageHandler
        
        super.init()
        
        // add observers for Dexcom share settings which may require testing and/or start upload
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomSharePassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareAccountName.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.useUSDexcomShareurl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.uploadReadingstoDexcomShare.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareSerialNumber.rawValue, options: .new, context: nil)

    }
    
    // MARK: - public functions
    
    /// uploads latest BgReadings to Dexcom Share
    public func upload() {
        // check if Dexcom share upload is enabled and required settings are set
        if UserDefaults.standard.uploadReadingstoDexcomShare && UserDefaults.standard.dexcomShareAccountName != nil && UserDefaults.standard.dexcomSharePassword != nil && UserDefaults.standard.dexcomShareSerialNumber != nil {
            uploadBgReadingsToDexcomShare(firstAttempt: true)
        }
    }

    // MARK: - overriden functions
    
    /// when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                case UserDefaults.Key.dexcomShareAccountName, UserDefaults.Key.dexcomSharePassword :
                    
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        if requiredSettingsAreNotNil() {
                            
                            // check if required dexcom share settings are not nil
                            loginAndStoreSessionId { (success, error) in
                                DispatchQueue.main.async {
                                    
                                    self.callMessageHandler(withCredentialVerificationResult: success, errorMessage: self.translateDexcomErrorMessage(errorText: error?.localizedDescription ?? nil))
                                    
                                    if success {
                                        os_log("in observeValue, start upload", log: self.log, type: .info)
                                        
                                        self.uploadBgReadingsToDexcomShare(firstAttempt: true)
                                        
                                    } else {
                                        os_log("in observeValue, Dexcom Share credential check failed", log: self.log, type: .error)
                                    }
                                }

                            }
                            
                        }
                    }
                    
                case UserDefaults.Key.uploadReadingstoDexcomShare, UserDefaults.Key.dexcomShareSerialNumber, UserDefaults.Key.useUSDexcomShareurl :
                    
                    // if changing to enabled, then do a credentials test and if ok start upload, if fail don't give warning, that's the only difference with previous cases
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // check if dexcom share is enabled
                        if UserDefaults.standard.uploadReadingstoDexcomShare {
                            
                            // check if required dexcom share settings are not nil
                            if requiredSettingsAreNotNil() {

                                // test credentials
                                loginAndStoreSessionId { (success, error) in
                                    DispatchQueue.main.async {
                                        if success {
                                            
                                            os_log("in observeValue, start upload", log: self.log, type: .info)
                                            self.uploadBgReadingsToDexcomShare(firstAttempt: true)

                                        } else {
                                            
                                            os_log("in observeValue, Dexcom Share credential check failed", log: self.log, type: .error)
                                        }
                                    }
                                    
                                }

                            }
                        } else {
                            // dexcom share disabled, set sessionid to nil, although this is not really necessary
                            dexcomShareSessionId = nil
                        }
                    }
                    
                default:
                    break
                }
            }
        }
    }

    // MARK: - private helper functions
    
    /// will call StartRemoteMonitoringSession with serialNumber
    ///
    /// dexcomShareSessionId and UserDefaults.standard.dexcomShareSerialNumber should be not nil
    private func startRemoteMonitoringSessionAndStartUpload() {
        
        os_log("in startRemoteMonitoringSessionAndStartUpload", log: self.log, type: .info)
        
        guard let url = URL(string: dexcomShareUrl), let dexcomShareSessionId = dexcomShareSessionId, let dexcomShareSerialNumber = UserDefaults.standard.dexcomShareSerialNumber, let dexcomShareAccountName = UserDefaults.standard.dexcomShareAccountName else {
            os_log("    failed to create url or dexcomShareSessionId or dexcomShareSerialNumber or dexcomShareAccountName is nil", log: self.log, type: .error)
            return
        }
        
        let startRemoteMonitoringSessionUrl = url.appendingPathComponent(startRemoteMonitoringSessionPath)
        
        // create NSURLComponents instance with scheme, host, queryItems
        guard let components = NSURLComponents(url: startRemoteMonitoringSessionUrl, resolvingAgainstBaseURL: false) else {
            os_log("in startRemoteMonitoringSessionAndStartUpload, failed to create components", log: self.log, type: .error)
            return
        }
        
        components.scheme = startRemoteMonitoringSessionUrl.scheme
        components.host = startRemoteMonitoringSessionUrl.host
        components.queryItems = [URLQueryItem(name: "sessionId", value: dexcomShareSessionId), URLQueryItem(name: "serialNumber", value: dexcomShareSerialNumber)]
        
        guard let newUrl = components.url else {
            os_log("in startRemoteMonitoringSessionAndStartUpload, failed to create newUrl", log: self.log, type: .error)
            return
        }

        // create the request
        var request = URLRequest(url: newUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

        // get shared URLSession
        let sharedSession = URLSession.shared

        // Create upload Task
        let dataTask = sharedSession.uploadTask(with: request, from: "".data(using: .utf8), completionHandler: { (data, response, error) -> Void in
            
            os_log("in startRemoteMonitoringSessionAndStartUpload, in uploadTask completionHandler", log: self.log, type: .info)
            
            // if ends without success then log the data when existing the scope
            var success = false
            defer {
                if !success {
                    if let data = data {
                        if let dataAsString = String(bytes: data, encoding: .utf8) {
                            os_log("    data = %{public}@", log: self.log, type: .error, dataAsString)
                        }
                    }
                }
            }

            // error cases
            if let error = error {
                os_log("    error = %{public}@", log: self.log, type: .error, error.localizedDescription)
                return
            }
            
            // check that response is HTTPURLResponse
            if let response = response as? HTTPURLResponse {
                
                if let data = data {
                    
                    // data has sessionid (if success) or error details (if failure) which can be logged and shown to the user
                    guard let decoded = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
                        else {
                            os_log("    JSONSerialization failed", log: self.log, type: .error)
                            return
                    }
                    
                    // if status code is not in range 200 to 299 then it's an error case
                    guard (200...299).contains(response.statusCode) else {
                        
                        // failure is a JSON object containing the error code
                        let errorCode = (decoded as? [String: String])?["Code"] ?? "unknown"
                        
                        os_log("    statuscode = %{public}@, error = %{public}@", log: self.log, type: .error, response.statusCode.description, errorCode)
                        
                        if errorCode == "MonitoredReceiverSerialNumberDoesNotMatch" {
                            
                            os_log("    MonitoredReceiverSerialNumberDoesNotMatch", log: self.log, type: .error)
                            DispatchQueue.main.async {
                                if let messageHandler = self.messageHandler {
                                    messageHandler(Texts_DexcomShareTestResult.uploadErrorWarning, Texts_DexcomShareTestResult.monitoredReceiverSNDoesNotMatch)
                                }
                            }
                            return
                            
                        } else if errorCode == "MonitoredReceiverNotAssigned" {
                            
                            os_log("    new login failed with error MonitoredReceiverNotAssigned", log: self.log, type: .error)
                            DispatchQueue.main.async {
                                if let messageHandler = self.messageHandler {
                                    messageHandler(Texts_DexcomShareTestResult.uploadErrorWarning, self.createMonitoredReceiverNotAssignedMessage(acount: dexcomShareAccountName, serialNumber: dexcomShareSerialNumber))
                                }
                            }
                            return
                            
                        }
                        
                        return
                    }
                    
                    //there's no error, call uploadBgReadingsToDexcomShare in main thread
                    DispatchQueue.main.async {
                        self.uploadBgReadingsToDexcomShare(firstAttempt: true)
                    }
                    
                } else {
                    os_log("    no data received", log: self.log, type: .error)
                    return
                }
                
            } else {
                os_log("    response is not HTTPURLResponse", log: self.log, type: .error)
                return
            }
            
        })
        
        dataTask.resume()

    }
    
    /// will try to upload the latest readings - if dexcomShareSessionId is nil then first a login attempt will be done and after that an upload.
    /// - parameters:
    ///     - firstAttempt : if true, and if dexcomShareSessionId not nil, but upload attempt fails with because dexcomShareSessionId is not valid, then a new login attempt will be done, after which a new upload attempt - if false, then no new upload attempt will be done
    ///
    /// firstAttempt is there to avoid that the app runs in an endless loop
    private func uploadBgReadingsToDexcomShare(firstAttempt:Bool) {
        
        os_log("in uploadBgReadingsToDexcomShare", log: self.log, type: .info)
        
        // dexcomShareSerialNumber and dexcomShareAccountName needed else no further processing
        guard let dexcomShareSerialNumber = UserDefaults.standard.dexcomShareSerialNumber, let dexcomShareAccountName = UserDefaults.standard.dexcomShareAccountName else {
            os_log("    dexcomShareSerialNumber and/or dexcomShareAccountName are/is nil", log: self.log, type: .error)
            return
        }
        
        guard let dexcomShareSessionId = dexcomShareSessionId else {
            
            os_log("    dexcomShareSessionId is nil, will try to login", log: self.log, type: .error)
            
            // try to login
            loginAndStoreSessionId { (success, error) in
                DispatchQueue.main.async {
                    if success {
                        os_log("in uploadBgReadingsToDexcomShare, login successful, will restart uploadBgReadingsToDexcomShare", log: self.log, type: .info)
                        // retry the upload
                        self.uploadBgReadingsToDexcomShare(firstAttempt: firstAttempt)
                    } else {
                        os_log("in uploadBgReadingsToDexcomShare, login failed, no further processing", log: self.log, type: .error)
                    }
                }
            }
            return
        }
        
        // get readings to upload, limit to 8 hours
        var timeStamp = Date(timeIntervalSinceNow: -8*60*60)
        if let timeStampLatestDexcomShareUploadedBgReading = UserDefaults.standard.timeStampLatestDexcomShareUploadedBgReading {
            timeStamp = timeStampLatestDexcomShareUploadedBgReading
        }
        let bgReadingsToUpload = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: timeStamp, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        os_log("    number of readings to upload : %{public}@", log: self.log, type: .info, bgReadingsToUpload.count.description)

        // if no no readings to upload, no further processing
        guard bgReadingsToUpload.count > 0 else {
            os_log("    no readings to upload", log: self.log, type: .info)
            return
        }
        
        // create url request
        guard let request = createURLRequestForUploadBgReadings(dexcomShareSessionId: dexcomShareSessionId) else {
            os_log("    failed to create request", log: self.log, type: .error)
            return
        }
        
        // get shared URLSession
        let sharedSession = URLSession.shared
        
        // create upload data as dictionary
        let bgReadingsDictionaryRepresentation = bgReadingsToUpload.map({$0.dictionaryRepresentationForDexcomShareUpload})
        let uploadDataAsDictionary:[String : Any] = [
            "Egvs" : bgReadingsDictionaryRepresentation,
            "SN" : dexcomShareSerialNumber,
            "TA" : -5
        ]
        
        do {
            
            // create upload data in json format
            let uploadData = try JSONSerialization.data(withJSONObject: uploadDataAsDictionary, options: [])
            
            // Create upload Task
            let dataTask = sharedSession.uploadTask(with: request, from: uploadData, completionHandler: { (data, response, error) -> Void in
                
                os_log("in uploadBgReadingsToDexcomShare, in uploadTask completionHandler", log: self.log, type: .info)
                
                // error cases
                if let error = error {
                    os_log("    failed to upload, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
                    return
                }
                
                // check that response is HTTPURLResponse
                if let response = response as? HTTPURLResponse {
                    
                    if let data = data {
                        
                        // if data is empty, then this means the upload was successful
                        if data.count == 0 {
                            
                            // success
                            if let lastReading = bgReadingsToUpload.first {
                                os_log("    upload succeeded, setting timeStampLatestDexcomShareUploadedBgReading to %{public}@", log: self.log, type: .info, lastReading.timeStamp.description(with: .current))
                                UserDefaults.standard.timeStampLatestDexcomShareUploadedBgReading = lastReading.timeStamp
                            }
                            
                            return

                        } else {
                            
                            // returned data, which means an error occurred - although it's still possible that it was successful, eg DuplicateEgvPosted is considered successful
                            if let dataAsString = String(data: data, encoding: String.Encoding.utf8) {
                                os_log("    response from Dexcom = %{public}@", log: self.log, type: .error, dataAsString)
                            }

                            // try json decoding
                            guard let decoded = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
                                else {
                                    os_log("    JSONSerialization failed", log: self.log, type: .error)
                                    return
                            }
                            
                            // if status code is not in range 200 to 299 then it's an error case
                            if !(200...299).contains(response.statusCode) {
                                
                                // failure is a JSON object containing the error code
                                let errorCode = (decoded as? [String: String])?["Code"] ?? "unknown"
                                
                                os_log("    failed to upload, statuscode = %{public}@, error = %{public}@", log: self.log, type: .error, response.statusCode.description, errorCode)
                                
                                // evaluate the error code
                                if errorCode == "SessionNotValid" || errorCode == "SessionIdNotFound" {
                                    
                                    // reset dexcomShareSessionId
                                    self.dexcomShareSessionId = nil
                                    
                                    // try to login again and if successful retry upload readings
                                    self.loginAndStoreSessionId { (success, error) in
                                        DispatchQueue.main.async {
                                            if success {
                                                os_log("in uploadBgReadingsToDexcomShare, new login successful", log: self.log, type: .info)
                                                // retry the upload
                                                self.uploadBgReadingsToDexcomShare(firstAttempt: false)
                                            } else {
                                                os_log("in uploadBgReadingsToDexcomShare, new login failed", log: self.log, type: .error)
                                            }
                                        }
                                    }
                                    
                                    return
                                    
                                } else if errorCode == "MonitoringSessionNotActive" {
                                    // call startRemoteMonitoringSessionAndStartUpload in main thread
                                    DispatchQueue.main.async {
                                        self.startRemoteMonitoringSessionAndStartUpload()
                                    }
                                    return
                                    
                                } else if errorCode == "DuplicateEgvPosted" {
                                    // consider as successful
                                    // don't return
                                    
                                } else if errorCode == "MonitoredReceiverSerialNumberDoesNotMatch" {
                                    os_log("in uploadBgReadingsToDexcomShare, new login failed with error MonitoredReceiverSerialNumberDoesNotMatch", log: self.log, type: .error)
                                    DispatchQueue.main.async {
                                        if let messageHandler = self.messageHandler {
                                            messageHandler(Texts_DexcomShareTestResult.uploadErrorWarning, Texts_DexcomShareTestResult.monitoredReceiverSNDoesNotMatch)
                                        }
                                    }
                                    return
                                    
                                } else if errorCode == "MonitoredReceiverNotAssigned" {
                                    os_log("in uploadBgReadingsToDexcomShare, new login failed with error MonitoredReceiverNotAssigned", log: self.log, type: .error)
                                    DispatchQueue.main.async {
                                        if let messageHandler = self.messageHandler {
                                            messageHandler(Texts_DexcomShareTestResult.uploadErrorWarning, self.createMonitoredReceiverNotAssignedMessage(acount: dexcomShareAccountName, serialNumber: dexcomShareSerialNumber))
                                        }
                                    }
                                    return
                                    
                                } else {
                                    // unknown error code -  the error code value is already logged
                                    os_log("in uploadBgReadingsToDexcomShare, new login failed with unknown error code", log: self.log, type: .error)
                                    return
                                }
                                
                            }
                            
                            // success
                            if let lastReading = bgReadingsToUpload.first {
                                os_log("    upload succeeded, setting timeStampLatestDexcomShareUploadedBgReading to %{public}@", log: self.log, type: .info, lastReading.timeStamp.description(with: .current))
                                UserDefaults.standard.timeStampLatestDexcomShareUploadedBgReading = lastReading.timeStamp
                            }
                            return
                        }
                    } else {
                        
                        // don't think we should every come here
                        os_log("    no data received, considered successful upload", log: self.log, type: .error)

                        if let lastReading = bgReadingsToUpload.first {
                            os_log("    upload succeeded, setting timeStampLatestDexcomShareUploadedBgReading to %{public}@", log: self.log, type: .info, lastReading.timeStamp.description(with: .current))
                            UserDefaults.standard.timeStampLatestDexcomShareUploadedBgReading = lastReading.timeStamp
                        }
                        return
                        
                    }
                    
                } else {
                    os_log("    failed to upload, response is not HTTPURLResponse", log: self.log, type: .error)
                    return
                }
                
            })
            
            dataTask.resume()
            
        } catch let error {
            os_log("     failed to upload, error = %{public}@", log: self.log, type: .info, error.localizedDescription)
            return
        }

    }
    
    
    /// test dexcom share credentials (accountname, password) - the credentials must be not nil in userdefaults, otherwise completion is called with error
    ///
    /// in case of success, the function will store the dexcomShareSessionId
    private func loginAndStoreSessionId( _ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        os_log("in testDexcomShareCredentials", log: self.log, type: .info)
        
        guard let url = URL(string: dexcomShareUrl), let dexcomShareAccountName = UserDefaults.standard.dexcomShareAccountName, let dexcomSharePassword = UserDefaults.standard.dexcomSharePassword else {
            
            os_log("    required credentials are not set", log: self.log, type: .error)
            completion(false, NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "required credentials are not set or failed to create url"]))
            return
            
        }
            
        // create url
        let testURL = url.appendingPathComponent(loginPath)
        
        // create the request
        var request = URLRequest(url: testURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        
        do {
            
            // create authParameters in json format
            let uploadData = try JSONSerialization.data(withJSONObject: [
                "accountName": dexcomShareAccountName,
                "password": dexcomSharePassword,
                "applicationId": ConstantsDexcomShare.applicationId
                ], options: [])
            
            // get shared URLSession
            let sharedSession = URLSession.shared
            
            // Create upload Task
            let dataTask = sharedSession.uploadTask(with: request, from: uploadData, completionHandler: { (data, response, error) -> Void in
                
                os_log("    in uploadTask completionHandler", log: self.log, type: .info)
                
                // error cases
                if let error = error {
                    os_log("    failed to login, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
                    completion(false, error)
                    return
                }
                
                // check that response is HTTPURLResponse
                if let response = response as? HTTPURLResponse {
                    
                    if let data = data {
                        
                        // data has sessionid (if success) or error details (if failure) which can be logged and shown to the user
                        guard let decoded = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
                            else {
                                
                                os_log("    failed to login, JSONSerialization failed", log: self.log, type: .error)
                                completion(false, NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Could not do JSONSerialization of data"]))
                                return
                        }
                        
                        guard (200...299).contains(response.statusCode) else {
                            
                            os_log("    failed to login, statuscode = %{public}@", log: self.log, type: .error, response.statusCode.description)
                            
                            // failure should be a JSON object containing the error reason, if not use "unknown" as error code
                            let errorCode = (decoded as? [String: String])?["Code"] ?? "unknown"
                            
                            completion(false, NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: errorCode]))
                            
                            return
                        }
                        
                        //there's no error, means decoded should now have the value of the new sessionid
                        if let dexcomShareSessionId = decoded as? String {
                            
                            // success is a JSON-encoded string containing the dexcomShareSessionId
                            os_log("    successful login", log: self.log, type: .info)
                            self.dexcomShareSessionId = dexcomShareSessionId
                            
                            completion(true, nil)
                            
                            return
                            
                        } else {
                            
                            // failure
                            os_log("    failed to login, failed to get dexcomShareSessionId, decoded is not a string", log: self.log, type: .error)
                            
                            completion(false, NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "decoded is not a string"]))
                            
                            return
                        }
                        
                        
                    } else {
                        os_log("    failed to login, no date received", log: self.log, type: .error)
                        completion(false, NSError(domain: "", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "no data received"]))
                        return
                    }
                    
                } else {
                    os_log("    response is not HTTPURLResponse", log: self.log, type: .error)
                    completion(false, NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "response is not HTTPURLResponse"]))
                    return
                }
                
            })
            
            dataTask.resume()

        } catch let error {
            os_log("     %{public}@", log: self.log, type: .info, error.localizedDescription)
            completion(false, NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
            return
        }
    }

    /// calls messageHandler with title and errorMessage. Title text will depend on success.
    private func callMessageHandler(withCredentialVerificationResult success:Bool, errorMessage:String?) {
        // define the title text
        var title = Texts_DexcomShareTestResult.verificationSuccessFulAlertTitle
        if !success {
            title = Texts_DexcomShareTestResult.verificationErrorAlertTitle
        }
        
        // if error.localizedDescription one of the known Dexcom share error codes, then translate
        
        
        // define the message text
        var message = Texts_DexcomShareTestResult.verificationSuccessFulAlertBody
        if !success {
            if let errorMessage = errorMessage {
                message = errorMessage
            } else {
                message = "unknown error"// shouldn't happen
            }
        }
        
        // call messageHandler
        if let messageHandler = messageHandler {
            messageHandler(title, message)
        }
    }
    
    /// if error.localizedDescription is one of the known Dexcom login error codes, then a translation will be done
    /// - parameters:
    ///     - errorText : if nil returnvalue will also be nil
    /// - returns:
    ///     - if errorText is known Dexcom error text, then returnValue will be translated text, else returns errorText
    private func translateDexcomErrorMessage(errorText: String?) -> String? {
        
        guard let errorText = errorText else {return nil}
        
        if errorText.uppercased() == "SSO_AuthenticateAccountNotFound".uppercased() {
            return Texts_DexcomShareTestResult.authenticateAccountNotFound
        } else if errorText.uppercased() == "SSO_AuthenticatePasswordInvalid".uppercased() {
            return Texts_DexcomShareTestResult.authenticatePasswordInvalid
        } else if errorText.uppercased() == "SSO_AuthenticateMaxAttemptsExceeed".uppercased() {
            return Texts_DexcomShareTestResult.authenticateMaxAttemptsExceeded
        } else {
            return errorText
        }
        
    }
    
    /// creates the message to be displayed to user when MonitoredReceiverNotAssigned error occurs
    ///
    /// this is just to minimize a bit the lines of code in the calling function
    private func createMonitoredReceiverNotAssignedMessage(acount: String, serialNumber:String) -> String {
        return Texts_DexcomShareTestResult.monitoredReceiverNotAssigned1 + " " + serialNumber + " " + Texts_DexcomShareTestResult.monitoredReceiverNotAssigned2 + " " + acount + ". " + Texts_DexcomShareTestResult.monitoredReceiverNotAssigned3
    }
    
    /// will check value of UserDefaults.standard.dexcomShareAccountName, UserDefaults.standard.dexcomSharePassword, UserDefaults.standard.uploadReadingstoDexcomShare
    private func requiredSettingsAreNotNil() -> Bool {
        return UserDefaults.standard.dexcomShareAccountName != nil && UserDefaults.standard.dexcomSharePassword != nil && UserDefaults.standard.uploadReadingstoDexcomShare
    }
    
    /// creates URLRequest to be used for uploading readings to Dexcom Share Server
    /// - returns:
    ///     - a URLRequest, shouldn't be nil normally, if it is looks more like a coding error
    private func createURLRequestForUploadBgReadings(dexcomShareSessionId:String) -> URLRequest? {
        // create url
        guard let url = URL(string: dexcomShareUrl) else {
            os_log("in createURLRequestForUploadBgReadings, failed to create url", log: self.log, type: .error)
            return nil
        }
        let postReceiverEgvRecordsUrl = url.appendingPathComponent(postReceiverEgvRecordsPath)
        
        // create NSURLComponents instance with scheme, host, queryItems
        guard let components = NSURLComponents(url: postReceiverEgvRecordsUrl, resolvingAgainstBaseURL: false) else {
            os_log("in createURLRequestForUploadBgReadings, failed to create components", log: self.log, type: .error)
            return nil
        }
        components.scheme = postReceiverEgvRecordsUrl.scheme
        components.host = postReceiverEgvRecordsUrl.host
        components.queryItems = [URLQueryItem(name: "sessionId", value: dexcomShareSessionId)]
        
        guard let newUrl = components.url else {
            os_log("in createURLRequestForUploadBgReadings, failed to create newUrl", log: self.log, type: .error)
            return nil
        }
        
        //create the request
        var request = URLRequest(url: newUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue("Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")
        
        return request
    }
}
