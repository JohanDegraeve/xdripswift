//
//  Calibration+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 23/12/2018.
//  Copyright © 2018 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension Calibration {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Calibration> {
        return NSFetchRequest<Calibration>(entityName: "Calibration")
    }

    @NSManaged public var adjustedRawValue: Double
    @NSManaged public var bg: Double
    @NSManaged public var checkIn: Bool
    @NSManaged public var distanceFromEstimate: Double
    @NSManaged public var estimateBgAtTimeOfCalibration: Double
    @NSManaged public var estimateRawAtTimeOfCalibration: Double
    @NSManaged public var firstDecay: Double
    @NSManaged public var firstIntercept: Double
    @NSManaged public var firstScale: Double
    @NSManaged public var firstSlope: Double
    @NSManaged public var id: String
    @NSManaged public var intercept: Double
    @NSManaged public var possibleBad: Bool
    @NSManaged public var rawTimeStamp: Date?
    @NSManaged public var rawValue: Double
    @NSManaged public var secondDecay: Double
    @NSManaged public var secondIntercept: Double
    @NSManaged public var secondScale: Double
    @NSManaged public var secondSlope: Double
    @NSManaged public var sensorConfidence: Double
    @NSManaged public var slope: Double
    @NSManaged public var slopeConfidence: Double
    @NSManaged public var timeStamp: Date
    @NSManaged public var bgreadings: NSSet
    @NSManaged public var sensor: Sensor

}

// MARK: Generated accessors for bgreadings
extension Calibration {

    @objc(addBgreadingsObject:)
    @NSManaged public func addToBgreadings(_ value: BgReading)

    @objc(removeBgreadingsObject:)
    @NSManaged public func removeFromBgreadings(_ value: BgReading)

    @objc(addBgreadings:)
    @NSManaged public func addToBgreadings(_ values: NSSet)

    @objc(removeBgreadings:)
    @NSManaged public func removeFromBgreadings(_ values: NSSet)

}
