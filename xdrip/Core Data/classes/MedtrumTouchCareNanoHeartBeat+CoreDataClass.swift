import Foundation
import CoreData

public class MedtrumTouchCareNanoHeartBeat: NSManagedObject {

    /// create MedtrumTouchCareNanoHeartBeat
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {

        let entity = NSEntityDescription.entity(forEntityName: "MedtrumTouchCareNanoHeartBeat", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)

        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, bluetoothPeripheralType: .MedtrumTouchCareNanoHeartBeatType, nsManagedObjectContext: nsManagedObjectContext)

    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

}
