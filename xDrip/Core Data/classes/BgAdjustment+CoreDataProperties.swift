//
//  BgAdjustment+CoreDataProperties.swift
//  xdrip
//
//  Created by Paul Plant on 1/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

extension BgAdjustment {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BgAdjustment> {
        return NSFetchRequest<BgAdjustment>(entityName: "BgAdjustment")
    }

    @NSManaged public var adjustmentShapeType: Int16
    @NSManaged public var applyFromTimeStamp: Date
    @NSManaged public var enteredBgValue: NSNumber?
    @NSManaged public var id: String
    @NSManaged public var intercept: Double
    @NSManaged public var isBasicAdjustment: Bool
    @NSManaged public var isEnabled: Bool
    @NSManaged public var slope: Double
    @NSManaged public var sourceCalculatedValue: NSNumber?
    @NSManaged public var sourceContextIdentifier: String
    @NSManaged public var sourceDescription: String?
    @NSManaged public var timeStamp: Date
}
