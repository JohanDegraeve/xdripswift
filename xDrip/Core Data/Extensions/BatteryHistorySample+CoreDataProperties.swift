//
//  BatteryHistorySample+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 1/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

/// Persisted raw fields for a genuine battery observation. Optional protocol fields are populated
/// only when that measurement family supplies them.
extension BatteryHistorySample {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BatteryHistorySample> {
        NSFetchRequest<BatteryHistorySample>(entityName: "BatteryHistorySample")
    }

    @NSManaged public var batteryStatusRaw: NSNumber?
    @NSManaged public var dexcomFamilyRaw: NSNumber?
    @NSManaged public var id: String
    @NSManaged public var measurementKindRaw: Int16
    @NSManaged public var observedAt: Date
    @NSManaged public var percentage: NSNumber?
    @NSManaged public var producerKindRaw: Int16
    @NSManaged public var resistanceRaw: NSNumber?
    @NSManaged public var runtimeRaw: NSNumber?
    @NSManaged public var temperatureRaw: NSNumber?
    @NSManaged public var utcHourBucketStart: Date?
    @NSManaged public var voltageARaw: NSNumber?
    @NSManaged public var voltageBRaw: NSNumber?
    @NSManaged public var blePeripheral: BLEPeripheral
}
