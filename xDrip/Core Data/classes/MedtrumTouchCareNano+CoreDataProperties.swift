import Foundation
import CoreData

extension MedtrumTouchCareNano {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedtrumTouchCareNano> {
        return NSFetchRequest<MedtrumTouchCareNano>(entityName: "MedtrumTouchCareNano")
    }

    /// blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral

    /// firmware version, if discovered
    @NSManaged public var firmware: String?

}
