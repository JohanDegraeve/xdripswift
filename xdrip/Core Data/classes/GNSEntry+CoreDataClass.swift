import Foundation
import CoreData

public class GNSEntry: NSManagedObject {
    
    /// batterylevel, not stored in coreData, will only be available after having received it from the M5Stack
    public var batteryLevel: Int = 0
    
    /// create GNSEntry
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "GNSEntry", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
        
    }
    
    /// create GNSEntry
    /// - parameters:
    init(address: String, name: String, alias: String?, timeStampLastBgReading: Date?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "GNSEntry", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.timeStampLastBgReading = timeStampLastBgReading
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

        blePeripheral.webOOPEnabled = false

    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
