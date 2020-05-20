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
    
    // MARK: - public functions
    static func webOOP(uploadURL: URL, callback: ((LibreRawGlucoseOOPData?) -> ())?) {
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
    }
    
    static func oopParams(libreData: [UInt8], params: LibreDerivedAlgorithmParameters, timeStampLastBgReading: Date) -> [LibreRawGlucoseData] {
        let last16 = trendMeasurements(bytes: libreData, date: Date(), timeStampLastBgReading: timeStampLastBgReading, LibreDerivedAlgorithmParameterSet: params)
        if var glucoseData = trendToLibreGlucose(last16), let first = glucoseData.first {
            let last32 = historyMeasurements(bytes: libreData, date: first.timeStamp, LibreDerivedAlgorithmParameterSet: params)
            let glucose32 = trendToLibreGlucose(last32) ?? []
            let last96 = split(current: first, glucoseData: glucose32.reversed())
            glucoseData = last96
            return glucoseData
        } else {
            return []
        }
    }
    
    static func oop(libreData: Data, serialNumber: String, timeStampLastBgReading: Date, oopWebSite: String, oopWebToken: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int, errorDescription: String?)) -> Void) {
        let sensorState = LibreSensorState(stateByte: libreData[4])
        let body = Array(libreData[24 ..< 320])
        let sensorTime = Int(body[293]) << 8 + Int(body[292])
        guard sensorTime >= 60 else {
            callback(([], .starting, sensorTime, nil))
            return
        }
        
        calibrateSensor(bytes: [UInt8](libreData), serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken) {
            (calibrationparams)  in
            var params = LibreDerivedAlgorithmParameters.init(slope_slope: 0.13,
                                                              slope_offset: 0,
                                                              offset_slope: 0,
                                                              offset_offset: -20,
                                                              isValidForFooterWithReverseCRCs: 1,
                                                              extraSlope: 1.0,
                                                              extraOffset: 0.0, sensorSerialNumber: serialNumber)
            if let p = calibrationparams {
                params = p
                guard !p.isErrorParameters else {
                    callback(([], sensorState, sensorTime, "parameter error"))
                    return
                }
            }
            
            callback((oopParams(libreData: [UInt8](libreData), params: params, timeStampLastBgReading: timeStampLastBgReading),
                      sensorState,
                      sensorTime, nil))
        }
    }
    
    static func handleLibreData(libreData: Data, patchUid: String?, patchInfo: String?, timeStampLastBgReading: Date, serialNumber: String, oopWebSite: String, oopWebToken: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int, errorDescription: String?)) -> Void) {
        
        guard let patchUid = patchUid, let patchInfo = patchInfo else {
            oop(libreData: libreData, serialNumber: serialNumber, timeStampLastBgReading: timeStampLastBgReading, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback)
            return
        }
        
        let bytesAsData = Data(bytes: [UInt8](libreData), count: libreData.count)
        let item = URLQueryItem(name: "accesstoken", value: oopWebToken)
        let item1 = URLQueryItem(name: "patchUid", value: patchUid)
        let item2 = URLQueryItem(name: "patchInfo", value: patchInfo)
        let item3 = URLQueryItem(name: "content", value: bytesAsData.hexEncodedString())
        var urlComponents = URLComponents(string: "\(oopWebSite)/libreoop2")!
        urlComponents.queryItems = [item, item1, item2, item3]
        var retryCount = 1
        if let uploadURL = URL.init(string: urlComponents.url?.absoluteString.removingPercentEncoding ?? "") {
            func retry() {
                retryCount += 1
                webOOP(uploadURL: uploadURL) { oopValue in
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
                                    LibreOOPClient.calibrateSensor(bytes: [UInt8](libreData), serialNumber: serialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback: {_ in })
                                }
                            }
                            
                            if let time = oopValue.sensorTime {
                                var last96 = [LibreRawGlucoseData]()
                                if !(oopValue.historicGlucose?.isEmpty ?? true) {
                                    let value = oopValue.glucoseData(date: Date())
                                    last96 = split(current: value.0, glucoseData: value.1)
                                }
                                
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
                        if patchInfo.contains(find: "70") || patchInfo.contains(find: "E5")  {
                            oop(libreData: libreData, serialNumber: serialNumber, timeStampLastBgReading: timeStampLastBgReading, oopWebSite: oopWebSite, oopWebToken: oopWebToken, callback)
                        } else {
                            callback(([], .failure, 0, "network failed"))
                        }
                    }
                }
            }
            retry()
        }
    }
    
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
        
        let frameS = SKKeyframeSequence.init(keyframeValues: y, times: x as [NSNumber])
        frameS.interpolationMode = .spline
        var items = [LibreRawGlucoseData]()
        var ptime = endTime
        while ptime >= startTime {
            let value = (frameS.sample(atTime: CGFloat(ptime)) as? Double) ?? 0
            let item = LibreRawGlucoseData.init(timeStamp: Date.init(timeIntervalSince1970: ptime / 1000), glucoseLevelRaw: value)
            items.append(item)
            ptime -= 300000
        }
        return items
    }
    
    public static func calibrateSensor(bytes: [UInt8], serialNumber: String, oopWebSite: String, oopWebToken: String,  callback: @escaping (LibreDerivedAlgorithmParameters?) -> Void) {
        if let parameters = UserDefaults.standard.algorithmParameters {
            if parameters.serialNumber == serialNumber {
                callback(parameters)
                return
            }
        }
        
        post(bytes: bytes, oopWebSite: oopWebSite, oopWebToken: oopWebToken, { (data, str, can) in
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(GetCalibrationStatus.self, from: data)
                if let slope = response.slope {
                    var p = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope?.toDouble() ?? 0, slope_offset: slope.slopeOffset?.toDouble() ?? 0, offset_slope: slope.offsetSlope?.toDouble() ?? 0, offset_offset: slope.offsetOffset?.toDouble() ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0, sensorSerialNumber: serialNumber)
                    p.serialNumber = serialNumber
                    if p.slope_slope != 0 ||
                        p.slope_offset != 0 ||
                        p.offset_slope != 0 ||
                        p.offset_offset != 0 {
                        UserDefaults.standard.algorithmParameters = p
                        callback(p)
                    } else {
                        callback(nil)
                    }
                } else {
                    callback(nil)
                }
            } catch {
                callback(nil)
            }
        })
    }
    
    // MARK: - private functions
    
    static func post(bytes: [UInt8], oopWebSite: String, oopWebToken: String,_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
        let date = Date().toMillisecondsAsInt64()
        let bytesAsData = Data(bytes: bytes, count: bytes.count)
        let json: [String: String] = [
            "token": oopWebToken,
            "content": "\(bytesAsData.hexEncodedString())",
            "timestamp": "\(date)",
            "appName": "diabox"
        ]
        
        if let uploadURL = URL.init(string: "\(oopWebSite)/calibrateSensor") {
            let request = NSMutableURLRequest(url: uploadURL)
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
    
    static func dateOfMostRecentHistoryValue(minutesSinceStart: Int, nextHistoryBlock: Int, date: Date) -> (date: Date, counter: Int) {
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay) ), counter: minutesSinceStart - delay)
        } else {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay - 15)), counter: minutesSinceStart - delay)
        }
    }
    
    
    static func trendToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData]?{
        
        var origarr = [LibreRawGlucoseData]()
        for trend in measurements {
            let glucose = LibreRawGlucoseData.init(timeStamp: trend.date, glucoseLevelRaw: trend.temperatureAlgorithmGlucose)
            origarr.append(glucose)
        }
        return origarr
    }
    
}
