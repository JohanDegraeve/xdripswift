//
//  Libre3+CoreDataClass.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

public class Libre3: NSManagedObject, BluetoothPeripheral {
    @NSManaged public var blePeripheral: BLEPeripheral
    @NSManaged public var firmware: String?
    @NSManaged public var status: String?
    @NSManaged public var warmupMinutes: Int32
    @NSManaged public var wearMinutes: Int32
    @NSManaged public var startedAt: Date?

    init(address: String, name: String, alias: String?, nsManagedObjectContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Libre3", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        blePeripheral = BLEPeripheral(address: address, name: name, alias: alias, bluetoothPeripheralType: .Libre3Type, nsManagedObjectContext: nsManagedObjectContext)
    }
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    func bluetoothPeripheralType() -> BluetoothPeripheralType { .Libre3Type }
    var productName: String { Libre3ProductNameResolver.title(wearMinutes: Int(wearMinutes)) }
}
