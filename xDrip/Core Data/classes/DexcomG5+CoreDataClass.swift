import Foundation
import CoreData

/// used for DexcomG5 and G6
public class DexcomG5: NSManagedObject {
    
    /// should reset be done ? Not stored in coreData, means will be reset to false each time app is resarted
    public var resetRequired: Bool = false

    /// create DexcomG5
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "DexcomG5", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, bluetoothPeripheralType: .DexcomType, nsManagedObjectContext: nsManagedObjectContext)
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
