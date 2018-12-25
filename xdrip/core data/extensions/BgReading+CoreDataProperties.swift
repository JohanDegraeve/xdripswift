//
//  BgReading+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 23/12/2018.
//  Copyright © 2018 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension BgReading {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BgReading> {
        return NSFetchRequest<BgReading>(entityName: "BgReading")
    }

    @NSManaged public var a: Double
    @NSManaged public var ageAdjustedRawValue: Double
    @NSManaged public var b: Double
    @NSManaged public var c: Double
    @NSManaged public var calculatedValue: Double
    @NSManaged public var calculatedValueSlope: Double
    @NSManaged public var calibrationFlag: Bool
    @NSManaged public var filteredCalculatedValue: Double
    @NSManaged public var filteredData: Double
    @NSManaged public var hideSlope: Bool
    @NSManaged public var id: String
    @NSManaged public var ra: Double
    @NSManaged public var rawCalculated: Double
    @NSManaged public var rawData: Double
    @NSManaged public var rb: Double
    @NSManaged public var rc: Double
    @NSManaged public var timeStamp: Date
    @NSManaged public var calibration: Calibration?
    @NSManaged public var sensor: Sensor?

}
