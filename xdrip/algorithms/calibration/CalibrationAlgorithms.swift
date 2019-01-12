import Foundation
import CoreData
import os



    /// creates two calibrations, stored in the database, but context not saved. Also readings will be adpated, also not saved.
    ///
    /// - parameters:
    ///     - firstCalibrationBgValue: the first (ie the oldest) calibration value
    ///     - secondCalibrationBgValue: the second (ie the youngest) calibration value
    ///     - firstCalibrationTimeStamp: timestamp of the first calibration
    ///     - secondCalibrationTimeStamp: timestamp of the second calibration
    ///     - sensor: the current sensor
    ///     - lastBgReadingsWithCalculatedValue0AndForSensor : the readings that need to be adjusted after the calibration, first is the youngest, result of call to BgReadings.getLatestBgtReadings with ignoreRawData: false, ignoreCalculatedValue: true, minimum 2
    ///     - nsManagedObjectContext: the nsmanagedobject context in which calibration should be created
    /// - returns:
    ///     - two Calibrations, stored in the context but context not saved. The first calibration and second
func initialCalibration(firstCalibrationBgValue:Double, firstCalibrationTimeStamp:Date, secondCalibrationBgValue:Double, secondCalibrationTimeStamp:Date, sensor:Sensor, lastBgReadingsWithCalculatedValue0AndForSensor:inout Array<BgReading>, nsManagedObjectContext:NSManagedObjectContext, isTypeLimitter:Bool) -> (firstCalibration: Calibration, secondCalibration: Calibration){
        //let log:OSLog = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.calibration)

        let bgReading1 = lastBgReadingsWithCalculatedValue0AndForSensor[0]
        let bgReading2 = lastBgReadingsWithCalculatedValue0AndForSensor[1]
        bgReading1.calculatedValue = firstCalibrationBgValue;
        bgReading1.calibrationFlag = true;
        bgReading2.calculatedValue = secondCalibrationBgValue;
        bgReading2.calibrationFlag = true;
        
        debuglogging("bgReading 1 = " + bgReading1.log("") + "\nbgReading2 = " + bgReading2.log(""))
        
        var last2Readings = Array(lastBgReadingsWithCalculatedValue0AndForSensor.prefix(2))

        debuglogging("bgReading 0 = has calculatedvalue " + last2Readings[0].calculatedValue.description)
        debuglogging("bgReading 1 = has calculatedvalue " + last2Readings[1].calculatedValue.description)

        findNewCurve(for: bgReading1, last3Readings: &last2Readings)
        findNewRawCurve(for: bgReading1, last3Readings: &last2Readings)
        findNewCurve(for: bgReading2, last3Readings: &last2Readings)
        findNewRawCurve(for: bgReading2, last3Readings: &last2Readings)
        
        debuglogging("after find new curves, bgReading 1 = " + bgReading1.log("") + "bgReading2 = " + bgReading2.log(""));
        
        var calibration1 = Calibration(timeStamp: firstCalibrationTimeStamp, sensor: sensor, bg: firstCalibrationBgValue, rawValue: bgReading1.rawData, adjustedRawValue: bgReading1.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * firstCalibrationBgValue * firstCalibrationBgValue) + (0.6657 * firstCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading1.timeStamp, slope: 1, intercept: firstCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading1.ageAdjustedRawValue, slopeConfidence: 0.5, nsManagedObjectContext: nsManagedObjectContext)
        var tempCalibrationArray:Array<Calibration> = []
        
        debuglogging("calibration1 before calculate wls " + calibration1.log(""))

        calculateWLS(for: &calibration1, last4CalibrationsForActiveSensor: &tempCalibrationArray, firstCalibration: calibration1, lastCalibration: calibration1, isTypeLimitter: isTypeLimitter)
        debuglogging("calibration1 after calculate wls " + calibration1.log(""))

        var calibration2 = Calibration(timeStamp: secondCalibrationTimeStamp, sensor: sensor, bg: secondCalibrationBgValue, rawValue: bgReading2.rawData, adjustedRawValue: bgReading2.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * secondCalibrationBgValue * secondCalibrationBgValue) + (0.6657 * secondCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading2.timeStamp, slope: 1, intercept: secondCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading2.ageAdjustedRawValue, slopeConfidence: 0.5, nsManagedObjectContext: nsManagedObjectContext)
        tempCalibrationArray = [calibration1]
        debuglogging("calibration2 before calculate wls " + calibration2.log(""))

        calculateWLS(for: &calibration2, last4CalibrationsForActiveSensor: &tempCalibrationArray, firstCalibration: calibration1, lastCalibration: calibration2, isTypeLimitter: isTypeLimitter)
        
        debuglogging("calibration2 after calculate wls " + calibration2.log(""))

        //assign calibration objects to two first readings
        bgReading1.calibration = calibration1
        bgReading2.calibration = calibration2
        
        //needed in call to adjustRecentBgReadings
        tempCalibrationArray = [calibration1, calibration2]
        //reset calculatedValue in bgReading1 and bgReading2, they will be getting a real calculated value in adjustRecentBgReadings
        bgReading1.calculatedValue = 0.0
        bgReading2.calculatedValue = 0.0
        adjustRecentBgReadings(readingsToBeAdjusted: &lastBgReadingsWithCalculatedValue0AndForSensor, calibrations: &tempCalibrationArray)
        
        return (calibration1, calibration2)
    }
   
    /// adjust recent readings after a calibration, only the latest that have calculatedValue = 0, will be adjusted, as soon as a reading is found with calculatedValue != 0, it stops processing
    /// - parameters:
    ///     - readingsToBeAdjusted: must be the latest readings
    ///     - calibrations: latest calibrations, timestamp large to small (ie young to old). There should be minimum 2 calibrations, if less then the function
    ///     will not do anything.
    ///     Only the three first calibrations will be used.
    private func adjustRecentBgReadings(readingsToBeAdjusted:inout Array<BgReading>, calibrations:inout Array<Calibration>) {
        
        if (calibrations.count > 2) {
            let denom = Double(readingsToBeAdjusted.count)
            let latestCalibration = calibrations[0]
            var i = 0.0
            loop: for index in 0..<readingsToBeAdjusted.count {
                if readingsToBeAdjusted[index].calculatedValue != 0.0 {
                    //no further processing needed, all next readings should have a value != 0
                    break loop
                } else {
                    let oldYValue = readingsToBeAdjusted[index].calculatedValue
                    let newYvalue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) + latestCalibration.intercept
                    readingsToBeAdjusted[index].calculatedValue = ((newYvalue * (denom - i)) + (oldYValue * ( i ))) / denom
                    i += 1
                }
            }
        } else if (calibrations.count == 2) {
            debuglogging("in adjustRecentBgReadings, reading 0 " + calibrations[0].timeStamp.description);
            debuglogging("in adjustRecentBgReadings, reading 1 " + calibrations[1].timeStamp.description);

            let latestCalibration = calibrations[0]
            loop: for index in 0..<readingsToBeAdjusted.count {
                debuglogging("in adjustRecentBgReadings, bgreading processed = " + readingsToBeAdjusted[index].timeStamp.description)

                if readingsToBeAdjusted[index].calculatedValue != 0.0 {
                    //no further processing needed, all next readings should have a value != 0
                    break loop
                } else {
                    readingsToBeAdjusted[index].calculatedValue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) +  latestCalibration.intercept
                    debuglogging("bgReading.ageAdjustedRawValue = " + readingsToBeAdjusted[index].ageAdjustedRawValue.description + ", latestCalibration.intercept = " + latestCalibration.intercept.description)
                    debuglogging("newYvalue = " + readingsToBeAdjusted[index].calculatedValue.description);

                    updateCalculatedValue(for: readingsToBeAdjusted[index])
                }
            }
        }
        
        findNewRawCurve(for: readingsToBeAdjusted[0], last3Readings: &readingsToBeAdjusted)
        findNewCurve(for: readingsToBeAdjusted[0], last3Readings: &readingsToBeAdjusted)
    }

