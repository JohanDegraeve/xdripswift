//
//  AlertType+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 14/04/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension AlertType {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlertType> {
        return NSFetchRequest<AlertType>(entityName: "AlertType")
    }

    @NSManaged public var name: String
    @NSManaged public var enabled: Bool
    @NSManaged public var vibrate: Bool
    @NSManaged public var snooze: Bool
    @NSManaged public var snoozeperiod: Int16
    @NSManaged public var soundname: String?
    @NSManaged public var alertEntries: NSSet?
    @NSManaged public var overridemute: Bool

}

// MARK: Generated accessors for alertEntries
extension AlertType {

    @objc(addAlertEntriesObject:)
    @NSManaged public func addToAlertEntries(_ value: AlertEntry)

    @objc(removeAlertEntriesObject:)
    @NSManaged public func removeFromAlertEntries(_ value: AlertEntry)

    @objc(addAlertEntries:)
    @NSManaged public func addToAlertEntries(_ values: NSSet)

    @objc(removeAlertEntries:)
    @NSManaged public func removeFromAlertEntries(_ values: NSSet)

}
