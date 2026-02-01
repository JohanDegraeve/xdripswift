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
        
    /// should non fixed slopes be used or not - defined here to make it easier for coding, although not every type of bluetoothperipheral needs this
    @NSManaged public var nonFixedSlopeEnabled: Bool

    /// should weboop be used or not - defined here to make it easier for coding, although not every type of bluetoothperipheral needs this
    @NSManaged public var webOOPEnabled: Bool

    /// - a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    /// - dexcomG5 is also used for dexcomG6
    @NSManaged public var dexcomG5: DexcomG5?
    
    /// a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var m5Stack: M5Stack?
    
    /// a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var bubble: Bubble?
  
    /// a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var miaoMiao: MiaoMiao?
    
    // a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var libre2: Libre2?
    
    // a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var libre2heartbeat: Libre2HeartBeat?

    // a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var dexcomG7HeartBeat: DexcomG7HeartBeat?

    // a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var omniPodHeartBeat: OmniPodHeartBeat?
    
    // a BLEPeripheral should only have one of dexcomG5, m5Stack, ...
    @NSManaged public var dexcomG7: DexcomG7?
    
    /// sensorSerialNumber of last sensor that was read
    @NSManaged public var sensorSerialNumber: String?

    /// timestamp when connection changed to connected or not connected
    @NSManaged public var lastConnectionStatusChangeTimeStamp: Date?
    
}
