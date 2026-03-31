import Foundation
import CoreData
import os

class BLEPeripheralAccessor {
    
    // MARK: - Properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBLEPeripheral)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: Public functions
    
    /// gets all BLEPeripheral instances from coredata
    func getBLEPeripherals() -> [BLEPeripheral] {
        
        // create fetchRequest to get BLEPeripheral's as BLEPeripheral classes
        let blePeripheralFetchRequest: NSFetchRequest<BLEPeripheral> = BLEPeripheral.fetchRequest()
        
        // fetch the BLEPeripherals
        var blePeripheralArray = [BLEPeripheral]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                // Execute Fetch Request
                blePeripheralArray = try blePeripheralFetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getBLEPeripherals, Unable to Execute BLEPeripherals Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBLEPeripheral, type: .error, fetchError.localizedDescription)
            }
        }
        
        return blePeripheralArray
        
    }
    
}
