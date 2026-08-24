//
//  NightscoutDeviceStatusEntry+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

extension NightscoutDeviceStatusEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NightscoutDeviceStatusEntry> {
        return NSFetchRequest<NightscoutDeviceStatusEntry>(entityName: "NightscoutDeviceStatusEntry")
    }

    @NSManaged public var activeProfile: String?
    @NSManaged public var appVersion: String?
    @NSManaged public var bolusVolume: NSNumber?
    @NSManaged public var cob: NSNumber?
    @NSManaged public var createdAt: Date
    @NSManaged public var currentTarget: NSNumber?
    @NSManaged public var device: String?
    @NSManaged public var duration: NSNumber?
    @NSManaged public var error: String?
    @NSManaged public var eventualBG: NSNumber?
    @NSManaged public var id: String
    @NSManaged public var insulinReq: NSNumber?
    @NSManaged public var iob: NSNumber?
    @NSManaged public var isf: NSNumber?
    @NSManaged public var lastCheckedDate: Date
    @NSManaged public var lastLoopDate: Date
    @NSManaged public var overrideActive: NSNumber?
    @NSManaged public var overrideMaxValue: NSNumber?
    @NSManaged public var overrideMinValue: NSNumber?
    @NSManaged public var overrideMultiplier: NSNumber?
    @NSManaged public var overrideName: String?
    @NSManaged public var pumpBatteryPercent: NSNumber?
    @NSManaged public var pumpIsBolusing: NSNumber?
    @NSManaged public var pumpIsSuspended: NSNumber?
    @NSManaged public var pumpManufacturer: String?
    @NSManaged public var pumpModel: String?
    @NSManaged public var pumpReservoir: NSNumber?
    @NSManaged public var pumpStatus: String?
    @NSManaged public var pumpStatusTimestamp: Date?
    @NSManaged public var rate: NSNumber?
    @NSManaged public var reason: String?
    @NSManaged public var sensitivityRatio: NSNumber?
    @NSManaged public var tdd: NSNumber?
    @NSManaged public var timestamp: Date?
    @NSManaged public var updatedDate: Date
    @NSManaged public var uploaderBatteryPercent: NSNumber?
    @NSManaged public var uploaderIsCharging: NSNumber?
}
