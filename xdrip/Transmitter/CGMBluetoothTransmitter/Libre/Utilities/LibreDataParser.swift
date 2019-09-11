import Foundation

class LibreDataParser {
    
    /// parses libre block
    /// - parameters:
    ///     - libreData: the 344 bytes block from Libre
    ///     - timeStampLastBgReadingStoredInDatabase: this is of the timestamp of the latest reading we already received during previous session
    /// - returns:
    ///     - array of GlucoseData, first is the most recent, LibreSensorState. Only returns recent readings, ie not the ones that are older than timeStampLastBgReadingStoredInDatabase. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReadingStoredInDatabase
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes
    public static func parse(libreData: Data, timeStampLastBgReading:Date) -> (glucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int) {
        var i:Int
        var glucoseData:GlucoseData
        var byte:Data
        var timeInMinutes:Double
        let ourTime:Date = Date()
        let indexTrend:Int = getByteAt(buffer: libreData, position: 26) & 0xFF
        let indexHistory:Int = getByteAt(buffer: libreData, position: 27) & 0xFF
        let sensorTimeInMinutes:Int = 256 * (getByteAt(buffer:libreData, position: 317) & 0xFF) + (getByteAt(buffer:libreData, position: 316) & 0xFF)
        let sensorStartTimeInMilliseconds:Double = ourTime.toMillisecondsAsDouble() - (Double)(sensorTimeInMinutes * 60 * 1000)
        var returnValue:Array<GlucoseData> = []
        let sensorState = LibreSensorState(stateByte: libreData[4])
        
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
            if timeStampOfNewGlucoseData > (timeStampLastBgReading.toMillisecondsAsDouble() + 30000.0)
            {
                if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                    byte = Data()
                    byte.append(libreData[(i * 6 + 29)])
                    byte.append(libreData[(i * 6 + 28)])
                    let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                    if (glucoseLevelRaw > 0) {
                        glucoseData = GlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * ConstantsBloodGlucose.libreMultiplier)
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
            if timeStampOfNewGlucoseData > (timeStampLastBgReading.toMillisecondsAsDouble() + 30000.0)
            {
                if timeStampOfNewGlucoseData < timeStampLastAddedGlucoseData - (5 * 60 * 1000 - 10000) {
                    byte = Data()
                    byte.append(libreData[(i * 6 + 125)])
                    byte.append(libreData[(i * 6 + 124)])
                    let glucoseLevelRaw = Double(getGlucoseRaw(bytes: byte))
                    if (glucoseLevelRaw > 0) {
                        glucoseData = GlucoseData(timeStamp: Date(timeIntervalSince1970: sensorStartTimeInMilliseconds/1000 + timeInMinutes * 60), glucoseLevelRaw: Double(getGlucoseRaw(bytes: byte)) * ConstantsBloodGlucose.libreMultiplier)
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
    
    /// Function which groups common functionality used for transmitters that support the 344 Libre block. It checks if webOOP is enabled, if yes tries to use the webOOP, response is processed and delegate is called. If webOOP is not enabled, then local parsing is done.
    /// - parameters:
    ///     - sensorSerialNumber : if nil, then webOOP will not be used and local parsing will be done
    ///     - libreData : the 344 bytes from Libre sensor
    ///     - timeStampLastBgReading : timestamp of last reading, older readings will be ignored
    ///     - webOOPEnabled : is webOOP enabled or not, if not enabled, local parsing is used
    ///     - cgmTransmitterDelegate : the cgmTransmitterDelegate
    ///     - completionHandler : will be called when glucose data is read with as parameter the timestamp of the last reading. Goal is that caller an set timeStampLastBgReading to the new value
    ///     - transmitterBatteryInfo : not mandatory, if nil then delegate will simply not receive it, possibly the delegate already received it before, and if not
    ///     - firmware : not mandatory, if nil then delegate will simply not receive it, possibly the delegate already received it before, and if not or maybe it doesn't exist for the specific type of transmitter
    ///     - hardware : not mandatory, if nil then delegate will simply not receive it, possibly the delegate already received it before, and if not or maybe it doesn't exist for the specific type of transmitter
    ///     - hardwareSerialNumber : not mandatory, if nil then delegate will simply not receive it, possibly the delegate already received it before, and if not or maybe it doesn't exist for the specific type of transmitter
    ///     - bootloader : not mandatory, if nil then delegate will simply not receive it, possibly the delegate already received it before, and if not or maybe it doesn't exist for the specific type of transmitter
    ///
    /// parameter values that are not known, simply ignore them, if they are not known then they are probably not important, or they've already been passed to the delegate before. 
    public static func libreDataProcessor(sensorSerialNumber: String?, webOOPEnabled: Bool, libreData: Data, cgmTransmitterDelegate : CGMTransmitterDelegate?, transmitterBatteryInfo:TransmitterBatteryInfo?, firmware: String?, hardware: String?, hardwareSerialNumber: String?, bootloader:String?, timeStampLastBgReading: Date, completionHandler:@escaping ((_ timeStampLastBgReading: Date) -> ())) {

        if let sensorSerialNumber = sensorSerialNumber, webOOPEnabled {
            LibreOOPClient.handleLibreData(libreData: [UInt8](libreData), timeStampLastBgReading: timeStampLastBgReading, serialNumber: sensorSerialNumber) {
                (result) in
                if let res = result {
                    handleGlucoseData(result: res, cgmTransmitterDelegate: cgmTransmitterDelegate, transmitterBatteryInfo: transmitterBatteryInfo, firmware: firmware, hardware: hardware, hardwareSerialNumber: hardwareSerialNumber, bootloader: bootloader, sensorSerialNumber: sensorSerialNumber, completionHandler: completionHandler)
                    
                    
                    let params = libreData.hexEncodedString()
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: "webOOPLog"), object: params)
                }
            }
        } else if !webOOPEnabled {
            // use local parser
            process(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading, cgmTransmitterDelegate: cgmTransmitterDelegate, transmitterBatteryInfo: transmitterBatteryInfo, firmware: firmware, hardware: hardware, hardwareSerialNumber: hardwareSerialNumber, bootloader: bootloader, sensorSerialNumber: sensorSerialNumber, completionHandler: completionHandler)
        }

    }

}


fileprivate func getByteAt(buffer:Data, position:Int) -> Int {
    // TODO: move to extension data
    return Int(buffer[position])
}

fileprivate func getGlucoseRaw(bytes:Data) -> Int {
    return ((256 * (getByteAt(buffer: bytes, position: 0) & 0xFF) + (getByteAt(buffer: bytes, position: 1) & 0xFF)) & 0x1FFF)
}

/// calls LibreDataParser.parse - calls handleGlucoseData
fileprivate func process(libreData: Data, timeStampLastBgReading: Date, cgmTransmitterDelegate : CGMTransmitterDelegate?, transmitterBatteryInfo:TransmitterBatteryInfo?, firmware: String?, hardware: String?, hardwareSerialNumber: String?, bootloader:String?, sensorSerialNumber:String?, completionHandler:((_ timeStampLastBgReading: Date) -> ())) {
    
    //get readings from buffer and send to delegate
    let result = LibreDataParser.parse(libreData: libreData, timeStampLastBgReading: timeStampLastBgReading)
    
    handleGlucoseData(result: result, cgmTransmitterDelegate: cgmTransmitterDelegate, transmitterBatteryInfo: transmitterBatteryInfo, firmware: firmware, hardware: hardware, hardwareSerialNumber: hardwareSerialNumber, bootloader: bootloader, sensorSerialNumber: sensorSerialNumber, completionHandler: completionHandler)
}

/// calls delegate with parameters from result, will change value of timeStampLastBgReading
fileprivate func handleGlucoseData(result: (glucoseData:[GlucoseData], sensorState: LibreSensorState, sensorTimeInMinutes:Int), cgmTransmitterDelegate : CGMTransmitterDelegate?, transmitterBatteryInfo:TransmitterBatteryInfo?, firmware:String?, hardware:String?, hardwareSerialNumber:String?, bootloader:String?, sensorSerialNumber:String?, completionHandler:((_ timeStampLastBgReading: Date) -> ())) {
    
    var result = result
    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: transmitterBatteryInfo, sensorState: result.sensorState, sensorTimeInMinutes: result.sensorTimeInMinutes, firmware: firmware, hardware: hardware, hardwareSerialNumber: hardwareSerialNumber, bootloader: bootloader, sensorSerialNumber: sensorSerialNumber)
    
    //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
    if result.glucoseData.count > 0 {
        completionHandler(result.glucoseData[0].timeStamp)
    }
}

