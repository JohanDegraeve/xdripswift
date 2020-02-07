import Foundation
import CoreData

extension BLEPeripheral {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BLEPeripheral> {
        return NSFetchRequest<BLEPeripheral>(entityName: "BLEPeripheral")
    }
    
    /// bluetooth peripheral mac address
    @NSManaged public var address: String
    
    /// bluetooth peripheral device name
    @NSManaged public var name: String
    
    /// should app try to connect to the device yes or no
    @NSManaged public var shouldconnect: Bool
    
    /// alias chosen by user, to recognize the device or to distinguish two devices that have the same name
    @NSManaged public var alias: String?
    
    /// optional because not every transmitter type needs it, and even for transmitter types that need it, it's not available at the moment an object is instantiated, because for new peripherals, the assignment of transmitterId happens in the viewmodel, when user clicks the done button
    @NSManaged public var transmitterId: String?

    /// typical for M5Stack but can also be applicable for other device types. If app is connected, and user makes an update to one of the attributes, then the new value can immediately be sent. If app is not connected, then the sending must happen as soon as reconnect occurs. Then parameterUpdateNeededAtNextConnect will be set to true
    @NSManaged public var parameterUpdateNeededAtNextConnect: Bool
    
    /// a BLEPeripheral should only have one of dexcomG5, watlaa, m5Stack, ...
    @NSManaged public var dexcomG5: DexcomG5?
    
    /// a BLEPeripheral should only have one of dexcomG5, watlaa, m5Stack, ...
    @NSManaged public var watlaa: Watlaa?
    
    /// a BLEPeripheral should only have one of dexcomG5, watlaa, m5Stack, ...
    @NSManaged public var m5Stack: M5Stack?
    
}
