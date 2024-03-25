//
//  DexcomG7HeartBeat+CoreDataProperties.swift
//
//
//  Created by Johan Degraeve on 08/02/2024
//
//

import Foundation
import CoreData


extension DexcomG7HeartBeat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DexcomG7HeartBeat> {
        return NSFetchRequest<DexcomG7HeartBeat>(entityName: "DexcomG7HeartBeat")
    }

    @NSManaged public var blePeripheral: BLEPeripheral
    
}
