//
//  BgAdjustment+CoreDataClass.swift
//  xdrip
//
//  Created by Paul Plant on 1/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

public class BgAdjustment: NSManagedObject {

    init(timeStamp: Date, applyFromTimeStamp: Date, slope: Double, intercept: Double, adjustmentShapeType: Int16, isEnabled: Bool, isBasicAdjustment: Bool, enteredBgValue: Double?, sourceCalculatedValue: Double?, sourceDescription: String?, sourceContextIdentifier: String, nsManagedObjectContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "BgAdjustment", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)

        self.id = UniqueId.createEventId()
        self.timeStamp = timeStamp
        self.applyFromTimeStamp = applyFromTimeStamp
        self.slope = slope
        self.intercept = intercept
        self.adjustmentShapeType = adjustmentShapeType
        self.isEnabled = isEnabled
        self.isBasicAdjustment = isBasicAdjustment
        self.enteredBgValue = enteredBgValue as NSNumber?
        self.sourceCalculatedValue = sourceCalculatedValue as NSNumber?
        self.sourceDescription = sourceDescription
        self.sourceContextIdentifier = sourceContextIdentifier
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
