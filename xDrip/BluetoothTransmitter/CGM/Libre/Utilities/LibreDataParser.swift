import Foundation
import os

/// for trace
fileprivate let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreDataParser)

class LibreDataParser {
    
    // MARK: - private properties
    
    /// - per minute readings (trend) will be stored each time, as received rom Libre (meaning not smoothed)
    /// - goal is to reuse them in next reading session, for the smoothing of new values
    private var previousRawValues = UserDefaults.standard.previousRawLibreValues {
        didSet {
            UserDefaults.standard.previousRawLibreValues = previousRawValues
        }
    }
    
    /// for appending of previously stored values, how many values should match ?
    private let amountOfValuesToCompare = 4
    
    // MARK: - public functions
    
    /// parses libre1 block, with or without oop web, if libre1DerivedAlgorithmParameters is nil, then oop web is not used
    /// - parameters:
    ///     - libreData: the 344 bytes block from Libre
    /// - returns:
    ///     - array of GlucoseData, first is the most recent.
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes
    ///     - libre1DerivedAlgorithmParameters : if nil then oop web is not used
    ///     - testTimeStamp : if set, then the most recent reading will get this timestamp
    ///     - libreSensorType. if nil means not known.  For transmitters that don't know the sensorType, this will not work
    private func parseLibre1Data(libreData: Data, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?, testTimeStamp: Date?, libreSensorType: LibreSensorType?) -> (glucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int) {
        
        let ourTime = testTimeStamp == nil ? Date() : testTimeStamp!
        let indexTrend:Int = libreData.getByteAt(position: (libreSensorType == .libreProH ? 76:26)) & 0xFF
        let indexHistory:Int = (libreSensorType == .libreProH ? 29 :libreData.getByteAt(position: 27) & 0xFF) //If Tomato firmware is modified, we will 168 byte history ..presently this to be ignored..
        let sensorTimeInMinutes:Int = (libreSensorType == .libreProH ? 256 * (libreData.getByteAt(position: 75) & 0xFF) + (libreData.getByteAt(position: 74) & 0xFF) : 256 * (libreData.getByteAt(position: 317) & 0xFF) + (libreData.getByteAt(position: 316) & 0xFF))
        let sensorStartTimeInMilliseconds:Double = ourTime.toMillisecondsAsDouble() - (Double)(sensorTimeInMinutes * 60 * 1000)
        var returnValue:Array<GlucoseData> = []
        let sensorState = LibreSensorState(stateByte: libreData[4])
        
        // rangeProcessor will be used for processing trend or history range, and return trend or history as array of GlucoseData
        let rangeProcessor = { (maxIndex: Int, indexTrendOrHistory: Int, timeInSecondsCalculator: (Int) -> Double, firstByteToAppend: Int ) -> [GlucoseData] in
            
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
                
                // only add if readingTimeStamp smaller (ie reading is older) than the readingTimestamp of the last already known reading. This needs to be done because history measurements start with a timestamp somewhere in the middle of the trend measurements
                if let last = returnValue.last {
                    
                    if !(readingTimeStamp < last.timeStamp) {
                        
                        // skip the reading
                        continue
                        
                    }
                    
                }
                
                // do we calibrate with the oop web derived slope and intercep t?
                if let libre1DerivedAlgorithmParameters = libre1DerivedAlgorithmParameters {
                    
                    result.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: LibreMeasurement(bytes: byte, slope: 0.1, offset: 0.0, date: readingTimeStamp, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters).temperatureAlgorithmGlucose))
                    
                } else {
                    
                    // no calibration to do
                    let glucoseLevelRaw = Double(((256 * (byte.getByteAt(position: 1) & 0xFF) + (byte.getByteAt(position: 0) & 0xFF)) & 0x1FFF))
                    
                    if (glucoseLevelRaw > 0) {
                        
                        result.append(GlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: glucoseLevelRaw * ConstantsBloodGlucose.libreMultiplier ))
                    
                    }
                    
                }
                
            }
            
            return result
            
        }
        
        // now use rangeProcessor to get trend measurements as array of GlucoseData
        var trend  = rangeProcessor(16, indexTrend, { index in
            return (max(0, (Double)(sensorTimeInMinutes - index))) * 60.0
        }, (libreSensorType == .libreProH ? 80:28))
        
        // add previously stored values if there are any
        trend = extendWithPreviousRawValues(trend: trend)
        
        // check if the trend and the previous raw values have at least 5 equal values, if so this is an expired sensor that keeps sending the same values, in that case no further processing
        if trend.hasEqualValues(howManyToCheck: 5, otherArray: previousRawValues) {
            
            trace("in libreDataProcessor, did detect flat values, returning empty GlucoseData array", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
            return ([GlucoseData](), sensorState, sensorTimeInMinutes)
        }
        
        // now, if previousRawValues was not an empty list, trend is a longer list of values because it's been extended with a subrange of previousRawvalues
        // we re-assign previousRawValues to the current list in trend, for next usage
        // but we restricted it to maximum x most recent values, it makes no sense to store more
        previousRawValues = Array(trend.map({$0.glucoseLevelRaw})[0..<(min(trend.count, ConstantsLibreSmoothing.amountOfPreviousReadingsToStore))])
        
        // smooth, if required
        if UserDefaults.standard.smoothLibreValues {
            
            // apply Libre smoothing
            LibreSmoothing.smooth(trend: &trend, repeatPerMinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.libreSmoothingRepeatPerMinuteSmoothing, filterWidthPerMinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPerMinuteValues, filterWidthPer5MinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPer5MinuteValues, repeatPer5MinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.repeatPer5MinuteSmoothing)
            
        }
        
        // if trend count would be 0 here then no reason to continue, should normally not be the case
        guard trend.count > 0 else {
            return ([GlucoseData](), sensorState, sensorTimeInMinutes)
        }
        
        // assign returnValue to trend, returnValue is used in rangeProcessor, which is still called to process the history values - just to get the timestamp of the first reading in trend
        returnValue = trend
        
        // timeInSecondsOfMostRecentHistoryValue is needed in timeInSecondsCalculator to get the trend
        let timeInSecondsOfMostRecentHistoryValue = (dateOfMostRecentHistoryValue(sensorTimeInMinutes: sensorTimeInMinutes, nextHistoryBlock: indexHistory, date: ourTime).toMillisecondsAsDouble() - sensorStartTimeInMilliseconds) / 1000

        // now use rangeProcessor to get history measurements as array of GlucoseData
        var history = rangeProcessor((libreSensorType == .libreProH ? 28:32), indexHistory, { index in
            return (max(0, timeInSecondsOfMostRecentHistoryValue - 900.0 * (Double)(index)))
        }, (libreSensorType == .libreProH ? 170:124))
        
        // smooth history one time, if required
        if UserDefaults.standard.smoothLibreValues {
            
            // add the oldest trend value to the history, this will make the smoothing of the history values more correct
            // otherwise we apply linear regression to the first element(s) in the history, which will give a less accurate result
            // trend.last is the oldest measurement more recent than the most recent element in history, so we insert it at index 0
            // and only if (trend.last timestamp + 10 minutes) > history.first timestamp
            var trendAdded = false
            if let firstHistory = history.first, let lastTrend = trend.last, lastTrend.timeStamp.timeIntervalSince(firstHistory.timeStamp) > 10.0 * 60.0  {
                
                history.insert(GlucoseData(timeStamp: lastTrend.timeStamp, glucoseLevelRaw: lastTrend.glucoseLevelRaw), at: 0)
                
                // need to remove it after applying the smoothing
                trendAdded = true

            }
            
            // smooth
            LibreSmoothing.smooth(history: &history, filterWidthPer5MinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.libreSmoothingFilterWidthPer15MinutesValues)
            
            // now remove the trend measurement that was inserted
            if trendAdded {
                history.remove(at: 0)
            }
            
        }
        
        // add history to returnvalue
        returnValue = returnValue + history
        
        return (returnValue, sensorState, sensorTimeInMinutes)
        
    }
    
    /// - Process Libre block for all types of Libre sensors, and for both with and without web oop (without only for Libre 1). It checks if webOOP is enabled, if yes tries to use the webOOP, response is processed and delegate is called. If webOOP not enabled, and if Libre1, then local processing is done, in that case glucose values are not calibrated
    /// - if an error occurred, then this function will call cgmTransmitterDelegate.errorOccurred
    /// - parameters:
    ///     - libreSensorSerialNumber : if nil, then webOOP will not be used and local parsing will be done, but only for Libre 1
    ///     - patchInfo : will be used by server to out the glucose data, corresponds to type of sensor. Nil if not known which is used for Bubble or MM older firmware versions 
    ///     - libreData : the 344 bytes from Libre sensor
    ///     - webOOPEnabled : is webOOP enabled or not, if not enabled, local parsing is used. This can only be the case for Libre1
    ///     - cgmTransmitterDelegate : the cgmTransmitterDelegate, will be used to send the resultin glucose data and sensorTime (function cgmTransmitterInfoReceived)
    ///     - testTimeStamp : if set, then the most recent reading will get this timestamp
    ///     - dataIsDecryptedToLibre1Format : example if transmitter is Libre 2, data is already decrypted to Libre 1 format
    ///     - completionHandler : called with sensorState and xDripError
    public func libreDataProcessor(libreSensorSerialNumber: String?, patchInfo: String?, webOOPEnabled: Bool, libreData: Data, cgmTransmitterDelegate : CGMTransmitterDelegate?, dataIsDecryptedToLibre1Format: Bool, testTimeStamp: Date?, completionHandler:@escaping ((_ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {

        // get libreSensorType, if this fails then it must be an unknown Libre sensor type in which case we don't proceed
        guard let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) else {
            
            // unwrap patchInfo, although it can't be nil here because LibreSensorType.type would have returned .libre1 otherwise
            if let patchInfo = patchInfo {
                
                trace("in libreDataProcessor, failed to create libreSensorType, patchInfo = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, patchInfo)
                
            }
         
            return
            
        }
        
        trace("in libreDataProcessor, sensortype = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, libreSensorType.description)
        
        // let's see if we must use webOOP (if webOOPEnabled is true) and if so if we have all required info (libreSensorSerialNumber)
        if let libreSensorSerialNumber = libreSensorSerialNumber, webOOPEnabled {
            
            // if data is already decrypted then process the data as if it were a libre1 sensor type
            if dataIsDecryptedToLibre1Format {
                
                libre1DataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, libreSensorType: libreSensorType, libreData: libreData, cgmTransmitterDelegate: cgmTransmitterDelegate, testTimeStamp: testTimeStamp, completionHandler: completionHandler)
                
                return
                
            }
            
            switch libreSensorType {
                
            case .libre1A2, .libre1, .libreProH:// these types are all Libre 1
                
                libre1DataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, libreSensorType: libreSensorType, libreData: libreData, cgmTransmitterDelegate: cgmTransmitterDelegate, testTimeStamp: testTimeStamp, completionHandler: completionHandler)
                
            case .libreUS, .libreUSE6:// not sure if this works for libreUS
                
                // libreUS isn't working yet, create an error and send to delegate
                cgmTransmitterDelegate?.errorOccurred(xDripError: LibreOOPWebError.libreUSNotSupported)
                
                // should never come here ?
                trace("in libreDataProcessor, is libreUS but data is not decrypted - no further processing", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
                
            case .libre2, .libre2C5, .libre2C6, .libre27F:
                
                // should never come here ?
                trace("in libreDataProcessor, is libre2 but data is not decrypted - no further processing", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
                
            }
            
        } else if (!webOOPEnabled || dataIsDecryptedToLibre1Format) {
            
            // as webOOPEnabled is not enabled it must be a Libre 1 type of sensor that supports "offline" parsing, ie without need for oop web
            // or it's a libre 2 sensor but the data is decrypted
            
            // get readings from buffer using local Libre 1 parser
            let parsedLibre1Data = parseLibre1Data(libreData: libreData, libre1DerivedAlgorithmParameters: nil, testTimeStamp: testTimeStamp, libreSensorType: libreSensorType)
            
            // handle the result
            handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, completionHandler: completionHandler)
            
        } else {
            
            // it's not a libre 1 and oop web is enabled, so there's nothing we can do
            trace("in libreDataProcessor, can not continue - web oop is enabled, but there's missing info in the request", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
            
        }

    }
    
    // MARK: - private functions
    
    /// processes libre data that is in Libre 1 format, this includes decrypted Libre 2 - this is with oop web
    /// - parameters:
    ///     - libreData : either Libre 1 data or decrypted Libre 2 data
    ///     - testTimeStamp : if set, then the most recent reading will get this timestamp
    private func libre1DataProcessor(libreSensorSerialNumber: String, libreSensorType: LibreSensorType, libreData: Data, cgmTransmitterDelegate: CGMTransmitterDelegate?, testTimeStamp: Date?, completionHandler:@escaping ((_ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {
        
        // if libre1DerivedAlgorithmParameters not nil, but not matching serial number, then assign to nil
        if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber != libreSensorSerialNumber {
            
            UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
            
        }
        
        // if libre1DerivedAlgorithmParameters == nil, then calculate them
        if UserDefaults.standard.libre1DerivedAlgorithmParameters == nil {
            
            UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: libreData, serialNumber: libreSensorSerialNumber, libreSensorType: libreSensorType)
            
        }
        
        // unwrap libre1DerivedAlgorithmParameters, should be non nil because they've just been calculated
        guard let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters else {return}
        
        
        trace("in libreDataProcessor, found libre1DerivedAlgorithmParameters in UserDefaults", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
        
        // if debug level logging enabled, than add full dump of libre1DerivedAlgorithmParameters in the trace (checking here to save some processing time if it's not needed
        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
            trace("in libreDataProcessor, libre1DerivedAlgorithmParameters = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .debug, libre1DerivedAlgorithmParameters.description)
        }
        
        let parsedLibre1Data = parseLibre1Data(libreData: libreData, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters, testTimeStamp: testTimeStamp, libreSensorType: libreSensorType)
        
        // handle the result
        handleGlucoseData(result: (parsedLibre1Data.glucoseData, parsedLibre1Data.sensorTimeInMinutes, parsedLibre1Data.sensorState, nil), cgmTransmitterDelegate: cgmTransmitterDelegate, completionHandler: completionHandler)
        
        return

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
    ///
    /// if result.errorDescription not nil, then delegate function error will be called
    private func handleGlucoseData(result: (glucoseData:[GlucoseData], sensorTimeInMinutes:Int?, sensorState: LibreSensorState?, xDripError:XdripError?), cgmTransmitterDelegate : CGMTransmitterDelegate?, completionHandler:((_ sensorState: LibreSensorState?, _ xDripError: XdripError?) -> ())) {
        
        // trace the sensor state
        if let sensorState = result.sensorState {
            trace("in handleGlucoseData, sensor state = %{public}@", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info, sensorState.description)
            
            if sensorState != .ready && sensorState != .expired {
                
                trace("    not processing data as sensor does not have the state ready or expired", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
                
                // initialize xDripError, to be used in calls to cgmTransmitterDelegate.errorOccurred and completionHandler
                let xDripError = LibreError.sensorNotReady
                
                // call cgmTransmitterDelegate (this is actually the RootViewController passed in via the BluetoothTransmitter
                cgmTransmitterDelegate?.errorOccurred(xDripError: xDripError)
                
                // call completionHandler, to inform caller about sensorState and xDripError
                completionHandler(sensorState, xDripError)
                
                return
                
            }
            
        } else {
            trace("in handleGlucoseData, sensor state is unknown", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
        }
        
        // if result.error not nil, then send it to the delegate and
        if let xDripError =  result.xDripError {
            
            cgmTransmitterDelegate?.errorOccurred(xDripError: xDripError)
            
        }

        // variable to  be used in last call to cgmTransmitterDelegate
        var sensorTimeInResult: TimeInterval?

        // if sensor time < 60, return an empty glucose data array
        // should probably not happen because we only get here if status = .ready or .expired ?
        if let sensorTimeInMinutes = result.sensorTimeInMinutes {
            
            // assign sensorTimeInResult, will be used later
            sensorTimeInResult = TimeInterval(minutes: Double(sensorTimeInMinutes))
            
            guard sensorTimeInMinutes >= 60 else {
                
                trace("in handleGlucoseData, sensorTimeInMinutes < 60 minutes, no further processing", log: log, category: ConstantsLog.categoryLibreDataParser, type: .info)
                
                var emptyArray = [GlucoseData]()
                
                cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorAge: TimeInterval(minutes: Double(sensorTimeInMinutes)))
                
                // call completion handler to make sure the sensor state is handled, set state to .starting, because result.sensorState has value .ready here which is not correct
                completionHandler(.starting, result.xDripError)
                
                return
                
            }
            
        }
        
        var result = result

        // call delegate with result
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: nil, sensorAge: sensorTimeInResult)
        
        completionHandler(result.sensorState, result.xDripError)
        
    }


    /// Get date of most recent history value. (source dabear)
    /// History values are updated every 15 minutes. Their corresponding time from start of the sensor in minutes is 15, 30, 45, 60, ..., but the value is delivered three minutes later, i.e. at the minutes 18, 33, 48, 63, ... and so on. So for instance if the current time in minutes (since start of sensor) is 67, the most recent value is 7 minutes old. This can be calculated from the minutes since start. Unfortunately sometimes the history index is incremented earlier than the minutes counter and they are not in sync. This has to be corrected.
    ///
    /// - Returns: the date of the most recent history value and the corresponding minute counter
    private func dateOfMostRecentHistoryValue(sensorTimeInMinutes: Int, nextHistoryBlock: Int, date: Date) -> Date {
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
    
    private func recursive(indexInPreviousRawValues: Int, indexInTrend: Int, trendValues: inout [GlucoseData]) -> Bool {
        
        if previousRawValues[indexInPreviousRawValues] == trendValues[indexInTrend].glucoseLevelRaw {
            
            if indexInPreviousRawValues < amountOfValuesToCompare - 1 {
                
                return recursive(indexInPreviousRawValues: indexInPreviousRawValues + 1, indexInTrend: indexInTrend + 1, trendValues: &trendValues)
                
            } else {
                
                return true
                
            }
            
        } else {
            
            return false
            
        }
        
    }

    /// - uses previously stored values and tries to append trend with previous values, based on mathing values (appending meaning, as it's sorted by first the youngest
    /// - we need to find at least 4 matching values (just in case user has perfectly steady values for more than 3 minutes which will probably never happen), but this means maximum gap that we can close is 11 minutes, which is enough
    private func extendWithPreviousRawValues(trend: [GlucoseData]) -> [GlucoseData] {
        
        // previousRawValues length must be at least 16 and trend length must equal to 16 values, should always be the case, just to avoid crashes
        guard previousRawValues.count >= 16 && trend.count == 16 else {return trend}
        
        // create a new array with new GlucoseData instances
        var newTrend = trend.map({GlucoseData(timeStamp: $0.timeStamp, glucoseLevelRaw: $0.glucoseLevelRaw)})
        
        // for each value in trend, we will try to find a series of 4 (defined by amountOfValuesToCompare) matching values in previousRawValues
        // if found then we add the last values of previousRawValues, until we have a new consecutive array of values in newTrend
        for (match, _) in trend.enumerated() {
            
            if recursive(indexInPreviousRawValues: 0, indexInTrend: match, trendValues: &newTrend) {

                // now match indexes the first matching index
                
                // we'll need the timestamp of the current last element
                var lastTimeStamp = trend.last!.timeStamp
                
                // the first element from previousRawValue to append is at index size of trend - index
                // ad we go up to size of previousRawValues - 1 (stride is exclusive the last value)
                for i in stride(from: (16 - match), to: previousRawValues.count, by: 1) {

                    // next element will have a timestamp being previous timestamp - 1 minute
                    lastTimeStamp = lastTimeStamp.addingTimeInterval(-60.0)
                    
                    newTrend.append(GlucoseData(timeStamp: lastTimeStamp, glucoseLevelRaw: previousRawValues[i]))
                   
                }
                
                // found a matching range, now further processing needed
                break
                
            } else {
                
                // didn't find a match
                // if we already reached 16 minutes amount of values to compare then stop
                if match == 16 - amountOfValuesToCompare {
                    
                    break
                    
                }
                
            }
            
        }
        
        return newTrend
        
    }
    
}



