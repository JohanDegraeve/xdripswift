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

class LibreOOPClient {
    
    // MARK: - properties
    
    /// for trace
    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreOOPClient)
    
    /// get the libre glucose data by server
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - libreSensorSerialNumber : sensor sn
    ///   - patchInfo : will be used by server to out the glucose data
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: server data that contains the 344 bytes details, is called in DispatchQueue.main.async
    static func getLibreRawGlucoseOOPData(libreData: Data, libreSensorSerialNumber: LibreSensorSerialNumber, patchInfo: String, oopWebSite: String, oopWebToken: String, callback:@escaping (LibreRawGlucoseOOPData) -> Void) {
        
        let item = URLQueryItem(name: "accesstoken", value: oopWebToken)
        let item1 = URLQueryItem(name: "patchUid", value: libreSensorSerialNumber.uidString.uppercased())
        let item2 = URLQueryItem(name: "patchInfo", value: patchInfo)
        let item3 = URLQueryItem(name: "content", value: libreData.hexEncodedString())
        
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
                        trace("in getLibreRawGlucoseOOPData, data is nil", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                        return
                    }
                    
                    // trace data as string in debug mode
                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                        trace("in getLibreRawGlucoseOOPData, data received frop oop web server = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .debug, dataAsString)
                    }
                    
                    let decoder = JSONDecoder()
                    
                    if let oopValue = try? decoder.decode(LibreRawGlucoseOOPData.self, from: data) {
                        
                        callback(oopValue)
                        
                    } else {
                        
                        // json parsing failed
                        trace("in getLibreRawGlucoseOOPData, could not do json parsing", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                        
                        // if response is not nil then trace
                        if let response = String(data: data, encoding: String.Encoding.utf8) {
                            
                            trace("in getLibreRawGlucoseOOPData,    data as string = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, response)
                            
                        }
                        
                        return
                        
                    }

                }

            }
            
            task.resume()
            
        } else {
            
            return
            
        }
    }

    /// if `patchInfo.hasPrefix("A2") 'Libre 1 A2', server uses another arithmetic to handle the 344 bytes
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - callback: server data that contains the 344 bytes details
    static func getLibreRawGlucoseOOPOA2Data (libreData: Data, oopWebSite: String,  callback:@escaping (LibreRawGlucoseOOPA2Data) -> Void) {

        if let uploadURL = URL(string: "\(oopWebSite)/callnox") {
            do {
                var request = URLRequest(url: uploadURL)
                request.httpMethod = "POST"
                let data = try JSONSerialization.data(withJSONObject: [["timestamp": "\(Int(Date().timeIntervalSince1970 * 1000))",
                    "content": libreData.hexEncodedString()]], options: [])
                let string = String.init(data: data, encoding: .utf8)
                let json: [String: String] = ["userId": "1",
                                           "list": string!]
                request.setBodyContent(contentMap: json)
                let task = URLSession.shared.dataTask(with: request as URLRequest) {
                    data, response, error in
                    
                    DispatchQueue.main.async {
                        
                        if let error = error {
                            trace("in getLibreRawGlucoseOOPOA2Data, error is not nil, error = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, error.localizedDescription)
                            return
                        }
                        
                        guard let data = data else {
                            trace("in getLibreRawGlucoseOOPOA2Data, data is nil", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                            return
                        }
                        
                        // trace data as string in debug mode
                        if let dataAsString = String(bytes: data, encoding: .utf8) {
                            trace("in getOopWebCalibrationStatus, data as string", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .debug)
                            debuglogging("dataastring = " + dataAsString)
                        }
                        
                        let decoder = JSONDecoder()
                        
                        do {
                            
                            
                            let oopValue = try decoder.decode(LibreRawGlucoseOOPA2Data.self, from: data)
                            
                            callback(oopValue)
                            
                        } catch {
                            
                            // json parsing failed
                            trace("in getLibreRawGlucoseOOPOA2Data, could not do json parsing", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                            
                            // if response is not nil then trace
                            if let response = String(data: data, encoding: String.Encoding.utf8) {
                                
                                trace("in getLibreRawGlucoseOOPOA2Data,    data as string = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, response)
                                
                            }
                            
                            return
                            
                        }

                    }
                    
                }
                
                task.resume()
                
            } catch let error {
                
                    trace("     failed to upload, error = %{public}@", log: log, category: ConstantsLog.categoryDexcomShareUploadManager, type: .info, error.localizedDescription)
                    return
                    
            }
        }
    }
        
    /// get the `Libre1DerivedAlgorithmParameters for Libre1 Sensor, either from UserDefaults (if already fetched earlier for that sensor), or from oopWeb. If oopWeb fetch fails, then default values are used
    /// - Parameters:
    ///   - bytes: the 344 bytes from Libre sensor
    ///   - libreSensorSerialNumber: LibreSensorSerialNumber is a structure that hold the serial number
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: takes LibreDerivedAlgorithmParameters`as parameter, will not be called if there's no result for instance because oop web server can not be reached
    static func getLibre1DerivedAlgorithmParameters(bytes: Data, libreSensorSerialNumber: LibreSensorSerialNumber, oopWebSite: String, oopWebToken: String, callback: @escaping (Libre1DerivedAlgorithmParameters) -> Void) {
        
        // the parameters of one sensor will not be changed, if the values are already available in userdefaults , then use those values
        if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters {
            if libre1DerivedAlgorithmParameters.serialNumber == libreSensorSerialNumber.serialNumber {
                
                callback(libre1DerivedAlgorithmParameters)
                return
                
            }
        }
        
        // calibration parameters not available yet, get them from oopWebSite
        let json: [String: String] = [
            "token": oopWebToken,
            "content": "\(bytes.hexEncodedString())",
            "timestamp": "\(Date().toMillisecondsAsInt64())",
        ]
        
        if let uploadURL = URL(string: "\(oopWebSite)/calibrateSensor") {
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setBodyContent(contentMap: json)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
                
                DispatchQueue.main.async {
                    
                    if let error = error {
                        
                        trace("in getOopWebCalibrationStatus, received error : %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, error.localizedDescription)
                        
                        return
                        
                    }
                    
                    guard let data = data else {
                        
                        trace("in getOopWebCalibrationStatus, data is nil", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                        
                        return
                        
                    }
                    
                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                        trace("in getOopWebCalibrationStatus, data as string", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .debug)
                        debuglogging("dataastring = " + dataAsString)
                    }

                    // trace data as string in debug mode
                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                        trace("in getOopWebCalibrationStatus, data as string", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .debug)
                        debuglogging("dataastring = " + dataAsString)
                    }

                    // data is not nil, let's try to do json decoding
                    let decoder = JSONDecoder()
                    
                    do {
                        
                        let response = try decoder.decode(OopWebCalibrationStatus.self, from: data)
                        
                        if let slope = response.slope {
                            
                            if let libreDerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0, sensorSerialNumber: libreSensorSerialNumber.serialNumber) {
                                
                                // store result in UserDefaults, next time, server will not be used anymore, we will use the stored value
                                UserDefaults.standard.libre1DerivedAlgorithmParameters = libreDerivedAlgorithmParameters
                                
                                callback(libreDerivedAlgorithmParameters)
                                
                            }
                        }
                    } catch {
                        
                        // json parsing failed
                        trace("in calibrateSensor, could not do json parsing", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                        
                        // if response is not nil then trace
                        if let response = String(data: data, encoding: String.Encoding.utf8) {
                            
                            trace("    data as string = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, response)
                            
                        }
                        
                    }

                }
                
            }
            
            task.resume()
            
        }

    }

}
