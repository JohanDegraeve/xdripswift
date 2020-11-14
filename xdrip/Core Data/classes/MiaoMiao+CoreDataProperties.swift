import Foundation
import CoreData

extension MiaoMiao {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MiaoMiao> {
        return NSFetchRequest<MiaoMiao>(entityName: "MiaoMiao")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
    /// firmware
    @NSManaged public var firmware: String?
    
    /// hardware
    @NSManaged public var hardware: String?
    
}
