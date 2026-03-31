import Foundation
import CoreData

extension Bubble {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Bubble> {
        return NSFetchRequest<Bubble>(entityName: "Bubble")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
    /// firmware
    @NSManaged public var firmware: String?
    
    /// hardware
    @NSManaged public var hardware: String?
    
}
