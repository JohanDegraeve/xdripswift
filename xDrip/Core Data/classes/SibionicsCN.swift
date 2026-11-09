import CoreData
import Foundation

@objc(SibionicsCN)
public final class SibionicsCN: NSManagedObject, BluetoothPeripheral {
    @NSManaged public var blePeripheral: BLEPeripheral
    @NSManaged public var sensorCode: String?
    @NSManaged public var declaredMAC: String?
    @NSManaged public var startAuthorized: Bool
    init(address: String, name: String, alias: String?, nsManagedObjectContext: NSManagedObjectContext) {
        super.init(entity: NSEntityDescription.entity(forEntityName: "SibionicsCN", in: nsManagedObjectContext)!, insertInto: nsManagedObjectContext)
        blePeripheral = BLEPeripheral(address: address, name: name, alias: alias, bluetoothPeripheralType: .SibionicsCNType, nsManagedObjectContext: nsManagedObjectContext)
        blePeripheral.shouldconnect = false
        blePeripheral.webOOPEnabled = true
    }
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) { super.init(entity: entity, insertInto: context) }
    func bluetoothPeripheralType() -> BluetoothPeripheralType { .SibionicsCNType }
    func getAddress() -> String { blePeripheral.address }
    func getDeviceName() -> String? { blePeripheral.name }
}
