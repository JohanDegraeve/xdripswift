//
//  M5StackName+CoreDataClass.swift
//  
//
//  Created by Johan Degraeve on 22/09/2019.
//
//

import Foundation
import CoreData


public class M5StackName: NSManagedObject, BluetoothPeripheral {

    /// create M5StackName
    init(address: String, userDefinedName: String, nsManagedObjectContext:NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "M5StackName", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.userDefinedName = userDefinedName
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
