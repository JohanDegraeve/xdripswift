//
//  StatisticsManager.swift
//  xdrip
//
//  Created by Paul Plant on 26/04/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

public final class StatisticsManager {
    
    // MARK: - private properties
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    
    
    // MARK: - public functions
    
    public func calculateStatistics(fromDate: Date, toDate: Date? = Date(), coreDataManager: CoreDataManager) -> (lowStatisticValue: Double, highStatisticValue: Double, inRangeStatisticValue: Double, averageStatisticValue: Double, a1CStatisticValue: Double, cVStatisticValue: Double, lowLimitForTIR: Double, highLimitForTIR: Double, numberOfDaysUsed: Int, numberOfReadingsAvailable: Double, numberOfReadingsUsed: Double)? {
        
        // declare variables/constants
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        var glucoseValues: [Double] = []
        
        // declare return variables
        var lowStatisticValue: Double = 0
        var highStatisticValue: Double = 0
        var inRangeStatisticValue: Double = 0
        var averageStatisticValue: Double = 0
        var a1CStatisticValue: Double = 0
        var cVStatisticValue: Double = 0
        var lowLimitForTIR: Double = 0
        var highLimitForTIR: Double = 0
        var numberOfDaysUsed: Int = 0
        // TEST: these two variables are used for debugging. They can be removed from the method for release
        var numberOfReadingsAvailable: Double = 0
        var numberOfReadingsUsed: Double = 0
        
        // check that bgReadingsAccessor exists, otherwise return - this happens if updateLabelsAndChart is called from viewDidload at app launch
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        guard let bgReadingsAccessor = bgReadingsAccessor else { return nil }
        
        // lets get the readings from the bgReadingsAccessor
        let readings = bgReadingsAccessor.getBgReadings(from: fromDate, to: toDate, on: coreDataManager.mainManagedObjectContext)
        
        //if there are no available readings, return without doing anything
        if readings.count == 0 {
            return nil
        }
  
        // let's calculate the actual first day of readings in bgReadings. Although the user wants to use 60 days to calculate, maybe we only have 4 days of data. This will be returned from the method and used in the UI
        numberOfDaysUsed = Calendar.current.dateComponents([.day], from: readings.first!.timeStamp, to: Date()).day!
        
        
        // get the minimum time between readings (convert to seconds). This is to avoid getting too many extra 60-second readings from the Libre 2 Direct - they will take up a lot more processing time and don't add anything to the accuracy of the results so we'll just filter them out if they exist.
        let minimumSecondsBetweenReadings: Double = ConstantsStatistics.minimumFilterTimeBetweenReadings * 60
        
        // get the timestamp of the first reading
        let firstValueTimeStamp = readings.first?.timeStamp
        var previousValueTimeStamp = firstValueTimeStamp
        
        // step though all values, check them to validity, convert if necessary and append them to the glucoseValues array
        for reading in readings {
            
            // declare and initialise the date variables needed
            var calculatedValue = reading.calculatedValue
            let currentTimeStamp = reading.timeStamp
            
            if calculatedValue != 0.0 {
                
                // get the difference between the previous value's timestamp and the new one
                let secondsDifference = Calendar.current.dateComponents([.second], from: previousValueTimeStamp!, to: currentTimeStamp)
                
                //if the current values timestamp is more than the minimum filter time, then add it to the glucoseValues array. Include a check to ensure that the first reading is added despite there not being any difference to itself
                if (Double(secondsDifference.second!) >= minimumSecondsBetweenReadings) || (previousValueTimeStamp == firstValueTimeStamp) {
                    
                    if !isMgDl {
                        calculatedValue = calculatedValue * ConstantsBloodGlucose.mgDlToMmoll
                    }
                    
                    glucoseValues.append(calculatedValue)
                    
                    // update the timestamp for the next loop
                    previousValueTimeStamp = currentTimeStamp
                    
                }
                
            }
        }
        
        // TEST
        numberOfReadingsAvailable = Double(readings.count)
        numberOfReadingsUsed = Double(glucoseValues.count)
        
        
        // let's set up the which values will finally be used to calculate TIR. It can be either user-specified or the standardised values
        if UserDefaults.standard.useStandardStatisticsRange {
            if isMgDl {
                lowLimitForTIR = ConstantsStatistics.standardisedLowValueForTIRInMgDl
                highLimitForTIR = ConstantsStatistics.standardisedHighValueForTIRInMgDl
            } else {
                lowLimitForTIR = ConstantsStatistics.standardisedLowValueForTIRInMmol
                highLimitForTIR = ConstantsStatistics.standardisedHighValueForTIRInMmol
            }
        } else {
            lowLimitForTIR = UserDefaults.standard.lowMarkValueInUserChosenUnit
            highLimitForTIR = UserDefaults.standard.highMarkValueInUserChosenUnit
        }
        
        
        // calculate low %
        lowStatisticValue = Double((glucoseValues.lazy.filter { $0 < lowLimitForTIR }.count * 200) / (glucoseValues.count * 2))
        
        
        // calculate high %
        highStatisticValue = Double((glucoseValues.lazy.filter { $0 > highLimitForTIR }.count * 200) / (glucoseValues.count * 2))
        
        
        // calculate TIR % (let's be lazy and just subtract the other two values from 100)
        inRangeStatisticValue = 100 - lowStatisticValue - highStatisticValue
        
        
        // calculate average glucose value
        averageStatisticValue = Double(glucoseValues.reduce(0, +)) / Double(glucoseValues.count)
        
        
        // calculate standard deviation (we won't show this but we need it to calculate CV)
        var sum: Double = 0;
        
        for glucoseValue in glucoseValues {
            sum += (Double(glucoseValue.value) - averageStatisticValue) * (Double(glucoseValue.value) - averageStatisticValue)
        }
        
        let stdDeviationStatisticValue: Double = sqrt(sum / Double(glucoseValues.count))
        
        
        // calculate Coeffecient of Variation
        cVStatisticValue = ((stdDeviationStatisticValue) / averageStatisticValue) * 100
        
        
        // calculate an estimated HbA1C value using either IFCC (e.g 49 mmol/mol) or NGSP (e.g 5.8%) methods: http://www.ngsp.org/ifccngsp.asp
        if UserDefaults.standard.useIFCCA1C {
            a1CStatisticValue = (((46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7) - 2.152) / 0.09148
        } else {
            a1CStatisticValue = (46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7
        }
    
        // return all of the populated parameters
        return (
            lowStatisticValue,
            highStatisticValue,
            inRangeStatisticValue,
            averageStatisticValue,
            a1CStatisticValue,
            cVStatisticValue,
            lowLimitForTIR,
            highLimitForTIR,
            numberOfDaysUsed,
            // TEST
            numberOfReadingsAvailable,
            numberOfReadingsUsed
        )
        
    }
    
    
}

