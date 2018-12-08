import Foundation
import CoreData

/// only algorithms related to creating of bgreading
/// these come form the original BgReading classes (Spike and xdripplus)
/// no data
class BgReadingAlgorithms {
    
    ///no instances should be created
    private init() {}
    
    /// converts mgdl to mmol
    static func mgdlToMmol(withmgDlValue mgDlValue: Double) -> Double {
        return mgDlValue * Constants.BloodGlucose.mgDlToMmoll
    }

    /// converts mmol to mgdl
    static func mmolToMgdl(withMmolValue mmolValue:Double) -> Double {
        return mmolValue * Constants.BloodGlucose.mmollToMgdl
    }
    
    /// taken over form xdripplus
    /// - Parameters:
    ///     - bgReading : can be nil, if nil then return value is 0
    static func activeSlope(bgReading:BgReading?) -> Double {
        if let reading = bgReading {
            return (2 * reading.a * (Date().toMillisecondsAsDouble())) + reading.b
        } else {
            return 0
        }
    }
    
    /// taken over form xdripplus
    static func calculateSlope(withCurrentBgReading currentBgReading:BgReading, withLastBgReading lastBgReading:BgReading) -> (Double, Bool) {
        if currentBgReading.timeStamp == lastBgReading.timeStamp
            ||
            currentBgReading.timeStamp.toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble() > Double(Constants.BGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0,true)
        }
        return ((lastBgReading.calculatedValue - currentBgReading.calculatedValue) / (lastBgReading.timeStamp.toMillisecondsAsDouble() - currentBgReading.timeStamp.toMillisecondsAsDouble()), false)
    }
    
    /// taken over from xdripplus
    ///
    /// updates parameter forBgReading
    ///
    /// new value is not stored in the database
    /// - parameters:
    ///     - forBgReading : reading that needs to be updated
    ///     - withLast3Readings : result of call to BgReadings.getLatestReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    private static func findNewCurve(forBgReading bgReading:BgReading, withLast3Readings last3:Array<BgReading>) {
        var y3:Double
        var x3:Double
        var y2:Double
        var x2:Double
        var y1:Double
        var x1:Double
        var latest:BgReading
        var secondlatest:BgReading
        var thirdlatest:BgReading
        if (last3.count == 3) {
            latest = last3[0]
            secondlatest = last3[1]
            thirdlatest = last3[2]
            y3 = latest.calculatedValue
            x3 = latest.timeStamp.toMillisecondsAsDouble()
            y2 = secondlatest.calculatedValue
            x2 = secondlatest.timeStamp.toMillisecondsAsDouble()
            y1 = thirdlatest.calculatedValue
            x1 = thirdlatest.timeStamp.toMillisecondsAsDouble()
    
            bgReading.a = y1/((x1-x2)*(x1-x3))+y2/((x2-x1)*(x2-x3))+y3/((x3-x1)*(x3-x2))
            bgReading.b = (-y1*(x2+x3)/((x1-x2)*(x1-x3))-y2*(x1+x3)/((x2-x1)*(x2-x3))-y3*(x1+x2)/((x3-x1)*(x3-x2)))
            bgReading.c = (y1*x2*x3/((x1-x2)*(x1-x3))+y2*x1*x3/((x2-x1)*(x2-x3))+y3*x1*x2/((x3-x1)*(x3-x2)))
        } else if (last3.count == 2) {
            latest = last3[0]
            secondlatest = last3[1]
            y2 = latest.calculatedValue
            x2 = latest.timeStamp.toMillisecondsAsDouble()
            y1 = secondlatest.calculatedValue
            x1 = secondlatest.timeStamp.toMillisecondsAsDouble()
            if (y1 == y2) {
                bgReading.b = 0
            } else {
                bgReading.b = (y2 - y1)/(x2 - x1)
            }
            bgReading.a = 0
            bgReading.c = -1 * ((latest.b * x1) - y1)
        } else {
            bgReading.a = 0
            bgReading.b = 0
            bgReading.c = bgReading.calculatedValue
        }
    }
    
    /// taken over from xdripplus
    ///
    /// updates parameter forBgReading
    ///
    /// new value is not stored in the database
    /// - parameters:
    ///     - forBgReading : reading that needs to be updated
    ///     - withLast3Readings : result of call to BgReadings.getLatestReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    ///     - withLastNoSensor : result of call to getLastReadingNoSensor
    private static func findNewRawCurve(forBgReading bgReading:BgReading, withLast3Readings last3:Array<BgReading>, withLastNoSensor lastNoSensor:BgReading?) {
    var y3:Double
    var x3:Double
    var y2:Double
    var x2:Double
    var y1:Double
    var x1:Double
    var latest:BgReading
    var secondlatest:BgReading
    var thirdlatest:BgReading
    if (last3.count == 3) {
        latest = last3[0] as BgReading
        secondlatest = last3[1] as BgReading
        thirdlatest = last3[2] as BgReading
    
        y3 = latest.ageAdjustedRawValue
        x3 = latest.timeStamp.toMillisecondsAsDouble()
        y2 = secondlatest.ageAdjustedRawValue
        x2 = secondlatest.timeStamp.toMillisecondsAsDouble()
        y1 = thirdlatest.ageAdjustedRawValue
        x1 = thirdlatest.timeStamp.toMillisecondsAsDouble()
    
        bgReading.ra = y1/((x1-x2)*(x1-x3))+y2/((x2-x1)*(x2-x3))+y3/((x3-x1)*(x3-x2))
        bgReading.rb = (-y1*(x2+x3)/((x1-x2)*(x1-x3))-y2*(x1+x3)/((x2-x1)*(x2-x3))-y3*(x1+x2)/((x3-x1)*(x3-x2)))
        bgReading.rc = (y1*x2*x3/((x1-x2)*(x1-x3))+y2*x1*x3/((x2-x1)*(x2-x3))+y3*x1*x2/((x3-x1)*(x3-x2)))
    
    } else if (last3.count == 2) {
        latest = last3[0] as BgReading
        secondlatest = last3[1] as BgReading
    
        y2 = latest.ageAdjustedRawValue
        x2 = latest.timeStamp.toMillisecondsAsDouble()
        y1 = secondlatest.ageAdjustedRawValue
        x1 = secondlatest.timeStamp.toMillisecondsAsDouble()
    
        if(y1 == y2) {
            bgReading.rb = 0
        } else {
            bgReading.rb = (y2 - y1)/(x2 - x1)
        }
        bgReading.ra = 0
        bgReading.rc = -1 * ((latest.rb * x1) - y1)
    
        } else {
            bgReading.ra = 0
            bgReading.rb = 0
            if let last = lastNoSensor {
                bgReading.rc = last.ageAdjustedRawValue
            } else {
                bgReading.rc = 105
            }
        }
    }
    
    /// taken over from xdripplus
    ///
    /// updates parameter forBgReading
    ///
    /// new value is not stored in the database
    /// - parameters:
    ///     - forBgReading : reading that needs to be updated
    private static func updateCalculatedValue(forBgReading bgReading:BgReading) {
        if (bgReading.calculatedValue < 10) {
            bgReading.calculatedValue = 38
            bgReading.hideSlope = true
        } else {
            bgReading.calculatedValue = min(400, max(39, bgReading.calculatedValue))
        }
    }
    
    /// taken over from xdripplus
    ///
    /// - parameters:
    ///     - withTimeStamp : timeStamp :)
    ///     - last1Reading : result of call to BgReadings.getLatestReadings(1, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    private static func getEstimatedRawBg(withTimeStamp timeStamp:Double, withLast1Reading last1Reading:Array<BgReading>) -> Double {
        var estimate:Double
        if (last1Reading.count == 0) {
            estimate = 160
        } else {
            let latest:BgReading = last1Reading[0]
            estimate = (latest.ra * timeStamp * timeStamp) + (latest.rb * timeStamp) + latest.rc
        }
        return estimate
    }
    
    private static func calculateAgeAdjustedRawValue(withBgReading bgReading:BgReading, withSensor sensor:Sensor?) {
        if let sensor = sensor {
            let adjustfor:Double = Constants.BgReadingAlgorithms.ageAdjustmentTime - (bgReading.timeStamp.toMillisecondsAsDouble() - sensor.startDate.toMillisecondsAsDouble())
            if (adjustfor <= 0 || ActiveBluetoothDevice.shared.isTypeLimitter()) {
                bgReading.ageAdjustedRawValue = bgReading.rawData
            } else {
                bgReading.ageAdjustedRawValue = ((Constants.BgReadingAlgorithms.ageAdjustmentFactor * (adjustfor / Constants.BgReadingAlgorithms.ageAdjustmentTime)) * bgReading.rawData) + bgReading.rawData
            }
        } else {
            bgReading.ageAdjustedRawValue = bgReading.rawData
        }
    }
    

    
    /// create a new BgReading
    ///
    /// - parameters:
    ///     - withLast3Readings : result of call to BgReadings.getLatestReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
   static func createNewReading(withRawData rawData:Double, withFilteredData filteredData:Double, withTimeStamp timeStamp:Date?, withSensor sensor:Sensor, withLastCalibration lastCalibration:Calibration?, withLast3Readings last3Readings:Array<BgReading>, in nsManagedObjectContext:NSManagedObjectContext ) -> BgReading {
      
        var timeStampToUse:Date = Date()
        if let timeStamp = timeStamp {
            timeStampToUse = timeStamp
        }
        
        var bgReading:BgReading = BgReading(
            timeStamp:timeStampToUse,
            sensor:sensor,
            calibration:lastCalibration,
            rawData:rawData / 1000,
            filteredData:filteredData / 1000,
            nsManagedObjectContext:nsManagedObjectContext
        )
        
        calculateAgeAdjustedRawValue(withBgReading:bgReading, withSensor:sensor)
        if let calibration = lastCalibration {
            if calibration.checkIn {
                var firstAdjSlope:Double = calibration.firstSlope + (calibration.firstDecay * (ceil(Date.nowInMilliSecondsAsDouble() - calibration.timeStamp.toMillisecondsAsDouble())/(1000 * 60 * 10)))
                var calSlope:Double = (calibration.firstScale / firstAdjSlope) * 1000
                var calIntercept:Double = ((calibration.firstScale * calibration.firstIntercept) / firstAdjSlope) * -1
                bgReading.calculatedValue = (((calSlope * rawData) + calIntercept) - 5)
                bgReading.filteredCalculatedValue = (((calSlope * bgReading.ageAdjustedRawValue) + calIntercept) - 5)
            } else {
                if (last3Readings.count > 0) {
                    let latest:BgReading = last3Readings[0]
                    if let latestReadingCalibration = latest.calibration {
                        if (latest.calibrationFlag && ((latest.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble()) && ((latestReadingCalibration.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble())) {
                            latestReadingCalibration.calibration.rawValueOverride(BgReading.weightedAverageRaw(latest.timestamp, timeStampToUse, lastBgReading.calibration.timestamp, lastBgReading.ageAdjustedRawValue, bgReading.ageAdjustedRawValue))
                        }
                    }
                }
                bgReading.calculatedValue = ((calibration.slope * bgReading.ageAdjustedRawValue) + calibration.intercept)
                bgReading.filteredCalculatedValue = ((calibration.slope * ageAdjustedFiltered(withLastCalibration: lastCalibration, withBgReading: bgReading)) + calibration.intercept)
            }
            updateCalculatedValue(forBgReading: bgReading)
        }
    
        //it looks as if argument withLastNoSensor is just the same reading, which means reading  is passed two times
        // TO DO this needs to be double-checked
        performCalculations(forBgReading: bgReading, withLast3Readings: last3Readings, withLastNoSensor: bgReading, forSensor: sensor)
        return bgReading
    }

    private static func getUsedRaw(withLastCalibration calibration:Calibration?, withBgReading bgReading:BgReading) -> Double {
        if let calibration = calibration {
            if calibration.checkIn {
                return bgReading.rawData
            }
        } else {
            return bgReading.ageAdjustedRawValue
        }
    }

    private static func ageAdjustedFiltered(withLastCalibration calibration:Calibration?, withBgReading bgReading:BgReading) -> Double {
        let usedRaw = getUsedRaw(withLastCalibration: calibration, withBgReading: bgReading)
        if(usedRaw == bgReading.rawData || bgReading.rawData == 0) {
            return bgReading.filteredData
        } else {
            // adjust the filtereddata with the same factor as the age adjusted raw value
            return bgReading.filteredData * usedRaw / bgReading.rawData;
        }
    }
    
    private static func weightedAverageRaw (withTimeA timeA:Double, withTimeB timeB:Double, withCalibrationTime calibrationTime:Double, withRawA rawA:Double, withRawB rawB:Double) -> Double {
        let relativeSlope:Double = (rawB -  rawA)/(timeB - timeA)
        let relativeIntercept:Double = rawA - (relativeSlope * timeA)
        return ((relativeSlope * calibrationTime) + relativeIntercept)
    }

    private static func performCalculations(forBgReading bgReading:BgReading, withLast3Readings last3:Array<BgReading>, withLastNoSensor lastNoSensor:BgReading?, forSensor sensor:Sensor?)  {
        
        findNewCurve(forBgReading: bgReading, withLast3Readings: last3)
        findNewRawCurve(forBgReading: bgReading, withLast3Readings: last3, withLastNoSensor: lastNoSensor)
        
        findSlope(forBgReading: bgReading, forSensor: sensor)
    }
    
    /// sensor nil corresponds to ignoresensorid
    public static func findSlope(forBgReading bgReading:BgReading, forSensor sensor:Sensor?) {
        var last2 = BgReadings.getLatestReadings(howMany: 2, forSensor: sensor, ignoreRawData: false, ignoreCalculatedValue: false)
        
        bgReading.hideSlope = true;
        if (last2.count == 2) {
            let (slope, hide) = calculateSlope(withCurrentBgReading:bgReading, withLastBgReading:last2[1]);
            bgReading.calculatedValueSlope = slope
            bgReading.hideSlope = hide
        } else if (last2.count == 1) {
            bgReading.calculatedValueSlope = 0
        } else {
            bgReading.calculatedValueSlope = 0
        }
    }
    
    

}
