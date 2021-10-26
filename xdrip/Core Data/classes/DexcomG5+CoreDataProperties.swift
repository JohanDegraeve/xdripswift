import Foundation
import CoreData

extension DexcomG5 {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG5> {
        return NSFetchRequest<DexcomG5>(entityName: "DexcomG5")
    }
    
    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral
    
    @NSManaged public var firmwareVersion: String?
    
    @NSManaged public var batteryResist: Int32
    
    @NSManaged public var batteryRuntime: Int32
    
    @NSManaged public var batteryStatus: Int32
    
    @NSManaged public var batteryTemperature: Int32
    
    @NSManaged public var voltageA: Int32
    
    @NSManaged public var voltageB: Int32
    
    @NSManaged public var lastResetTimeStamp: Date?
    
    @NSManaged public var isDexcomG6: Bool
    
    @NSManaged public var transmitterStartDate: Date?
    
    @NSManaged public var sensorStartDate: Date?
    
}
