import Foundation
import CoreData


    
    /// converts mgdl to mmol
    func mgdlToMmol(with mgDlValue: Double) -> Double {
        return mgDlValue * Constants.BloodGlucose.mgDlToMmoll
    }

    /// converts mmol to mgdl
    func mmolToMgdl(with mmolValue:Double) -> Double {
        return mmolValue * Constants.BloodGlucose.mmollToMgdl
    }
    
    /// taken over from xdripplus
    ///
    /// updates parameter forBgReading
    ///
    /// - parameters:
    ///     - bgReading : reading that needs to be updated
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - it's ok if there's less than 3 readings - inout parameter to improve performance
    func findNewCurve(for bgReading:inout BgReading, with last3Readings:inout Array<BgReading>) {
        
        var y3:Double
        var x3:Double
        var y2:Double
        var x2:Double
        var y1:Double
        var x1:Double
        var latest:BgReading
        var secondlatest:BgReading
        var thirdlatest:BgReading
        
        if (last3Readings.count == 3) {
            latest = last3Readings[0]
            secondlatest = last3Readings[1]
            thirdlatest = last3Readings[2]
            y3 = latest.calculatedValue
            x3 = latest.timeStamp.toMillisecondsAsDouble()
            y2 = secondlatest.calculatedValue
            x2 = secondlatest.timeStamp.toMillisecondsAsDouble()
            y1 = thirdlatest.calculatedValue
            x1 = thirdlatest.timeStamp.toMillisecondsAsDouble()
    
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
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
    ///     - lastNoSensor : result of call to BgReadings.getLastReadingNoSensor, can be nil
    func findNewRawCurve(for bgReading:inout BgReading, with last3Readings:inout Array<BgReading>, with lastNoSensor:BgReading?) {
        
        var y3:Double
        var x3:Double
        var y2:Double
        var x2:Double
        var y1:Double
        var x1:Double
        var latest:BgReading
        var secondlatest:BgReading
        var thirdlatest:BgReading
        
        if (last3Readings.count == 3) {
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
            latest = last3Readings[0]
            secondlatest = last3Readings[1]
            
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
    ///     - bgReading : reading that needs to be updated - inout parameter to improve performance
    func updateCalculatedValue(for bgReading:inout BgReading) {
        if (bgReading.calculatedValue < 10) {
            bgReading.calculatedValue = 38
            bgReading.hideSlope = true
        } else {
            bgReading.calculatedValue = min(400, max(39, bgReading.calculatedValue))
        }
    }
 
    /// taken over form xdripplus
    ///
    /// - parameters:
    ///     - currentBgReading : reading for which slope is calculated
    ///     - lastBgReading : last reading result of call to BgReadings.getLatestBgReadings(1, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    /// - returns:
    ///     - calculated slope
    private func calculateSlope(with currentBgReading:BgReading, with lastBgReading:BgReading) -> (Double, Bool) {
        if currentBgReading.timeStamp == lastBgReading.timeStamp
            ||
            currentBgReading.timeStamp.toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble() > Double(Constants.BGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0,true)
        }
        return ((lastBgReading.calculatedValue - currentBgReading.calculatedValue) / (lastBgReading.timeStamp.toMillisecondsAsDouble() - currentBgReading.timeStamp.toMillisecondsAsDouble()), false)
    }
    
    /// taken over from xdripplus
    ///
    /// - parameters:
    ///     - withTimeStamp : timeStamp :)
    ///     - withLast1Reading : result of call to BgReadings.getLatestBgReadings(1, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    /// - returns:
    ///     - estimatedrawbg
    private func getEstimatedRawBg(withTimeStamp timeStamp:Double, withLast1Reading last1Reading:inout Array<BgReading>) -> Double {
        var estimate:Double
        if (last1Reading.count == 0) {
            estimate = 160
        } else {
            let latest:BgReading = last1Reading[0]
            estimate = (latest.ra * timeStamp * timeStamp) + (latest.rb * timeStamp) + latest.rc
        }
        return estimate
    }
    
    /// taken over from xdripplus
    ///
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
    }
    
    /// create a new BgReading
    ///
    /// - parameters:
    ///     - withRawData : the rawdata value
    ///     - withFilteredData : the filtered data
    ///     - withTimeStamp : optional, if nil then actualy date and time is used
    ///     - withSensor : actual sensor, optional
    ///     - withLast3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
    ///     - withSsManagedObjectContext : the nsManagedObjectContext
    ///     - withLastNoSensor : result of call to BgReadings.getLastReadingNoSensor, can be nil
    ///     - withLast4CalibrationsForActiveSensor :  result of call to Calibrations.allForSensor(4, active sensor) - inout parameter to improve performance
    ///     - withFirstCalibration : result of call to Calibrations.firstCalibrationForActiveSensor
    ///     - withLastCalibration : result of call to Calibrations.lastCalibrationForActiveSensor
    ///     - isTypeLimitter : type limitter means sensor is Libre
    /// - returns:
    ///     - the created bgreading
    func createNewReading(withRawData rawData:Double, withFilteredData filteredData:Double, withTimeStamp timeStamp:Date?, withSensor sensor:Sensor?, withLast3Readings last3Readings:inout Array<BgReading>, withLastNoSensor lastNoSensor:BgReading?, withLast4CalibrationsForActiveSensor last4CalibrationsForActiveSensor:inout Array<Calibration>, withFirstCalibration firstCalibration:Calibration, withLastCalibration lastCalibration:Calibration, isTypeLimitter:Bool, withnSManagedObjectContext nsManagedObjectContext:NSManagedObjectContext ) -> BgReading {
      
        var timeStampToUse:Date = Date()
        if let timeStamp = timeStamp {
            timeStampToUse = timeStamp
        }
        
        var lastCalibration:Calibration? = nil
        if last4CalibrationsForActiveSensor.count > 0 {
            lastCalibration = last4CalibrationsForActiveSensor[0]
        }
        
        var bgReading:BgReading = BgReading(
            timeStamp:timeStampToUse,
            sensor:sensor,
            calibration:lastCalibration,
            rawData:rawData / 1000,
            filteredData:filteredData / 1000,
            nsManagedObjectContext:nsManagedObjectContext
        )
        
        calculateAgeAdjustedRawValue(for:bgReading, withSensor:sensor, isTypeLimitter: isTypeLimitter)
        
        if let calibration = lastCalibration {
            if calibration.checkIn {
                let firstAdjSlope:Double = calibration.firstSlope + (calibration.firstDecay * (ceil(timeStampToUse.toMillisecondsAsDouble() - calibration.timeStamp.toMillisecondsAsDouble())/(1000 * 60 * 10)))
                let calSlope:Double = (calibration.firstScale / firstAdjSlope) * 1000
                let calIntercept:Double = ((calibration.firstScale * calibration.firstIntercept) / firstAdjSlope) * -1
                bgReading.calculatedValue = (((calSlope * rawData) + calIntercept) - 5)
                bgReading.filteredCalculatedValue = (((calSlope * bgReading.ageAdjustedRawValue) + calIntercept) - 5)
            } else {
                if (last3Readings.count > 0) {
                    let latest:BgReading = last3Readings[0]
                    if var latestReadingCalibration = latest.calibration {
                        if (latest.calibrationFlag && ((latest.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble()) && ((latestReadingCalibration.timeStamp.toMillisecondsAsDouble() + (60000 * 20)) > timeStampToUse.toMillisecondsAsDouble())) {
                            rawValueOverride(for: &latestReadingCalibration, with: weightedAverageRaw(with: latest.timeStamp, with: timeStampToUse, with: latestReadingCalibration.timeStamp, with: latest.ageAdjustedRawValue, with: bgReading.ageAdjustedRawValue), with: &last4CalibrationsForActiveSensor, with: firstCalibration, with: calibration, isTypeLimitter: isTypeLimitter)
                        }
                    }
                }
                bgReading.calculatedValue = ((calibration.slope * bgReading.ageAdjustedRawValue) + calibration.intercept)
                bgReading.filteredCalculatedValue = ((calibration.slope * ageAdjustedFiltered(with: bgReading, with: lastCalibration)) + calibration.intercept)
            }
            updateCalculatedValue(for: &bgReading)
        }
        
        performCalculations(for: &bgReading, with: &last3Readings, with: lastNoSensor)
        return bgReading
    }

    private func weightedAverageRaw (with timeA:Date, with timeB:Date, with calibrationTime:Date, with rawA:Double, with rawB:Double) -> Double {
        
        let relativeSlope:Double = (rawB -  rawA)/(timeB.toMillisecondsAsDouble() - timeA.toMillisecondsAsDouble())
        let relativeIntercept:Double = rawA - (relativeSlope * timeA.toMillisecondsAsDouble())
        
        return ((relativeSlope * calibrationTime.toMillisecondsAsDouble()) + relativeIntercept)
    }

    /// taken from xdripplus
    ///
    /// - parameters:
    ///     - bgReading : bgreading for whcih usedRaw will be calculated
    ///     - lastCalibration : last calibration, optional
    /// - returns:
    ///     -   usedRaw
    func getUsedRaw(with bgReading:BgReading, with lastCalibration:Calibration?) -> Double {
        
        var returnValue = bgReading.ageAdjustedRawValue
        
        if let calibration = lastCalibration {
            if calibration.checkIn {
                returnValue = bgReading.rawData
            }
        }
        
        return returnValue
    }

    /// taken from xdripplus
    ///
    /// - parameters:
    ///     - bgReading : bgreading for which usedRaw will be calculated
    ///     - calibration : last calibration, optional
    /// - returns:
    ///     -   ageAdjustedFiltered
    private func ageAdjustedFiltered(with bgReading:BgReading, with calibration:Calibration?) -> Double {
        
        let usedRaw = getUsedRaw(with: bgReading, with: calibration)
        
        if(usedRaw == bgReading.rawData || bgReading.rawData == 0) {
            return bgReading.filteredData
        } else {
            // adjust the filtereddata with the same factor as the age adjusted raw value
            return bgReading.filteredData * usedRaw / bgReading.rawData;
        }
    }
    
    /// taken from xdripplus
    ///
    /// - parameters:
    ///     - bgReading : reading that will be updated
    ///     - last3Readings : result of call to BgReadings.getLatestBgReadings(3, sensor) with sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false - inout parameter to improve performance
    ///     - withLastNoSensor result of call to BgReadings.getLastReadingNoSensor, can be nil
    private func performCalculations(for bgReading:inout BgReading, with last3Readings:inout Array<BgReading>, with lastNoSensor:BgReading?)  {
        
        findNewCurve(for: &bgReading, with: &last3Readings)
        
        findNewRawCurve(for: &bgReading, with: &last3Readings, with: lastNoSensor)
        
        var last2Readings:Array<BgReading> = []
        for (index, bgReadingToAdd) in last3Readings.enumerated() where index < 3 {
            last2Readings.append(bgReadingToAdd)
        }
        findSlope(for: &bgReading, with: &last2Readings)
    }
    
    /// taken from xdripplus
    ///
    /// updates bgreading
    ///
    /// - parameters:
    ///     - bgReading : reading that will be updated
    ///     - last2Readings result of call to BgReadings.getLatestBgReadings(2, sensor) with ignoreRawData and ignoreCalculatedValue false - inout parameter to improve performance
    func findSlope(for bgReading:inout BgReading, with last2Readings:inout Array<BgReading>) {

        bgReading.hideSlope = true;
        if (last2Readings.count == 2) {
            let (slope, hide) = calculateSlope(with:bgReading, with:last2Readings[1]);
            bgReading.calculatedValueSlope = slope
            bgReading.hideSlope = hide
        } else if (last2Readings.count == 1) {
            bgReading.calculatedValueSlope = 0
        } else {
            bgReading.calculatedValueSlope = 0
        }
    }
