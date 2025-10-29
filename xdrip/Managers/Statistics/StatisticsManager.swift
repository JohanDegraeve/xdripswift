//
//  StatisticsManager.swift
//  xdrip
//
//  Created by Paul Plant on 26/04/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

public final class StatisticsManager {
    // MARK: - private properties
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// used for calculating statistics on a background thread
    private let operationQueue: OperationQueue
    
    /// a coreDataManager
    private var coreDataManager: CoreDataManager
    
    // MARK: - intializer
    
    init(coreDataManager: CoreDataManager) {
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)

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
            var numberOfDaysUsed = 0
            
            self.coreDataManager.privateManagedObjectContext.performAndWait {
                // lets get the readings from the bgReadingsAccessor
                let readings = self.bgReadingsAccessor.getBgReadings(from: fromDate, to: toDate, on: self.coreDataManager.privateManagedObjectContext)
                
                // if there are no available readings, return without doing anything
                if readings.count == 0 {
                    DispatchQueue.main.async {
                        callback(Statistics(lowStatisticValue: 0, highStatisticValue: 0, inRangeStatisticValue: 0, averageStatisticValue: 0, a1CStatisticValue: 0, cVStatisticValue: 0, lowLimitForTIR: UserDefaults.standard.timeInRangeType.lowerLimit, highLimitForTIR: UserDefaults.standard.timeInRangeType.higherLimit, numberOfDaysUsed: 0))
                    }
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
                    
                    if calculatedValue != 0.0, calculatedValue >= minValidReading, calculatedValue <= maxValidReading {
                        // get the difference between the previous value's timestamp and the new one
                        let secondsDifference = Calendar.current.dateComponents([.second], from: previousValueTimeStamp!, to: currentTimeStamp)
                        
                        // if the current values timestamp is more than the minimum filter time, then add it to the glucoseValues array. Include a check to ensure that the first reading is added despite there not being any difference to itself
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
                    var sum: Double = 0
                    
                    for glucoseValue in glucoseValues {
                        sum += (Double(glucoseValue.value) - averageStatisticValue) * (Double(glucoseValue.value) - averageStatisticValue)
                    }
                    
                    let stdDeviationStatisticValue: Double = sqrt(sum / Double(glucoseValues.count))
                    
                    // calculate Coeffecient of Variation
                    cVStatisticValue = (stdDeviationStatisticValue / averageStatisticValue) * 100
                
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
            
            // call callback in main thread,
            DispatchQueue.main.async {
                callback(Statistics(lowStatisticValue: lowStatisticValue, highStatisticValue: highStatisticValue, inRangeStatisticValue: inRangeStatisticValue, averageStatisticValue: averageStatisticValue, a1CStatisticValue: a1CStatisticValue, cVStatisticValue: cVStatisticValue, lowLimitForTIR: lowLimitForTIR, highLimitForTIR: highLimitForTIR, numberOfDaysUsed: numberOfDaysUsed))
            }

        })
        
        // add the operation to the queue and start it. As maxConcurrentOperationCount = 1, it may be kept until a previous operation has finished
        operationQueue.addOperation {
            operation.start()
        }
    }
    
