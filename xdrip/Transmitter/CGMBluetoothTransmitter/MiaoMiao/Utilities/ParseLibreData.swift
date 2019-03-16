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
func parseLibreData(data:inout Data, timeStampLastBgReadingStoredInDatabase:Date, headerOffset:Int) -> (glucoseData:[RawGlucoseData], sensorState:SensorState, sensorTimeInMinutes:Int) {
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
    let sensorState = SensorState(stateByte: data[headerOffset + 4])
    
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
                    glucoseData = RawGlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * Constants.Libre.libreMultiplier)
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
                    glucoseData = RawGlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * Constants.Libre.libreMultiplier)
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

