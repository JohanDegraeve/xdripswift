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

class LibreOOPClient {
    
    // MARK: - properties
    
    private static let filePath: String = NSHomeDirectory() + ConstantsLibreOOP.filePathForParameterStorage
    
    /// for trace
    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreOOPClient)

    // MARK: - public functions
    
    public static func handleLibreData(libreData: [UInt8], timeStampLastBgReading: Date, serialNumber: String, _ callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int)?) -> Void) {
        //only care about the once per minute readings here, historical data will not be considered
        
        let sensorState = LibreSensorState(stateByte: libreData[4])

        LibreOOPClient.calibrateSensor(bytes: libreData, serialNumber: serialNumber) {
            (calibrationparams)  in
            guard let params = calibrationparams else {
                callback(nil)
                return
            }
            
            //here we assume success, data is not changed,
            //and we trust that the remote endpoint returns correct data for the sensor
            var date = Date()
            #if DEBUG
//            date = date.addingTimeInterval(-60 * 60 * 8)
            #endif
            let last16 = trendMeasurements(bytes: libreData, date: date, timeStampLastBgReading: timeStampLastBgReading, LibreDerivedAlgorithmParameterSet: params)
            if var glucoseData = trendToLibreGlucose(last16), let first = glucoseData.first {
                let last32 = historyMeasurements(bytes: libreData, date: first.timeStamp, LibreDerivedAlgorithmParameterSet: params)
                let glucose32 = trendToLibreGlucose(last32) ?? []
                var result = ""
                for g in last32 {
                    result += "\(g.temperatureAlgorithmGlucose), \(g.date)\n"
                }
                let last96 = split(current: first, glucoseData: glucose32)
                glucoseData = last96
                callback((glucoseData, sensorState, 0))
            }
        }
    }
    
    private static func split(current: LibreRawGlucoseData?, glucoseData: [LibreRawGlucoseData]) -> [LibreRawGlucoseData] {
        var x = [Double]()
        var y = [Double]()
        
        if let current = current {
            let timeInterval = current.timeStamp.timeIntervalSince1970 * 1000
            x.append(timeInterval)
            y.append(current.glucoseLevelRaw)
        }
        
        for glucose in glucoseData {
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
    

    private static func calibrateSensor(bytes: [UInt8], serialNumber: String,  callback: @escaping (LibreDerivedAlgorithmParameters?) -> Void) {
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
                    print(para)
                    do {
                        let data = try JSONEncoder().encode(para)
                        save(data: data)
                    } catch {
                        trace("in calibrateSensor, error : %{public}@@", log: log, type: .error, error.localizedDescription)
                    }

                    callback(para)
                    
                } else {
                    trace("in calibrateSensor, failed to decode", log: log, type: .error)
                    callback(nil)
                }
            } catch {
                trace("in calibrateSensor, got error trying to decode GetCalibrationStatus", log: log, type: .error)
                callback(nil)
            }
        })
    }
    
    // MARK: - private functions
    
    private static func post(bytes: [UInt8],_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
        let date = Date().toMillisecondsAsInt64()
        let bytesAsData = Data(bytes: bytes, count: bytes.count)
        let json: [String: String] = [
            "token": ConstantsLibreOOP.token, 
            "content": "\(bytesAsData.hexEncodedString())",
            "timestamp": "\(date)"]
        if let uploadURL = URL.init(string: ConstantsLibreOOP.site) {
            let request = NSMutableURLRequest(url: uploadURL)
            request.httpMethod = "POST"
            
            request.setBodyContent(contentMap: json)
//            guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else { return }
//            request.httpBody = data
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                data, response, error in
                
                guard let data = data else {
                    
                    trace("in post, network error", log: log, type: .error)
                    
                    DispatchQueue.main.sync {
                        completion("network error".data(using: .utf8)!, "network error", false)
                    }
                    return

                }
                
                if let response = String(data: data, encoding: String.Encoding.utf8) {
                    
                    trace("in post, successful", log: log, type: .info)

                    DispatchQueue.main.sync {
                        completion(data, response, true)
                    }
                    
                    return
                    
                }
                
                trace("in post, response error", log: log, type: .error)
                DispatchQueue.main.sync {
                    completion("response error".data(using: .utf8)!, "response error", false)
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

    private static func trendMeasurements(bytes: [UInt8], date: Date, timeStampLastBgReading: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        
        //    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
        let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
        //    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
        
        let body   = Array(bytes[bodyRange])
        let nextTrendBlock = Int(body[2])
        
        var measurements = [LibreMeasurement]()
        // Trend data is stored in body from byte 4 to byte 4+96=100 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0...15 {
            var index = 4 + (nextTrendBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 4 {
                index = index + 96 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            let range = index..<index+6
            let measurementBytes = Array(body[range])
            let measurementDate = date.addingTimeInterval(Double(-60 * blockIndex))
            
            if measurementDate > timeStampLastBgReading {
                let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
                measurements.append(measurement)
            }
            
        }
        return measurements
    }
    
    private static func historyMeasurements(bytes: [UInt8], date: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        //    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
        let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
        //    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
        
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
            
            let range = index..<index+6
            let measurementBytes = Array(body[range])
            //            let measurementDate = dateOfMostRecentHistoryValue().addingTimeInterval(Double(-900 * blockIndex)) // 900 = 60 * 15
            //            let measurement = Measurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate)
            let (date, counter) = dateOfMostRecentHistoryValue(minutesSinceStart: minutesSinceStart, nextHistoryBlock: nextHistoryBlock, date: date)
            
            let final = date.addingTimeInterval(Double(-900 * blockIndex))
            let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, counter: counter - blockIndex * 15, date: final, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
            measurements.append(measurement)
        }
        return measurements
    }
    
    private static func dateOfMostRecentHistoryValue(minutesSinceStart: Int, nextHistoryBlock: Int, date: Date) -> (date: Date, counter: Int) {
        // Calculate correct date for the most recent history value.
        //        date.addingTimeInterval( 60.0 * -Double( (minutesSinceStart - 3) % 15 + 3 ) )
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay) ), counter: minutesSinceStart - delay)
        } else {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay - 15)), counter: minutesSinceStart - delay)
        }
    }
    
    
    private static func trendToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData]?{
        
        var origarr = [LibreRawGlucoseData]()
        
        for trend in measurements {
            let glucose = LibreRawGlucoseData(timeStamp: trend.date, unsmoothedGlucose: trend.temperatureAlgorithmGlucose)
//            debuglogging("in trendToLibreGlucose before CalculateSmothedData5Points, glucose.glucoseLevelRaw = " + glucose.glucoseLevelRaw.description + ", glucose.unsmoothedGlucose = " + glucose.unsmoothedGlucose.description)
            origarr.append(glucose)
        }
        
        var arr : [LibreRawGlucoseData]
        arr = LibreGlucoseSmoothing.CalculateSmothedData5Points(origtrends: origarr)

        for glucose in arr {
            debuglogging("in trendToLibreGlucose after CalculateSmothedData5Points, glucose.glucoseLevelRaw = " + glucose.glucoseLevelRaw.description + ", glucose.unsmoothedGlucose = " + glucose.unsmoothedGlucose.description)
        }

        return arr
    }

}
