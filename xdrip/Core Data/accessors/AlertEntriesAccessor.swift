import Foundation
import os
import CoreData

class AlertEntriesAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataAlertEntries)
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    // MARK: - functions
    
    /// will check for the specified date (only the time of the day will be used) which AlertEntry is applicable, then for that Alertentry, get the AlertType. Should not be nil. In case it is, a default value will be returned
    ///
    /// if the currentAlertEntry is the last of the day, then the nextAlertEntry in the return value will be the alertentry with start 0
    func getCurrentAndNextAlertEntry(forAlertKind alertKind:AlertKind, forWhen when:Date, alertTypesAccessor:AlertTypesAccessor) -> (currentAlertEntry:AlertEntry, nextAlertEntry: AlertEntry?) {
        
        // fetch the alert entries
        let alertEntries = getAllEntries(forAlertKind: alertKind, alertTypesAccessor: alertTypesAccessor)
        
        // get the number of minutes in the date
        let minutes = Int16(when.minutesSinceMidNightLocalTime())

        // initialize currentEntry and nextAlertEntry with nil
        var currentEntry:AlertEntry?
        var nextAlertEntry:AlertEntry?

        // search through the alert entries for the current and next alertentry
        loop: for alertEntry in alertEntries {
            if alertEntry.start <= minutes {
                currentEntry = alertEntry
            } else {
                nextAlertEntry = alertEntry
                break loop
            }
        }
        
        guard let current = currentEntry else {
            // No entries exist (unexpected); return first if any, else nils or assert.
            return (alertEntries.first!, alertEntries.dropFirst().first)
        }
        
        // if there's no nextalertentry, but there is a currententry with start > 0 then pick as nextalertentry the first of the day, this one is applicable the day after at 00:00
        if nextAlertEntry == nil && current.start > 0 {
            nextAlertEntry = alertEntries.first
        }
        
        // explicitly unwrap, because when calling getAllEntries, there should have been at least one alertEntry
        return (current, nextAlertEntry)
    }
    
    /// gets all entries for a specific alertkind, sorted by start - if there's no alertEntries yet in the coredata, then a default alert will be created, with default values as defined per alertKind
    /// - parameters:
    ///     - alertKind the alertKind for which AlertEntries should be fetched, if nil then all AlertEntries are fetched, still sorted by start
    ///     - alertTypesAccessor needed for in case there's no alertEntries for a specific alertKind, then a default alertentry will be created. If alertKind = nil, then this check will be done for every alertkind
    func getAllEntries(forAlertKind alertKind:AlertKind?, alertTypesAccessor:AlertTypesAccessor) -> [AlertEntry] {
        
        // create fetchrequest
        let fetchRequest: NSFetchRequest<AlertEntry> = AlertEntry.fetchRequest()
        
        // sort by start
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(AlertEntry.start), ascending: true)]
        
        // predicate to get only alertentries for the specified alertKind
        if let alertKind = alertKind {
            fetchRequest.predicate = NSPredicate(format: "alertkind = %i", Int32(alertKind.rawValue))
        }
        
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.includesPropertyValues = true
        
        // fetch the alert entries
        var alertEntries = [AlertEntry]()
        
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                alertEntries = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getAlertEntries, Unable to Execute AlertEntry Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataAlertEntries, type: .error, fetchError.localizedDescription)
            }
            
            // check for each alertKind if there's at least one alertentry and if not create a default one - if the parameter alertKind is not nil then do this only for this alertKind
            for alertKindInCases in AlertKind.allCases {
                if alertKind != nil && alertKind != alertKindInCases {
                    // input parameter is not nil, but the alertKindInCases != alertKind, skip this one
                } else {
                    // check if there's at least one alertentry for alertKindInCases
                    var entryFound = false
                    alertentryloop: for alertEntry in alertEntries {
                        if alertEntry.alertkind == alertKindInCases.rawValue {
                            entryFound = true
                            break alertentryloop
                        }
                    }
                    if (!entryFound) {
                        // there's no entry found for alertKindInCases, create one and save it in coredata
                        let  newAlertEntry = AlertEntry(value: alertKindInCases.defaultAlertValue(), alertKind: alertKindInCases, start: 0, alertType: alertTypesAccessor.getDefaultAlertType(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                        
                        // insert it at location 0, because it has a start 0, to keep it sorted correctly, at least per alertkind
                        alertEntries.insert(newAlertEntry, at: 0)
                        
                        coreDataManager.saveChanges()
                    }
                }
            }
        }
        
        return alertEntries
    }
    
    /// returns an array of AlertEntry arrays, one AlertEntry array per AlertKind
    ///
    /// - each array has an array of AlertEntry arrays, sorted by rawValue of the AlertKinds, ie the first array will be the AlertEntries for low alert
    /// - each AlertEntry array has a list of AlertEntries for a specific alertKind, sorted by start
    /// - parameters:
    ///     - alertTypesAccessor needed for in case there's no alertEntries for a specific alertKind, then a default alertentry will be created. If alertKind = nil, then this check will be done for every alertkind
    func getAllEntriesPerAlertKind(alertTypesAccessor:AlertTypesAccessor) -> [[AlertEntry]] {
        
        // initialize returnvalue
        var returnValue = [[AlertEntry]]()
        
        // loop through alertkinds
        for alertKind in AlertKind.allCases {
            // get all alertEntries for this AlertKind
            let alertEntries = getAllEntries(forAlertKind: alertKind, alertTypesAccessor: alertTypesAccessor)
            returnValue.append(alertEntries)
        }

        return returnValue
    }
}
