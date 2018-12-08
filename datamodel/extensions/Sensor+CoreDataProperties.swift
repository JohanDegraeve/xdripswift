//
//  Sensor+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 06/12/2018.
//  Copyright © 2018 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension Sensor {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sensor> {
        return NSFetchRequest<Sensor>(entityName: "Sensor")
    }

    @NSManaged public var endDate: Date
    @NSManaged public var startDate: Date
    @NSManaged public var id: String

}
