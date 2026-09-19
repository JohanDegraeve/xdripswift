import Foundation
import CoreData
import os

class SnoozeParametersAccessor {
    
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataSnoozeParameter)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    /// - gets one SnoozeParameters instance for every current AlertKind
    /// - creates records for kinds that are genuinely missing from Core Data
    /// - returns them in raw-value order because AlertManager indexes this array by AlertKind.rawValue
    func getSnoozeParameters() -> [SnoozeParameters] {
        
        // create fetchRequest to get SnoozeParameters's as SnoozeParameters classes
        let snoozeParametersFetchRequest: NSFetchRequest<SnoozeParameters> = SnoozeParameters.fetchRequest()
        
        // sort by alertkind from low to high
        snoozeParametersFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SnoozeParameters.alertKind), ascending: true)]
        
        // ensure objects are fully realized before returning
        snoozeParametersFetchRequest.returnsObjectsAsFaults = false
        snoozeParametersFetchRequest.includesPropertyValues = true
        
        // fetch the SnoozeParameterss
        var snoozeParameterArray = [SnoozeParameters]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                snoozeParameterArray = try snoozeParametersFetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getSnoozeParameterss, Unable to Execute SnoozeParameterss Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataSnoozeParameter, type: .error, fetchError.localizedDescription)
            }
            
            // Reconcile by the persisted raw value, never by the number of fetched rows. A database
            // can legitimately contain a raw value introduced by a newer development build, and it
            // can contain a missing or duplicate row after an older restore. Using `count..<allCases`
            // traps when there are more stored rows than current cases and can silently misalign the
            // array when one kind is missing. Unknown future rows are deliberately left in Core Data
            // so installing an older build cannot erase settings needed after upgrading again.
            var storedByRawValue = [Int: SnoozeParameters]()
            for parameters in snoozeParameterArray {
                let rawValue = Int(parameters.alertKind)
                guard AlertKind(rawValue: rawValue) != nil else { continue }

                if let existing = storedByRawValue[rawValue] {
                    // Do not return two objects for one array index. If legacy data contains a
                    // duplicate, the most recently snoozed row carries the most useful state.
                    if Self.shouldPrefer(parameters, over: existing) {
                        storedByRawValue[rawValue] = parameters
                    }
                } else {
                    storedByRawValue[rawValue] = parameters
                }
            }

            snoozeParameterArray = AlertKind.allCases
                .sorted { $0.rawValue < $1.rawValue }
                .map { alertKind in
                    if let stored = storedByRawValue[alertKind.rawValue] {
                        return stored
                    }
                    return SnoozeParameters(
                        alertKind: alertKind,
                        snoozePeriodInMinutes: 0,
                        snoozeTimeStamp: nil,
                        nsManagedObjectContext: coreDataManager.mainManagedObjectContext
                    )
                }
            
            // persist new SnoozeParameters if any were created
            if coreDataManager.mainManagedObjectContext.hasChanges {
                do {
                    try coreDataManager.mainManagedObjectContext.save()
                } catch {
                    let saveError = error as NSError
                    trace("in getSnoozeParameterss, Unable to Save SnoozeParameters : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataSnoozeParameter, type: .error, saveError.localizedDescription)
                }
            }
        }
        
        return snoozeParameterArray
    }

    /// Chooses a deterministic canonical row when legacy data contains duplicate alert kinds.
    /// A timestamp means the row has carried a snooze, and the newest timestamp represents the
    /// latest user action. Equal or absent timestamps retain the first fetched row.
    private static func shouldPrefer(_ candidate: SnoozeParameters, over existing: SnoozeParameters) -> Bool {
        switch (candidate.snoozeTimeStamp, existing.snoozeTimeStamp) {
        case let (candidateDate?, existingDate?):
            return candidateDate > existingDate
        case (.some, .none):
            return true
        case (.none, _):
            return false
        }
    }
}
