//
//  SnoozeParameters+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 14/04/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension SnoozeParameters {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SnoozeParameters> {
        return NSFetchRequest<SnoozeParameters>(entityName: "SnoozeParameters")
    }
    
    /// the alertKind for which these snooze parameters are applicable
    @NSManaged public var alertKind: Int16

    /// this is snooze period chosen by user, nil value is not snoozed
    @NSManaged public var snoozePeriodInMinutes:Int16
    
    /// when was the alert snoozed, nil is not snoozed
    @NSManaged public var snoozeTimeStamp:Date?

}
