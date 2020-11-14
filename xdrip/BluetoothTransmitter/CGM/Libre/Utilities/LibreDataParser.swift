import Foundation
import os

/// for trace
fileprivate let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreDataParser)

class LibreDataParser {
    
    // MARK: - public functions
    
    /// parses libre1 block, with or without oop web, if libre1DerivedAlgorithmParameters is nil, then oop web is not used
    /// - parameters:
    ///     - libreData: the 344 bytes block from Libre
    ///     - timeStampLastBgReading: this is of the timestamp of the latest reading we already received during previous session
    /// - returns:
    ///     - array of GlucoseData, first is the most recent. Only returns recent readings, ie not the ones that are older than timeStampLastBgReading. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReading
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes
    ///     - libre1DerivedAlgorithmParameters : if nil then oop web is not used
    public static func parseLibre1Data(libreData: Data, timeStampLastBgReading:Date, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?) -> (glucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int) {
        
        let ourTime:Date = Date()
        let indexTrend:Int = libreData.getByteAt(position: 26) & 0xFF
        let indexHistory:Int = libreData.getByteAt(position: 27) & 0xFF
        let sensorTimeInMinutes:Int = 256 * (libreData.getByteAt(position: 317) & 0xFF) + (libreData.getByteAt(position: 316) & 0xFF)
        let sensorStartTimeInMilliseconds:Double = ourTime.toMillisecondsAsDouble() - (Double)(sensorTimeInMinutes * 60 * 1000)
        var returnValue:Array<GlucoseData> = []
        let sensorState = LibreSensorState(stateByte: libreData[4])
        
        var valuesBeforeSmoothing = [GlucoseData]()
        
        // closure will be used for processing trend and history
        let rangeProcessor = { (maxIndex: Int, indexTrendOrHistory: Int, timeInSecondsCalculator: (Int) -> Double, firstByteToAppend: Int ) in
            
            var result = [GlucoseData]()
            
            for index in 0..<maxIndex {
                var i = indexTrendOrHistory - index - 1
                if i < 0 {i += maxIndex}
                let timeInSeconds = timeInSecondsCalculator(index)
                
                var byte = Data()
                byte.append(libreData[(i * 6 + firstByteToAppend)])
                byte.append(libreData[(i * 6 + firstByteToAppend + 1)])
                byte.append(libreData[(i * 6 + firstByteToAppend + 2)])
                byte.append(libreData[(i * 6 + firstByteToAppend + 3)])
                byte.append(libreData[(i * 6 + firstByteToAppend + 4)])
                byte.append(libreData[(i * 6 + firstByteToAppend + 5)])
                
                let readingTimeStamp = Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInSeconds)
                
                // only add if readingTimeStamp smaller (ie older) than the readingTimestamp of the last already known reading. This is because history measurements start with a timestamp somewhere in the middle of the trend measurements
                if let last = returnValue.last {
                    
                    if !(readingTimeStamp < last.timeStamp) {
                        
                        // skip the reading
                        continue
                        
                    }
                    
                }
                
                if let libre1DerivedAlgorithmParameters = libre1DerivedAlgorithmParameters {
                    
                    result.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: LibreMeasurement(bytes: byte, slope: 0.1, offset: 0.0, date: readingTimeStamp, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters).temperatureAlgorithmGlucose))
                    
                    valuesBeforeSmoothing.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: LibreMeasurement(bytes: byte, slope: 0.1, offset: 0.0, date: readingTimeStamp, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters).temperatureAlgorithmGlucose))
                    
                } else {
                    
                    let glucoseLevelRaw = Double(((256 * (byte.getByteAt(position: 1) & 0xFF) + (byte.getByteAt(position: 2) & 0xFF)) & 0x1FFF))
                    
                    if (glucoseLevelRaw > 0) {
                        result.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: glucoseLevelRaw * ConstantsBloodGlucose.libreMultiplier))
                        valuesBeforeSmoothing.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: glucoseLevelRaw * ConstantsBloodGlucose.libreMultiplier))
                    }
                    
                }
                
            }
            
            // smooth if required
            if UserDefaults.standard.smoothLibreValues {
                
                result.smoothSavitzkyGolayQuaDratic(withFilterWidth: ConstantsSmoothing.libreSmoothingFilterWidth)
                result.smoothSavitzkyGolayQuaDratic(withFilterWidth: ConstantsSmoothing.libreSmoothingFilterWidth)
                
            }
            
            returnValue = returnValue + result
            
        }
        
        // process trend
        rangeProcessor(16, indexTrend, { index in
            return (max(0, (Double)(sensorTimeInMinutes - index))) * 60.0
        }, 28)

        // needed in timeInSecondsCalculator for history processing
        let date = dateOfMostRecentHistoryValue(sensorTimeInMinutes: sensorTimeInMinutes, nextHistoryBlock: indexHistory, date: ourTime)
        let timeInSecondsOfMostRecentHistoryValue = (date.toMillisecondsAsDouble() - sensorStartTimeInMilliseconds) / 1000

        // process history
        //date.addingTimeInterval(Double(-900 * blockIndex)
        rangeProcessor(32, indexHistory, { index in
            return (max(0, timeInSecondsOfMostRecentHistoryValue - 900.0 * (Double)(index)))
        }, 124)
    
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
    ///     - dataIsDecryptedToLibre1Format : example if transmitter is Libre 2, data is already decrypted to Libre 1 format
    public static func libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber?, patchInfo: String?, webOOPEnabled: Bool, oopWebSite: String?, oopWebToken: String?, libreData: Data, cgmTransmitterDelegate : CGMTransmitterDelegate?, timeStampLastBgReading: Date, dataIsDecryptedToLibre1Format: Bool, completionHandler:@escaping ((_ timeStampLastBgReading: Date?, _ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {

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
            
            // if data is already decrypted then process the data as if it were a libre1 sensor type
            if dataIsDecryptedToLibre1Format {
                
                libre1DataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, libreSensorType: libreSensorType, libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, cgmTransmitterDelegate: cgmTransmitterDelegate, oopWebSite: oopWebSite, oopWebToken: oopWebToken, completionHandler: completionHandler)
                
                return
                
            }
            
            switch libreSensorType {
                
            case .libre1A2, .libre1, .libreProH:// these types are all Libre 1
                
                libre1DataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, libreSensorType: libreSensorType, libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, cgmTransmitterDelegate: cgmTransmitterDelegate, oopWebSite: oopWebSite, oopWebToken: oopWebToken, completionHandler: completionHandler)
                
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
                        
                        // convert libreRawGlucoseOOPA2Data to (libreRawGlucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
                        let parsedResult = libreRawGlucoseOOPA2Data.glucoseData(timeStampLastBgReading: timeStampLastBgReading)
                        
                        handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    } else {
                        
                        // libreRawGlucoseOOPA2Data is nil, but possibly xDripError is not nil, so need to call handleGlucoseData which will process xDripError
                        handleGlucoseData(result: ([GlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

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
                        
                        // convert libreRawGlucoseOOPData to (libreRawGlucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
                        let parsedResult = libreRawGlucoseOOPData.glucoseData(timeStampLastBgReading: timeStampLastBgReading)
                        
                        handleGlucoseData(result: (parsedResult.libreRawGlucoseData.map { $0 as GlucoseData }, parsedResult.sensorTimeInMinutes, parsedResult.sensorState, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    } else {
                       
                        // libreRawGlucoseOOPData is nil, but possibly xDripError is not nil, so need to call handleGlucoseData which will process xDripError
                        handleGlucoseData(result: ([GlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

                    }
                    
                }
                
            }
            
        } else if (!webOOPEnabled || dataIsDecryptedToLibre1Format) {
            
            // as webOOPEnabled is not enabled it must be a Libre 1 type of sensor that supports "offline" parsing, ie without need for oop web
            // or it's a libre 2 sensor but the data is decrypted
            
            // get readings from buffer using local Libre 1 parser
            let parsedLibre1Data = LibreDataParser.parseLibre1Data(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, libre1DerivedAlgorithmParameters: nil)
            
            // handle the result
            handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
            
        } else {
            
            // it's not a libre 1 and oop web is enabled, so there's nothing we can do
            trace("in libreDataProcessor, can not continue - web oop is enabled, but there's missing info in the request", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
        }

    }

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
        
        if sensorState != .ready && sensorState != .expired {
            
            trace("    not processing data as sensor does not have the state ready or expired", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
            cgmTransmitterDelegate?.errorOccurred(xDripError: LibreError.sensorNotReady)
            
            return
            
        }
        
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

/// processes libre data that is in Libre 1 format, this includes decrypted Libre 2 - this is with oop web
/// - parameters:
///     - libreData : either Libre 1 data or decrypted Libre 2 data
fileprivate func libre1DataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber, libreSensorType: LibreSensorType, libreData: Data, timeStampLastBgReading: Date, cgmTransmitterDelegate: CGMTransmitterDelegate?, oopWebSite: String, oopWebToken: String, completionHandler:@escaping ((_ timeStampLastBgReading: Date?, _ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {
    
    // if libre1DerivedAlgorithmParameters not nil, but not matching serial number, then assign to nil
    if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber != libreSensorSerialNumber.serialNumber {
        
        UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
        
    }
    
    // if libre1DerivedAlgorithmParameters == nil, then calculate them
    if UserDefaults.standard.libre1DerivedAlgorithmParameters == nil {
        
        UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: libreData, serialNumber: libreSensorSerialNumber.serialNumber)
        
    }
    
    // If the values are already available in userdefaults , then use those values
    if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber == libreSensorSerialNumber.serialNumber {
        
        // only for libre1 en libre1A2 : in some cases libre1DerivedAlgorithmParameters is stored wiht slope_slope = 0, this doesn't work, reset the userdefaults to nil. The parameters will be fetched again from OOP Web
        // for libre1A2 : this check on slope_slope = 0 has been removed some time ago, with commit b8d5b0dea77b098a1c9d88e410f485b7b17b8fd7, so solve issues with libre1A2, so it looks as if b8d5b0dea77b098a1c9d88e410f485b7b17b8fd7 should be undone
        // checking on slope_slope should have the same result, ie it's an invalid libre1DerivedAlgorithmParameters
        if (libreSensorType == .libre1 || libreSensorType == .libre1A2) && libre1DerivedAlgorithmParameters.slope_slope == 0 {
            
            UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
            
        } else {
            
            trace("in libreDataProcessor, found libre1DerivedAlgorithmParameters in UserDefaults", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
            // if debug level logging enabled, than add full dump of libre1DerivedAlgorithmParameters in the trace (checking here to save some processing time if it's not needed
            if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
                trace("in libreDataProcessor, libre1DerivedAlgorithmParameters = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .debug, libre1DerivedAlgorithmParameters.description)
            }
            
            let parsedLibre1Data = LibreDataParser.parseLibre1Data(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
            
            // handle the result
            handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
            
            return
            
        }
        
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
            
            let parsedLibre1Data = LibreDataParser.parseLibre1Data(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, libre1DerivedAlgorithmParameters: UserDefaults.standard.libre1DerivedAlgorithmParameters)
            
            // handle the result
            handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)

        } else {
            
            // libre1DerivedAlgorithmParameters not created, but possibly xDripError is not nil, so we need to call handleGlucoseData which will process xDripError
            handleGlucoseData(result: ([GlucoseData](), nil, nil, xDripError), cgmTransmitterDelegate: cgmTransmitterDelegate, libreSensorSerialNumber: libreSensorSerialNumber, completionHandler: completionHandler)
            
        }
        
    }

}


/// Get date of most recent history value. (source dabear)
/// History values are updated every 15 minutes. Their corresponding time from start of the sensor in minutes is 15, 30, 45, 60, ..., but the value is delivered three minutes later, i.e. at the minutes 18, 33, 48, 63, ... and so on. So for instance if the current time in minutes (since start of sensor) is 67, the most recent value is 7 minutes old. This can be calculated from the minutes since start. Unfortunately sometimes the history index is incremented earlier than the minutes counter and they are not in sync. This has to be corrected.
///
/// - Returns: the date of the most recent history value and the corresponding minute counter
fileprivate func dateOfMostRecentHistoryValue(sensorTimeInMinutes: Int, nextHistoryBlock: Int, date: Date) -> Date {
    // Calculate correct date for the most recent history value.
    //        date.addingTimeInterval( 60.0 * -Double( (sensorTimeInMinutes - 3) % 15 + 3 ) )
    let nextHistoryIndexCalculatedFromMinutesCounter = ( (sensorTimeInMinutes - 3) / 15 ) % 32
    let delay = (sensorTimeInMinutes - 3) % 15 + 3 // in minutes
    if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
        // Case when history index is incremented togehter with sensorTimeInMinutes (in sync)
        //            print("delay: \(delay), sensorTimeInMinutes: \(sensorTimeInMinutes), result: \(sensorTimeInMinutes-delay)")
        return date.addingTimeInterval( 60.0 * -Double(delay))
    } else {
        // Case when history index is incremented before sensorTimeInMinutes (and they are async)
        //            print("delay: \(delay), sensorTimeInMinutes: \(sensorTimeInMinutes), result: \(sensorTimeInMinutes-delay-15)")
        return date.addingTimeInterval( 60.0 * -Double(delay - 15))
    }
}
