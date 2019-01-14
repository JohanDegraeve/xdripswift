import Foundation
import CoreData

/// converts mgdl to mmol
func mgdlToMmol(mgDlValue: Double) -> Double {
    return mgDlValue * Constants.BloodGlucose.mgDlToMmoll
}

/// converts mmol to mgdl
func mmolToMgdl(mmolValue:Double) -> Double {
    return mmolValue * Constants.BloodGlucose.mmollToMgdl
}

/// taken over from xdripplus
///
/// updates parameter forBgReading
///
/// - parameters:
///     - bgReading : reading that needs to be updated
///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - it's ok if there's less than 3 readings - inout parameter to improve performance
func findNewCurve(for bgReading: BgReading, last3Readings:inout Array<BgReading>) {
    //debuglogging("in findNewCurve with last3Readings.count = " + last3Readings.count.description)

    var y3:Double
    var x3:Double
    var y2:Double
    var x2:Double
    var y1:Double
    var x1:Double
    var latest:BgReading
    var secondlatest:BgReading
    var thirdlatest:BgReading
    
    
    if (last3Readings.count > 2) {
        latest = last3Readings[0]
        secondlatest = last3Readings[1]
        thirdlatest = last3Readings[2]
        y3 = latest.calculatedValue
        x3 = latest.timeStamp.toMillisecondsAsDouble()
        y2 = secondlatest.calculatedValue
        x2 = secondlatest.timeStamp.toMillisecondsAsDouble()
        y1 = thirdlatest.calculatedValue
        x1 = thirdlatest.timeStamp.toMillisecondsAsDouble()
        
        //debuglogging("latest = " + latest.log(""))
        //debuglogging("X3 = " + x3.description + ", Y 3 = " + y3.description + ",x2 = " + x2.description + ", y2 = " + y2.description + ", x1 = " + x1.description + ", y1 = " + y1.description);
        
        bgReading.a = y1/((x1-x2)*(x1-x3))+y2/((x2-x1)*(x2-x3))+y3/((x3-x1)*(x3-x2))
        bgReading.b = (-y1*(x2+x3)/((x1-x2)*(x1-x3))-y2*(x1+x3)/((x2-x1)*(x2-x3))-y3*(x1+x2)/((x3-x1)*(x3-x2)))
        bgReading.c = (y1*x2*x3/((x1-x2)*(x1-x3))+y2*x1*x3/((x2-x1)*(x2-x3))+y3*x1*x2/((x3-x1)*(x3-x2)))
    } else if (last3Readings.count == 2) {
        latest = last3Readings[0]
        secondlatest = last3Readings[1]
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
///     - bgReading : reading that needs to be updated
///     - last3Readings : result of call to BgReadings.getLatestBgReadings(x, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
func findNewRawCurve(for bgReading: BgReading, last3Readings:inout Array<BgReading>) {
    //debuglogging("in findNewRawCurve with last3Readings.count = " + last3Readings.count.description)
    
    var y3:Double
    var x3:Double
    var y2:Double
    var x2:Double
    var y1:Double
    var x1:Double
    var latest:BgReading
    var secondlatest:BgReading
    var thirdlatest:BgReading
    
    if (last3Readings.count > 2) {
        latest = last3Readings[0]
        secondlatest = last3Readings[1]
        thirdlatest = last3Readings[2]
        
        y3 = latest.ageAdjustedRawValue
        x3 = latest.timeStamp.toMillisecondsAsDouble()
        y2 = secondlatest.ageAdjustedRawValue
        x2 = secondlatest.timeStamp.toMillisecondsAsDouble()
        y1 = thirdlatest.ageAdjustedRawValue
        x1 = thirdlatest.timeStamp.toMillisecondsAsDouble()
        
        bgReading.ra = y1/((x1-x2)*(x1-x3))+y2/((x2-x1)*(x2-x3))+y3/((x3-x1)*(x3-x2))
        bgReading.rb = (-y1*(x2+x3)/((x1-x2)*(x1-x3))-y2*(x1+x3)/((x2-x1)*(x2-x3))-y3*(x1+x2)/((x3-x1)*(x3-x2)))
        bgReading.rc = (y1*x2*x3/((x1-x2)*(x1-x3))+y2*x1*x3/((x2-x1)*(x2-x3))+y3*x1*x2/((x3-x1)*(x3-x2)))
        
    } else if (last3Readings.count == 2) {
        //debuglogging("in last3Readings.count == 2")
        latest = last3Readings[0]
        secondlatest = last3Readings[1]
        
        //debuglogging("latest timestamp =  "  + latest.timeStamp.description)
        //debuglogging("secondlatest timestamp =  "  + secondlatest.timeStamp.description)
        //debuglogging("this reading timestamp =  "  + bgReading.timeStamp.description)
        
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
        bgReading.rc = 105
    }
}

/// verify against minimum and maximum values 38 and 400
///
/// new value is not stored in the database
/// - parameters:
///     - bgReading : reading that needs to be updated - inout parameter to improve performance
func updateCalculatedValue(for bgReading:BgReading) {
    if (bgReading.calculatedValue < 10) {
        bgReading.calculatedValue = Constants.BgReadingAlgorithms.bgReadingErrorValue
        bgReading.hideSlope = true
    } else {
        bgReading.calculatedValue = min(Constants.BgReadingAlgorithms.maximumBgReadingCalculatedValue, max(Constants.BgReadingAlgorithms.minimumBgReadingCalculatedValue, bgReading.calculatedValue))
    }
}

/// create a new BgReading
///
/// - parameters:
///     - rawData : the rawdata value
///     - filteredData : the filtered data
///     - timeStamp : optional, if nil then actualy date and time is used
///     - sensor : actual sensor, optional
///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance and also because it's an NSManagedObject
///     - nsManagedObjectContext : the nsManagedObjectContext
///     - lastCalibrationsForActiveSensorInLastXDays :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
///     - isTypeLimitter : type limitter means sensor is Libre
/// - returns:
///     - the created bgreading
func createNewReading(rawData:Double, filteredData:Double, timeStamp:Date?, sensor:Sensor?, last3Readings:inout Array<BgReading>, lastCalibrationsForActiveSensorInLastXDays:inout Array<Calibration>, firstCalibration:Calibration?, lastCalibration:Calibration?, isTypeLimitter:Bool, nsManagedObjectContext:NSManagedObjectContext ) -> BgReading {
    
    var timeStampToUse:Date = Date()
    if let timeStamp = timeStamp {
        timeStampToUse = timeStamp
    }
    
    let bgReading:BgReading = BgReading(
        timeStamp:timeStampToUse,
        sensor:sensor,
        calibration:lastCalibration,
        rawData:rawData / 1000,
        filteredData:filteredData / 1000,
        nsManagedObjectContext:nsManagedObjectContext
    )
    
    calculateAgeAdjustedRawValue(for:bgReading, withSensor:sensor, isTypeLimitter: isTypeLimitter)
    
    if let lastCalibration = lastCalibration, let firstCalibration = firstCalibration {
        if (last3Readings.count > 0) {
            let latest:BgReading = last3Readings[0]
            if var latestReadingCalibration = latest.calibration {
                if (latest.calibrationFlag && ((latest.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble()) && ((latestReadingCalibration.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble())) {
                    rawValueOverride(for: &latestReadingCalibration, rawValue: weightedAverageRaw(timeA: latest.timeStamp, timeB: timeStampToUse, calibrationTime: latestReadingCalibration.timeStamp, rawA: latest.ageAdjustedRawValue, rawB: bgReading.ageAdjustedRawValue), lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibration, lastCalibration: lastCalibration, isTypeLimitter: isTypeLimitter)
                }
            }
            bgReading.calculatedValue = ((lastCalibration.slope * bgReading.ageAdjustedRawValue) + lastCalibration.intercept)
            bgReading.filteredCalculatedValue = ((lastCalibration.slope * ageAdjustedFiltered(bgReading: bgReading)) + lastCalibration.intercept)
        }
        updateCalculatedValue(for: bgReading)
    }
    
    performCalculations(for: bgReading, last3Readings: &last3Readings)
    
    return bgReading
}

/// taken over form xdripplus
///
/// - parameters:
///     - currentBgReading : reading for which slope is calculated
///     - lastBgReading : last reading result of call to BgReadings.getLatestBgReadings(1, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
/// - returns:
///     - calculated slope
private func calculateSlope(currentBgReading:BgReading, lastBgReading:BgReading) -> (Double, Bool) {
    if currentBgReading.timeStamp == lastBgReading.timeStamp
        ||
        currentBgReading.timeStamp.toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble() > Double(Constants.BGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
        return (0,true)
    }
    return ((lastBgReading.calculatedValue - currentBgReading.calculatedValue) / (lastBgReading.timeStamp.toMillisecondsAsDouble() - currentBgReading.timeStamp.toMillisecondsAsDouble()), false)
}

/// - parameters:
///     - withTimeStamp : timeStamp :)
///     - withLast1Reading : last reading
/// - returns:
///     - estimatedrawbg
public func getEstimatedRawBg(withTimeStamp timeStamp:Date, withLast1Reading last1Reading:BgReading) -> Double {
    let timeStampInMs = timeStamp.toMillisecondsAsDouble()
    return (last1Reading.ra * timeStampInMs * timeStampInMs) + (last1Reading.rb * timeStampInMs) + last1Reading.rc
}

/// - parameters:
///     - bgReading : reading that needs to be updated
///     - withSensor : the currently active sensor, optional
private func calculateAgeAdjustedRawValue(for bgReading:BgReading, withSensor sensor:Sensor?, isTypeLimitter:Bool) {
    if let sensor = sensor {
        let adjustfor:Double = Constants.BgReadingAlgorithms.ageAdjustmentTime - (bgReading.timeStamp.toMillisecondsAsDouble() - sensor.startDate.toMillisecondsAsDouble())
        if (adjustfor <= 0 || isTypeLimitter) {
            bgReading.ageAdjustedRawValue = bgReading.rawData
        } else {
            bgReading.ageAdjustedRawValue = ((Constants.BgReadingAlgorithms.ageAdjustmentFactor * (adjustfor / Constants.BgReadingAlgorithms.ageAdjustmentTime)) * bgReading.rawData) + bgReading.rawData
        }
    } else {
        bgReading.ageAdjustedRawValue = bgReading.rawData
    }
    //debuglogging("in calculateAgeAdjustedRawValue bgReading.ageAdjustedRawValue" + bgReading.ageAdjustedRawValue.description)
}

private func weightedAverageRaw(timeA:Date, timeB:Date, calibrationTime:Date, rawA:Double, rawB:Double) -> Double {
    let relativeSlope:Double = (rawB -  rawA)/(timeB.toMillisecondsAsDouble() - timeA.toMillisecondsAsDouble())
    let relativeIntercept:Double = rawA - (relativeSlope * timeA.toMillisecondsAsDouble())
    
    return ((relativeSlope * calibrationTime.toMillisecondsAsDouble()) + relativeIntercept)
}

/// taken from xdripplus
///
/// - parameters:
///     - bgReading : bgreading for which usedRaw will be calculated
/// - returns:
///     -   ageAdjustedFiltered
private func ageAdjustedFiltered(bgReading:BgReading) -> Double {
    let usedRaw = bgReading.ageAdjustedRawValue
    
    if(usedRaw == bgReading.rawData || bgReading.rawData == 0) {
        return bgReading.filteredData
    } else {
        // adjust the filtereddata the same factor as the age adjusted raw value
        return bgReading.filteredData * usedRaw / bgReading.rawData;
    }
}

/// calls findNewCurve, findNewRawCurve and findSlope for bgReading
/// - parameters:
///     - bgReading : reading that will be updated
///     - last3Readings : result of call to BgReadings.getLatestBgReadings(x, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
private func performCalculations(for bgReading:BgReading, last3Readings:inout Array<BgReading>)  {
    findNewCurve(for: bgReading, last3Readings: &last3Readings)
    findNewRawCurve(for: bgReading, last3Readings: &last3Readings)
    findSlope(for: bgReading, last2Readings: &last3Readings)
}

/// taken from xdripplus
///
/// updates bgreading
///
/// - parameters:
///     - bgReading : reading that will be updated
///     - last2Readings result of call to BgReadings.getLatestBgReadings(2, sensor) ignoreRawData and ignoreCalculatedValue false - inout parameter to improve performance
private func findSlope(for bgReading: BgReading, last2Readings:inout Array<BgReading>) {
    bgReading.hideSlope = true;
    if (last2Readings.count > 2) {
        let (slope, hide) = calculateSlope(currentBgReading:bgReading, lastBgReading:last2Readings[1]);
        bgReading.calculatedValueSlope = slope
        bgReading.hideSlope = hide
    } else if (last2Readings.count == 1) {
        bgReading.calculatedValueSlope = 0
    } else {
        bgReading.calculatedValueSlope = 0
    }
}

