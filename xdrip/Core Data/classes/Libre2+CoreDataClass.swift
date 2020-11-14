import Foundation
import CoreData

public class Libre2: NSManagedObject {
    
    // sensorState, not stored in coreData, will only be available after having received it from the Libre2
    public var sensorState: LibreSensorState = .unknown
    
    /// create Libre2
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Libre2", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
        
    }
    
    /// create Libre2
    /// - parameters:
    init(address: String, name: String, alias: String?, sensorSerialNumber: String?, webOOPEnabled: Bool, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Libre2", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

        blePeripheral.webOOPEnabled = webOOPEnabled

    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
