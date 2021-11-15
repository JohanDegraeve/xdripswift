import Foundation
import os
import CoreData

class CalibrationsAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        
    }
    
    // MARK: - functions
    
    /// get first calibration (ie oldest) for currently active sensor and with sensorconfidence and slopeconfidence != 0
    /// - parameters:
    ///     - withActivesensor : should be currently active sensor
    /// - returns:
    ///     - the first calibration, can be nil
    func firstCalibrationForActiveSensor(withActivesensor sensor:Sensor) -> Calibration? {
        return getFirstOrLastCalibration(withActivesensor: sensor, first: true)
    }

    /// get last calibration (ie youngest) for currently active sensor and with sensorconfidence and slopeconfidence != 0
    /// - parameters:
    ///     - withActivesensor : should be currently active sensor - if nil then returnvalue is also nil
    /// - returns:
    ///     - the last calibration, can be nil
    func lastCalibrationForActiveSensor(withActivesensor sensor:Sensor?) -> Calibration? {
        
        guard let sensor = sensor else {return nil}
        
        return getFirstOrLastCalibration(withActivesensor: sensor, first: false)
        
    }
    
    /// Returns last calibrations, possibly zero
    /// - parameters:
    ///     - howManyDays: yes how many days of calibrations, maximum off course because result can be 0 calibrations
    ///     - forSensor: for which sensor, if nil then sensorid is igored
    /// - returns:
    ///     - array of calibrations, can have size 0 if there's no calibration matching
    ///     - ordered by timestamp, large to small (descending) ie the first is the youngest
    func getLatestCalibrations(howManyDays amount:Int, forSensor sensor:Sensor?) -> Array<Calibration> {
        
        // create fetchrequest
        let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        
        // sort ascending, ie first element will be first calibration
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: false)]
        
        // define predicates
        var subPredicate1:NSPredicate?
        if let sensor = sensor {
            subPredicate1 = NSPredicate(format: "sensor == %@", sensor)
        }
        let subPredicate2 = NSPredicate(format: "timeStamp > %@", NSDate(timeIntervalSinceNow: Double(-amount*24*3600)))
        if let subPredicate1 = subPredicate1 {
            fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [subPredicate1, subPredicate2])
        } else {
            fetchRequest.predicate = subPredicate2
        }

        var calibrations = [Calibration]()
        
        // fetch the calibrations
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                calibrations = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getLatestCalibrations, Unable to Execute Fetch Request : %{public}@", log: log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        return calibrations
    }
    
    /// gets calibrations, synchronously, in the managedObjectContext's thread
    /// - returns:
    ///        calibrations sorted by timestamp, ascending (ie first is oldest)
    /// - parameters:
    ///     - to : if specified, only return calibrations with timestamp  smaller than fromDate (not equal to)
    ///     - from : if specified, only return calibrations with timestamp greater than fromDate (not equal to)
    ///     - managedObjectContext : the ManagedObjectContext to use
    func getCalibrations(from: Date?, to: Date?, on managedObjectContext: NSManagedObjectContext) -> [Calibration] {
        
        let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: true)]
        
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
        
        var calibrations = [Calibration]()
        
        managedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                calibrations = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getCalibrations, Unable to Execute Calibration Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        
        return calibrations
        
    }

    /// deletes Calibration, synchronously, in the managedObjectContext's thread
    ///     - calibration : calibration to delete
    ///     - managedObjectContext : the ManagedObjectContext to use
    func delete(calibration: Calibration, on managedObjectContext: NSManagedObjectContext) {
        
        managedObjectContext.performAndWait {
            
            managedObjectContext.delete(calibration)
            
            // save changes to coredata
            do {
                try managedObjectContext.save()
            } catch {
                trace("in delete calibration,  Unable to Save Changes, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, error.localizedDescription)
            }

        }
                
    }
    

    // MARK: - private helper functions
    
    private func getFirstOrLastCalibration(withActivesensor sensor:Sensor, first:Bool) -> Calibration? {
        // create fetchrequest
        let fetchRequest: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: first)]
        
        // define predicates
        let subPredicate1 = NSPredicate(format: "sensor == %@", sensor)
        let subPredicate2 = NSPredicate(format: "sensorConfidence != %@", 0.0)
        let subPredicate3 = NSPredicate(format: "slopeConfidence != %@", 0.0)
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [subPredicate1, subPredicate2, subPredicate3])
        
        // set limit to 1
        fetchRequest.fetchLimit = 1
        
        var calibrations = [Calibration]()
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                calibrations = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getFirstOrLastCalibration, Unable to Execute Fetch Request : %{public}@", log: log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        
        if calibrations.count > 0 {
            return calibrations[0]
        } else {
            return nil
        }
    }
}
