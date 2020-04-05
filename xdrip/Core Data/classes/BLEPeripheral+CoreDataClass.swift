import Foundation
import CoreData

/// - has attributes which are common to all kinds of BluetoothPeripheral : address, name, shouldconnect, alias, parameterUpdateNeededAtNextConnect.
/// - the name is very close the the protocol BluetoothPeripheral, bad luck that's all
public class BLEPeripheral: NSManagedObject {
    
    /// create BLEPeripheral, shouldconnect default value = true
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "BLEPeripheral", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        self.shouldconnect = true
        self.alias = alias
        self.parameterUpdateNeededAtNextConnect = false
     
        webOOPEnabled = ConstantsLibreOOP.defaultWebOOPEnabled
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
