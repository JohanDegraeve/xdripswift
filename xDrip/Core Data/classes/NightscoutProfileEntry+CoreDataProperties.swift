//
//  NightscoutProfileEntry+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

extension NightscoutProfileEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NightscoutProfileEntry> {
        return NSFetchRequest<NightscoutProfileEntry>(entityName: "NightscoutProfileEntry")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var dia: NSNumber?
    @NSManaged public var enteredBy: String?
    @NSManaged public var id: String
    @NSManaged public var isMgDl: NSNumber?
    @NSManaged public var lastCheckedDate: Date
    @NSManaged public var profileName: String?
    @NSManaged public var startDate: Date
    @NSManaged public var timezone: String?
    @NSManaged public var updatedDate: Date
    @NSManaged public var schedules: NSSet?
}

extension NightscoutProfileEntry {

    @objc(addSchedulesObject:)
    @NSManaged public func addToSchedules(_ value: NightscoutProfileScheduleEntry)

    @objc(removeSchedulesObject:)
    @NSManaged public func removeFromSchedules(_ value: NightscoutProfileScheduleEntry)

    @objc(addSchedules:)
    @NSManaged public func addToSchedules(_ values: NSSet)

    @objc(removeSchedules:)
    @NSManaged public func removeFromSchedules(_ values: NSSet)
}
