import Foundation
import os
import CoreData

class WatlaaAccessor {
    
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataWatlaa)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    /// gets all Watlaa instances from coredata
    func getWatlaas() -> [Watlaa] {
        
        // create fetchRequest to get watlaa's as Watlaa classes
        let watlaaFetchRequest: NSFetchRequest<Watlaa> = Watlaa.fetchRequest()
        
        // fetch the Watlaa's
        var watlaaArray = [Watlaa]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                watlaaArray = try watlaaFetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getWatlaas, Unable to Execute Watlaas Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        return watlaaArray
        
    }
    
}
