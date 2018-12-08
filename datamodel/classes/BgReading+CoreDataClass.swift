//
//  BgReading+CoreDataClass.swift
//  xdrip
//
//  Created by Johan Degraeve on 02/12/2018.
//  Copyright © 2018 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


public class BgReading: NSManagedObject {
    init(
        timeStamp:Date,
        sensor:Sensor?,
        calibration:Calibration?,
        rawData:Double,
        filteredData:Double,
        nsManagedObjectContext:NSManagedObjectContext
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BgReading", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        self.timeStamp = timeStamp
        self.sensor = sensor
        self.calibration = calibration
        self.rawData = rawData
        self.filteredData = filteredData
        
        ageAdjustedRawValue = 0
        calibrationFlag = false
        calculatedValue = 0
        filteredCalculatedValue = 0
        calculatedValueSlope = 0
        a = 0
        b = 0
        c = 0
        ra = 0
        rb = 0
        rc = 0
        rawCalculated  = 0
        hideSlope = false
        id = UniqueId.createEventId()
    }
}
