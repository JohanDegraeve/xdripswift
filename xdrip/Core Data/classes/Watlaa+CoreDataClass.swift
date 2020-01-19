import Foundation
import CoreData

public class Watlaa: NSManagedObject {

    /// explanation, see function parameterUpdateNotNeededAtNextConnect in protocol BluetoothPeripheral
    public var parameterUpdateNeeded: Bool = false
    
    /// battery level , not stored in coredata,
    public var batteryLevel: Int?

    /// create Watlaa, shouldconnect default value = true
    /// - parameters:
    ///     - rotation is internally stored as Int32, actual value should always be between 0 and 360 so UInt16 as parameter is sufficient.
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Watlaa", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        self.shouldconnect = true
        self.alias = alias
        
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
