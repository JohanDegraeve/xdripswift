//
//  TreatmentEntry+CoreDataProperties.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData


extension TreatmentEntry {

	@nonobjc public class func fetchRequest() -> NSFetchRequest<TreatmentEntry> {
		return NSFetchRequest<TreatmentEntry>(entityName: "TreatmentEntry")
	}

	@NSManaged public var date: Date

	@NSManaged public var value: Double

	@NSManaged public var treatmentType: TreatmentType
	
	@NSManaged public var uploaded: Bool
	
}
