import Foundation

/// has the last 24Hr (or more ? ) readings
///
/// also methods to get specific readings, needed in the calibration algorithms
///
/// also used by viewcontroller
class BgReadings {
    
    //static let shared:BgReadings = BgReadings()
    
    /// the latest 24 hours (or more ?) of readings.
    /// the latest element is the youngest
    static private var bgReadings:Array<BgReading> = []
 
    private init() {
    }
    
    /// Gives readings for which calculatedValue != 0, rawdata != 0, matching sensorid if sensorid not nil,
    /// - parameters:
    ///     - howMany : maximum amount of readings to return
    ///     - forSensor : if not nil, then only readings for the given sensor will be returned - if nil, then sensor is ignored
    ///     - if ignoreRawData = true, then value of rawdata will be ignored
    ///     - if ignoreCalculatedValue = true, then value of calculatedValue will be ignored
    /// - returns: an array with readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    static func getLatestReadings(howMany amount:Int, forSensor sensor:Sensor?, ignoreRawData:Bool, ignoreCalculatedValue:Bool) -> Array<BgReading> {
        var returnValue:Array<BgReading> = []
        let ignoreSensorId = sensor == nil ? true:false
        loop: if ignoreSensorId {
            for bgReading in bgReadings.reversed() {
                if (bgReading.sensor != nil || ignoreSensorId) {
                    if ((ignoreSensorId || bgReading.sensor!.id == sensor!.id) && (bgReading.calculatedValue != 0 || ignoreCalculatedValue) && (bgReading.rawData != 0 || ignoreRawData)) {
                        returnValue.append(bgReading)
                        if returnValue.count == amount {
                            break loop
                        }
                    }
                }
            }
        }
        return returnValue
    }
    
    /// Gives readings of last 30 minutes for which calculatedValue != 0, rawdata != 0
    /// - returns: an array with readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    static func getReadingsOfLast30Minutes () -> Array<BgReading> {
        var returnValue:Array<BgReading> = []
        let nowMinus30Minutes = Date.nowInMilliSecondsAsDouble() - Double(60000 * 30)
        loop: for bgReading in bgReadings.reversed() {
            if (bgReading.calculatedValue != 0 && bgReading.rawData != 0 && (bgReading.timeStamp.toMillisecondsAsDouble()) > nowMinus30Minutes) {
                returnValue.append(bgReading)
            }
            if !((bgReading.timeStamp.toMillisecondsAsDouble()) <= nowMinus30Minutes) {
                break loop
            }
        }
        return returnValue
    }
    
    /// get last reading for which calculatedValue != 0, rawdata != 0
    /// - returns: the last reading for which calculatedValue != 0, rawdata != 0, can be nil
    static func getLastReadingNoSensor() -> BgReading? {
        loop: for bgReading in bgReadings.reversed() {
            if (bgReading.calculatedValue != 0 && bgReading.rawData != 0) {
                return bgReading
            }
        }
        return nil
    }
    
    /// get last reading for which calculatedValue != 0
    /// - returns: the last reading for which calculatedValue != 0, can be nil
    static func getLastWithCalculatedValue() -> BgReading? {
        loop: for bgReading in bgReadings.reversed() {
            if bgReading.calculatedValue != 0 {
                return bgReading
            }
        }
        return nil
    }
    
    

}
