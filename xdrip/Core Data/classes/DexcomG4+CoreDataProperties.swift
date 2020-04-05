import Foundation
import CoreData

extension DexcomG4 {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG4> {
        return NSFetchRequest<DexcomG4>(entityName: "DexcomG4")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
}
