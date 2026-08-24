//
//  MedtrumTouchCareNano+CoreDataProperties.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

extension MedtrumTouchCareNano {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedtrumTouchCareNano> {
        return NSFetchRequest<MedtrumTouchCareNano>(entityName: "MedtrumTouchCareNano")
    }

    /// blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral

    /// firmware version, if discovered
    @NSManaged public var firmware: String?

}
