import Foundation
import CoreData

extension Libre2 {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Libre2> {
        return NSFetchRequest<Libre2>(entityName: "Libre2")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
}
