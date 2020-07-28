import Foundation
import CoreData

/// calibrator for cases where transmitter gives calibrated values, ie no calibration necessary. It will simply create readings with the value of rawData in the reading
class NoCalibrator: Calibrator {
    
    // not used here, arbitrary value assigned
    var rawValueDivider: Double = 1000.0
    
    /// value nil, not needed
    var sParams: SlopeParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)
    
    /// value false, not needed
    var ageAdjustMentNeeded: Bool = false
    
    /// create a new BgReading
    /// - parameters:
    ///     - rawData : the rawdata value
    ///     - filteredData : the filtered data
    ///     - timeStamp : optional, if nil then actualy date and time is used
    ///     - sensor : actual sensor, optional
    ///     - last3Readings : empty array
    ///     - nsManagedObjectContext : the nsManagedObjectContext
    ///     - lastCalibrationsForActiveSensorInLastXDays : empty array
    ///     - firstCalibration : nil
    ///     - lastCalibration : nil
    /// - returns:
    ///     - the created bgreading
    func createNewBgReading(rawData:Double, filteredData:Double, timeStamp:Date?, sensor:Sensor?, last3Readings:inout Array<BgReading>, lastCalibrationsForActiveSensorInLastXDays:inout Array<Calibration>, firstCalibration:Calibration?, lastCalibration:Calibration?, deviceName:String?, nsManagedObjectContext:NSManagedObjectContext ) -> BgReading {
        
        var timeStampToUse:Date = Date()
        if let timeStamp = timeStamp {
            timeStampToUse = timeStamp
        }
        
        let bgReading:BgReading = BgReading(
            timeStamp:timeStampToUse,
            sensor:sensor,
            calibration:lastCalibration,
            rawData:rawData,
            filteredData:filteredData,
            deviceName:deviceName,
            nsManagedObjectContext:nsManagedObjectContext
        )
        
        bgReading.calculatedValue = rawData
        
        findSlope(for: bgReading, last2Readings: &last3Readings)
        
        return bgReading
    }
    
    

    
}
