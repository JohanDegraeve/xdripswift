import Foundation
import CoreData

public class Libre2: NSManagedObject {
    
    /// sensor time in Minutes if known
    var sensorTimeInMinutes: Int?
    
    /// create Libre2
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Libre2", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, bluetoothPeripheralType: .Libre2Type, nsManagedObjectContext: nsManagedObjectContext)
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
