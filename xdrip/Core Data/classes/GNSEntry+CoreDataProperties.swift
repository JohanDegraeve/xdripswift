import Foundation
import CoreData

extension GNSEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GNSEntry> {
        return NSFetchRequest<GNSEntry>(entityName: "GNSEntry")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral

    /// bootloader
    @NSManaged public var bootLoader: String?
    
    /// firmwareVersion
    @NSManaged public var firmwareVersion: String?
    
    /// serialNumber
    @NSManaged public var serialNumber: String?
    
}
