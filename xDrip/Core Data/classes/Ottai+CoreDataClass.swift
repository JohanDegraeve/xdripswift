import Foundation
import CoreData

/// The Core Data object for an Ottai / Syai CGM. The keys and the cloud login are
/// stored in UserDefaults (see OttaiRegistry). This object only holds the normal
/// Bluetooth device data, so the sensor shows up in xDrip's device list.
public class Ottai: NSManagedObject {

    init(address: String, name: String, alias: String?, nsManagedObjectContext: NSManagedObjectContext) {

        let entity = NSEntityDescription.entity(forEntityName: "Ottai", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)

        blePeripheral = BLEPeripheral(address: address, name: name, alias: alias, bluetoothPeripheralType: .OttaiType, nsManagedObjectContext: nsManagedObjectContext)
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
