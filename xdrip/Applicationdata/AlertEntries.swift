import Foundation
import os
import CoreData

class AlertEntries {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryApplicationDataAlertEntries)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    // MARK: - functions
    
    /// will check for the specified date (only the time of the day will be used) which AlertEntry is applicable, then for that Alertentry, get the AlertType. Should not be nil. In case it is, a default value will be returned
    func getCurrentAndNextAlertEntry(alertKind:AlertKind, forWhen:Date, alertTypes:AlertTypes) -> (currentAlertEntry:AlertEntry, nextAlertEntry: AlertEntry?) {
        
        // create fetchrequest
        let fetchRequest: NSFetchRequest<AlertEntry> = AlertEntry.fetchRequest()
        // sort by value, when searching through the alertentries later, we'll try to find the matching entry, by comparing forWhen with value
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(AlertEntry.value), ascending: true)]
        
        // predicate to get only alertentries for the specified alertKind
        let predicate = NSPredicate(format: "alertkind = %i", Int32(alertKind.rawValue))
        fetchRequest.predicate = predicate
        
        // fetch the alert entries
        var alertEntries = [AlertEntry]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                alertEntries = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                os_log("in getAlertEntry, Unable to Execute AlertEntry Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        // get the number of minutes in the date
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: forWhen)
        let minute = calendar.component(.minute, from: forWhen)
        let minutes:Int16 = Int16(hour * 60 + minute)
        
        // search through the alert entries for the current and next alertentry
        var currentEntry:AlertEntry?
        var nextAlertEntry:AlertEntry?
        loop: for alertEntry in alertEntries {
            if alertEntry.value <= minutes {
                currentEntry = alertEntry
            } else {
                nextAlertEntry = alertEntry
                break loop
            }
        }
        if let currentAlertEntry = currentEntry {
            return (currentAlertEntry, nextAlertEntry)
        } else {
            let  newAlertEntry = AlertEntry(value: alertKind.defaultAlertValue(), alertKind: alertKind, start: 0, alertType: alertTypes.getDefaultAlertType(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            coreDataManager.saveChanges()
            return (newAlertEntry, nextAlertEntry)
        }
    }

}
