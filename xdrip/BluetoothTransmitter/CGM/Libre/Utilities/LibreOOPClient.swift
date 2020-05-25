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
// adapted by Johan Degraeve for xdrip ios
import Foundation
import os

import SpriteKit
import UserNotifications

public class LibreOOPClient {
    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreOOPClient)
    
    
    /// get the libre glucose data by server
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - patchUid : sensor sn hex string
    ///   - patchInfo : will be used by server to out the glucose data
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: server data that contains the 344 bytes details
    static func webOOP(libreData: [UInt8], patchUid: String, patchInfo: String, oopWebSite: String, oopWebToken: String, callback: ((LibreRawGlucoseOOPData?) -> Void)?) {
        let bytesAsData = Data(bytes: libreData, count: libreData.count)
        let item = URLQueryItem(name: "accesstoken", value: oopWebToken)
        let item1 = URLQueryItem(name: "patchUid", value: patchUid)
        let item2 = URLQueryItem(name: "patchInfo", value: patchInfo)
        let item3 = URLQueryItem(name: "content", value: bytesAsData.hexEncodedString())
        var urlComponents = URLComponents(string: "\(oopWebSite)/libreoop2")!
        urlComponents.queryItems = [item, item1, item2, item3]
        if let uploadURL = URL.init(string: urlComponents.url?.absoluteString.removingPercentEncoding ?? "") {
            let request = NSMutableURLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                data, response, error in
                DispatchQueue.main.async {
                    guard let data = data else {
                        callback?(nil)
                        return
                    }
                    
                    let decoder = JSONDecoder.init()
                    if let oopValue = try? decoder.decode(LibreRawGlucoseOOPData.self, from: data) {
                        callback?(oopValue)
                    } else {
                        callback?(nil)
                    }
                }
            }
            task.resume()
        } else {
            callback?(nil)
        }
    }
    
    
    /// if server failed, will parse the 344 bytes by `LibreMeasurement`
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - params: local algorithm use this
    ///   - timeStampLastBgReading: timestamp of last reading, older readings will be ignored
    /// - Returns: glucose data
    static func oopParams(libreData: [UInt8], params: LibreDerivedAlgorithmParameters, timeStampLastBgReading: Date) -> [LibreRawGlucoseData] {
        // get current glucose from 344 bytes
        let last16 = trendMeasurements(bytes: libreData, date: Date(), timeStampLastBgReading: timeStampLastBgReading, LibreDerivedAlgorithmParameterSet: params)
        if let glucoseData = trendToLibreGlucose(last16), let first = glucoseData.first {
            // get histories from 344 bytes
            let last32 = historyMeasurements(bytes: libreData, date: first.timeStamp, LibreDerivedAlgorithmParameterSet: params)
            // every 15 minutes apart
            let glucose32 = trendToLibreGlucose(last32) ?? []
            // every 5 minutes apart, fill data by `SKKeyframeSequence`
            let last96 = split(current: first, glucoseData: glucose32.reversed())
            return last96
        } else {
            return []
        }
    }
    
    /// get the parameters and local parse
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - serialNumber: sensor serial number
    ///   - timeStampLastBgReading: timestamp of last reading, older readings will be ignored
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: will be called when glucose data is read with as parameter the timestamp of the last reading.
    static func oop(libreData: [UInt8], serialNumber: String, timeStampLastBgReading: Date, oopWebSite: String, oopWebToken: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int, errorDescription: String?)) -> Void) {
        let sensorState = LibreSensorState(stateByte: libreData[4])
        let body = Array(libreData[24 ..< 320])
        let sensorTime = Int(body[293]) << 8 + Int(body[292])
        // if sensor time < 60, it can not get the parameters from the server
        guard sensorTime >= 60 else {
            callback(([], .starting, sensorTime, nil))
            return
        }
        
        // get LibreDerivedAlgorithmParameters
        calibrateSensor(bytes: [UInt8](libreData), serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken) {
            (calibrationparams)  in
            callback((oopParams(libreData: [UInt8](libreData), params: calibrationparams, timeStampLastBgReading: timeStampLastBgReading),
                      sensorState,
                      sensorTime, nil))
        }
    }
    
    /// if `patchInfo.hasPrefix("A2")`, server uses another arithmetic to handle the 344 bytes
    /// - Parameters:
    ///   - libreData:  the 344 bytes from Libre sensor
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - callback: server data that contains the 344 bytes details
    static func handleLibreA2Data(libreData: [UInt8], oopWebSite: String, callback: ((LibreRawGlucoseOOPA2Data?) -> Void)?) {
        let bytesAsData = Data(bytes: libreData, count: libreData.count)
        if let uploadURL = URL.init(string: "\(oopWebSite)/callnox") {
            do {
                var request = URLRequest(url: uploadURL)
                request.httpMethod = "POST"
                let data = try JSONSerialization.data(withJSONObject: [["timestamp": "\(Int(Date().timeIntervalSince1970 * 1000))",
                    "content": bytesAsData.hexEncodedString()]], options: [])
                let string = String.init(data: data, encoding: .utf8)
                let json: [String: String] = ["userId": "1",
                                           "list": string!]
                request.setBodyContent(contentMap: json)
                let task = URLSession.shared.dataTask(with: request as URLRequest) {
                    data, response, error in
                    do {
                        guard let data = data else {
                            callback?(nil)
                            return
                        }
                        let decoder = JSONDecoder.init()
                        let oopValue = try decoder.decode(LibreRawGlucoseOOPA2Data.self, from: data)
                        callback?(oopValue)
                    } catch {
                        callback?(nil)
                    }
                }
                task.resume()
            } catch {
                callback?(nil)
            }
        }
    }
    
    
    /// handle server data from two functions `webOOP` and `handleLibreA2Data`, parse the data to glucse data
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - patchInfo: sensor sn hex string
    ///   - oopValue: parsed value
    ///   - timeStampLastBgReading: timestamp of last reading, older readings will be ignored
    ///   - serialNumber: serial number
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: will be called when glucose data is read with as parameter the timestamp of the last reading.
    static func handleGlucose(libreData: [UInt8], patchInfo: String, oopValue: LibreRawGlucoseWeb?, timeStampLastBgReading: Date, serialNumber: String, oopWebSite: String, oopWebToken: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int, errorDescription: String?)) -> Void) {
        if let oopValue = oopValue, !oopValue.isError {
            if oopValue.valueError {
                if oopValue.sensorState == .notYetStarted {
                    callback(([], .notYetStarted, 0, nil))
                } else {
                    callback(([], .failure, 0, nil))
                }
            } else {
                if oopValue.canGetParameters {
                    if UserDefaults.standard.algorithmParameters?.serialNumber != serialNumber {
                        calibrateSensor(bytes: [UInt8](libreData), serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback: {_ in })
                    }
                }
                
                if let time = oopValue.sensorTime {
                    var last96 = [LibreRawGlucoseData]()
                    let value = oopValue.glucoseData(date: Date())
                    last96 = split(current: value.0, glucoseData: value.1)
                    
                    if time < 20880 {
                        callback((last96, oopValue.sensorState, time, nil))
                    } else {
                        callback(([], .expired, time, nil))
                    }
                } else {
                    callback(([], oopValue.sensorState, 0, nil))
                }
            }
        } else {
            // only patchInfo `hasPrefix` "70" and "E5" can use the local parse
            if patchInfo.hasPrefix("70") || patchInfo.hasPrefix("E5")  {
                oop(libreData: libreData, serialNumber: serialNumber, timeStampLastBgReading: timeStampLastBgReading, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback)
            } else {
                callback(([], .failure, 0, nil))
            }
        }
    }
    
    
    /// handle 344 bytes
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - patchUid: sensor sn hex string
    ///   - patchInfo: will be used by server to out the glucose data
    ///   - timeStampLastBgReading: timestamp of last reading, older readings will be ignored
    ///   - serialNumber: serial number
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: will be called when glucose data is read with as parameter the timestamp of the last reading.
    static func handleLibreData(libreData: Data, patchUid: String?, patchInfo: String?, timeStampLastBgReading: Date, serialNumber: String, oopWebSite: String, oopWebToken: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int, errorDescription: String?)) -> Void) {
        let bytes = [UInt8](libreData)
        guard let patchUid = patchUid, let patchInfo = patchInfo else {
            oop(libreData: bytes, serialNumber: serialNumber, timeStampLastBgReading: timeStampLastBgReading, oopWebSite: oopWebSite, oopWebToken: oopWebToken,  callback)
            return
        }
        // if patchInfo.hasPrefix("A2"), server uses another arithmetic to handle the 344 bytes
        if patchInfo.hasPrefix("A2") {
            handleLibreA2Data(libreData: bytes, oopWebSite: oopWebSite) { (data) in
                DispatchQueue.main.async {
                    handleGlucose(libreData: bytes, patchInfo: patchInfo, oopValue: data, timeStampLastBgReading: timeStampLastBgReading, serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback)
                }
            }
        } else {
            DispatchQueue.main.async {
                webOOP(libreData: bytes, patchUid: patchUid, patchInfo: patchInfo, oopWebSite: oopWebSite, oopWebToken: oopWebToken) { (data) in
                    handleGlucose(libreData: bytes, patchInfo: patchInfo, oopValue: data, timeStampLastBgReading: timeStampLastBgReading, serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback)
                }
            }
        }
    }
    
    
    /// 15 minutes apart to 5 minutes apart
    /// - Parameters:
    ///   - current: current glucose
    ///   - glucoseData: histories
    /// - Returns: contains current glucose and histories, 5 minutes apart
    static func split(current: LibreRawGlucoseData?, glucoseData: [LibreRawGlucoseData]) -> [LibreRawGlucoseData] {
        var x = [Double]()
        var y = [Double]()
        
        if let current = current {
            let timeInterval = current.timeStamp.timeIntervalSince1970 * 1000
            x.append(timeInterval)
            y.append(current.glucoseLevelRaw)
        }
        
        for glucose in glucoseData.reversed() {
            let time = glucose.timeStamp.timeIntervalSince1970 * 1000
            x.insert(time, at: 0)
            y.insert(glucose.glucoseLevelRaw, at: 0)
        }
        
        let startTime = x.first ?? 0
        let endTime = x.last ?? 0
        
        // add glucoses to `SKKeyframeSequence`
        let frameS = SKKeyframeSequence.init(keyframeValues: y, times: x as [NSNumber])
        frameS.interpolationMode = .spline
        var items = [LibreRawGlucoseData]()
        var ptime = endTime
        while ptime >= startTime {
            // get value from SKKeyframeSequence
            let value = (frameS.sample(atTime: CGFloat(ptime)) as? Double) ?? 0
            let item = LibreRawGlucoseData.init(timeStamp: Date.init(timeIntervalSince1970: ptime / 1000), glucoseLevelRaw: value)
            items.append(item)
            ptime -= 300000
        }
        return items
    }
    
    /// get the `LibreDerivedAlgorithmParameters`
    /// - Parameters:
    ///   - bytes: the 344 bytes from Libre sensor
    ///   - serialNumber: serial number
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: return `LibreDerivedAlgorithmParameters`
    public static func calibrateSensor(bytes: [UInt8], serialNumber: String, oopWebSite: String, oopWebToken: String,  callback: @escaping (LibreDerivedAlgorithmParameters) -> Void) {
        // the parameters of one sensor will not be changed, if have cached it, get it from userdefaults
        if let parameters = UserDefaults.standard.algorithmParameters {
            if parameters.serialNumber == serialNumber {
                callback(parameters)
                return
            }
        }
        
        // default parameters
        let params = LibreDerivedAlgorithmParameters.init(slope_slope: 0.00001729,
                                                          slope_offset: -0.0006316,
                                                          offset_slope: 0.002080,
                                                          offset_offset: -20.15,
                                                          isValidForFooterWithReverseCRCs: 1,
                                                          extraSlope: 1.0,
                                                          extraOffset: 0.0,
                                                          sensorSerialNumber: serialNumber)
        
        post(bytes: bytes, oopWebSite: oopWebSite, oopWebToken: oopWebToken, { (data, str, can) in
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(GetCalibrationStatus.self, from: data)
                if let slope = response.slope {
                    var libreDerivedAlgorithmParameters = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope ?? 0,
                                                                 slope_offset: slope.slopeOffset ?? 0,
                                                                 offset_slope: slope.offsetSlope ?? 0,
                                                                 offset_offset: slope.offsetOffset ?? 0,
                                                                 isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1),
                                                                 extraSlope: 1.0,
                                                                 extraOffset: 0.0,
                                                                 sensorSerialNumber: serialNumber)
                    libreDerivedAlgorithmParameters.serialNumber = serialNumber
                    if !libreDerivedAlgorithmParameters.isErrorParameters {
                        UserDefaults.standard.algorithmParameters = libreDerivedAlgorithmParameters
                        callback(libreDerivedAlgorithmParameters)
                    } else {
                        // server values all 0, `isErrorParameters` is true
                        // return the default parameters
                        callback(params)
                    }
                } else {
                    // encoding data failed, no need to handle as an error, it means probably next time a new post will be done to the oop web server
                    trace("in calibrateSensor, slope is nil", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                    // return the default parameters
                    callback(params)
                }
            } catch {
                // encoding data failed, return the default parameters
                callback(params)
                trace("in calibrateSensor, error while encoding data : %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, error.localizedDescription)
            }
        })
    }
    
    
    /// get `LibreDerivedAlgorithmParameters` from server
    /// - Parameters:
    ///   - bytes: the 344 bytes from Libre sensor
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - completion: network result
    static func post(bytes: [UInt8], oopWebSite: String, oopWebToken: String,_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
        let date = Date().toMillisecondsAsInt64()
        let bytesAsData = Data(bytes: bytes, count: bytes.count)
        let json: [String: String] = [
            "token": oopWebToken,
            "content": "\(bytesAsData.hexEncodedString())",
            "timestamp": "\(date)",
        ]
        
        if let uploadURL = URL.init(string: "\(oopWebSite)/calibrateSensor") {
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setBodyContent(contentMap: json)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                data, response, error in
                
                guard let data = data else {
                    DispatchQueue.main.sync {
                        completion("network error".data(using: .utf8)!, "network error", false)
                    }
                    return
                    
                }
                
                if let response = String(data: data, encoding: String.Encoding.utf8) {
                    DispatchQueue.main.sync {
                        completion(data, response, true)
                    }
                    return
                }
                
                DispatchQueue.main.sync {
                    completion("response error".data(using: .utf8)!, "response error", false)
                }
                
            }
            task.resume()
        }
    }
    
    
    /// current glucose value from 344 bytes
    /// - Parameters:
    ///   - bytes: the 344 bytes from Libre sensor
    ///   - date: the current date
    ///   - timeStampLastBgReading: timestamp of last reading, older readings will be ignored
    ///   - offset: glucose offset to be added in mg/dl
    ///   - slope: slope to calculate glucose from raw value in (mg/dl)/raw
    ///   - LibreDerivedAlgorithmParameterSet: algorithm parameters
    /// - Returns: return parsed values
    static func trendMeasurements(bytes: [UInt8], date: Date, timeStampLastBgReading: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        guard bytes.count >= 320 else { return [] }
        //    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
        let bodyRange   =  24 ..< 320  // 296 bytes, i.e. 37 blocks a 8 bytes
        //    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
        
        let body   = Array(bytes[bodyRange])
        let nextTrendBlock = Int(body[2])
        
        var measurements = [LibreMeasurement]()
        // Trend data is stored in body from byte 4 to byte 4+96=100 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0 ... 15 {
            var index = 4 + (nextTrendBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 4 {
                index = index + 96 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            guard index + 6 < body.count else { break }
            let range = index ..< index + 6
            let measurementBytes = Array(body[range])
            let measurementDate = date.addingTimeInterval(Double(-60 * blockIndex))
            
            if measurementDate > timeStampLastBgReading {
                let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
                measurements.append(measurement)
            }
        }
        return measurements
    }
    
    /// histories for 344 bytes
    /// - Parameters:
    ///   - bytes: the 344 bytes from Libre sensor
    ///   - date: the current date
    ///   - offset: glucose offset to be added in mg/dl
    ///   - slope: slope to calculate glucose from raw value in (mg/dl)/raw
    ///   - LibreDerivedAlgorithmParameterSet: algorithm parameters
    /// - Returns: return parsed values
    static func historyMeasurements(bytes: [UInt8], date: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        guard bytes.count >= 320 else { return [] }
        let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
        let body   = Array(bytes[bodyRange])
        let nextHistoryBlock = Int(body[3])
        let minutesSinceStart = Int(body[293]) << 8 + Int(body[292])
        var measurements = [LibreMeasurement]()
        // History data is stored in body from byte 100 to byte 100+192-1=291 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0..<32 {
            var index = 100 + (nextHistoryBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 100 {
                index = index + 192 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            guard index + 6 < body.count else { break }
            let range = index..<index+6
            let measurementBytes = Array(body[range])
            let (date, counter) = dateOfMostRecentHistoryValue(minutesSinceStart: minutesSinceStart, nextHistoryBlock: nextHistoryBlock, date: date)
            let final = date.addingTimeInterval(Double(-900 * blockIndex))
            let measurement = LibreMeasurement(bytes: measurementBytes,
                                               slope: slope,
                                               offset: offset,
                                               minuteCounter: counter - blockIndex * 15,
                                               date: final,
                                               LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
            measurements.append(measurement)
        }
        return measurements
    }
    
    
    /// Get date of most recent history value.
    /// History values are updated every 15 minutes. Their corresponding time from start of the sensor in minutes is 15, 30, 45, 60, ..., but the value is delivered three minutes later, i.e. at the minutes 18, 33, 48, 63, ... and so on. So for instance if the current time in minutes (since start of sensor) is 67, the most recent value is 7 minutes old. This can be calculated from the minutes since start. Unfortunately sometimes the history index is incremented earlier than the minutes counter and they are not in sync. This has to be corrected.
    /// - Parameters:
    ///   - minutesSinceStart: /// Minutes (approx) since start of sensor
    ///   - nextHistoryBlock: /// Index on the next block of trend data that the sensor will measure and store
    ///   - date: the current date
    /// - Returns: the date of the most recent history value and the corresponding minute counter
    static func dateOfMostRecentHistoryValue(minutesSinceStart: Int, nextHistoryBlock: Int, date: Date) -> (date: Date, counter: Int) {
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay) ), counter: minutesSinceStart - delay)
        } else {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay - 15)), counter: minutesSinceStart - delay)
        }
    }
    
    
    /// to glucose data
    /// - Parameter measurements: measurements
    /// - Returns: glucose data
    static func trendToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData]?{
        
        var origarr = [LibreRawGlucoseData]()
        for trend in measurements {
            let glucose = LibreRawGlucoseData.init(timeStamp: trend.date, glucoseLevelRaw: trend.temperatureAlgorithmGlucose)
            origarr.append(glucose)
        }
        return origarr
    }
    
}
