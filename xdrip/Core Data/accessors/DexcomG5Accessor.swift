import Foundation
import CoreData
import os

class DexcomG5Accessor {
    
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataDexcomG5)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    /// gets all DexcomG5 instances from coredata
    func getDexcomG5s() -> [DexcomG5] {
        
        // create fetchRequest to get DexcomG5's as DexcomG5 classes
        let DexcomG5FetchRequest: NSFetchRequest<DexcomG5> = DexcomG5.fetchRequest()
        
        // fetch the DexcomG5's
        var DexcomG5Array = [DexcomG5]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                DexcomG5Array = try DexcomG5FetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getDexcomG5s, Unable to Execute DexcomG5s Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataDexcomG5, type: .error, fetchError.localizedDescription)
            }
        }
        
        return DexcomG5Array
        
    }
    
}
