import Foundation
import CoreData

public class Bubble: NSManagedObject {
    
    /// batterylevel, not stored in coreData, will only be available after having received it from the Bubble
    public var batteryLevel: Int = 0
    
    // sensorState
    public var sensorState: LibreSensorState = .unknown
    
    /// create Bubble
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Bubble", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)
        
    }
    
    /// create Bubble
    /// - parameters:
    init(address: String, name: String, alias: String?, sensorSerialNumber: String?, webOOPEnabled: Bool, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Bubble", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, nsManagedObjectContext: nsManagedObjectContext)

        blePeripheral.webOOPEnabled = webOOPEnabled

    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
