import Foundation
import os
import CoreData

class M5StackAccessor {
    
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataM5Stacks)

    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    func getM5Stacks() -> [M5Stack] {
        
        // create fetchRequest
        let fetchRequest: NSFetchRequest<M5Stack> = M5Stack.fetchRequest()
        
        // fetch the M5Stacks
        var m5Stacks = [M5Stack]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                m5Stacks = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getM5Stacks, Unable to Execute m5Stacks Fetch Request : %{public}@", log: self.log, type: .error, fetchError.localizedDescription)
            }
        }
        
        return m5Stacks

    }
}
