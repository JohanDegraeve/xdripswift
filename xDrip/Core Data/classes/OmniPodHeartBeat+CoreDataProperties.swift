//
//  OmniPodHeartBeat+CoreDataProperties.swift
//
//
//  Created by Johan Degraeve on 08/02/2024
//
//

import Foundation
import CoreData


extension OmniPodHeartBeat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OmniPodHeartBeat> {
        return NSFetchRequest<OmniPodHeartBeat>(entityName: "OmniPodHeartBeat")
    }

    @NSManaged public var blePeripheral: BLEPeripheral
}
