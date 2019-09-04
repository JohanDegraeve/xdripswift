import Foundation
import CoreData
import os

class BgReadingsAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBgReadings)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - functions
    
    /// Gives readings for which calculatedValue != 0, rawdata != 0, matching sensorid if sensorid not nil, with maximumDays old
    ///
    /// - parameters:
    ///     - limit : maximum amount of readings to return, if nil then no limit in amount
    ///     - howOld : maximum age in days, it will calculate exacte (24 hours) * howOld, if nil then no limit in age
    ///     - forSensor : if not nil, then only readings for the given sensor will be returned - if nil, then sensor is ignored
    ///     - if ignoreRawData = true, then value of rawdata will be ignored
    ///     - if ignoreCalculatedValue = true, then value of calculatedValue will be ignored
    /// - returns: an array with readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    func getLatestBgReadings(limit:Int?, howOld maximumDays: Float?, forSensor sensor:Sensor?, ignoreRawData:Bool, ignoreCalculatedValue:Bool) -> [BgReading] {
        
        // if maximum age specified then create fromdate
        var fromDate:Date?
        if let maximumDays = maximumDays, maximumDays >= 0 {
            fromDate = Date(timeIntervalSinceNow: Double(-maximumDays * 60 * 60 * 24))
        }
        
        return getLatestBgReadings(limit: limit, fromDate: fromDate, forSensor: sensor, ignoreRawData: ignoreRawData, ignoreCalculatedValue: ignoreCalculatedValue)
        
    }
    
    func judgeReading(fromDate: Date, toDate: Date, sensor:Sensor?) -> Bool {
        let bgReadings = fetchBgReadings(limit: 1, fromDate: fromDate, toDate: toDate)
        print("from: \(fromDate), to: \(toDate), date: \(bgReadings.first?.timeStamp)")
        return bgReadings.count > 0
    }
    
    /// Gives readings for which calculatedValue != 0, rawdata != 0, matching sensorid if sensorid not nil, with timestamp higher than fromDate
    ///
    /// - parameters:
    ///     - limit : maximum amount of readings to return, if nil then no limit in amount
    ///     - fromDate : reading must have date > fromDate
    ///     - forSensor : if not nil, then only readings for the given sensor will be returned - if nil, then sensor is ignored
    ///     - if ignoreRawData = true, then value of rawdata will be ignored
    ///     - if ignoreCalculatedValue = true, then value of calculatedValue will be ignored
    /// - returns: an array with readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    func getLatestBgReadings(limit:Int?, fromDate:Date?, toDate: Date? = nil, forSensor sensor:Sensor?, ignoreRawData:Bool, ignoreCalculatedValue:Bool) -> [BgReading] {
        
        var returnValue:[BgReading] = []
        
//        let ignoreSensorId = sensor == nil ? true:false
        
        let bgReadings = fetchBgReadings(limit: limit, fromDate: fromDate, toDate: toDate)
        returnValue = bgReadings
        // why? ? ? ?
//        loop: for (_,bgReading) in bgReadings.enumerated() {
//            if ignoreSensorId {
//                if (bgReading.calculatedValue != 0.0 || ignoreCalculatedValue) && (bgReading.rawData != 0.0 || ignoreRawData) {
//                    returnValue.append(bgReading)
//                }
//            } else {
//                if let readingsensor = bgReading.sensor {
//                    if readingsensor.id == sensor!.id {
//                        if (bgReading.calculatedValue != 0.0 || ignoreCalculatedValue) && (bgReading.rawData != 0.0 || ignoreRawData) {
//                            returnValue.append(bgReading)
//                        }
//                    }
//                }
//            }
//
//            if let limit = limit {
//                if returnValue.count == limit {
//                    break loop
//                }
//            }
//        }
        
        return returnValue
    }
    
    /// gets last reading, ignores rawData and calculatedValue
    /// - parameters:
    ///     - sensor: sensor for which reading is asked, if nil then sensor value is ignored
    func last(forSensor sensor:Sensor?) -> BgReading? {
        let readings = getLatestBgReadings(limit: 1, howOld: nil, forSensor: sensor, ignoreRawData: true, ignoreCalculatedValue: true)
        if readings.count > 0 {
            return readings.last
        } else {
            return nil
        }
    }
    
    // MARK: - private helper functions
    
    /// returnvalue can be empty array
    /// - parameters:
    ///     - limit: maximum amount of readings to fetch, if 0 then no limit
    ///     - fromDate : if specified, only return readings with timestamp > fromDate
    private func fetchBgReadings(limit:Int?, fromDate:Date?, toDate: Date? = nil) -> [BgReading] {
        let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
        
        // if fromDate specified then create predicate
        if let fromDate = fromDate {
            var predicate = NSPredicate(format: "timeStamp >= %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970))
            if let toDate = toDate {
                predicate = NSPredicate(format: "timeStamp >= %@ && timeStamp <= %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970), NSDate(timeIntervalSince1970: toDate.timeIntervalSince1970))
            }
            fetchRequest.predicate = predicate
        }
        
        // set fetchLimit
        if let limit = limit, limit >= 0 {
            fetchRequest.fetchLimit = limit
        }
        
        var bgReadings = [BgReading]()
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                bgReadings = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in fetchBgReadings, Unable to Execute BgReading Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgReadings
    }
}
