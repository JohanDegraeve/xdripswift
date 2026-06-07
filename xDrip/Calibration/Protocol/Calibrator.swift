import Foundation
import CoreData

protocol Calibrator {
    
    ///slope parameters to be defined per type of sensor Dexcom/Libre, in class that conforms to Calibrator protocol
    var sParams: SlopeParameters{get}
    
    /// for instance Dexcom values come in 100.000's, (eg rawvalue 140.000), in case of Dexcom divider is 1000, resulting in 140, then this value will be used in calibration algorithm.
    var rawValueDivider: Double {get}

    /// false for Libre, true for Dexcom
    var ageAdjustMentNeeded: Bool{get}
    
    /// creates two calibrations, stored in the database, but context not saved. Also readings will be adpated, also not saved.
    /// - parameters:
    ///     - firstCalibrationBgValue: the first (ie the oldest) calibration value
    ///     - secondCalibrationBgValue: the second (ie the youngest) calibration value (if you don't like to ask the user two calibrations with a delay of 5 minutes each, then use the same bg value for second as first)
    ///     - firstCalibrationTimeStamp: timestamp of the first calibration (ie should be the one of 5 minutes ago, except if you use only one calibration)
    ///     - sensor: the current sensor
    ///     - lastBgReadingsWithCalculatedValue0AndForSensor : the readings that need to be adjusted after the calibration, first is the youngest, result of call to BgReadings.getLatestBgtReadings with ignoreRawData: false, ignoreCalculatedValue: true, minimum 2
    ///     - nsManagedObjectContext: the nsmanagedobject context in which calibration should be created
    /// - returns:
    ///     - two Calibrations, stored in the context but context not saved. The first calibration and second. Can be nil values, if anything goes wrong in the algorithm
    func initialCalibration(firstCalibrationBgValue: Double, firstCalibrationTimeStamp: Date, secondCalibrationBgValue: Double, sensor: Sensor, lastBgReadingsWithCalculatedValue0AndForSensor:inout Array<BgReading>, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) -> (firstCalibration: Calibration?, secondCalibration: Calibration?)

    /// create a new BgReading
    /// - parameters:
    ///     - rawData : the rawdata value
    ///     - timeStamp : optional, if nil then actualy date and time is used
    ///     - sensor : actual sensor, optional
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance and also because it's an NSManagedObject
    ///     - nsManagedObjectContext : the nsManagedObjectContext
    ///     - lastCalibrationsForActiveSensorInLastXDays :  result of call to getLatestCalibrations(howManyDays:4, forSensor: active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    /// - returns:
    ///     - the created bgreading
    func createNewBgReading(rawData: Double, timeStamp: Date?, sensor: Sensor?, last3Readings: inout Array<BgReading>, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration?, lastCalibration: Calibration?, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) -> BgReading
    
    /// creates a calibration, stored in the database, but context not saved. Also readings will be adpated, also not saved.
    /// - parameters:
    ///     - bgValue: calibration value
    ///     - lastBgReading: latest bgreading - optional, to support NoCalibrator which does not always have a BgReading available
    ///     - lastCalibrationsForActiveSensorInLastXDays: ... the latest calibrations in x days, in Spike/xdripplus it's 4. Order by timestamp, large to small, ie the first is createNewCalibration(bgValue:Do youngest
    ///     - firstCalibration: the very first calibration for the sensor
    func createNewCalibration(bgValue: Double, lastBgReading: BgReading?, sensor: Sensor, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration,deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) -> Calibration?
    
    /// gives a description
    func description() -> String
}

