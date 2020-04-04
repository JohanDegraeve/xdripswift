import Foundation
import CoreData

extension Droplet {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Droplet> {
        return NSFetchRequest<Droplet>(entityName: "Droplet")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
}
