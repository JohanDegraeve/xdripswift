import Foundation
import CoreData

extension DexcomG5 {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG5> {
        return NSFetchRequest<DexcomG5>(entityName: "DexcomG5")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
    @NSManaged public var firmwareVersion: String?
    
}
