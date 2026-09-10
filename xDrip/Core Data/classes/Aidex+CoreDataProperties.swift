import CoreData
import Foundation

extension Aidex {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Aidex> {
        return NSFetchRequest<Aidex>(entityName: "Aidex")
    }

    @NSManaged public var blePeripheral: BLEPeripheral

    /// UUID string of the CoreBluetooth peripheral, used for direct reconnection
    @NSManaged public var peripheralIdentifier: String?

    /// firmware version read from DIS
    @NSManaged public var firmwareVersion: String?

    /// model name read from DIS
    @NSManaged public var modelName: String?
}