/// forCalibration will get changed
/// - parameters:
///     - calibration : calibration for which calculation is done
///     - last4CalibrationsForActiveSensor :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
///     - isTypeLimitter : type limitter means sensor is Libre
func rawValueOverride(for calibration:inout Calibration, rawValue:Double, last4CalibrationsForActiveSensor:inout Array<Calibration>, firstCalibration:Calibration, lastCalibration:Calibration, isTypeLimitter:Bool) {
    //TODO: - implement value override, there's no update of bgreading here ?
    calibration.estimateRawAtTimeOfCalibration = rawValue
    calculateWLS(for: &calibration, last4CalibrationsForActiveSensor: &last4CalibrationsForActiveSensor, firstCalibration: firstCalibration, lastCalibration: lastCalibration, isTypeLimitter: isTypeLimitter)
}

    /// from xdripplus
    /// forCalibration will get changed
    /// - parameters:
    ///     - calibration : calibration for which calculation is done
    ///     - last4CalibrationsForActiveSensor :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    ///     - isTypeLimitter : type limitter means sensor is Libre
    private func calculateWLS(for calibration:inout Calibration, last4CalibrationsForActiveSensor:inout Array<Calibration>, firstCalibration:Calibration, lastCalibration:Calibration, isTypeLimitter:Bool) {
        
        let sParams:SlopeParameters = isTypeLimitter ? Constants.CalibrationAlgorithms.liParameters:Constants.CalibrationAlgorithms.dexParameters
        
        var l:Double = 0
        var m:Double = 0
        var n:Double = 0
        var p:Double = 0
        var q:Double = 0
        var w:Double
        
        check(ifThisCalibration: calibration, isInThisList: &last4CalibrationsForActiveSensor)
        
        if (last4CalibrationsForActiveSensor.count <= 1) {
            calibration.slope = 1
            calibration.intercept = calibration.bg - (calibration.rawValue * calibration.slope)
        } else {
            loop2 : for calibrationItem in last4CalibrationsForActiveSensor {
                w = calculateWeight(for: calibrationItem, firstCalibration: firstCalibration, lastCalibration: lastCalibration)
                l += (w)
                m += (w * calibrationItem.estimateRawAtTimeOfCalibration)
                n += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.estimateRawAtTimeOfCalibration)
                p += (w * calibrationItem.bg)
                q += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.bg)
            }
            
            w = ((calculateWeight(for: calibration, firstCalibration: firstCalibration, lastCalibration: lastCalibration)) * (((Double)(last4CalibrationsForActiveSensor.count)) * 0.14))
            l += (w)
            m += (w * calibration.estimateRawAtTimeOfCalibration)
            n += (w * calibration.estimateRawAtTimeOfCalibration * calibration.estimateRawAtTimeOfCalibration)
            p += (w * calibration.bg)
            q += (w * calibration.estimateRawAtTimeOfCalibration * calibration.bg)
            debuglogging("in calculatewls, loop2 w = " + w.description)
            debuglogging("in calculatewls, loop2 l = " + l.description)
            debuglogging("in calculatewls, loop2 m = " + m.description)
            debuglogging("in calculatewls, loop2 n = " + n.description)
            debuglogging("in calculatewls, loop2 p = " + p.description)
            debuglogging("in calculatewls, loop2 q = " + q.description)
            let d:Double = (l * n) - (m * m)
            debuglogging("in calculatewls, loop2 d = " + d.description)
            calibration.intercept = ((n * p) - (m * q)) / d
            debuglogging("in calculatewls, 1, intercept = " + calibration.intercept.description)
            calibration.slope = ((l * q) - (m * p)) / d
            
            var last3CalibrationsForActiveSensor = Array(last4CalibrationsForActiveSensor.prefix(3))
            
            check(ifThisCalibration: calibration, isInThisList: &last3CalibrationsForActiveSensor)
            
            last3CalibrationsForActiveSensor = Array(last3CalibrationsForActiveSensor.prefix(3))
            
            if ((last4CalibrationsForActiveSensor.count == 2 && calibration.slope < sParams.LOW_SLOPE_1) || (calibration.slope < sParams.LOW_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus:0, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor, isTypeLimitter:isTypeLimitter)
                if(last4CalibrationsForActiveSensor.count > 2) { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
                debuglogging("in calculatewls, 2, intercept = " + calibration.intercept.description)
            }
            if ((last4CalibrationsForActiveSensor.count == 2 && calibration.slope > sParams.HIGH_SLOPE_1) || (calibration.slope > sParams.HIGH_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus:1, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor, isTypeLimitter:isTypeLimitter)
                if last4CalibrationsForActiveSensor.count > 2 { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
                debuglogging("in calculatewls, 3, intercept = " + calibration.intercept.description)
            }
        }
    }

    /// taken from xdripplus
    ///
    /// - parameters:
    ///     - calibration : the calibration for which calculateweight will be done
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor for activeSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor for activeSensor
    /// - returns:
    ///     - calculated weight
    private func calculateWeight(for calibration:Calibration, firstCalibration:Calibration, lastCalibration:Calibration) -> Double {
        
        let firstTimeStarted = firstCalibration.sensorAgeAtTimeOfEstimation
        let lastTimeStarted = lastCalibration.sensorAgeAtTimeOfEstimation
        //we know that
        var timePercentage = min(((calibration.sensorAgeAtTimeOfEstimation - firstTimeStarted) / (lastTimeStarted - firstTimeStarted)) / (0.85), 1)
        timePercentage = (timePercentage + 0.01)
        
        return max((((((calibration.slopeConfidence + calibration.sensorConfidence) * (timePercentage))) / 2) * 100), 1)
    }

    /// check if calibration is in list, and if not added, correctly sorted
    /// - parameters:
    ///     - calibration : calibration to check if it's in the list
    ///     - list : list to check
    private func check(ifThisCalibration calibration:Calibration, isInThisList list:inout Array<Calibration>) {
        loop1 : for (index, calibrationItem) in list.enumerated() {
            if calibration.timeStamp.toMillisecondsAsDouble() > calibrationItem.timeStamp.toMillisecondsAsDouble() {
                list.insert(calibration, at: index)
            } else if calibrationItem.id == calibration.id {
                break loop1
            } else if index == (list.count - 1) {
                list.append(calibration)
            }
        }
    }
    
    /// calculate slopeOOBHandler
    /// - parameters:
    ///     - status : status
    ///     - calibrations : last 3 calibrations for the active sensor
    private func slopeOOBHandler(withStatus status:Int, withLast3CalibrationsForActiveSensor calibrations:Array<Calibration>, isTypeLimitter:Bool) -> Double {
        
        let sParams:SlopeParameters = isTypeLimitter ? Constants.CalibrationAlgorithms.liParameters:Constants.CalibrationAlgorithms.dexParameters
        
        let thisCalibration:Calibration = calibrations[0]
        
        if(status == 0) {
            if calibrations.count == 3 {
                if ((abs(thisCalibration.bg - thisCalibration.estimateBgAtTimeOfCalibration) < 30) && (calibrations[1].possibleBad)) {
                    return calibrations[1] .slope
                } else {
                    return max(((-0.048) * (thisCalibration.sensorAgeAtTimeOfEstimation / (60000 * 60 * 24))) + 1.1, sParams.DEFAULT_LOW_SLOPE_LOW)
                }
            } else if calibrations.count == 2 {
                return max(((-0.048) * (thisCalibration.sensorAgeAtTimeOfEstimation / (60000 * 60 * 24))) + 1.1, sParams.DEFAULT_LOW_SLOPE_HIGH)
            }
            return Double(sParams.DEFAULT_SLOPE)
        } else {
            if calibrations.count == 3 {
                if ((abs(thisCalibration.bg - thisCalibration.estimateBgAtTimeOfCalibration) < 30) && (calibrations[1].possibleBad)) {
                    return calibrations[1].slope
                } else {
                    return sParams.DEFAULT_HIGH_SLOPE_HIGH
                }
            } else if calibrations.count == 2 {
                return sParams.DEFAUL_HIGH_SLOPE_LOW
            }
        }
        return Double(sParams.DEFAULT_SLOPE)
    }
    

