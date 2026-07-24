//
//  SensorNoiseSample+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

extension SensorNoiseSample {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SensorNoiseSample> {
        return NSFetchRequest<SensorNoiseSample>(entityName: "SensorNoiseSample")
    }

    @NSManaged public var id: String
    @NSManaged public var longTermNoise: NSNumber?
    @NSManaged public var sensorID: String
    @NSManaged public var shortTermNoise: NSNumber?
    @NSManaged public var stateRaw: Int16
    @NSManaged public var timeStamp: Date
    @NSManaged public var sensor: Sensor
}
