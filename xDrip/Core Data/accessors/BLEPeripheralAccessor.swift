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

    /// Returns the hardware-reported start date for the active Dexcom battery family.
    ///
    /// G5, G6 and ONE have a reusable transmitter, so their battery settles relative to the
    /// transmitter's own start date. G7, ONE+ and Stelo contain a disposable transmitter in each
    /// sensor, so their equivalent battery age begins at the sensor start date.
    ///
    /// This deliberately does not use Bluetooth connection dates. Dexcom devices disconnect and
    /// reconnect as part of normal operation, and using those dates would repeatedly restart the
    /// battery-alert suppression period.
    func activeDexcomBatteryStartDate(for family: DexcomBatteryFamily) -> Date? {
        var startDate: Date?

        coreDataManager.mainManagedObjectContext.performAndWait {
            let fetchRequest: NSFetchRequest<BLEPeripheral> = BLEPeripheral.fetchRequest()

            do {
                // The application permits only one active CGM. Still inspect every enabled
                // peripheral so a non-CGM heartbeat cannot hide the active Dexcom relationship.
                let activePeripherals = try fetchRequest.execute().filter(\.shouldconnect)

                switch family {
                case .g5:
                    startDate = activePeripherals.compactMap(\.dexcomG5?.transmitterStartDate).first
                case .g7:
                    startDate = activePeripherals.compactMap(\.dexcomG7?.sensorStartDate).first
                }
            } catch {
                let fetchError = error as NSError
                trace("in activeDexcomBatteryStartDate, Unable to Execute BLEPeripherals Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataBLEPeripheral, type: .error, fetchError.localizedDescription)
            }
        }

        return startDate
    }
    
}
