//
//  MedtrumTouchCareNano+CoreDataClass.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

public class MedtrumTouchCareNano: NSManagedObject {

    /// last decoded reading counter from the pump's 669A9141 packet — used to drop duplicates across reconnects
    public var lastReadingCounter: Int = -1

    init(address: String, name: String, alias: String?, nsManagedObjectContext: NSManagedObjectContext) {

        let entity = NSEntityDescription.entity(forEntityName: "MedtrumTouchCareNano", in: nsManagedObjectContext)!

        super.init(entity: entity, insertInto: nsManagedObjectContext)

        blePeripheral = BLEPeripheral(address: address, name: name, alias: alias, bluetoothPeripheralType: .MedtrumTouchCareNanoType, nsManagedObjectContext: nsManagedObjectContext)

    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

}
