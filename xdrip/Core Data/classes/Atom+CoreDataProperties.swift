import Foundation
import CoreData

extension Atom {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Atom> {
        return NSFetchRequest<Atom>(entityName: "Atom")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
    /// firmware
    @NSManaged public var firmware: String?
    
    /// hardware
    @NSManaged public var hardware: String?
    
}
