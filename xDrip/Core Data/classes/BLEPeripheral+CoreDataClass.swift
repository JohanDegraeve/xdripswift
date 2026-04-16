import Foundation
import CoreData

/// - has attributes which are common to all kinds of BluetoothPeripheral : address, name, shouldconnect, alias, parameterUpdateNeededAtNextConnect.
/// - the name is very close the the protocol BluetoothPeripheral, bad luck that's all
public class BLEPeripheral: NSManagedObject {
 
    /// - libre sensor type, not stored in coreData, will only be available after having received it from the Bubble
    /// - if nil, then it's not known yet
    /// - will only be used for BLEPeripherals that support Libre
    public var libreSensorType: LibreSensorType?

    /// create BLEPeripheral, shouldconnect default value = true
    init(address: String, name: String, alias: String?, bluetoothPeripheralType: BluetoothPeripheralType, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "BLEPeripheral", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        self.shouldconnect = true
        self.alias = alias
        self.parameterUpdateNeededAtNextConnect = false
     
        webOOPEnabled = ConstantsLibre.defaultWebOOPEnabled && bluetoothPeripheralType.canWebOOP()
        
        nonFixedSlopeEnabled = ConstantsLibre.defaultNonFixedSlopeEnabled
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
