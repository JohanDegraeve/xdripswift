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

    /// The raw Dexcom authentication role. Nil resolves to the family default for migrated stores.
    @NSManaged public var bluetoothSlot: NSNumber?
    
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

/// Shared storage contract for Dexcom transmitter families that persist a Bluetooth slot.
/// DexcomG7 can adopt the same contract when its protocol slot values are established.
protocol DexcomBluetoothSlotPersisting: AnyObject {
    var bluetoothSlot: NSNumber? { get set }
}

extension DexcomBluetoothSlotPersisting {
    /// Returns the stored slot or the family default without changing persistent storage.
    func effectiveBluetoothSlot<Slot: DexcomBluetoothSlotValue>(as _: Slot.Type) -> Slot {
        bluetoothSlot.flatMap { storedValue in
            let integerValue = storedValue.intValue
            guard Int(UInt8.min)...Int(UInt8.max) ~= integerValue else { return nil }
            return Slot(rawValue: UInt8(integerValue))
        } ?? Slot.defaultSlot
    }

    /// Returns a valid typed slot and materializes the family default when storage is missing or invalid.
    func resolvedBluetoothSlot<Slot: DexcomBluetoothSlotValue>(as _: Slot.Type) -> Slot {
        let resolvedSlot = effectiveBluetoothSlot(as: Slot.self)

        if bluetoothSlot?.intValue != Int(resolvedSlot.rawValue) {
            bluetoothSlot = NSNumber(value: resolvedSlot.rawValue)
        }

        return resolvedSlot
    }

    func setBluetoothSlot<Slot: DexcomBluetoothSlotValue>(_ slot: Slot) {
        bluetoothSlot = NSNumber(value: slot.rawValue)
    }
}

extension DexcomG5: DexcomBluetoothSlotPersisting {}

extension DexcomG5 {
    /// Applies the Anubis-only Slot 3 rule without changing persistent storage.
    func effectiveDexcomG6BluetoothSlot() -> DexcomG6BluetoothSlot {
        effectiveBluetoothSlot(as: DexcomG6BluetoothSlot.self).normalized(isAnubis: isAnubis)
    }

    /// Returns a usable slot and repairs stale Slot 3 values on non-Anubis transmitters.
    func resolvedDexcomG6BluetoothSlot() -> DexcomG6BluetoothSlot {
        let resolvedSlot = effectiveDexcomG6BluetoothSlot()

        if bluetoothSlot?.intValue != Int(resolvedSlot.rawValue) {
            setBluetoothSlot(resolvedSlot)
        }

        return resolvedSlot
    }
}
