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

	// Used to load entries from CoreData.
	@nonobjc public class func fetchRequest() -> NSFetchRequest<TreatmentEntry> {
		return NSFetchRequest<TreatmentEntry>(entityName: "TreatmentEntry")
	}

	// Date represents the date of the treatment, not the date of creation.
	@NSManaged public var date: Date

	// Value represents the amount (e.g. insulin units or carbs grams).
	@NSManaged public var value: Double

	// Enum TreatmentType defines which treatment this instance is.
	@NSManaged public var treatmentType: TreatmentType
	
	// Tells if this instance has been uploaded to Nightscout.
	@NSManaged public var uploaded: Bool
	
}