    /// Calculates per-day TIR statistics in a single batched Core Data fetch.
    /// - Parameters:
    ///   - fromDate: Start of the range (inclusive)
    ///   - toDate: End of the range (inclusive if same day; defaults to now)
    ///   - callback: Called on the main thread with a dictionary keyed by each day's start-of-day `Date`
    public func calculateDailyTIR(fromDate: Date, toDate: Date? = Date(), callback: @escaping ([Date: Statistics]) -> Void) {
        // create a new operation
        let operation = BlockOperation(block: {
            // declare variables/constants
            let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            let lowLimitForTIRLocal: Double = UserDefaults.standard.timeInRangeType.lowerLimit
            let highLimitForTIRLocal: Double = UserDefaults.standard.timeInRangeType.higherLimit
            let minimumSecondsBetweenReadings: Double = ConstantsStatistics.minimumFilterTimeBetweenReadings * 60
            let minValidReading: Double = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
            let maxValidReading: Double = 450

            var statisticsByDay: [Date: Statistics] = [:]

            // Build the list of calendar days we want to cover (inclusive)
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: fromDate)
            let endDay = calendar.startOfDay(for: toDate ?? Date())
            var dayIterator = startDay
            var allDays: [Date] = []
            
            while dayIterator <= endDay {
                allDays.append(dayIterator)
                guard let next = calendar.date(byAdding: .day, value: 1, to: dayIterator) else { break }
                dayIterator = next
            }

            self.coreDataManager.privateManagedObjectContext.performAndWait {
                // Single fetch for the entire window
                let readings = self.bgReadingsAccessor.getBgReadings(from: fromDate, to: toDate, on: self.coreDataManager.privateManagedObjectContext)

                // Group filtered, unit-corrected values by calendar day, with minimal Libre 2 60s sampling noise
                var glucoseValuesByDay: [Date: [Double]] = [:]
                var previousTimeStampByDay: [Date: Date] = [:]

                for reading in readings {
                    var calculatedValue = reading.calculatedValue
                    let currentTimeStamp = reading.timeStamp

                    // Basic validity filter first
                    if calculatedValue != 0.0, calculatedValue >= minValidReading, calculatedValue <= maxValidReading {
                        let dayKey = calendar.startOfDay(for: currentTimeStamp)
                        let previousTimeStamp = previousTimeStampByDay[dayKey]

                        // Respect the minimum spacing per day-bucket
                        var allowAppend = false
                        if previousTimeStamp == nil {
                            allowAppend = true
                        } else {
                            let secondsDifference = calendar.dateComponents([.second], from: previousTimeStamp!, to: currentTimeStamp).second ?? 0
                            allowAppend = Double(secondsDifference) >= minimumSecondsBetweenReadings
                        }

                        if allowAppend {
                            if !isMgDl {
                                calculatedValue = calculatedValue * ConstantsBloodGlucose.mgDlToMmoll
                            }
                            var dayArray = glucoseValuesByDay[dayKey] ?? []
                            dayArray.append(calculatedValue)
                            glucoseValuesByDay[dayKey] = dayArray
                            previousTimeStampByDay[dayKey] = currentTimeStamp
                        }
                    }
                }

                // Produce a Statistics value for every requested day (including empty days)
                for dayKey in allDays {
                    let glucoseValues = glucoseValuesByDay[dayKey] ?? []

                    if glucoseValues.isEmpty {
                        statisticsByDay[dayKey] = Statistics(
                            lowStatisticValue: 0,
                            highStatisticValue: 0,
                            inRangeStatisticValue: 0,
                            averageStatisticValue: 0,
                            a1CStatisticValue: 0,
                            cVStatisticValue: 0,
                            lowLimitForTIR: lowLimitForTIRLocal,
                            highLimitForTIR: highLimitForTIRLocal,
                            numberOfDaysUsed: 0
                        )
                    } else {
                        let count = glucoseValues.count
                        let lowCount = glucoseValues.lazy.filter { $0 < lowLimitForTIRLocal }.count
                        let highCount = glucoseValues.lazy.filter { $0 > highLimitForTIRLocal }.count

                        // Keep the same integer-percent arithmetic style used elsewhere
                        let lowStatisticValue = Double((lowCount * 200) / (count * 2))
                        let highStatisticValue = Double((highCount * 200) / (count * 2))
                        let inRangeStatisticValue = 100 - lowStatisticValue - highStatisticValue

                        let sum = glucoseValues.reduce(0, +)
                        let averageStatisticValue = sum / Double(count)

                        let a1CStatisticValue: Double
                        if UserDefaults.standard.useIFCCA1C {
                            a1CStatisticValue = (((46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7) - 2.152) / 0.09148
                        } else {
                            a1CStatisticValue = (46.7 + Double(isMgDl ? averageStatisticValue : (averageStatisticValue / ConstantsBloodGlucose.mgDlToMmoll))) / 28.7
                        }

                        var sumOfSquares: Double = 0
                        for value in glucoseValues {
                            sumOfSquares += (value - averageStatisticValue) * (value - averageStatisticValue)
                        }
                        let standardDeviationStatisticValue = sqrt(sumOfSquares / Double(count))
                        let cVStatisticValue = (standardDeviationStatisticValue / averageStatisticValue) * 100

                        statisticsByDay[dayKey] = Statistics(lowStatisticValue: lowStatisticValue, highStatisticValue: highStatisticValue, inRangeStatisticValue: inRangeStatisticValue, averageStatisticValue: averageStatisticValue, a1CStatisticValue: a1CStatisticValue, cVStatisticValue: cVStatisticValue, lowLimitForTIR: lowLimitForTIRLocal, highLimitForTIR: highLimitForTIRLocal, numberOfDaysUsed: 1)
                    }
                }
            }

            // Always callback - the queue is already serialized
            DispatchQueue.main.async {
                callback(statisticsByDay)
            }
        })

        // Serialize via the same queue as the single-day calculator
        operationQueue.addOperation {
            operation.start()
        }
    }
    
    /// can store result of calculations in calculateStatistics, to be used in UI
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
