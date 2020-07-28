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
    
    // MARK: - public functions
    
    /// get the libre glucose data by server
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - libreSensorSerialNumber : sensor sn
    ///   - patchInfo : will be used by server to out the glucose data
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - oopWebToken: the token to use if oop web would be enabled
    ///   - callback: LibreRawGlucoseOOPData and/or error
    static func getLibreRawGlucoseOOPData(libreData: Data, libreSensorSerialNumber: LibreSensorSerialNumber, patchInfo: String, oopWebSite: String, oopWebToken: String, callback:@escaping (LibreOOPWebServerResponseData?, _ xDripError: XdripError?) -> Void) {
        
        let item = URLQueryItem(name: "accesstoken", value: oopWebToken)
        let item1 = URLQueryItem(name: "patchUid", value: libreSensorSerialNumber.uidString.uppercased())
        let item2 = URLQueryItem(name: "patchInfo", value: patchInfo)
        let item3 = URLQueryItem(name: "content", value: libreData.hexEncodedString())

        var urlComponents = URLComponents(string: "\(oopWebSite)/libreoop2")!
        
        urlComponents.queryItems = [item, item1, item2, item3]
        
        if let uploadURL = URL(string: urlComponents.url?.absoluteString.removingPercentEncoding ?? "") {
            
            let request = NSMutableURLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            createDataTaskAndHandleResponse(LibreRawGlucoseOOPData.self, request: request as URLRequest, callback: callback)

        } else {
            
            return
            
        }
    }

    /// if `patchInfo.hasPrefix("A2") 'Libre 1 A2', server uses another arithmetic to handle the 344 bytes
    /// - Parameters:
    ///   - libreData: the 344 bytes from Libre sensor
    ///   - oopWebSite: the site url to use if oop web would be enabled
    ///   - callback: LibreRawGlucoseOOPA2Data and/or error
    static func getLibreRawGlucoseOOPOA2Data (libreData: Data, oopWebSite: String,  callback:@escaping (LibreOOPWebServerResponseData?, _ xDripError: XdripError?) -> Void) {

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
                
                createDataTaskAndHandleResponse(LibreRawGlucoseOOPA2Data.self, request: request, callback: callback)
                
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
    ///   - callback: takes OopWebCalibrationStatus`as parameter, and/or error
    static func getOopWebCalibrationStatus(bytes: Data, libreSensorSerialNumber: LibreSensorSerialNumber, oopWebSite: String, oopWebToken: String, callback: @escaping (_ oopWebCalibrationStatus: LibreOOPWebServerResponseData?, _ xDripError: XdripError?) -> Void) {
        
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
            
            createDataTaskAndHandleResponse(OopWebCalibrationStatus.self, request: request, callback: callback)
                
            
        } else {
            
            trace("in getOopWebCalibrationStatus, failed to create uploadURL", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .info)
            
        }

    }

    /// checks the error, response and data, makes json decoding to type, calls callback with result
    ///
    /// grouping common functionality in functions that make a post to the oop web server and need to analyse the respone. This analyses is done by this function here. It also calls the callback.
    /// LibreOOPWebServerResponseData is just a do nothing protocol to which a few specific classes conform. The calling function will use one of those classes as type parameter.
    private static func createDataTaskAndHandleResponse<T:LibreOOPWebServerResponseData>(_ type: T.Type, request: URLRequest, callback:@escaping ((_ libreOOPWebServerResponseData: LibreOOPWebServerResponseData?, _ xDripError: XdripError?) -> Void)) {
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            DispatchQueue.main.async {
                
                trace("in createDataTaskAndHandleResponse, finished task", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .info)
                
                if let error = error {
                    
                    trace("in createDataTaskAndHandleResponse, received error : %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, error.localizedDescription)
                    
                    callback(nil, LibreOOPWebError.genericError(error.localizedDescription))
                    
                    return
                    
                }
                
                guard let data = data else {
                    
                    trace("in createDataTaskAndHandleResponse, data is nil", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                    
                    callback(nil, LibreOOPWebError.receivedDataIsNil)
                    
                    return
                    
                }
                
                // if debug level tracing, then log the data as String
                if let dataAsString = String(bytes: data, encoding: .utf8), UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                    trace("in createDataTaskAndHandleResponse, data as string = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .debug, dataAsString)
                }
                
                // data is not nil, let's try to do json decoding
                let decoder = JSONDecoder()
               
                do {
                    
                    let response = try decoder.decode(type.self, from: data)
                    
                    if response.isError {

                        // if response isError is true, then still send the response, but also the msg, which should contain the error description
                        callback(response, LibreOOPWebError.jsonResponseHasError(msg: response.msg, errcode: response.errcode))
                        
                    } else {

                        callback(response, nil)

                    }
                 
                    return
                    
                } catch {
                    
                    // json parsing failed
                    trace("in createDataTaskAndHandleResponse, could not do json parsing", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error)
                    
                    // if response is not nil then trace
                    if let response = String(data: data, encoding: String.Encoding.utf8) {
                        
                        trace("    data as string = %{public}@", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .error, response)
                        
                    }
                    
                    callback(nil, LibreOOPWebError.jsonParsingFailed)
                    
                    return
                    
                }
                
            }
            
        }
        
        trace("in createDataTaskAndHandleResponse, calling task.resume", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .info)
        task.resume()
        
    }
    
}
