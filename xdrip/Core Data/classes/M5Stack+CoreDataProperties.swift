//
//  M5Stack+CoreDataProperties.swift
//  
//
//  Created by Johan Degraeve on 21/09/2019.
//
//

import Foundation
import CoreData


extension M5Stack {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<M5Stack> {
        return NSFetchRequest<M5Stack>(entityName: "M5Stack")
    }

    @NSManaged public var address: String?
    @NSManaged public var name: String?
    @NSManaged public var blepassword: String?

}
