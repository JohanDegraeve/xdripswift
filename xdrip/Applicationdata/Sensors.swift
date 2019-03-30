import Foundation
import os
import CoreData

class Sensors {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryApplicationDataSensors)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - functions
    
    /// will actually get last stored sensor (ie highest startdate) and if enddate of that sensor is nil then returns that sensor
    /// otherwise returns nil
    func fetchActiveSensor() -> Sensor? {
        // create fetchRequest
        let fetchRequest: NSFetchRequest<Sensor> = Sensor.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Sensor.startDate), ascending: false)]
        fetchRequest.fetchLimit = 1

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
                os_log("Unable to Execute Sensor Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        return returnValue
    }
}

