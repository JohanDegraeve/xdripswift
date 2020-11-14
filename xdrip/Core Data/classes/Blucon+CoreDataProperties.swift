import Foundation
import CoreData

extension Blucon {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Blucon> {
        return NSFetchRequest<Blucon>(entityName: "Blucon")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
}
