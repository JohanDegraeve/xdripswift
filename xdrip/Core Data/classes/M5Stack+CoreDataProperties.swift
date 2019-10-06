//
//  M5Stack+CoreDataProperties.swift
//  xdrip
//
//  Created by Johan Degraeve on 06/10/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//
//

import Foundation
import CoreData


extension M5Stack {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<M5Stack> {
        return NSFetchRequest<M5Stack>(entityName: "M5Stack")
    }

    @NSManaged public var address: String
    @NSManaged public var blepassword: String?
    @NSManaged public var name: String
    @NSManaged public var shouldconnect: Bool
    @NSManaged public var textcolor: Int32
    @NSManaged public var m5StackName: M5StackName?

}
