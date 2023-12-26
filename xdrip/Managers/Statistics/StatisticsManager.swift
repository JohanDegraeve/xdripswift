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
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// used for calculating statistics on a background thread
    private let operationQueue: OperationQueue
    
    /// a coreDataManager
    private var coreDataManager: CoreDataManager
    
    // MARK: - intializer
    
    init(coreDataManager: CoreDataManager) {
        
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)

        // initialize operationQueue
        operationQueue = OperationQueue()
        
        // operationQueue will be queue of blocks that gets readings and updates glucoseChartPoints, startDate and endDate. To avoid race condition, the operations should be one after the other
        operationQueue.maxConcurrentOperationCount = 1
        
    }
    
    // MARK: - public functions
    
    /// calculates statistics, will execute in background.
    /// - parameters:
    ///     - callback : will be called with result of calculations in UI thread
    public func calculateStatistics(fromDate: Date, toDate: Date? = Date(), callback: @escaping (Statistics) -> Void) {
        
        // create a new operation
        let operation = BlockOperation(block: {
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one
            guard self.operationQueue.operations.count <= 1 else {
                return
            }
            
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
            
            self.coreDataManager.privateManagedObjectContext.performAndWait {

                // lets get the readings from the bgReadingsAccessor
                let readings = self.bgReadingsAccessor.getBgReadings(from: fromDate, to: toDate, on: self.coreDataManager.privateManagedObjectContext)
                
                //if there are no available readings, return without doing anything
                if readings.count == 0 {
                    return
                }
                
                // let's calculate the actual first day of readings in bgReadings. Although the user wants to use 60 days to calculate, maybe we only have 4 days of data. This will be returned from the method and used in the UI. To ensure we calculate the whole days used, we should subtract 5 minutes from the fromDate
                numberOfDaysUsed = Calendar.current.dateComponents([.day], from: readings.first!.timeStamp - 5 * 60, to: Date()).day!
                
                // get the minimum time between readings (convert to seconds). This is to avoid getting too many extra 60-second readings from the Libre 2 Direct - they will take up a lot more processing time and don't add anything to the accuracy of the results so we'll just filter them out if they exist.
                let minimumSecondsBetweenReadings: Double = ConstantsStatistics.minimumFilterTimeBetweenReadings * 60
                
                // get the timestamp of the first reading
                let firstValueTimeStamp = readings.first?.timeStamp
                var previousValueTimeStamp = firstValueTimeStamp
                
                // add filter values to ensure that any clearly invalid glucose data is not included into the array and used in the calculations
                let minValidReading: Double = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
                let maxValidReading: Double = 450
                
                // step though all values, check them for validity, convert if necessary and append them to the glucoseValues array
                for reading in readings {
                    
                    // declare and initialise the date variables needed
                    var calculatedValue = reading.calculatedValue
                    let currentTimeStamp = reading.timeStamp
                    
                    if (calculatedValue != 0.0) && (calculatedValue >= minValidReading) && (calculatedValue <= maxValidReading) {
                        
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
                
                /*
                // let's set up the which values will be used to calculate TIR. It can be either the standardised "Time in Range" values or the newer "Time in Tight Range" values.
                let useTITR: Bool = UserDefaults.standard.useTITRStatisticsRange
                
                if isMgDl {
                    lowLimitForTIR = useTITR ? ConstantsStatistics.standardisedLowValueForTITRInMgDl : ConstantsStatistics.standardisedLowValueForTIRInMgDl
                    highLimitForTIR = useTITR ? ConstantsStatistics.standardisedHighValueForTITRInMgDl : ConstantsStatistics.standardisedHighValueForTIRInMgDl
                } else {
                    lowLimitForTIR = useTITR ? ConstantsStatistics.standardisedLowValueForTITRInMmol : ConstantsStatistics.standardisedLowValueForTIRInMmol
                    highLimitForTIR = useTITR ? ConstantsStatistics.standardisedHighValueForTITRInMmol : ConstantsStatistics.standardisedHighValueForTIRInMmol
                }
                */
                lowLimitForTIR = UserDefaults.standard.timeInRangeType.lowerLimit
                highLimitForTIR = UserDefaults.standard.timeInRangeType.higherLimit
                
                // make sure that there exist elements in the glucoseValue array before trying to process statistics calculations or we could get a fatal divide by zero error/crash
                if glucoseValues.count > 0 {
                    
                    // calculate low %
                    lowStatisticValue = Double((glucoseValues.lazy.filter { $0 < lowLimitForTIR }.count * 200) / (glucoseValues.count * 2))
                
                
                    // calculate high %
                    highStatisticValue = Double((glucoseValues.lazy.filter { $0 > highLimitForTIR }.count * 200) / (glucoseValues.count * 2))
                    
                    
                    // calculate TIR % (let's be lazy and just subtract the other two values from 100)
                    inRangeStatisticValue = 100 - lowStatisticValue - highStatisticValue
                    
                    
                    // calculate average glucose value
                    averageStatisticValue = Double(glucoseValues.reduce(0, +)) / Double(glucoseValues.count)
                
                    
                    // calculate an estimated HbA1C value using either IFCC (e.g 49 mmol/mol) or NGSP (e.g 5.8%) methods: http://www.ngsp.org/ifccngsp.asp
                    if UserDefaults.standard.useIFCCA1C {
                        a1CStatisticValue = (((46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7) - 2.152) / 0.09148
                    } else {
                        a1CStatisticValue = (46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7
                    }
                    
                    
                    // calculate standard deviation (we won't show this but we need it to calculate CV)
                    var sum: Double = 0;
                    
                    for glucoseValue in glucoseValues {
                        sum += (Double(glucoseValue.value) - averageStatisticValue) * (Double(glucoseValue.value) - averageStatisticValue)
                    }
                    
                    let stdDeviationStatisticValue: Double = sqrt(sum / Double(glucoseValues.count))
                    
                    
                    // calculate Coeffecient of Variation
                    cVStatisticValue = ((stdDeviationStatisticValue) / averageStatisticValue) * 100
                
                } else {
                
                    // just assign a zero value to all statistics variables
                    lowStatisticValue = 0
                    highStatisticValue = 0
                    inRangeStatisticValue = 0
                    averageStatisticValue = 0
                    cVStatisticValue = 0
                    a1CStatisticValue = 0
                
                }

            }
            
            // call callback in main thread, this callback will only update the UI when the user hasn't requested more statistics updates in the meantime (this will only apply if they are reaaaallly quick at tapping the segmented control)
            if self.operationQueue.operations.count <= 1 {
                DispatchQueue.main.async {
                    callback( Statistics(lowStatisticValue: lowStatisticValue, highStatisticValue: highStatisticValue, inRangeStatisticValue: inRangeStatisticValue, averageStatisticValue: averageStatisticValue, a1CStatisticValue: a1CStatisticValue, cVStatisticValue: cVStatisticValue, lowLimitForTIR: lowLimitForTIR, highLimitForTIR: highLimitForTIR, numberOfDaysUsed: numberOfDaysUsed))
                }
            }

        })
        
        // add the operation to the queue and start it. As maxConcurrentOperationCount = 1, it may be kept until a previous operation has finished
        operationQueue.addOperation {
            operation.start()
        }
        

        
    }
    
    /// can store rresult off calculations in calculateStatistics,  to be used in UI
    public struct Statistics {
        
        var lowStatisticValue: Double
        var highStatisticValue: Double
        var inRangeStatisticValue: Double
        var averageStatisticValue: Double
        var a1CStatisticValue: Double
        var cVStatisticValue: Double
        var lowLimitForTIR: Double
        var highLimitForTIR: Double
        var numberOfDaysUsed: Int
        
    }
     
}

