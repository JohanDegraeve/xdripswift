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

	/// Used to load entries from CoreData.
	@nonobjc public class func fetchRequest() -> NSFetchRequest<TreatmentEntry> {
		return NSFetchRequest<TreatmentEntry>(entityName: "TreatmentEntry")
	}
	
    /// if TreatmentEntry is not yet uploaded to NS, then the id will get this value
	public static let EmptyId: String = ""

	/// Date represents the date of the treatment, not the date of creation.
	@NSManaged public var date: Date

	/// Value represents the amount (e.g. insulin units, carbs grams, BG check glucose value).
	@NSManaged public var value: Double

	/// Enum TreatmentType defines which treatment this instance is.
	@NSManaged public var treatmentType: TreatmentType
	
	/// Nightscout id, should be always generated at Nighscout and saved to core data when uploaded.
	@NSManaged public var id: String
	
	/// Tells if this instance has been uploaded to Nightscout.
	@NSManaged public var uploaded: Bool
	
    /// deleted means not visible anymore for user, not taken into account for IOB etc. Used to figure out if DELETE command needs to be sent to Nightscout
    @NSManaged public var treatmentdeleted: Bool
    
    /// - if it's a treatmentEntry that was downloaded from Nightscout, then this is the eventType as it was received form Nightscout
    /// - only used when updating an entry @ NS, to make sure the same eventType is used as the original one assigned by Nightscout
    @NSManaged public var nightscoutEventType: String?
    
}
