import CoreData
import Foundation

@objc(Aidex)
public final class Aidex: NSManagedObject {

    /// create Aidex
    init(address: String, name: String, alias: String?, nsManagedObjectContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Aidex", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)

        blePeripheral = BLEPeripheral(address: address, name: name, alias: alias, bluetoothPeripheralType: .AidexType, nsManagedObjectContext: nsManagedObjectContext)
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}