extension Calibrator {
    /// creates two calibrations, stored in the database, but context not saved. Also readings will be adpated, also not saved.
    ///
    /// - parameters:
    ///     - firstCalibrationBgValue: the first (ie the oldest) calibration value, usually one of 5 minutes ago
    ///     - secondCalibrationBgValue: the second (ie the youngest) calibration value, should be a value taken 5 minutes later than the first, if that's too much trouble, take the same value as the firstCalibrationBgValue
    ///     - firstCalibrationTimeStamp: timestamp of the first calibration
    ///     - sensor: the current sensor
    ///     - lastBgReadingsWithCalculatedValue0AndForSensor : the readings that need to be adjusted after the calibration, first is the youngest, result of call to BgReadings.getLatestBgtReadings with ignoreRawData: false, ignoreCalculatedValue: true, minimum 2
    ///     - deviceName, ie bluetoothdevice name when calibration is created
    ///     - nsManagedObjectContext: the nsmanagedobject context in which calibration should be created
    /// - returns:
    ///     - two Calibrations, stored in the context but context not saved. The first calibration and second
    func initialCalibration(firstCalibrationBgValue: Double, firstCalibrationTimeStamp: Date, secondCalibrationBgValue: Double, sensor: Sensor, lastBgReadingsWithCalculatedValue0AndForSensor: inout Array<BgReading>, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) -> (firstCalibration: Calibration?, secondCalibration: Calibration?){
        
        guard lastBgReadingsWithCalculatedValue0AndForSensor.count > 1 else {
            return (nil,nil)
        }
        
        let bgReading1 = lastBgReadingsWithCalculatedValue0AndForSensor[0]
        let bgReading2 = lastBgReadingsWithCalculatedValue0AndForSensor[1]
        bgReading1.calculatedValue = firstCalibrationBgValue
        bgReading1.calibrationFlag = true
        bgReading2.calculatedValue = secondCalibrationBgValue
        bgReading2.calibrationFlag = true
        
        let secondCalibrationTimeStamp = Date(timeInterval: (5*60), since: firstCalibrationTimeStamp)
        
        //debuglogging("bgReading 1 = " + bgReading1.log("") + "\nbgReading2 = " + bgReading2.log(""))
        
        var last2Readings = Array(lastBgReadingsWithCalculatedValue0AndForSensor.prefix(2))
        
        findNewCurve(for: bgReading1, last3Readings: &last2Readings)
        findNewRawCurve(for: bgReading1, last3Readings: &last2Readings)
        findNewCurve(for: bgReading2, last3Readings: &last2Readings)
        findNewRawCurve(for: bgReading2, last3Readings: &last2Readings)
        
        //debuglogging("after find new curves, bgReading 1 = " + bgReading1.log("") + "bgReading2 = " + bgReading2.log(""))
        
        let calibration1 = Calibration(timeStamp: firstCalibrationTimeStamp, sensor: sensor, bg: firstCalibrationBgValue, rawValue: bgReading1.rawData, adjustedRawValue: bgReading1.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * firstCalibrationBgValue * firstCalibrationBgValue) + (0.6657 * firstCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading1.timeStamp, slope: 1, intercept: firstCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading1.ageAdjustedRawValue, slopeConfidence: 0.5, deviceName:deviceName, nsManagedObjectContext: nsManagedObjectContext)
        var tempCalibrationArray:Array<Calibration> = []
        
        calculateWLS(for: calibration1, lastCalibrationsForActiveSensorInLastXDays: &tempCalibrationArray, firstCalibration: calibration1, lastCalibration: calibration1)
        
        let calibration2 = Calibration(timeStamp: secondCalibrationTimeStamp, sensor: sensor, bg: secondCalibrationBgValue, rawValue: bgReading2.rawData, adjustedRawValue: bgReading2.ageAdjustedRawValue, sensorConfidence: ((-0.0018 * secondCalibrationBgValue * secondCalibrationBgValue) + (0.6657 * secondCalibrationBgValue) + 36.7505) / 100, rawTimeStamp: bgReading2.timeStamp, slope: 1, intercept: secondCalibrationBgValue, distanceFromEstimate: 0, estimateRawAtTimeOfCalibration: bgReading2.ageAdjustedRawValue, slopeConfidence: 0.5, deviceName:deviceName, nsManagedObjectContext: nsManagedObjectContext)
        tempCalibrationArray = [calibration1]
        
        calculateWLS(for: calibration2, lastCalibrationsForActiveSensorInLastXDays: &tempCalibrationArray, firstCalibration: calibration1, lastCalibration: calibration2)
        
        //assign calibration objects to two first readings
        bgReading1.calibration = calibration1
        bgReading2.calibration = calibration2
        
        //needed in call to adjustRecentBgReadings
        tempCalibrationArray = [calibration1, calibration2]
        //reset calculatedValue in bgReading1 and bgReading2, they will be getting a real calculated value in adjustRecentBgReadings
        bgReading1.calculatedValue = 0.0
        bgReading2.calculatedValue = 0.0
        adjustRecentBgReadings(readingsToBeAdjusted: &lastBgReadingsWithCalculatedValue0AndForSensor, calibrations: &tempCalibrationArray, overwriteCalculatedValue: false)
        
        return (calibration1, calibration2)
    }
    
