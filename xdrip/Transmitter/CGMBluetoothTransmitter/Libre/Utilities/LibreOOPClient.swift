////
////  RemoteBG.swift
////  SwitftOOPWeb
////
////  Created by Bjørn Inge Berg on 08.04.2018.
////  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
////
//
//
//  LibreOOPClient.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 08.04.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
//
import Foundation

class LibreOOPClient {
    
    private var accessToken: String
    private var uploadEndpoint: String   // = "https://libreoopweb.azurewebsites.net/api/CreateRequestAsync"
    private var statusEndpoint: String   // = "https://libreoopweb.azurewebsites.net/api/GetStatus"
    private var calibrationEndpoint: String
    private var calibrationStatusEndpoint: String
    private static let filePath: String = NSHomeDirectory() + "/Documents/paras"
    
    init(accessToken: String, site: String = "https://libreoopweb.azurewebsites.net") {
        self.accessToken = accessToken
        self.uploadEndpoint = site + "/api/CreateRequestAsync"
        self.statusEndpoint = site + "/api/GetStatus"
        self.calibrationEndpoint = site + "/api/CreateCalibrationRequestAsync"
        self.calibrationStatusEndpoint = site + "/api/GetCalibrationStatus"
    }
    
    private static func readingToString(_ a: [UInt8]) -> String {
        return Data(a).base64EncodedString()
    }
    private func postToServer(_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void), postURL: String, postparams: [String: String]) {
        
        let request = NSMutableURLRequest(url: NSURL(string: postURL)! as URL)
        request.httpMethod = "POST"
        
        request.setBodyContent(contentMap: postparams)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, _ in
            
            guard let data = data else {
                completion("network error".data(using: .utf8)!, "network error", false)
                return
            }
            
            if let response = String(data: data, encoding: String.Encoding.utf8) {
                completion(data, response, true)
            }
            
        }
        task.resume()
        
    }
    
    private func getStatusIntervalled(uuid: String, intervalSeconds: UInt32=10, maxTries: Int8=8, _ completion:@escaping ((  _ success: Bool, _ message: String, _ oopCurrentValue: OOPCurrentValue?, _ newState: String) -> Void)) {
        
        let sem = DispatchSemaphore(value: 0)
        var oopCurrentValue: OOPCurrentValue? = nil
        var succeeded = false
        var error = ""
        var newState2 = ""
        
        DispatchQueue.global().async {
            for i in 1...maxTries {
                NSLog("Attempt \(i): Waiting \(intervalSeconds) seconds before calling getstatus")
                sleep(intervalSeconds)
                NSLog("Finished waiting \(intervalSeconds) seconds before calling getstatus")
                if (succeeded) {
                    error = ""
                    break
                    
                }
                self.getStatus(uuid: uuid, { (success, errormsg, response, newState) in
                    if (success) {
                        succeeded = true
                        newState2 = newState ?? ""
                        oopCurrentValue = self.getOOPCurrentValue(from: response)
                    } else {
                        error = errormsg
                    }
                    sem.signal()
                })
                
                sem.wait()
                
                /*if let oopCurrentValue = oopCurrentValue {
                 
                 NSLog("Hey hop, response received with success: \(succeeded)");
                 NSLog("Decoded content")
                 NSLog("  Current trend: \(oopCurrentValue.currentTrend)")
                 NSLog("  Current bg: \(oopCurrentValue.currentBg)")
                 NSLog("  Current time: \(oopCurrentValue.currentTime)")
                 NSLog("  Serial Number: \(oopCurrentValue.serialNumber ?? "-")")
                 NSLog("  timeStamp: \(oopCurrentValue.timestamp)")
                 var i = 0
                 for historyValue in oopCurrentValue.historyValues {
                 NSLog(String(format: "    #%02d: time: \(historyValue.time), quality: \(historyValue.quality), bg: \(historyValue.bg)", i))
                 i += 1
                 }
                 }*/
                
                if (succeeded) {
                    error = ""
                    break
                }
            }
            
            completion(succeeded, error, oopCurrentValue, newState2)
        }
    }
    
    private func getOOPCurrentValue(from response: String?) -> OOPCurrentValue? {
        // Decode json response string into OOPCurrentValue struct.
        // This requires to remove the beginning of the response string up to "FullAlgoResults"
        if let response = response,
            let jsonStringStartIndex = response.range(of: "FullAlgoResults: ")?.upperBound {
            do {
                let jsonString = String(response.suffix(from: jsonStringStartIndex))
                if let jsonData = jsonString.data(using: .utf8) {
                    let oopCurrentValue = try JSONDecoder().decode(OOPCurrentValue.self, from: jsonData)
                    return oopCurrentValue
                }
            } catch let error {
                NSLog("Error decoding json respons: \(error)")
            }
        }
        return nil
    }
    
    private func getStatus(uuid: String, _ completion:@escaping ((  _ success: Bool, _ message: String, _ response: String?, _ newState: String? ) -> Void)) {
        postToServer({ (data, response, success) in
            NSLog("getstatus here:" + response)
            if(!success) {
                NSLog("Get status failed")
                completion(false, response, response, nil)
                return
            }
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(LibreOOPResponse.self, from: data)
                
                NSLog("getstatus result received")
                if let msg = response.message {
                    NSLog("Error sending GetStatus request " + msg)
                    completion(false, "Error sending GetStatus reques" + msg, nil, nil)
                    //failureHandler(msg)
                    return
                }
                if let resp = response.result, let result2 = resp.result {
                    NSLog("GetStatus returned a valid result:"  + result2)
                    
                    completion(true, "", result2, resp.newState!)
                    return
                } else {
                    NSLog("Result was not ready,")
                    completion(false, "Result was not ready", nil, nil)
                    return
                }
                
            } catch (let error as NSError) {
                
                completion(false, error.localizedDescription, nil, nil)
                return
            }
            
        }, postURL: statusEndpoint, postparams: ["accesstoken": self.accessToken, "uuid": uuid])
    }
    
    private func uploadReading(reading: String, oldState: String?=nil, sensorStartTimestamp: Int?=nil, sensorScanTimestamp: Int?=nil, currentUtcOffset: Int?=nil, _ completion:@escaping (( _ resp: LibreOOPResponse?, _ success: Bool, _ errorMessage: String) -> Void)) {
        var postParams = ["accesstoken": self.accessToken, "b64contents": reading]
        
        if let oldState = oldState {
            postParams["oldState"] = oldState
        }
        
        if let sensorStartTimestamp = sensorStartTimestamp {
            postParams["sensorStartTimestamp"] = "\(sensorStartTimestamp)"
        }
        
        if let sensorScanTimestamp = sensorScanTimestamp {
            postParams["sensorScanTimestamp"] = "\(sensorScanTimestamp)"
        }
        
        if let currentUtcOffset = currentUtcOffset {
            postParams["currentUtcOffset"] = "\(currentUtcOffset)"
        }
        
        postToServer({ (data, _, success)  in
            
            if(!success) {
                
                completion(nil, false, "network error!?")
                return
            }
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(LibreOOPResponse.self, from: data)
                if let msg = result.message {
                    
                    completion(nil, false, msg)
                    return
                }
                
                completion(result, true, "")
                return
                
            } catch let error as NSError {
                completion(nil, false, error.localizedDescription)
                return
            }
            
        }, postURL: uploadEndpoint, postparams: postParams)
    }
    
    private func uploadDependantReadings(readings: [LibreReadingResult]) -> [(success: Bool, String, OOPCurrentValue?, String)]? {
        var ret = [(Bool, String, OOPCurrentValue?, String)]()
        
        var prevReading: LibreReadingResult? = nil
        
        for (_, var reading) in readings.enumerated() {
            
            //the semaphore lets me do the requests in-order
            let awaiter = DispatchSemaphore( value: 0 )
            
            let tempState = prevReading?.newState ?? LibreOOPDefaults.defaultState
            self.uploadReading(reading: reading.b64Contents, oldState: tempState, sensorStartTimestamp: LibreOOPDefaults.sensorStartTimestamp, sensorScanTimestamp: LibreOOPDefaults.sensorScanTimestamp, currentUtcOffset: LibreOOPDefaults.currentUtcOffset) { (response, success, errormessage) in
                if(!success) {
                    NSLog("remote: upload reading failed! \(errormessage)")
                    ret.append((success, errormessage, nil, ""))
                    awaiter.signal()
                    return
                }
                
                if let response = response, let uuid = response.result?.uuid {
                    print("uuid received: " + uuid)
                    self.getStatusIntervalled(uuid: uuid, { (success, errormessage, oopCurrentValue, newState) in
                        if let oopCurrentValue = oopCurrentValue {
                            ret.append((success, errormessage, oopCurrentValue, newState))
                            reading.newState = newState
                            prevReading = reading
                            
                        }
                        awaiter.signal()
                    })
                } else {
                    awaiter.signal()
                }
                
            }
            awaiter.wait()
            
        }
        
        return ret
    }
    
    private func getCalibrationStatus(uuid: String, _ completion:@escaping ((  _ success: Bool, _ message: String, _ response: LibreDerivedAlgorithmParameters?) -> Void)) {
        postToServer({ (data, response, success) in
            NSLog("getCalibrationStatus here:" + response + ", data: \(data)")
            if(!success) {
                NSLog("getCalibrationStatus failed")
                completion(false, response, nil)
                return
            }
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(GetCalibrationStatus.self, from: data)
                
                NSLog("getCalibrationStatus result received")
                
                if response.error ?? false {
                    completion(false, "getCalibrationStatus failes due to error", nil)
                    return
                }
                
                if let slope = response.result, slope.status == "complete" {
                    print("calibration  ready")
                    
                    let params = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0)

                    completion(true, "complete", params )
                    return
                }
                
                
                print("calibration  is not ready, status is not ready")
                
                completion(false, "result not ready", nil)
                
            } catch (let error as NSError) {
                print("got error trying to decode GetCalibrationStatus")
                completion(false, error.localizedDescription, nil)
                return
            }
            
        }, postURL: calibrationStatusEndpoint, postparams: ["accesstoken": self.accessToken, "uuid": uuid])
    }
    
    private static func post(bytes: [UInt8],_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
        let date = Int(Date().timeIntervalSince1970 * 1000)
        let bytesAsData = Data(bytes: bytes, count: bytes.count)
        let json: [String: String] = [
            "token": "bubble-201907",
            "content": "\(bytesAsData.hexEncodedString())",
            "timestamp": "\(date)"]
        if let uploadURL = URL.init(string: "http://www.glucose.space/calibrateSensor") {
            let request = NSMutableURLRequest(url: uploadURL)
            request.httpMethod = "POST"
            
            request.setBodyContent(contentMap: json)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                data, response, _ in
                
                guard let data = data else {
                    completion("network error".data(using: .utf8)!, "network error", false)
                    return
                }
                
                if let response = String(data: data, encoding: String.Encoding.utf8) {
                    completion(data, response, true)
                }
                
            }
            task.resume()
        }
    }

    private static func save(data: Data) {
        let url = URL.init(fileURLWithPath: filePath)
        do {
            try data.write(to: url)
        } catch {
            print("write error:", error)
        }
    }

    public static func calibrateSensor(bytes: [UInt8], serialNumber: String,  callback: @escaping (LibreDerivedAlgorithmParameters?) -> Void) {
        let url = URL.init(fileURLWithPath: filePath)
        if FileManager.default.fileExists(atPath: url.path) {
            let decoder = JSONDecoder()
            do {
                let data = try Data.init(contentsOf: url)
                let response = try decoder.decode(LibreDerivedAlgorithmParameters.self, from: data)
                if response.serialNumber == serialNumber {
                    callback(response)
                    return
                }
            } catch {
                print("decoder error:", error)
            }
        }
        
        post(bytes: bytes, { (data, str, can) in
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(GetCalibrationStatus.self, from: data)
                if let slope = response.slope {
                    var para = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0)
                    para.serialNumber = serialNumber
                    do {
                        let data = try JSONEncoder().encode(para)
                        save(data: data)
                    } catch {
                        print("encoder error:", error)
                    }
                    callback(para)
                } else {
                    callback(nil)
                }
            } catch {
                print("got error trying to decode GetCalibrationStatus")
                callback(nil)
            }
        })
    }
}
