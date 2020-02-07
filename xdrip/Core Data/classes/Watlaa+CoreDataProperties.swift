import Foundation
import CoreData


extension Watlaa {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Watlaa> {
        return NSFetchRequest<Watlaa>(entityName: "Watlaa")
    }

    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
}
