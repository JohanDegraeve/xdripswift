//
//  Alert+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 14/04/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension Alert {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Alert> {
        return NSFetchRequest<Alert>(entityName: "Alert")
    }

    @NSManaged public var type: Int32
    @NSManaged public var alertEntries: NSSet

}

// MARK: Generated accessors for alertEntries
extension Alert {

    @objc(addAlertEntriesObject:)
    @NSManaged public func addToAlertEntries(_ value: AlertEntry)

    @objc(removeAlertEntriesObject:)
    @NSManaged public func removeFromAlertEntries(_ value: AlertEntry)

    @objc(addAlertEntries:)
    @NSManaged public func addToAlertEntries(_ values: NSSet)

    @objc(removeAlertEntries:)
    @NSManaged public func removeFromAlertEntries(_ values: NSSet)

}
