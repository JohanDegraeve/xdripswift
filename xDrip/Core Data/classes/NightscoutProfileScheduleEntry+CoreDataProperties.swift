//
//  NightscoutProfileScheduleEntry+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

extension NightscoutProfileScheduleEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NightscoutProfileScheduleEntry> {
        return NSFetchRequest<NightscoutProfileScheduleEntry>(entityName: "NightscoutProfileScheduleEntry")
    }

    @NSManaged public var kind: Int16
    @NSManaged public var timeAsSecondsFromMidnight: Int32
    @NSManaged public var value: Double
    @NSManaged public var profile: NightscoutProfileEntry?
}
