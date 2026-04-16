
import Foundation
import CoreData
import os

class BgReadingsAccessor: ObservableObject {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBgReadings)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        
    }
    
    /// Distinct timestamp counts for rolling windows ending at a given time, plus earliest/latest in last 24h
    public struct TransmitterReadSuccessWindowCounts {
        public let earliestTimestampInLast24h: Date?
        public let latestTimestampInLast24h: Date?
        public var distinctCountLast6h: Int
        public var distinctCountLast12h: Int
        public var distinctCountLast24h: Int
    }


    // MARK: - public functions
    

    /// - Gives 2 latest readings with calculatedValue != 0, minimum time between the two readings specified by minimumTimeIntervalInMinutes
    ///
    /// - parameters:
    ///     - minimumTimeIntervalInMinutes : minimum time between the two readings in seconds
    /// - returns: 0 1 or 2 readings, minimum time diff between the two readings
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    func get2LatestBgReadings(minimumTimeIntervalInMinutes: Double) -> [BgReading] {
        
        // assuming there will be at most 1 reading per minute stored, feching minimumTimeIntervalInMinutes readings should be enough, adding 5 to be sure we fetch enough readings
        let readingsToFetch = Int(minimumTimeIntervalInMinutes) + 5
        
        // to define the fromDate, assume there's one reading every 5 minutes, and multiple with readingsToFetch
        let fromDate = Date(timeIntervalSinceNow: -(Double(readingsToFetch) * 5.0 * 60.0))
        
        // get latest readings
        let latestReadings = getLatestBgReadings(limit: readingsToFetch, fromDate: fromDate, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if there's no readings, then return empty array
        if latestReadings.count == 0 {return [BgReading]()}
        
        // if there's only one reading, then return it
        if latestReadings.count == 1 {return [latestReadings[0]]}
    
        // there's more than one reading, search the first with time difference >= minimumTimeIntervalInMinutes
        var indexNextReading = 1
        while indexNextReading < latestReadings.count && (abs(latestReadings[indexNextReading].timeStamp.timeIntervalSince(latestReadings[0].timeStamp)) < minimumTimeIntervalInMinutes * 60.0 ) {

            indexNextReading = indexNextReading + 1
            
        }
        
        // if indexNextReading = size of latestReadings, then it means we didn't find a second reading with time difference >= minimumTimeIntervalInMinutes, return only the first
        if indexNextReading == latestReadings.count {return [latestReadings[0]]}
        
        // return the first, and the one found matching the expected time difference
        return [latestReadings[0], latestReadings[indexNextReading]]
        
    }
    
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
    func getLatestBgReadings(limit:Int?, howOld:Int?, forSensor sensor:Sensor?, ignoreRawData:Bool, ignoreCalculatedValue:Bool) -> [BgReading] {
        
        // if maximum age specified then create fromdate
        var fromDate:Date?
        if let howOld = howOld, howOld >= 0 {
            fromDate = Date(timeIntervalSinceNow: Double(-howOld * 60 * 60 * 24))
        }
        
        return getLatestBgReadings(limit: limit, fromDate: fromDate, forSensor: sensor, ignoreRawData: ignoreRawData, ignoreCalculatedValue: ignoreCalculatedValue)
        
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

    func getLatestBgReadings(limit: Int?, fromDate: Date?, forSensor sensor: Sensor?, ignoreRawData: Bool, ignoreCalculatedValue: Bool) -> [BgReading] {

        var returnValue: [BgReading] = []

        // Core Data contexts are not thread-safe. We must run fetches/updates inside
        // performAndWait to ensure all access happens on the context's own queue.
        coreDataManager.mainManagedObjectContext.performAndWait {
            let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.includesPropertyValues = true
            fetchRequest.relationshipKeyPathsForPrefetching = ["sensor"]

            if let fromDate = fromDate {
                fetchRequest.predicate = NSPredicate(format: "timeStamp > %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970))
            }
            
            if let limit = limit, limit >= 0 {
                fetchRequest.fetchLimit = limit
            }

            do {
                let bgReadings = try fetchRequest.execute()
                let sensorId = sensor?.id
                let ignoreSensorId = (sensorId == nil)

                for bgReading in bgReadings {
                    if !ignoreSensorId {
                        guard let fetchedSensor = bgReading.sensor, fetchedSensor.id == sensorId else { continue }
                    }
                    
                    guard (ignoreCalculatedValue || bgReading.calculatedValue != 0.0) && (ignoreRawData || bgReading.rawData != 0.0) else { continue }

                    returnValue.append(bgReading)

                    if let limit = limit, returnValue.count == limit { break }
                }
            } catch {
                let fetchError = error as NSError
                
                trace("in getLatestBgReading, Unable to Execute BgReading Fetch Request: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }

        return returnValue
    }
    
    /// Snapshot variant that returns value types (thread-safe, no Core Data objects escape)
    ///
    /// Gives readings for which calculatedValue != 0, rawdata != 0, matching sensorid if sensorid not nil, with timestamp higher than fromDate
    ///
    /// - parameters:
    ///     - limit : maximum amount of readings to return, if nil then no limit in amount
    ///     - fromDate : reading must have date > fromDate
    ///     - forSensor : if not nil, then only readings for the given sensor will be returned - if nil, then sensor is ignored
    ///     - if ignoreRawData = true, then value of rawdata will be ignored
    ///     - if ignoreCalculatedValue = true, then value of calculatedValue will be ignored
    /// - returns: an array with 'Snapshot" readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    func getLatestBgReadingSnapshots(limit: Int?, fromDate: Date?, forSensor sensor: Sensor?, ignoreRawData: Bool, ignoreCalculatedValue: Bool) -> [BgReadingSnapshot] {
        var returnValue: [BgReadingSnapshot] = []
        
        // Core Data contexts are not thread-safe. We must run fetches/updates inside
        // performAndWait to ensure all access happens on the context's own queue.
        coreDataManager.mainManagedObjectContext.performAndWait {
            let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.includesPropertyValues = true
            fetchRequest.relationshipKeyPathsForPrefetching = ["sensor"]

            if let fromDate = fromDate {
                fetchRequest.predicate = NSPredicate(format: "timeStamp > %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970))
            }
            
            if let limit = limit, limit >= 0 {
                fetchRequest.fetchLimit = limit
            }

            do {
                let bgReadings = try fetchRequest.execute()
                let sensorId = sensor?.id
                let ignoreSensorId = (sensorId == nil)

                for bgReading in bgReadings {
                    if !ignoreSensorId {
                        guard let fetchedSensor = bgReading.sensor, fetchedSensor.id == sensorId else { continue }
                    }
                    
                    guard (ignoreCalculatedValue || bgReading.calculatedValue != 0.0) && (ignoreRawData || bgReading.rawData != 0.0) else { continue }

                    // this is the big difference here.
                    // Use snapshots instead of BgReading objects to avoid Core Data crashes.
                    // They’re plain value types, detached from the context, and safe to use on any thread.
                    returnValue.append(BgReadingSnapshot(timeStamp: bgReading.timeStamp, calculatedValue: bgReading.calculatedValue, rawData: bgReading.rawData, sensorID: bgReading.sensor?.id, objectID: bgReading.objectID))

                    if let limit = limit, returnValue.count == limit { break }
                }
            } catch {
                let fetchError = error as NSError
                
                trace("in getLatestBgReadingSnapshots, Unable to Execute BgReading Fetch Request: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }

        return returnValue
    }
    
    /// Returns plain Date timestamps for readings in the last 24 hours up to endingAt.
    /// Only readings with meaningful values are included (calculatedValue != 0.0 OR rawData != 0.0).
    /// - Parameters:
    ///   - forSensor: If not nil, restrict results to this sensor.
    ///   - endingAt: The window end time; the window start is "endingAt - 24h".
    /// - Returns: An array of timestamps sorted ascending. May be empty.
    func getReadingTimestampsForLast24h(forSensor sensor: Sensor?, endingAt endDate: Date) -> [Date] {
        var timestamps: [Date] = []
        let twentyFourHoursBefore = endDate.addingTimeInterval(-24 * 3600)

        coreDataManager.mainManagedObjectContext.performAndWait {
            let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.includesPropertyValues = true
            fetchRequest.fetchBatchSize = 512

            var subpredicates: [NSPredicate] = []
            // Meaningful values only
            subpredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "calculatedValue != 0.0"),
                NSPredicate(format: "rawData != 0.0")
            ]))
            // Time window
            subpredicates.append(NSPredicate(format: "timeStamp >= %@ AND timeStamp <= %@", NSDate(timeIntervalSince1970: twentyFourHoursBefore.timeIntervalSince1970), NSDate(timeIntervalSince1970: endDate.timeIntervalSince1970)))
            // Sensor filter if provided
            if let sensorId = sensor?.id {
                subpredicates.append(NSPredicate(format: "sensor.id == %@", sensorId as CVarArg))
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

            do {
                let results = try fetchRequest.execute()
                timestamps.reserveCapacity(results.count)
                for reading in results {
                    timestamps.append(reading.timeStamp)
                }
            } catch {
                let fetchError = error as NSError
                trace("in getReadingTimestampsForLast24h, fetch error: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }

        return timestamps
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
    
    /// Convenience: last snapshot, ignoring value filters
    ///
    /// gets last reading, ignores rawData and calculatedValue
    /// - parameters:
    ///     - sensor: sensor for which reading is asked, if nil then sensor value is ignored
    func lastSnapshot(forSensor sensor: Sensor?) -> BgReadingSnapshot? {
        getLatestBgReadingSnapshots(limit: 1, fromDate: nil, forSensor: sensor, ignoreRawData: true, ignoreCalculatedValue: true).first
    }
    
    /// gets bgReadings, synchronously, in the managedObjectContext's thread
    /// - returns:
    ///        readings sorted by timestamp, ascending (ie first is oldest)
    /// - parameters:
    ///     - to : if specified, only return readings with timestamp  smaller than fromDate (not equal to)
    ///     - from : if specified, only return readings with timestamp greater than fromDate (not equal to)
    ///     - managedObjectContext : the ManagedObjectContext to use
    func getBgReadings(from: Date?, to: Date?, on managedObjectContext: NSManagedObjectContext) -> [BgReading] {
        
        let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
        
        // create predicate
        if let from = from, to == nil {
            let predicate = NSPredicate(format: "timeStamp > %@", NSDate(timeIntervalSince1970: from.timeIntervalSince1970))
            fetchRequest.predicate = predicate
        } else if let to = to, from == nil {
            let predicate = NSPredicate(format: "timeStamp < %@", NSDate(timeIntervalSince1970: to.timeIntervalSince1970))
            fetchRequest.predicate = predicate
        } else if let to = to, let from = from {
            let predicate = NSPredicate(format: "timeStamp < %@ AND timeStamp > %@", NSDate(timeIntervalSince1970: to.timeIntervalSince1970), NSDate(timeIntervalSince1970: from.timeIntervalSince1970))
            fetchRequest.predicate = predicate
        }
        
        var bgReadings = [BgReading]()
        
        managedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                bgReadings = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getBgReadings, Unable to Execute BgReading Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgReadings

    }

    /// Summary accessor for TransmitterReadSuccess feature
    /// Returns earliest timestamp, latest timestamp, and a distinct count of timestamps within the range.
    /// - Parameters:
    ///   - fromDate: If specified, only include readings with timeStamp >= fromDate
    ///   - toDate: If specified, only include readings with timeStamp <= toDate
    ///   - forSensor: If not nil, only include readings belonging to this sensor
    /// - Returns: TransmitterReadSuccessResultwith optional earliest/latest and a distinct timestamps count
    func getTransmitterReadSuccess(fromDate: Date?, toDate: Date?, forSensor sensor: Sensor?) -> TransmitterReadSuccessResult {
        var earliest: Date?
        var latest: Date?
        var distinctCount: Int = 0

        // Build a shared predicate: valid values, optional sensor, optional date range
        var subpredicates: [NSPredicate] = []
        // Only consider readings that have meaningful values
        let validValuePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "calculatedValue != 0.0"),
            NSPredicate(format: "rawData != 0.0")
        ])
        subpredicates.append(validValuePredicate)

        if let sensorId = sensor?.id {
            subpredicates.append(NSPredicate(format: "sensor.id == %@", sensorId as CVarArg))
        }
        if let from = fromDate {
            subpredicates.append(NSPredicate(format: "timeStamp >= %@", NSDate(timeIntervalSince1970: from.timeIntervalSince1970)))
        }
        if let to = toDate {
            subpredicates.append(NSPredicate(format: "timeStamp <= %@", NSDate(timeIntervalSince1970: to.timeIntervalSince1970)))
        }
        let fullPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // 1) Earliest
                do {
                    let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
                    fetchRequest.predicate = fullPredicate
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
                    fetchRequest.fetchLimit = 1
                    fetchRequest.includesPropertyValues = true
                    fetchRequest.returnsObjectsAsFaults = false
                    if let first = try fetchRequest.execute().first { earliest = first.timeStamp }
                }

                // 2) Latest
                do {
                    let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
                    fetchRequest.predicate = fullPredicate
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
                    fetchRequest.fetchLimit = 1
                    fetchRequest.includesPropertyValues = true
                    fetchRequest.returnsObjectsAsFaults = false
                    if let last = try fetchRequest.execute().first { latest = last.timeStamp }
                }

                // 3) Distinct count of timestamps (timestamp-only, distinct)
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "BgReading")
                    fetchRequest.predicate = fullPredicate
                    fetchRequest.resultType = .dictionaryResultType
                    fetchRequest.returnsDistinctResults = true

                    let timeStampDescription = NSExpressionDescription()
                    timeStampDescription.name = "timeStamp"
                    timeStampDescription.expression = NSExpression(forKeyPath: "timeStamp")
                    timeStampDescription.expressionResultType = .dateAttributeType
                    fetchRequest.propertiesToFetch = [timeStampDescription]

                    let dicts = try coreDataManager.mainManagedObjectContext.fetch(fetchRequest)
                    distinctCount = dicts.count
                }

            } catch {
                let fetchError = error as NSError
                trace("in getTransmitterReadSuccess, fetch error: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }

        return TransmitterReadSuccessResult(earliestTimestamp: earliest, latestTimestamp: latest, distinctTimestampsCount: distinctCount)
    }
    
    /// Computes distinct timestamp counts for 6h/12h/24h windows ending at `endDate`,
    /// plus earliest and latest timestamps within the last 24h. If `sensor` is non-nil,
    /// only readings for that sensor are considered. Only meaningful readings are included
    /// (calculatedValue != 0.0 OR rawData != 0.0).
    func getTransmitterReadSuccessWindowCounts(endingAt endDate: Date, forSensor sensor: Sensor?) -> TransmitterReadSuccessWindowCounts {
        var earliest24h: Date?
        var latest24h: Date?
        var count6h: Int = 0
        var count12h: Int = 0
        var count24h: Int = 0

        let sixHoursBefore = endDate.addingTimeInterval(-6 * 3600)
        let twelveHoursBefore = endDate.addingTimeInterval(-12 * 3600)
        let twentyFourHoursBefore = endDate.addingTimeInterval(-24 * 3600)

        // Build base predicate components
        var baseSubpredicates: [NSPredicate] = []
        let validValuePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "calculatedValue != 0.0"),
            NSPredicate(format: "rawData != 0.0")
        ])
        baseSubpredicates.append(validValuePredicate)
        if let sensorId = sensor?.id {
            baseSubpredicates.append(NSPredicate(format: "sensor.id == %@", sensorId as CVarArg))
        }
        let basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: baseSubpredicates)

        // Helper to create slot expression description
        func makeSlotExpressionDescription() -> NSExpressionDescription {
            let slotExpression = NSExpression(forKeyPath: "timeStamp")
            let slotDescription = NSExpressionDescription()
            slotDescription.name = "timeStamp"
            slotDescription.expression = slotExpression
            slotDescription.expressionResultType = .dateAttributeType
            return slotDescription
        }

        // Helper to get distinct slot count in a window
        func distinctSlotCount(from: Date, to: Date) throws -> Int {
            let requestFetch = NSFetchRequest<NSDictionary>(entityName: "BgReading")
            var subPredicates: [NSPredicate] = []
            subPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "calculatedValue != 0.0"),
                NSPredicate(format: "rawData != 0.0")
            ]))
            if let sensorId = sensor?.id {
                subPredicates.append(NSPredicate(format: "sensor.id == %@", sensorId as CVarArg))
            }
            subPredicates.append(NSPredicate(format: "timeStamp >= %@", NSDate(timeIntervalSince1970: from.timeIntervalSince1970)))
            subPredicates.append(NSPredicate(format: "timeStamp <= %@", NSDate(timeIntervalSince1970: to.timeIntervalSince1970)))
            requestFetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
            requestFetch.resultType = .dictionaryResultType
            requestFetch.returnsDistinctResults = true
            requestFetch.propertiesToFetch = [makeSlotExpressionDescription()]
            let dicts = try coreDataManager.mainManagedObjectContext.fetch(requestFetch)
            return dicts.count
        }

        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Earliest in last 24h
                do {
                    let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        basePredicate,
                        NSPredicate(format: "timeStamp >= %@", NSDate(timeIntervalSince1970: twentyFourHoursBefore.timeIntervalSince1970))
                    ])
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
                    fetchRequest.fetchLimit = 1
                    fetchRequest.includesPropertyValues = true
                    fetchRequest.returnsObjectsAsFaults = false
                    if let first = try fetchRequest.execute().first {
                        earliest24h = first.timeStamp
                    }
                }

                // Latest in last 24h (up to endDate)
                do {
                    let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        basePredicate,
                        NSPredicate(format: "timeStamp <= %@", NSDate(timeIntervalSince1970: endDate.timeIntervalSince1970))
                    ])
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
                    fetchRequest.fetchLimit = 1
                    fetchRequest.includesPropertyValues = true
                    fetchRequest.returnsObjectsAsFaults = false
                    if let last = try fetchRequest.execute().first {
                        latest24h = last.timeStamp
                    }
                }

                // 6h distinct count
                count6h = try distinctSlotCount(from: sixHoursBefore, to: endDate)
                // 12h distinct count
                count12h = try distinctSlotCount(from: twelveHoursBefore, to: endDate)
                // 24h distinct count
                count24h = try distinctSlotCount(from: twentyFourHoursBefore, to: endDate)

            } catch {
                let fetchError = error as NSError
                trace("in getTransmitterReadSuccessWindowCounts, fetch error: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }

        return TransmitterReadSuccessWindowCounts(earliestTimestampInLast24h: earliest24h, latestTimestampInLast24h: latest24h, distinctCountLast6h: count6h,
            distinctCountLast12h: count12h, distinctCountLast24h: count24h)
    }
    
    /// deletes bgReading, synchronously, in the managedObjectContext's thread
    ///     - bgReading : bgReading to delete
    ///     - managedObjectContext : the ManagedObjectContext to use
    func delete(bgReading: BgReading, on managedObjectContext: NSManagedObjectContext) {
        
        managedObjectContext.performAndWait {
            
            managedObjectContext.delete(bgReading)
            
            // save changes to coredata
            do {
                
                try managedObjectContext.save()
                
            } catch {
                
                trace("in delete bgReading,  Unable to Save Changes, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, error.localizedDescription)
                
            }

        }
        
    }
    
    
    /// deletes bgReading
    ///     - bgReading : bgReading to delete
    func delete(bgReading: BgReading) {
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            
            coreDataManager.mainManagedObjectContext.delete(bgReading)
            
            // save changes to coredata
            do {
                
                try coreDataManager.mainManagedObjectContext.save()
                
            } catch {
                
                trace("in delete bgReading,  Unable to Save Changes, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, error.localizedDescription)
                
            }

        }
        
    }
    
    
    // MARK: - private helper functions
    
    /// returnvalue can be empty array
    /// - parameters:
    ///     - limit: maximum amount of readings to fetch, if 0 then no limit
    ///     - fromDate : if specified, only return readings with timestamp > fromDate
    /// - returns:
    ///     List of readings, descending, ie first is youngest
    private func fetchBgReadings(limit:Int?, fromDate:Date?) -> [BgReading] {
        let fetchRequest: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: false)]
        
        // if fromDate specified then create predicate
        if let fromDate = fromDate {
            let predicate = NSPredicate(format: "timeStamp > %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970))
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
                trace("in fetchBgReadings, Unable to Execute BgReading Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgReadings
    }
    
}
