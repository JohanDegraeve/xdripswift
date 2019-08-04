import Foundation

/// parses libre block
/// - parameters:
///     - data: the block, inout but not changes, to save copying time
///     - timeStampLastBgReadingStoredInDatabase: this is of the timestamp of the latest reading we already received during previous session
///     - headerOffset: location of Libre block in the data because MiaoMiao (or other) header is not stripped off
/// - returns:
///     - array of GlucoseData, first is the most recent, LibreSensorState. Only returns recent readings, ie not the ones that are older than timeStampLastBgReadingStoredInDatabase. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReadingStoredInDatabase
///     - sensorState: status of the sensor
///     - sensorTimeInMinutes: age of sensor in minutes
func parseLibreData(data:inout Data, timeStampLastBgReadingStoredInDatabase:Date, headerOffset:Int) -> (glucoseData:[RawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int) {
    var i:Int
    var glucoseData:RawGlucoseData
    var byte:Data
    var timeInMinutes:Double
    let ourTime:Date = Date()
    let indexTrend:Int = getByteAt(buffer: data, position: headerOffset + 26) & 0xFF
    let indexHistory:Int = getByteAt(buffer: data, position: headerOffset + 27) & 0xFF
    let sensorTimeInMinutes:Int = 256 * (getByteAt(buffer:data, position: headerOffset + 317) & 0xFF) + (getByteAt(buffer:data, position: headerOffset + 316) & 0xFF)
    let sensorStartTimeInMilliseconds:Double = ourTime.toMillisecondsAsDouble() - (Double)(sensorTimeInMinutes * 60 * 1000)
    var returnValue:Array<RawGlucoseData> = []
    let sensorState = LibreSensorState(stateByte: data[headerOffset + 4])
    
    /////// loads trend values

    // we will add the most recent readings, but then we'll only add the readings that are at least 5 minutes apart (giving 10 seconds spare)
    // for that variable timeStampLastAddedGlucoseData is used. It's initially set to now + 5 minutes
    var timeStampLastAddedGlucoseData = Date().toMillisecondsAsDouble() + 5 * 60 * 1000
    
    trendloop: for index in 0..<16 {
        i = indexTrend - index - 1
        if i < 0 {i += 16}
        timeInMinutes = max(0, (Double)(sensorTimeInMinutes - index))
        let timeStampOfNewGlucoseData = sensorStartTimeInMilliseconds + timeInMinutes * 60 * 1000
        //new reading should be at least 30 seconds younger than timeStampLastBgReadingStoredInDatabase
        if timeStampOfNewGlucoseData > (timeStampLastBgReadingStoredInDatabase.toMillisecondsAsDouble() + 30000.0)
        {
            if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                byte = Data()
                byte.append(data[headerOffset + (i * 6 + 29)])
                byte.append(data[headerOffset + (i * 6 + 28)])
                let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                if (glucoseLevelRaw > 0) {
                    glucoseData = RawGlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * ConstantsBloodGlucose.libreMultiplier)
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
        //new reading should be at least 30 seconds younger than timeStampLastBgReadingStoredInDatabase
        if timeStampOfNewGlucoseData > (timeStampLastBgReadingStoredInDatabase.toMillisecondsAsDouble() + 30000.0)
        {
            if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                byte = Data()
                byte.append(data[headerOffset + (i * 6 + 125)])
                byte.append(data[headerOffset + (i * 6 + 124)])
                let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                if (glucoseLevelRaw > 0) {
                    glucoseData = RawGlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * ConstantsBloodGlucose.libreMultiplier)
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

fileprivate func getByteAt(buffer:Data, position:Int) -> Int {
    return Int(buffer[position])
}

fileprivate func getGlucoseRaw(bytes:Data) -> Int {
    return ((256 * (getByteAt(buffer: bytes, position: 0) & 0xFF) + (getByteAt(buffer: bytes, position: 1) & 0xFF)) & 0x1FFF)
}

func handleGoodReading(bytes: [UInt8], serialNumber: String, _ callback: @escaping ((glucoseData: [RawGlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes: Int)?) -> Void) {
    //only care about the once per minute readings here, historical data will not be considered
    let sensorState = LibreSensorState(stateByte: bytes[4])
    calibrateSensor(bytes: bytes, serialNumber: serialNumber) {
        (calibrationparams)  in
        guard let params = calibrationparams else {
            NSLog("dabear:: could not calibrate sensor, check libreoopweb permissions and internet connection")
            callback(nil)
            return
        }
        //here we assume success, data is not changed,
        //and we trust that the remote endpoint returns correct data for the sensor
        let last16 = trendMeasurements(bytes: bytes, date: Date(), derivedAlgorithmParameterSet: params)
        if let glucoseData = trendToLibreGlucose(last16) {
            callback((glucoseData, sensorState, 0))
        }
    }
}

private func trendMeasurements(bytes: [UInt8], date: Date, _ offset: Double = 0.0, slope: Double = 0.1, derivedAlgorithmParameterSet: DerivedAlgorithmParameters?) -> [Measurement] {
    
//    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
    let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
//    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
    
    let body   = Array(bytes[bodyRange])
    let nextTrendBlock = Int(body[2])
    
    var measurements = [Measurement]()
    // Trend data is stored in body from byte 4 to byte 4+96=100 in units of 6 bytes. Index on data such that most recent block is first.
    for blockIndex in 0...15 {
        var index = 4 + (nextTrendBlock - 1 - blockIndex) * 6 // runs backwards
        if index < 4 {
            index = index + 96 // if end of ring buffer is reached shift to beginning of ring buffer
        }
        let range = index..<index+6
        let measurementBytes = Array(body[range])
        let measurementDate = date.addingTimeInterval(Double(-60 * blockIndex))
        let measurement = Measurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, derivedAlgorithmParameterSet: derivedAlgorithmParameterSet)
        measurements.append(measurement)
    }
    return measurements
}


private func trendToLibreGlucose(_ measurements: [Measurement]) -> [RawGlucoseData]?{
    var origarr = [RawGlucoseData]()
    
    //whether or not to return all the 16 latest trends or just every fifth element
    let returnAllTrends = true
    
    for trend in measurements {
        let glucose = RawGlucoseData.init(timeStamp: trend.date, unsmoothedGlucose: trend.temperatureAlgorithmGlucose)
        origarr.append(glucose)
    }
    //NSLog("dabear:: glucose samples before smoothing: \(String(describing: origarr))")
    var arr : [RawGlucoseData]
    arr = CalculateSmothedData5Points(origtrends: origarr)
    
    
    
    for i in 0 ..< arr.count {
        var trend = arr[i]
        //we know that the array "always" (almost) will contain 16 entries
        //the last five entries will get a trend arrow of flat, because it's not computable when we don't have
        //more entries in the array to base it on
    }
    
    if returnAllTrends {
        return arr
    }
    
    return arr
}
