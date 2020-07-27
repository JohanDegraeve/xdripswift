import Foundation
import os

/// for trace
fileprivate let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreDataParser)

class LibreDataParser {
    
    // MARK: - public functions
    
    /// parses libre1 block, without oop web.
    /// - parameters:
    ///     - libreData: the 344 bytes block from Libre
    ///     - timeStampLastBgReading: this is of the timestamp of the latest reading we already received during previous session
    /// - returns:
    ///     - array of GlucoseData, first is the most recent. Only returns recent readings, ie not the ones that are older than timeStampLastBgReading. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReading
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes
    public static func parseLibre1DataWithoutCalibration(libreData: Data, timeStampLastBgReading:Date) -> (glucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int) {
        
        var i:Int
        var glucoseData:GlucoseData
        var byte:Data
        var timeInMinutes:Double
        let ourTime:Date = Date()
        let indexTrend:Int = libreData.getByteAt(position: 26) & 0xFF
        let indexHistory:Int = libreData.getByteAt(position: 27) & 0xFF
        let sensorTimeInMinutes:Int = 256 * (libreData.getByteAt(position: 317) & 0xFF) + (libreData.getByteAt(position: 316) & 0xFF)
        let sensorStartTimeInMilliseconds:Double = ourTime.toMillisecondsAsDouble() - (Double)(sensorTimeInMinutes * 60 * 1000)
        var returnValue:Array<GlucoseData> = []
        let sensorState = LibreSensorState(stateByte: libreData[4])
        
       // we will add the most recent readings, but then we'll only add the readings that are at least 5 minutes apart (giving 10 seconds spare)
        // for that variable timeStampLastAddedGlucoseData is used. It's initially set to now + 5 minutes
        var timeStampLastAddedGlucoseData = Date().toMillisecondsAsDouble() + 5 * 60 * 1000
        
        trendloop: for index in 0..<16 {
            i = indexTrend - index - 1
            if i < 0 {i += 16}
            timeInMinutes = max(0, (Double)(sensorTimeInMinutes - index))
            let timeStampOfNewGlucoseData = sensorStartTimeInMilliseconds + timeInMinutes * 60 * 1000
            
            //new reading should be at least 30 seconds younger than timeStampLastBgReading
            if timeStampOfNewGlucoseData > (timeStampLastBgReading.toMillisecondsAsDouble() + 30000.0)
            {
                if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                    byte = Data()
                    byte.append(libreData[(i * 6 + 29)])
                    byte.append(libreData[(i * 6 + 28)])
                    let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                    if (glucoseLevelRaw > 0) {
                        glucoseData = GlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: glucoseLevelRaw * ConstantsBloodGlucose.libreMultiplier)
                        returnValue.append(glucoseData)
                        timeStampLastAddedGlucoseData = timeStampOfNewGlucoseData
                    }
                }
            } else {
                break trendloop
            }
        }

        // loads history values
        historyloop: for index in 0..<32 {
            i = indexHistory - index - 1
            if i < 0 {i += 32}
            timeInMinutes = max(0,(Double)(abs(sensorTimeInMinutes - 3)/15)*15 - (Double)(index*15))
            let timeStampOfNewGlucoseData = sensorStartTimeInMilliseconds + timeInMinutes * 60 * 1000
            
            //new reading should be at least 30 seconds younger than timeStampLastBgReading
            if timeStampOfNewGlucoseData > (timeStampLastBgReading.toMillisecondsAsDouble() + 30000.0)
            {
                if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                    byte = Data()
                    byte.append(libreData[(i * 6 + 125)])
                    byte.append(libreData[(i * 6 + 124)])
                    let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                    if (glucoseLevelRaw > 0) {
                        glucoseData = GlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: glucoseLevelRaw * ConstantsBloodGlucose.libreMultiplier)
                        returnValue.append(glucoseData)
                        timeStampLastAddedGlucoseData = timeStampOfNewGlucoseData
                    }
                }
            } else {
                break historyloop
            }
        }

        return (returnValue, sensorState, sensorTimeInMinutes)
        
    }
    
    /// - Process Libre block for all types of Libre sensors, and for both with and without web oop (without only for Libre 1). It checks if webOOP is enabled, if yes tries to use the webOOP, response is processed and delegate is called. If webOOP not enabled, and if Libre1, then local processing is done, in that case glucose values are not calibrated
    /// - if an error occurred, then this function will call cgmTransmitterDelegate.errorOccurred
    /// - parameters:
    ///     - libreSensorSerialNumber : if nil, then webOOP will not be used and local parsing will be done, but only for Libre 1
    ///     - patchInfo : will be used by server to out the glucose data, corresponds to type of sensor. Nil if not known which is used for Bubble or MM older firmware versions and also Watlaa
    ///     - libreData : the 344 bytes from Libre sensor
    ///     - timeStampLastBgReading : timestamp of last reading, older readings will be ignored. This is only used to save some processing time. If not known, set it to Date(timeIntervalSince1970: 0)
    ///     - webOOPEnabled : is webOOP enabled or not, if not enabled, local parsing is used. This can only be the case for Libre1
    ///     - oopWebSite : the site url to use if oop web would be enabled
    ///     - oopWebToken : the token to use if oop web would be enabled
    ///     - cgmTransmitterDelegate : the cgmTransmitterDelegate, will be used to send the resultin glucose data and sensorTime (function cgmTransmitterInfoReceived)
    ///     - completionHandler : called with timeStampLastBgReading, sensorState and xDripError
    public static func libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber?, patchInfo: String?, webOOPEnabled: Bool, oopWebSite: String?, oopWebToken: String?, libreData: Data, cgmTransmitterDelegate : CGMTransmitterDelegate?, timeStampLastBgReading: Date, completionHandler:@escaping ((_ timeStampLastBgReading: Date?, _ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {

        // get libreSensorType, if this fails then it must be an unknown Libre sensor type in which case we don't proceed
        guard let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) else {
            
            // unwrap patchInfo, although it can't be nil here because LibreSensorType.type would have returned .libre1 otherwise
            if let patchInfo = patchInfo {
                
                trace("in libreDataProcessor, failed to create libreSensorType, patchInfo = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, patchInfo)
                
            }
            
            return
            
        }
        
        trace("in libreDataProcessor, sensortype = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, libreSensorType.description)
        
        // let's see if we must use webOOP (if webOOPEnabled is true) and if so if we have all required info (libreSensorSerialNumber, oopWebSite and oopWebToken)
        if let libreSensorSerialNumber = libreSensorSerialNumber, let oopWebSite = oopWebSite, let oopWebToken = oopWebToken, webOOPEnabled {
            
            switch libreSensorType {
                
            case .libre1A2, .libre1, .libreProH:// these types are all Libre 1
                
                // If the values are already available in userdefaults , then use those values
                if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber == libreSensorSerialNumber.serialNumber {
                    
                    trace("in libreDataProcessor, found libre1DerivedAlgorithmParameters in UserDefaults", log: log, category: ConstantsLog.categoryLibreOOPClient, type: .info)
                    
                    // parse the data using oop web algorithm
                    let parsedResult = parseLibre1DataWithOOPWebCalibration(libreData: libreData, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters, timeStampLastBgReading: timeStampLastBgReading)
                    
                    handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
                    
                    return
                    
                }

                // get LibreDerivedAlgorithmParameters and parse using the libre1DerivedAlgorithmParameters
                LibreOOPClient.getOopWebCalibrationStatus(bytes: libreData, libreSensorSerialNumber: libreSensorSerialNumber, oopWebSite: oopWebSite, oopWebToken: oopWebToken) { (oopWebCalibrationStatus, xDripError) in

                    if let oopWebCalibrationStatus = oopWebCalibrationStatus as? OopWebCalibrationStatus,
                        let slope = oopWebCalibrationStatus.slope {
                        
                        let libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0, sensorSerialNumber: libreSensorSerialNumber.serialNumber)
                        
                        // store result in UserDefaults, next time, server will not be used anymore, we will use the stored value
                        UserDefaults.standard.libre1DerivedAlgorithmParameters = libre1DerivedAlgorithmParameters
                        
                        // if debug level logging enabled, than add full dump of libre1DerivedAlgorithmParameters in the trace (checking here to save some processing time if it's not needed
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            trace("in libreDataProcessor, received libre1DerivedAlgorithmParameters = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .debug, libre1DerivedAlgorithmParameters.description)
                        }
                        
                        // parse the data using oop web algorithm
                        let parsedResult = parseLibre1DataWithOOPWebCalibration(libreData: libreData, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters, timeStampLastBgReading: timeStampLastBgReading)
                        
                        handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
                        
                    } else {

                        // libre1DerivedAlgorithmParameters not created, but possibly xDripError is not nil, so we need to call handleGlucoseData which will process xDripError
                        handleGlucoseData(result: ([LibreRawGlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    }

                }
                
            case .libreUS:// not sure if this works for libreUS
                
                // libreUS isn't working yet, create an error and send to delegate
                cgmTransmitterDelegate?.errorOccurred(xDripError: LibreOOPWebError.libreUSNotSupported)
                
                // continue anyway, although this will not work
                LibreOOPClient.getLibreRawGlucoseOOPOA2Data(libreData: libreData, oopWebSite: oopWebSite) { (libreRawGlucoseOOPA2Data, xDripError) in
                    
                    if let libreRawGlucoseOOPA2Data = libreRawGlucoseOOPA2Data as? LibreRawGlucoseOOPA2Data {

                        // if debug level logging enabled, than add full dump of libreRawGlucoseOOPA2Data in the trace (checking here to save some processing time if it's not needed
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            trace("in libreDataProcessor, received libreRawGlucoseOOPA2Data = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .debug, libreRawGlucoseOOPA2Data.description)
                            
                        }
                        
                        // convert libreRawGlucoseOOPA2Data to (libreRawGlucoseData:[LibreRawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
                        let parsedResult = libreRawGlucoseOOPA2Data.glucoseData(timeStampLastBgReading: timeStampLastBgReading)
                        
                        handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    } else {
                        
                        // libreRawGlucoseOOPA2Data is nil, but possibly xDripError is not nil, so need to call handleGlucoseData which will process xDripError
                        handleGlucoseData(result: ([LibreRawGlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    }
                    
                }
                
            case .libre2:
                
                // patchInfo must be non nil to handle libre 2
                guard let patchInfo = patchInfo else {
                    trace("in libreDataProcessor, handling libre 2 but patchInfo is nil", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
                    return
                }
                
                LibreOOPClient.getLibreRawGlucoseOOPData(libreData: libreData, libreSensorSerialNumber: libreSensorSerialNumber, patchInfo: patchInfo, oopWebSite: oopWebSite, oopWebToken: oopWebToken) { (libreRawGlucoseOOPData, xDripError) in
                    
                    if let libreRawGlucoseOOPData = libreRawGlucoseOOPData as? LibreRawGlucoseOOPData {

                        // if debug level logging enabled, than add full dump of libreRawGlucoseOOPA2Data in the trace (checking here to save some processing time if it's not needed
                        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                            trace("in libreDataProcessor, received libreRawGlucoseOOPData = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .debug, libreRawGlucoseOOPData.description)
                        }
                        
                        // convert libreRawGlucoseOOPData to (libreRawGlucoseData:[LibreRawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
                        let parsedResult = libreRawGlucoseOOPData.glucoseData(timeStampLastBgReading: timeStampLastBgReading)
                        
                        handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    } else {
                       
                        // libreRawGlucoseOOPData is nil, but possibly xDripError is not nil, so need to call handleGlucoseData which will process xDripError
                        handleGlucoseData(result: ([LibreRawGlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    }
                    
                }
                
            }
            
        } else if !webOOPEnabled {
            
            // as webOOPEnabled is not enabled it must be a Libre 1 type of sensor that supports "offline" parsing, ie without need for oop web
            
            // get readings from buffer using local Libre 1 parser
            let parsedLibre1Data = LibreDataParser.parseLibre1DataWithoutCalibration(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading)
            
            // handle the result
            handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
            
        } else {
            
            // it's not a libre 1 and oop web is enabled, so there's nothing we can do
            trace("in libreDataProcessor, can not continue - web oop is enabled, but there's missing info in the request", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
        }

    }

}

fileprivate func getGlucoseRaw(bytes:Data) -> Int {
    return ((256 * (bytes.getByteAt(position: 0) & 0xFF) + (bytes.getByteAt(position: 1) & 0xFF)) & 0x1FFF)
}

fileprivate func trendMeasurements(bytes: Data, mostRecentReadingDate: Date, timeStampLastBgReading: Date, _ offset: Double = 0.0, slope: Double = 0.1, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?) -> [LibreMeasurement] {
    
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
        let measurementDate = mostRecentReadingDate.addingTimeInterval(Double(-60 * blockIndex))
        
        if measurementDate > timeStampLastBgReading {
            let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
            measurements.append(measurement)
        }
        
    }
    return measurements
}

fileprivate func historyMeasurements(bytes: Data, timeStampLastBgReading: Date, _ offset: Double = 0.0, slope: Double = 0.1, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?) -> [LibreMeasurement] {
    //    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
    let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
    //    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
    
    let body   = Array(bytes[bodyRange])
    let nextHistoryBlock = Int(body[3])
    let minutesSinceStart = Int(body[293]) << 8 + Int(body[292])
    let sensorStartTimeInMilliseconds:Double = Date().toMillisecondsAsDouble() - (Double)(minutesSinceStart * 60 * 1000)
    
    var measurements = [LibreMeasurement]()
    
    // History data is stored in body from byte 100 to byte 100+192-1=291 in units of 6 bytes. Index on data such that most recent block is first.
    for blockIndex in 0..<32 {
        
        let timeInMinutes = max(0,(Double)(abs(minutesSinceStart - 3)/15)*15 - (Double)(blockIndex*15))
        
        var index = 100 + (nextHistoryBlock - 1 - blockIndex) * 6 // runs backwards
        if index < 100 {
            index = index + 192 // if end of ring buffer is reached shift to beginning of ring buffer
        }
        
        let range = index..<index+6
        let measurementBytes = Array(body[range])
        
        let measurementDate = Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60)
        
        if measurementDate > timeStampLastBgReading {
            
            let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, minuteCounter: Int(timeInMinutes.rawValue), date: measurementDate, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
            measurements.append(measurement)
            
        } else {
            break
        }
        
    }
    
    return measurements
    
}

/// calls delegate with parameters from result
/// - parameters:
///     - result
///           - glucoseData : array of GlucoseData
///           - sensorTimeInMinutes: int
///           - error: optional xDripError
///           - sensorState: LibreSensorState
///     - cgmTransmitterDelegate: instance  of CGMTransmitterDelegate, which will be called with result and/or error if any
///     - libreSensorSerialNumber, if available
///     - callback which takes a data as parameter, being timeStampLastBgReading, sensorState and error
///
/// if result.errorDescription not nil, then delegate function error will be called
fileprivate func handleGlucoseData(result: (glucoseData:[GlucoseData], sensorTimeInMinutes:Int?, sensorState: LibreSensorState?, xDripError:XdripError?), cgmTransmitterDelegate : CGMTransmitterDelegate?, libreSensorSerialNumber:LibreSensorSerialNumber?, completionHandler:((_ timeStampLastBgReading: Date?, _ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {
    
    // trace the sensor state
    if let sensorState = result.sensorState {
        trace("in handleGlucoseData, sensor state = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, sensorState.description)
    } else {
        trace("in handleGlucoseData, sensor state is unknown", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
    }

    // if result.error not nil, then send it to the delegate and
    if let xDripError =  result.xDripError {
        
        cgmTransmitterDelegate?.errorOccurred(xDripError: xDripError)
        
    }
    
    // if sensor time < 60, return an empty glucose data array
    if let sensorTimeInMinutes = result.sensorTimeInMinutes {

        guard sensorTimeInMinutes >= 60 else {
            
            trace("in handleGlucoseData, sensorTimeInMinutes < 60 minutes, no further processing", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
            var emptyArray = [GlucoseData]()
            
            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorTimeInMinutes: result.sensorTimeInMinutes)
            
            return
            
        }

    }
    
    // call delegate with result
    var result = result
    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: nil, sensorTimeInMinutes: result.sensorTimeInMinutes)
    
    //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
    completionHandler(result.glucoseData.count > 0 ? result.glucoseData[0].timeStamp : nil, result.sensorState, result.xDripError)
    
}

/// to glucose data
/// - Parameter measurements: array of LibreMeasurement
/// - Returns: array of LibreRawGlucoseData
fileprivate func trendToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData] {
    
    var origarr = [LibreRawGlucoseData]()
    for trend in measurements {
        let glucose = LibreRawGlucoseData.init(timeStamp: trend.date, glucoseLevelRaw: trend.temperatureAlgorithmGlucose)
        origarr.append(glucose)
    }
    return origarr
}

fileprivate func historyToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData] {
    
    var origarr = [LibreRawGlucoseData]()
    
    for history in measurements {
        let glucose = LibreRawGlucoseData(timeStamp: history.date, unsmoothedGlucose: history.temperatureAlgorithmGlucose)
        origarr.append(glucose)
    }
    
    return origarr
    
}

/// parses libre 1 block with OOP WEB.
/// - parameters:
///     - libreData: the 344 bytes block from Libre
///     - timeStampLastBgReading: this is of the timestamp of the latest reading we already received during previous session
/// - returns:
///     - array of libreRawGlucoseData, first is the most recent. Only returns recent readings, ie not the ones that are older than timeStampLastBgReading. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReading
///     - sensorState: status of the sensor
///     - sensorTimeInMinutes: age of sensor in minutes
fileprivate func parseLibre1DataWithOOPWebCalibration(libreData: Data, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters, timeStampLastBgReading: Date) -> (libreRawGlucoseData:[LibreRawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?) {

    // initialise returnvalue, array of LibreRawGlucoseData
    var finalResult:[LibreRawGlucoseData] = []
    
    // calculate sensorState
    let sensorState = LibreSensorState(stateByte: libreData[4])
    
    // if sensorState is not .ready, then return empty array
    if sensorState != .ready { return (finalResult, sensorState, nil)  }
    
    let sensorTimeInMinutes:Int = 256 * (Int)(libreData.uint8(position: 317) & 0xFF) + (Int)(libreData.uint8(position: 316) & 0xFF)
    
    // iterates through glucoseData, compares timestamp, if still higher than timeStampLastBgReading (+ 30 seconds) then adds it to finalResult
    let processGlucoseData = { (glucoseData: [LibreRawGlucoseData], timeStampLastAddedGlucoseData: Date) in
        
        var timeStampLastAddedGlucoseDataAsDouble = timeStampLastAddedGlucoseData.toMillisecondsAsDouble()
        
        for glucose in glucoseData {
            
            let timeStampOfNewGlucoseData = glucose.timeStamp
            if timeStampOfNewGlucoseData.toMillisecondsAsDouble() > (timeStampLastBgReading.toMillisecondsAsDouble() + 30000.0) {
                
                // return only readings that are at least 5 minutes away from each other, except the first, same approach as in LibreDataParser.parse
                if timeStampOfNewGlucoseData.toMillisecondsAsDouble() < timeStampLastAddedGlucoseDataAsDouble - (5 * 60 * 1000 - 10000) {
                    timeStampLastAddedGlucoseDataAsDouble = timeStampOfNewGlucoseData.toMillisecondsAsDouble()
                    finalResult.append(glucose)
                }
                
            } else {
                break
            }
        }
        
    }
    
    // get last16 from trend data
    // latest reading will get date of now
    let last16 = trendMeasurements(bytes: libreData, mostRecentReadingDate: Date(), timeStampLastBgReading: timeStampLastBgReading, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
    
    // process last16, new readings should be smaller than now + 5 minutes
    processGlucoseData(trendToLibreGlucose(last16), Date(timeIntervalSinceNow: 5 * 60))
    
    // get last32 from history data
    let last32 = historyMeasurements(bytes: libreData, timeStampLastBgReading: timeStampLastBgReading, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
    
    // process last 32 with date earlier than the earliest in last16
    var timeStampLastAddedGlucoseData = Date()
    if last16.count > 0, let last = last16.last {
        timeStampLastAddedGlucoseData = last.date
    }
    
    processGlucoseData(historyToLibreGlucose(last32), timeStampLastAddedGlucoseData)
    
    return (finalResult, sensorState, sensorTimeInMinutes)
    
}

