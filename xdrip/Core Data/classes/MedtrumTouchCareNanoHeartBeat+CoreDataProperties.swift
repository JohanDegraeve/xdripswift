import Foundation
import CoreData

extension MedtrumTouchCareNanoHeartBeat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedtrumTouchCareNanoHeartBeat> {
        return NSFetchRequest<MedtrumTouchCareNanoHeartBeat>(entityName: "MedtrumTouchCareNanoHeartBeat")
    }

    @NSManaged public var blePeripheral: BLEPeripheral

}
