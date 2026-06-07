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
    ///     - timeStamp : optional, if nil then actualy date and time is used
    ///     - sensor : actual sensor, optional
    ///     - last3Readings : empty array
    ///     - nsManagedObjectContext : the nsManagedObjectContext
    ///     - lastCalibrationsForActiveSensorInLastXDays : empty array
    ///     - firstCalibration : nil
    ///     - lastCalibration : nil
    /// - returns:
    ///     - the created bgreading
    func createNewBgReading(rawData:Double, timeStamp:Date?, sensor:Sensor?, last3Readings:inout Array<BgReading>, lastCalibrationsForActiveSensorInLastXDays:inout Array<Calibration>, firstCalibration:Calibration?, lastCalibration:Calibration?, deviceName:String?, nsManagedObjectContext:NSManagedObjectContext ) -> BgReading {
        
        var timeStampToUse:Date = Date()
        if let timeStamp = timeStamp {
            timeStampToUse = timeStamp
        }
        
        let bgReading:BgReading = BgReading(
            timeStamp:timeStampToUse,
            sensor:sensor,
            calibration:lastCalibration,
            rawData:rawData,
            deviceName:deviceName,
            nsManagedObjectContext:nsManagedObjectContext
        )
        
        bgReading.calculatedValue = rawData
        
        findSlope(for: bgReading, last2Readings: &last3Readings)
        
        // just do a quick sanity check to ensure that we limit any very high values that come through unfiltered such as can occur with Libre 2 output immediately after start-up/insertion.
        // this will limit it to around 600 maximum. Most errant readings are 600 > bg > 5000.
        // we purposefully limit to 600 and not to 400 as Libre, unlike Dexcom, can send values between 400 and 600 and although we won't display them without "HIGH", we can use them to show the delta and trend to help the user
        bgReading.calculatedValue = min(ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValueLimit, bgReading.calculatedValue)
        
        return bgReading
    }
    
    func createNewCalibration(bgValue:Double, lastBgReading:BgReading?, sensor:Sensor, lastCalibrationsForActiveSensorInLastXDays:inout Array<Calibration>, firstCalibration:Calibration, deviceName:String?, nsManagedObjectContext:NSManagedObjectContext) -> Calibration? {
        
        return Calibration(timeStamp: Date(), sensor: sensor, bg: bgValue, rawValue: bgValue, adjustedRawValue: bgValue, sensorConfidence: 0, rawTimeStamp: Date(), slope: 0.0, intercept: 0.0, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: 0, slopeConfidence: 0, deviceName:deviceName, nsManagedObjectContext: nsManagedObjectContext)

    }
    
    func initialCalibration(firstCalibrationBgValue:Double, firstCalibrationTimeStamp:Date, secondCalibrationBgValue:Double, sensor:Sensor, lastBgReadingsWithCalculatedValue0AndForSensor:inout Array<BgReading>, deviceName:String?, nsManagedObjectContext:NSManagedObjectContext) -> (firstCalibration: Calibration?, secondCalibration: Calibration?){
        
        // create calibration with timestamp = firstCalibrationTimeStamp + 5 minutes, because the initialcalibration is done with first calibration of 5 minutes ago
        let calibration = Calibration(timeStamp: firstCalibrationTimeStamp.addingTimeInterval(TimeInterval(minutes: 5)), sensor: sensor, bg: firstCalibrationBgValue, rawValue: firstCalibrationBgValue, adjustedRawValue: firstCalibrationBgValue, sensorConfidence: 0, rawTimeStamp: Date(), slope: 0, intercept: 0.0, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: firstCalibrationBgValue, slopeConfidence: 0, deviceName: deviceName, nsManagedObjectContext:  nsManagedObjectContext)
        
        return (calibration, nil)
        
    }


    func description() -> String {
        return "NoCalibrator"
    }
    
}