    /// create a new BgReading
    ///
    /// - parameters:
    ///     - rawData : the rawdata value
    ///     - timeStamp : optional, if nil then actualy date and time is used
    ///     - sensor : actual sensor, optional
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance and also because it's an NSManagedObject
    ///     - nsManagedObjectContext : the nsManagedObjectContext
    ///     - lastCalibrationsForActiveSensorInLastXDays :  result of call to getLatestCalibrations(howManyDays:4, forSensor: active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    /// - returns:
    ///     - the created bgreading
    func createNewBgReading(rawData: Double, timeStamp: Date?, sensor: Sensor?, last3Readings: inout Array<BgReading>, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration?, lastCalibration: Calibration?, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext ) -> BgReading {
        
        var timeStampToUse: Date = Date()
        if let timeStamp = timeStamp {
            timeStampToUse = timeStamp
        }
        
        let bgReading: BgReading = BgReading(
            timeStamp: timeStampToUse,
            sensor: sensor,
            calibration: lastCalibration,
            rawData: rawData / rawValueDivider,
            deviceName: deviceName,
            nsManagedObjectContext: nsManagedObjectContext
        )
        
        calculateAgeAdjustedRawValue(for: bgReading, withSensor: sensor)
        
        if let lastCalibration = lastCalibration, let firstCalibration = firstCalibration {
            if last3Readings.count > 0 {
                let latest:BgReading = last3Readings[0]
                if var latestReadingCalibration = latest.calibration {
                    if (latest.calibrationFlag && ((latest.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble()) && ((latestReadingCalibration.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble())) {
                        rawValueOverride(for: &latestReadingCalibration, rawValue: weightedAverageRaw(timeA: latest.timeStamp, timeB: timeStampToUse, calibrationTime: latestReadingCalibration.timeStamp, rawA: latest.ageAdjustedRawValue, rawB: bgReading.ageAdjustedRawValue), lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibration, lastCalibration: lastCalibration)
                    }
                }
                bgReading.calculatedValue = ((lastCalibration.slope * bgReading.ageAdjustedRawValue) + lastCalibration.intercept)

            }
            updateCalculatedValue(for: bgReading)
        }
        
        performCalculations(for: bgReading, last3Readings: &last3Readings)
        
        return bgReading
    }
    
    
    func createNewCalibration(bgValue: Double, lastBgReading: BgReading?, sensor: Sensor, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) -> Calibration? {
        
        guard let lastBgReading = lastBgReading else {
            return nil
        }
        
        let estimatedRawBg = getEstimatedRawBg(withTimeStamp: Date(), withLast1Reading: lastBgReading)
        
        
        let calibration = Calibration(timeStamp: Date(), sensor: sensor, bg: bgValue, rawValue: lastBgReading.rawData, adjustedRawValue: lastBgReading.ageAdjustedRawValue, sensorConfidence: max(((-0.0018 * bgValue * bgValue) + (0.6657 * bgValue) + 36.7505) / 100, 0), rawTimeStamp: lastBgReading.timeStamp, slope: 0.0, intercept: 0.0, distanceFromEstimate: abs(bgValue - lastBgReading.calculatedValue), estimateRawAtTimeOfCalibration: abs(estimatedRawBg - lastBgReading.ageAdjustedRawValue) > 20 ? lastBgReading.ageAdjustedRawValue : estimatedRawBg, slopeConfidence: min(max(((4 - abs((lastBgReading.calculatedValueSlope) * 60000))/4), 0), 1), deviceName:deviceName, nsManagedObjectContext: nsManagedObjectContext)
        
        calculateWLS(for: calibration, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibration, lastCalibration: lastCalibrationsForActiveSensorInLastXDays[0])
        
        lastBgReading.calibration = calibration
        lastBgReading.calibrationFlag = true
        
        var temp = [lastBgReading]
        adjustRecentBgReadings(readingsToBeAdjusted: &temp, calibrations: &lastCalibrationsForActiveSensorInLastXDays, overwriteCalculatedValue: true)
        
        return calibration
    }
    
    /// adjust recent readings after a calibration, only the latest that have calculatedValue = 0, will be adjusted, as soon as a reading is found with calculatedValue != 0, it stops processing
    /// - parameters:
    ///     - readingsToBeAdjusted: must be the latest readings
    ///     - calibrations: latest calibrations, timestamp large to small (ie young to old). There should be minimum 2 calibrations, if less then the function will not do anything.
    ///     - overwriteCalculatedValue: if true, then if calculatedValue of readingsToBeAdjusted will be overriden, if false, then only readingsToBeAdjusted with calculatedValue = 0.0 will be overwritten
    private func adjustRecentBgReadings(readingsToBeAdjusted: inout Array<BgReading>, calibrations: inout Array<Calibration>, overwriteCalculatedValue: Bool) {
        
        guard calibrations.count > 0 else {
           return
        }
        
        let latestCalibration = calibrations[0]
        
        if calibrations.count > 2 {
            let denom = Double(readingsToBeAdjusted.count)
            var i = 0.0
            loop: for index in 0..<readingsToBeAdjusted.count {
                if readingsToBeAdjusted[index].calculatedValue != 0.0 && !overwriteCalculatedValue {
                    //no further processing needed, all next readings should have a value != 0
                    break loop
                } else {
                    let oldYValue = readingsToBeAdjusted[index].calculatedValue
                    let newYvalue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) + latestCalibration.intercept
                    readingsToBeAdjusted[index].calculatedValue = ((newYvalue * (denom - i)) + (oldYValue * ( i ))) / denom
                    i += 1
                }
            }
        } else if calibrations.count == 2 {
            loop: for index in 0..<readingsToBeAdjusted.count {
                if readingsToBeAdjusted[index].calculatedValue != 0.0 && !overwriteCalculatedValue {
                    //no further processing needed, all next readings should have a value != 0
                    break loop
                } else {
                    readingsToBeAdjusted[index].calculatedValue = (readingsToBeAdjusted[index].ageAdjustedRawValue * latestCalibration.slope) +  latestCalibration.intercept
                    
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
    ///     - lastCalibrationsForActiveSensorInLastXDays :  result of call to getLatestCalibrations(howManyDays:4, forSensor: active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    private func rawValueOverride(for calibration: inout Calibration, rawValue: Double, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration, lastCalibration: Calibration) {
        
        calibration.estimateRawAtTimeOfCalibration = rawValue
        calculateWLS(for: calibration, lastCalibrationsForActiveSensorInLastXDays: &lastCalibrationsForActiveSensorInLastXDays, firstCalibration: firstCalibration, lastCalibration: lastCalibration)
        
    }
    
    /// from xdripplus
    /// forCalibration will get changed
    /// - parameters:
    ///     - calibration : calibration for which calculation is done
    ///     - lastCalibrationsForActiveSensorInLastXDays :  result of call to getLatestCalibrations(howManyDays:4, forSensor: active sensor) - inout parameter to improve performance
    ///     - firstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - lastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    private func calculateWLS(for calibration: Calibration, lastCalibrationsForActiveSensorInLastXDays: inout Array<Calibration>, firstCalibration: Calibration, lastCalibration: Calibration) {
        
        var l:Double = 0
        var m:Double = 0
        var n:Double = 0
        var p:Double = 0
        var q:Double = 0
        var w:Double
        
        check(ifThisCalibration: calibration, isInThisList: &lastCalibrationsForActiveSensorInLastXDays)
        
        if (lastCalibrationsForActiveSensorInLastXDays.count <= 1) {
            calibration.slope = 1
            calibration.intercept = calibration.bg - (calibration.rawValue * calibration.slope)
        } else {
            loop2 : for calibrationItem in lastCalibrationsForActiveSensorInLastXDays {
                w = calculateWeight(for: calibrationItem, firstCalibration: firstCalibration, lastCalibration: lastCalibration)
                l += (w)
                m += (w * calibrationItem.estimateRawAtTimeOfCalibration)
                n += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.estimateRawAtTimeOfCalibration)
                p += (w * calibrationItem.bg)
                q += (w * calibrationItem.estimateRawAtTimeOfCalibration * calibrationItem.bg)
            }
            
            w = ((calculateWeight(for: calibration, firstCalibration: firstCalibration, lastCalibration: lastCalibration)) * (((Double)(lastCalibrationsForActiveSensorInLastXDays.count)) * 0.14))
            l += (w)
            m += (w * calibration.estimateRawAtTimeOfCalibration)
            n += (w * calibration.estimateRawAtTimeOfCalibration * calibration.estimateRawAtTimeOfCalibration)
            p += (w * calibration.bg)
            q += (w * calibration.estimateRawAtTimeOfCalibration * calibration.bg)
            
            let d:Double = (l * n) - (m * m)
            calibration.intercept = ((n * p) - (m * q)) / d
            calibration.slope = ((l * q) - (m * p)) / d
            
            var last3CalibrationsForActiveSensor = Array(lastCalibrationsForActiveSensorInLastXDays.prefix(3))
            
            check(ifThisCalibration: calibration, isInThisList: &last3CalibrationsForActiveSensor)
            
            last3CalibrationsForActiveSensor = Array(last3CalibrationsForActiveSensor.prefix(3))
            
            if ((lastCalibrationsForActiveSensorInLastXDays.count == 2 && calibration.slope < sParams.LOW_SLOPE_1) || (calibration.slope < sParams.LOW_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus: 0, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor)
                if(lastCalibrationsForActiveSensorInLastXDays.count > 2) { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
            }
            if ((lastCalibrationsForActiveSensorInLastXDays.count == 2 && calibration.slope > sParams.HIGH_SLOPE_1) || (calibration.slope > sParams.HIGH_SLOPE_2)) {
                calibration.slope = slopeOOBHandler(withStatus:1, withLast3CalibrationsForActiveSensor:last3CalibrationsForActiveSensor)
                if lastCalibrationsForActiveSensorInLastXDays.count > 2 { calibration.possibleBad = true }
                calibration.intercept = calibration.bg - (calibration.estimateRawAtTimeOfCalibration * calibration.slope)
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
    private func calculateWeight(for calibration: Calibration, firstCalibration: Calibration, lastCalibration: Calibration) -> Double {
        
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
    private func slopeOOBHandler(withStatus status: Int, withLast3CalibrationsForActiveSensor calibrations: Array<Calibration>) -> Double {
        let thisCalibration: Calibration = calibrations[0]
        
        if status == 0 {
            if calibrations.count == 3 {
                if ((abs(thisCalibration.bg) < 30) && (calibrations[1].possibleBad)) {
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
                if ((abs(thisCalibration.bg) < 30) && (calibrations[1].possibleBad)) {
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
    
    /// taken over from xdripplus
    ///
    /// updates parameter forBgReading
    ///
    /// - parameters:
    ///     - bgReading : reading that needs to be updated
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - it's ok if there's less than 3 readings - inout parameter to improve performance
    private func findNewCurve(for bgReading: BgReading, last3Readings: inout Array<BgReading>) {
        //debuglogging("in findNewCurve with last3Readings.count = " + last3Readings.count.description)
        
        var y3: Double
        var x3: Double
        var y2: Double
        var x2: Double
        var y1: Double
        var x1: Double
        var latest:BgReading
        var secondlatest:BgReading
        var thirdlatest:BgReading
        
        if last3Readings.count > 2 {
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
        } else if last3Readings.count == 2 {
            latest = last3Readings[0]
            secondlatest = last3Readings[1]
            y2 = latest.calculatedValue
            x2 = latest.timeStamp.toMillisecondsAsDouble()
            y1 = secondlatest.calculatedValue
            x1 = secondlatest.timeStamp.toMillisecondsAsDouble()
            if y1 == y2 {
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
    private func findNewRawCurve(for bgReading: BgReading, last3Readings: inout Array<BgReading>) {
        //debuglogging("in findNewRawCurve with last3Readings.count = " + last3Readings.count.description)
        
        var y3:Double
        var x3:Double
        var y2:Double
        var x2:Double
        var y1:Double
        var x1:Double
        var latest: BgReading
        var secondlatest: BgReading
        var thirdlatest: BgReading
        
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
            
            if y1 == y2 {
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
    private func updateCalculatedValue(for bgReading: BgReading) {
        if bgReading.calculatedValue < 10 {
            bgReading.calculatedValue = ConstantsCalibrationAlgorithms.bgReadingErrorValue
            bgReading.hideSlope = true
        } else {
            bgReading.calculatedValue = min(ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue, max(ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue, bgReading.calculatedValue))
        }
    }
    
    /// - parameters:
    ///     - withTimeStamp : timeStamp :)
    ///     - withLast1Reading : last reading
    /// - returns:
    ///     - estimatedrawbg
    private func getEstimatedRawBg(withTimeStamp timeStamp: Date, withLast1Reading last1Reading: BgReading) -> Double {
        let timeStampInMs = timeStamp.toMillisecondsAsDouble()
        return (last1Reading.ra * timeStampInMs * timeStampInMs) + (last1Reading.rb * timeStampInMs) + last1Reading.rc
    }
    
    /// - parameters:
    ///     - bgReading : reading that needs to be updated
    ///     - withSensor : the currently active sensor, optional
    private func calculateAgeAdjustedRawValue(for bgReading: BgReading, withSensor sensor: Sensor?) {
        if let sensor = sensor {
            let adjustfor:Double = ConstantsCalibrationAlgorithms.ageAdjustmentTime - (bgReading.timeStamp.toMillisecondsAsDouble() - sensor.startDate.toMillisecondsAsDouble())
            if (adjustfor <= 0 || !ageAdjustMentNeeded) {
                bgReading.ageAdjustedRawValue = bgReading.rawData
            } else {
                bgReading.ageAdjustedRawValue = ((ConstantsCalibrationAlgorithms.ageAdjustmentFactor * (adjustfor / ConstantsCalibrationAlgorithms.ageAdjustmentTime)) * bgReading.rawData) + bgReading.rawData
            }
        } else {
            bgReading.ageAdjustedRawValue = bgReading.rawData
        }
        //debuglogging("in calculateAgeAdjustedRawValue bgReading.ageAdjustedRawValue" + bgReading.ageAdjustedRawValue.description)
    }
    
    private func weightedAverageRaw(timeA: Date, timeB: Date, calibrationTime: Date, rawA: Double, rawB: Double) -> Double {
        let relativeSlope:Double = (rawB -  rawA)/(timeB.toMillisecondsAsDouble() - timeA.toMillisecondsAsDouble())
        let relativeIntercept:Double = rawA - (relativeSlope * timeA.toMillisecondsAsDouble())
        
        return ((relativeSlope * calibrationTime.toMillisecondsAsDouble()) + relativeIntercept)
    }
    
    /// calls findNewCurve, findNewRawCurve and findSlope for bgReading
    /// - parameters:
    ///     - bgReading : reading that will be updated
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(x, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
    private func performCalculations(for bgReading: BgReading, last3Readings: inout Array<BgReading>)  {
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
    public func findSlope(for bgReading: BgReading, last2Readings: inout Array<BgReading>) {
        bgReading.hideSlope = true;
        if last2Readings.count >= 2 {
            let (slope, hide) = bgReading.calculateSlope(lastBgReading: last2Readings[1])
            bgReading.calculatedValueSlope = slope
            bgReading.hideSlope = hide
        } else if last2Readings.count == 1 {
            bgReading.calculatedValueSlope = 0
        } else {
            bgReading.calculatedValueSlope = 0
        }
    }
}







