//
//  DexcomG7+CoreDataProperties.swift
//
//
//  Created by Johan Degraeve on 08/02/2024
//
//

import Foundation
import CoreData


extension DexcomG7 {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG7> {
        return NSFetchRequest<DexcomG7>(entityName: "DexcomG7")
    }

    @NSManaged public var blePeripheral: BLEPeripheral
    
    @NSManaged public var sensorStatus: String?

    /// Latest complete firmware string returned by the sensor's `0x4A` version response.
    @NSManaged public var firmwareVersion: String?
    /// Build identifier returned with the full firmware record.
    @NSManaged public var firmwareBuildVersion: NSNumber?
    /// Compatibility version code returned with the full firmware record.
    @NSManaged public var firmwareVersionCode: NSNumber?

    /// Raw battery response status byte retained for developer diagnostics.
    @NSManaged public var batteryStatus: Int32
    /// Voltage A in the Dexcom protocol's 10 mV units.
    @NSManaged public var voltageA: Int32
    /// Voltage B in the Dexcom protocol's 10 mV units.
    @NSManaged public var voltageB: Int32
    /// Internal resistance value returned beside both battery voltages.
    @NSManaged public var batteryResist: Int32
    /// Sensor runtime counter from the battery response.
    @NSManaged public var batteryRuntime: Int32
    /// Signed temperature value reported by the sensor battery record.
    @NSManaged public var batteryTemperature: Int32
    /// Time of the last complete battery response from this disposable sensor.
    @NSManaged public var batteryLastReadDate: Date?

    /// - contains sensor start date, received from transmitter
    @NSManaged public var sensorStartDate: Date?

    /// Four-digit applicator code required when this saved sensor uses Primary mode.
    @NSManaged public var sensorCode: String?
    /// Optional lot number decoded from the applicator Data Matrix.
    @NSManaged public var sensorLotNumber: String?
    /// Sensor serial number decoded from the applicator Data Matrix.
    @NSManaged public var sensorSerialNumber: String?
    /// Global Trade Item Number retained from the scan for persistence and diagnostics.
    @NSManaged public var sensorProductIdentifier: String?
    /// Manufacturing date decoded from the applicator Data Matrix.
    @NSManaged public var sensorManufactureDate: Date?
    /// Package expiry date decoded from the applicator Data Matrix.
    @NSManaged public var sensorExpirationDate: Date?
    /// Complete sensor session length reported by `0x52`, including the 12-hour grace period.
    @NSManaged public var sensorSessionLength: NSNumber?
    /// Optional persisted connection choice. `nil` identifies a pre-v28 saved sensor.
    @NSManaged public var useOtherAppValue: NSNumber?
    /// Optional Primary authentication slot. Coexistence mode does not use this value.
    @NSManaged public var bluetoothSlot: NSNumber?

}

extension DexcomG7: DexcomBluetoothSlotPersisting {
    var useOtherApp: Bool {
        get { useOtherAppValue?.boolValue ?? true }
        set { useOtherAppValue = NSNumber(value: newValue) }
    }

    /// Materializes settings written by pre-v28 builds. New code reads and writes only Core Data.
    func migrateLegacySettingsIfNeeded() {
        if useOtherAppValue == nil {
            useOtherApp = UserDefaults.standard.dexcomG7UseOtherApp
        }
        if sensorCode == nil {
            sensorCode = UserDefaults.standard.dexcomG7PairingCode(for: blePeripheral.transmitterId)
        }
        if bluetoothSlot == nil {
            setBluetoothSlot(UserDefaults.standard.dexcomG7BluetoothSlot(for: blePeripheral.transmitterId))
        }
    }
    func effectiveDexcomG7BluetoothSlot() -> DexcomG7BluetoothSlot {
        effectiveBluetoothSlot(as: DexcomG7BluetoothSlot.self)
    }

    func resolvedDexcomG7BluetoothSlot() -> DexcomG7BluetoothSlot {
        resolvedBluetoothSlot(as: DexcomG7BluetoothSlot.self)
    }

    func apply(sensorLabel: DexcomG6SensorLabel?) {
        guard let sensorLabel else { return }
        sensorCode = sensorLabel.sensorCode
        sensorLotNumber = sensorLabel.lotNumber.isEmpty ? nil : sensorLabel.lotNumber
        sensorSerialNumber = sensorLabel.serialNumber.isEmpty ? nil : sensorLabel.serialNumber
        sensorProductIdentifier = sensorLabel.productIdentifier
        sensorManufactureDate = sensorLabel.manufactureDate
        sensorExpirationDate = sensorLabel.expirationDate
    }

    var storedSensorLabel: DexcomG6SensorLabel? {
        guard let sensorCode else { return nil }
        return DexcomG6SensorLabel(
            sensorCode: sensorCode,
            lotNumber: sensorLotNumber ?? "",
            serialNumber: sensorSerialNumber ?? "",
            productIdentifier: sensorProductIdentifier,
            manufactureDate: sensorManufactureDate,
            expirationDate: sensorExpirationDate
        )
    }
}
