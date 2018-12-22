import Foundation
import CoreData




    /// - parameters:
    ///     - firstCalibrationBgValue : the first (ie the oldest) calibration value
    ///     - secondCalibrationBgValue : the second (ie the youngest) calibration value
    ///     - lastReadings : should be minimum 2 bgReadings, each reading will be adjusted at the end of calibration (in Spike it's 5), index 0 is the youngest, first is the youngest
    ///     - lastNoSensor : result of call to BgReadings.getLastReadingNoSensor
    /// - returns:
    ///     - two Calibrations
    func initialCalibration(with firstCalibrationBgValue:Double, with firstCalibrationTimeStamp:Date, with secondCalibrationBgValue:Double, with secondCalibrationTimeStamp:Date, with sensor:Sensor, with lastReadings:inout Array<BgReading>, with lastNoSensor:BgReading?, nsManagedObjectContext:NSManagedObjectContext, isTypeLimitter:Bool) -> (Calibration, Calibration){
        
        var bgReading1 = lastReadings[0]
        var bgReading2 = lastReadings[1]
        bgReading1.calculatedValue = firstCalibrationBgValue;
        bgReading1.calibrationFlag = true;
        bgReading2.calculatedValue = secondCalibrationBgValue;
        bgReading2.calibrationFlag = true;
        
        var lastMaximum3Readings = Array(lastReadings.prefix(3))
        findNewCurve(for: &bgReading1, with: &lastMaximum3Readings)
        findNewRawCurve(for: &bgReading1, with: &lastMaximum3Readings, with: lastNoSensor)
        findNewCurve(for: &bgReading2, with: &lastMaximum3Readings)
        findNewRawCurve(for: &bgReading2, with: &lastMaximum3Readings, with: lastNoSensor)
        
        var calibration1 = Calibration(timeStamp: firstCalibrationTimeStamp, sensor: sensor, bg: firstCalibrationBgValue, rawValue: bgReading1.rawData, adjustedRawValue: bgReading1.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * firstCalibrationBgValue * firstCalibrationBgValue) + (0.6657 * firstCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading1.timeStamp, slope: 1, intercept: firstCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading1.ageAdjustedRawValue, slopeConfidence: 0.5, nsManagedObjectContext: nsManagedObjectContext)
        var tempCalibrationArray:Array<Calibration> = []
        calculateWLS(for: &calibration1, with: &tempCalibrationArray, with: calibration1, with: calibration1, isTypeLimitter: isTypeLimitter)
        
        var calibration2 = Calibration(timeStamp: secondCalibrationTimeStamp, sensor: sensor, bg: secondCalibrationBgValue, rawValue: bgReading2.rawData, adjustedRawValue: bgReading2.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * secondCalibrationBgValue * secondCalibrationBgValue) + (0.6657 * secondCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading2.timeStamp, slope: 1, intercept: secondCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading2.ageAdjustedRawValue, slopeConfidence: 0.5, nsManagedObjectContext: nsManagedObjectContext)
        tempCalibrationArray = [calibration1]
        calculateWLS(for: &calibration2, with: &tempCalibrationArray, with: calibration1, with: calibration2, isTypeLimitter: isTypeLimitter)
        
        bgReading1.calibration = calibration1
        bgReading2.calibration = calibration2
        
        tempCalibrationArray = [calibration1, calibration2]
        adjustRecentBgReadings(with: &lastReadings, with: &tempCalibrationArray, with: &lastMaximum3Readings, with: lastNoSensor)
        
        return (calibration1, calibration2)
    }
   
    /// adjust recent readings after a calibration
    /// - parameters:
    ///     - readingsToBeAdjusted
    ///     - calibrations : latest calibrations, timestamp large to small. There should be minimum 2 calibrations, if less then the function
    ///     will not do anything.
    ///     Only the three first calibrations will be used.
    ///     - withLast3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - it' ok if there's less than 3 readings - inout parameter to improve performance
    func adjustRecentBgReadings(with readingsToBeAdjusted:inout Array<BgReading>, with calibrations:inout Array<Calibration>, with last3Readings:inout Array<BgReading>, with lastNoSensor:BgReading?) {
        
        if (calibrations.count == 3) {
            let denom = Double(readingsToBeAdjusted.count)
            let latestCalibration = calibrations[0]
            var i = 0.0
            for index in 0..<readingsToBeAdjusted.count {
                let oldYValue = readingsToBeAdjusted[index].calculatedValue
                let newYvalue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) + latestCalibration.intercept
                readingsToBeAdjusted[index].calculatedValue = ((newYvalue * (denom - i)) + (oldYValue * ( i ))) / denom
                i += 1
            }
        } else if (calibrations.count == 2) {
            let latestCalibration = calibrations[0]
            for index in 0..<readingsToBeAdjusted.count {
                let newYvalue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) + latestCalibration.intercept
                readingsToBeAdjusted[index].calculatedValue = newYvalue
                updateCalculatedValue(for: &readingsToBeAdjusted[index])
            }
        }
        
        findNewRawCurve(for: &readingsToBeAdjusted[0], with: &last3Readings, with: lastNoSensor)
        findNewCurve(for: &readingsToBeAdjusted[0], with: &last3Readings)
    }
    
    /// from xdripplus
    ///
    /// forCalibration will get changed
    ///
    /// - parameters:
    ///     - forCalibration : calibration for which calculation is done
    ///     - withLast4CalibrationsForActiveSensor :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
    ///     - withFirstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - withLastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    ///     - isTypeLimitter : type limitter means sensor is Libre
    func rawValueOverride(for calibration:inout Calibration, with rawValue:Double, with last4CalibrationsForActiveSensor:inout Array<Calibration>, with firstCalibration:Calibration, with lastCalibration:Calibration, isTypeLimitter:Bool) {
        
        calibration.estimateRawAtTimeOfCalibration = rawValue
        calculateWLS(for: &calibration, with: &last4CalibrationsForActiveSensor, with: firstCalibration, with: lastCalibration, isTypeLimitter: isTypeLimitter)
    }
    
    /// from xdripplus
    ///
    /// forCalibration will get changed
    ///
    /// - parameters:
    ///     - forCalibration : calibration for which calculation is done
    ///     - last4CalibrationsForActiveSensor :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    ///     - isTypeLimitter : type limitter means sensor is Libre
    private func calculateWLS(for calibration:inout Calibration, with last4CalibrationsForActiveSensor:inout Array<Calibration>, with firstCalibration:Calibration, with lastCalibration:Calibration, isTypeLimitter:Bool) {
        
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
                w = calculateWeight(forCalibration: calibrationItem, withFirstCalibration: firstCalibration, withLastCalibration: lastCalibration)
                l += (w)
                m += (w * calibrationItem.estimateRawAtTimeOfCalibration)
                n += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.estimateRawAtTimeOfCalibration)
                p += (w * calibrationItem.bg)
                q += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.bg)
            }
            
            w = ((calculateWeight(forCalibration: calibration, withFirstCalibration: firstCalibration, withLastCalibration: lastCalibration)) * (((Double)(last4CalibrationsForActiveSensor.count)) * 0.14))
            l += (w)
            m += (w * calibration.estimateRawAtTimeOfCalibration)
            n += (w * calibration.estimateRawAtTimeOfCalibration * calibration.estimateRawAtTimeOfCalibration)
            p += (w * calibration.bg)
            q += (w * calibration.estimateRawAtTimeOfCalibration * calibration.bg)
            let d:Double = (l * n) - (m * m)
            calibration.intercept = ((n * p) - (m * q)) / d
            calibration.slope = ((l * q) - (m * p)) / d
            
            var last3CalibrationsForActiveSensor = Array(last4CalibrationsForActiveSensor.prefix(3))
            
            check(ifThisCalibration: calibration, isInThisList: &last3CalibrationsForActiveSensor)
            
            last3CalibrationsForActiveSensor = Array(last3CalibrationsForActiveSensor.prefix(3))
            
            if ((last4CalibrationsForActiveSensor.count == 2 && calibration.slope < sParams.LOW_SLOPE_1) || (calibration.slope < sParams.LOW_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus:0, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor, isTypeLimitter:isTypeLimitter)
                if(last4CalibrationsForActiveSensor.count > 2) { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
            }
            if ((last4CalibrationsForActiveSensor.count == 2 && calibration.slope > sParams.HIGH_SLOPE_1) || (calibration.slope > sParams.HIGH_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus:1, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor, isTypeLimitter:isTypeLimitter)
                if last4CalibrationsForActiveSensor.count > 2 { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
            }
        }
    }

    /// taken from xdripplus
    ///
    /// - parameters:
    ///     - forCalibration : the calibration for which calculateweight will be done
    ///     - withFirstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor for activeSensor
    ///     - withLastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor for activeSensor
    /// - returns:
    ///     - calculated weight
    private func calculateWeight(forCalibration calibration:Calibration, withFirstCalibration firstCalibration:Calibration, withLastCalibration lastCalibration:Calibration) -> Double {
        
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
    

