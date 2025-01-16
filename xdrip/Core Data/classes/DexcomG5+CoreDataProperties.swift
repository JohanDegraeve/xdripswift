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
    
    @NSManaged public var transmitterStartDate: Date?
    
    /// - contains sensor start date, received from transmitter
    /// - if the user starts the sensor via xDrip4iOS, then only after having receivec a confirmation from the transmitter, then sensorStartDate will be assigned to the actual sensor start date
    @NSManaged public var sensorStartDate: Date?
    
    @NSManaged public var sensorStatus: String?
    
    /// if true then other app will be used in parallel with the same transmitter (only for firefly)
    @NSManaged public var useOtherApp: Bool
    
    @NSManaged public var isAnubis: Bool
    
}
