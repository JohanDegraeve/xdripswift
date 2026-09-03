import Foundation
import CoreData

extension Ottai {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Ottai> {
        return NSFetchRequest<Ottai>(entityName: "Ottai")
    }

    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral

    /// the cloud id (12 hex characters); it can be different from the Bluetooth address
    @NSManaged public var ottaiSensorId: String?
}
