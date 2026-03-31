//
//  M5Stack+CoreDataProperties.swift
//  
//
//  Created by Johan Degraeve on 25/12/2019.
//
//

import Foundation
import CoreData


extension M5Stack {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<M5Stack> {
        return NSFetchRequest<M5Stack>(entityName: "M5Stack")
    }

    // blePeripheral is required to conform to protocol BluetoothPeripheral
    @NSManaged public var blePeripheral: BLEPeripheral

    @NSManaged public var backGroundColor: Int32
    @NSManaged public var blepassword: String?
    @NSManaged public var brightness: Int16
    @NSManaged public var isM5StickC: Bool
    @NSManaged public var rotation: Int32
    @NSManaged public var textcolor: Int32
    @NSManaged public var connectToWiFi: Bool

}
