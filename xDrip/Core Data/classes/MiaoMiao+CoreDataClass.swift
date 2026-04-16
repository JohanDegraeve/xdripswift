import Foundation
import CoreData

public class MiaoMiao: NSManagedObject {
    
    /// batterylevel, not stored in coreData, will only be available after having received it from the M5Stack
    public var batteryLevel: Int = 0
    
    // sensorState
    public var sensorState: LibreSensorState = .unknown
    
  /// create MiaoMiao
    /// - parameters:
    init(address: String, name: String, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "MiaoMiao", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, bluetoothPeripheralType: .MiaoMiaoType, nsManagedObjectContext: nsManagedObjectContext)
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
