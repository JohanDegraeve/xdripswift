//
//  Libre2HeartBeat+CoreDataProperties.swift
//  
//
//  Created by Johan Degraeve on 06/08/2023.
//
//

import Foundation
import CoreData


extension Libre2HeartBeat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Libre2HeartBeat> {
        return NSFetchRequest<Libre2HeartBeat>(entityName: "Libre2HeartBeat")
    }

    @NSManaged public var blePeripheral: BLEPeripheral

}
