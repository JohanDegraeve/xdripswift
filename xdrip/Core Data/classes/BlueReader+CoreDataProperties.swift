import Foundation
import CoreData

extension BlueReader {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlueReader> {
        return NSFetchRequest<BlueReader>(entityName: "BlueReader")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
}
