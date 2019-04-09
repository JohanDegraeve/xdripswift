import Foundation
import os

public class NightScoutUploader {
    
    // MARK: - properties
    
    /// for readings and calibrations
    private let nightScoutEntriesPath = "/api/v1/entries"
    
    /// for treatments
    private let nightScoutTreatmentPath = "/api/v1/treatments"
    
    /// for devicestatus
    private let nightScoutDeviceStatusPath = "/api/v1/devicestatus"
    
    /// to test API Secret
    private let nightScoutAuthTestPath = "/api/v1/experiments/test"

    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryNightScoutUploader)
    
    /// BgReadings instance
    private let bgReadings:BgReadings
    
    init(bgReadings:BgReadings) {
        self.bgReadings = bgReadings
    }
    
    /// synchronizes all NightScout related, if needed
    public func synchronize() {
        // check if NightScout upload is enabled
        if UserDefaults.standard.uploadReadingsToNightScout, let siteURL = UserDefaults.standard.nightScoutUrl, let apiKey = UserDefaults.standard.nightScoutAPIKey {
            uploadBgReadingsToNightScout(siteURL: siteURL, apiKey: apiKey)
        }
    }
    
    private func uploadBgReadingsToNightScout(siteURL:String, apiKey:String) {
        
        os_log("in uploadBgReadingsToNightScout", log: self.log, type: .info)

        let bgReadingsToUpload = bgReadings.getLatestBgReadings(limit: nil, fromDate: UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        if bgReadingsToUpload.count > 0 {
            os_log("    number of readings to upload : %{public}@", log: self.log, type: .info, bgReadingsToUpload.count.description)

            // map readings to dictionaryRepresentation
            let bgReadingsDictionaryRepresentation = bgReadingsToUpload.map({$0.dictionaryRepresentation})
            
            do {
                // transform to json
                let sendData = try JSONSerialization.data(withJSONObject: bgReadingsDictionaryRepresentation, options: [])
                
                // then do this map thing
                
                // get shared URLSession
                let sharedSession = URLSession.shared
                
                if let url = URL(string: siteURL) {
                    // create upload url
                    let uploadURL = url.appendingPathComponent(nightScoutEntriesPath)
                    
                    // Create Request
                    var request = URLRequest(url: uploadURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.setValue(apiKey.sha1(), forHTTPHeaderField: "api-secret")
                    
                    // Create upload Task
                    let dataTask = sharedSession.uploadTask(with: request, from: sendData, completionHandler: { (data, response, error) -> Void in
                        
                        os_log("in uploadTask completionHandler", log: self.log, type: .info)
                        
                        // log returned data
                        if let data = data, let dataAsString = String(data: data, encoding: String.Encoding.utf8) {
                            os_log("       %{public}@", log: self.log, type: .info, dataAsString)
                        }
                        
                        // error cases
                        if let error = error {
                            os_log("    failed to upload, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
                            return
                        }
                        
                        if let response = response as? HTTPURLResponse {
                            guard (200...299).contains(response.statusCode) else {
                                os_log("    failed to upload, statuscode = %{public}@", log: self.log, type: .error, response.statusCode.description)
                                
                                return
                            }
                        } else {
                            os_log("    response is not HTTPURLResponse", log: self.log, type: .error)
                        }
                        
                        // successful cases, change timeStampLatestNightScoutUploadedBgReading
                        if let lastReading = bgReadingsToUpload.first {
                            os_log("    upload succeeded, setting timeStampLatestNightScoutUploadedBgReading to %{public}@", log: self.log, type: .info, lastReading.timeStamp.description(with: .current))
                            UserDefaults.standard.timeStampLatestNightScoutUploadedBgReading = lastReading.timeStamp
                        }
                        
                        // log the result from NightScout
                        guard let data = data, !data.isEmpty else {
                            os_log("    empty response received", log: self.log, type: .info)
                            return
                        }
                        
                    })
                    dataTask.resume()
                }
            } catch let error {
                os_log("     %{public}@", log: self.log, type: .info, error.localizedDescription)
            }
            
        } else {
            os_log("    no readings to upload", log: self.log, type: .info)
        }
        
    }
}
