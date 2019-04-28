import Foundation
import os
import CoreData

class AlertTypes {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryApplicationDataAlertTypes)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    // MARK: - functions
    
    // wil get the first created alertType, if there isn't any, then it will create one that is not enabled and that one will be the 
    public func getDefaultAlertType() -> AlertType {
        
        // create fetchRequest
        let fetchRequest: NSFetchRequest<AlertType> = AlertType.fetchRequest()
        // limit to 1, although there shouldn't be more than 1, later I need to create constraints so there can't be more than one alertType with the same name
        fetchRequest.fetchLimit = 1
        
        // predicate to get only alertType with name default
        let predicate = NSPredicate(format: "name = %@", Texts_Common.default0)
        fetchRequest.predicate = predicate
        
        // fetch the alerttype
        var alertTypes = [AlertType]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                alertTypes = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                os_log("in getAlertType, Unable to Execute alertTypes Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }

        // if alertType found then return it, if not create one
        if let alertType = alertTypes.first {
            return alertType
        } else {
            let defaultAlertType =  AlertType(enabled: true, name: Texts_Common.default0, overrideMute: false, snooze: true, snoozePeriod: 60, vibrate: true, soundName: "xDrip Alert", alertEntries: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            coreDataManager.saveChanges()
            return defaultAlertType
        }
    }
}
