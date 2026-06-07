//
//  AlertEntry+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 14/04/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//
//

import CoreData
import Foundation

public extension AlertEntry {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AlertEntry> {
        return NSFetchRequest<AlertEntry>(entityName: "AlertEntry")
    }

    @NSManaged var isDisabled: Bool
    @NSManaged var start: Int16
    @NSManaged var value: Int16
    @NSManaged var triggerValue: Int16
    @NSManaged var alertkind: Int16
    @NSManaged var alertType: AlertType
}
