//
//  M5StackName+CoreDataProperties.swift
//  
//
//  Created by Johan Degraeve on 22/09/2019.
//
//

import Foundation
import CoreData


extension M5StackName {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<M5StackName> {
        return NSFetchRequest<M5StackName>(entityName: "M5StackName")
    }

    @NSManaged public var address: String
    @NSManaged public var userDefinedName: String

}
