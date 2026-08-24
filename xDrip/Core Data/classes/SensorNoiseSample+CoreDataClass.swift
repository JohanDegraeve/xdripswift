//
//  SensorNoiseSample+CoreDataClass.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation

/// One stored sensor noise measurement linked to the sensor session that produced it.
public class SensorNoiseSample: NSManagedObject {

    /// Creates a history sample from the same measurement model used by live noise calculations.
    init(timeStamp: Date, measurement: SensorNoiseMeasurement, sensor: Sensor, nsManagedObjectContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "SensorNoiseSample", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)

        id = UniqueId.createEventId()
        self.timeStamp = timeStamp
        shortTermNoise = measurement.shortTermNoise.map(NSNumber.init(value:))
        longTermNoise = measurement.longTermNoise.map(NSNumber.init(value:))
        stateRaw = measurement.state.rawValue
        sensorID = sensor.id
        self.sensor = sensor
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
