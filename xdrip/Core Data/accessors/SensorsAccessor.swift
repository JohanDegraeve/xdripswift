import Foundation
import os
import CoreData

class SensorsAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataSensors)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - functions
    
    /// will get sensor with enddate nil (ie not stopped) and highest startDate,
    /// otherwise returns nil
    ///
    ///
    func fetchActiveSensor() -> Sensor? {
        // create fetchRequest
        let fetchRequest: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: false)]
        fetchRequest.fetchLimit = 1
        
        // only sensors with endDate nil, ie not started, should be only one in the end
        let predicate = NSPredicate(format: "endDate == nil")
        fetchRequest.predicate = predicate

        // define returnvalue
        var returnValue:Sensor?
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                let sensors = try fetchRequest.execute()
                
                if sensors.count > 0 {
                    if sensors[0].endDate == nil {
                        returnValue = sensors[0]
                    }
                }
            } catch {
                let fetchError = error as NSError
                trace("Unable to Execute Sensor Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryCoreDataManager, type: .error, fetchError.localizedDescription)
            }
        }
        
        return returnValue
    }
}

