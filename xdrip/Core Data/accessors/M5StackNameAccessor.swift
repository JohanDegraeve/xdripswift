import Foundation
import os
import CoreData

class M5StackNameAccessor {
 
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataM5StackNames)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    func getM5StackNames() -> [M5StackName] {
        
        // create fetchRequest
        let fetchRequest: NSFetchRequest<M5StackName> = M5StackName.fetchRequest()
        
        // fetch the M5StackNames
        var M5StackNames = [M5StackName]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                M5StackNames = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getM5StackNames, Unable to Execute M5StackNames Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        return M5StackNames
        
    }
    
    func deleteM5StackName(m5StackName: M5StackName) {
        
        coreDataManager.mainManagedObjectContext.delete(m5StackName)
        
    }

}
