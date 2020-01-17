import Foundation
import os
import CoreData

class AlertTypesAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataAlertTypes)
    
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
                trace("in getAlertType, Unable to Execute alertTypes Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataAlertTypes, type: .error, fetchError.localizedDescription)
            }
        }

        // if alertType found then return it, if not create one
        if let alertType = alertTypes.first {
            return alertType
        } else {
            let defaultAlertType =  AlertType(enabled: ConstantsDefaultAlertTypeSettings.enabled, name: Texts_Common.default0, overrideMute: ConstantsDefaultAlertTypeSettings.overrideMute, snooze: ConstantsDefaultAlertTypeSettings.snooze, snoozePeriod: Int(ConstantsDefaultAlertTypeSettings.snoozePeriod), vibrate: ConstantsDefaultAlertTypeSettings.vibrate, soundName: ConstantsSounds.getSoundName(forSound: .xdripalert), alertEntries: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            coreDataManager.saveChanges()
            return defaultAlertType
        }
    }
    
    /// get all alert types, if there's no alerttypes yet, then the default alerttpye will be returned
    public func getAllAlertTypes() -> [AlertType] {
        // create fetchRequest
        let fetchRequest: NSFetchRequest<AlertType> = AlertType.fetchRequest()
        
        // fetch the alerttypes
        var alertTypes = [AlertType]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                alertTypes = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getAllAlertTypes, Unable to Execute alertTypes Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataAlertTypes, type: .error, fetchError.localizedDescription)
            }
        }
        
        // if there's no alerttypes yet, then get default AlertTYpe, this will also create the alerttype and store it in coredata
        if alertTypes.count == 0 {
            return [getDefaultAlertType()]
        } else {
            return alertTypes
        }
    }
}
