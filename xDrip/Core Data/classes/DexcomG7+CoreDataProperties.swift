//
//  DexcomG7+CoreDataProperties.swift
//
//
//  Created by Johan Degraeve on 08/02/2024
//
//

import Foundation
import CoreData


extension DexcomG7 {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG7> {
        return NSFetchRequest<DexcomG7>(entityName: "DexcomG7")
    }

    @NSManaged public var blePeripheral: BLEPeripheral
    
    @NSManaged public var sensorStatus: String?

    /// - contains sensor start date, received from transmitter
    @NSManaged public var sensorStartDate: Date?

}
