//
//  TreatmentEntry+CoreDataClass.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData


// @objc and Int16 allows enums to work with CoreData
// WARNING: DO NOT change the order without caution.
// Changing the order will change the Int16 value
// and may change all Treatments Type present in CoreData.
// Add new at the end or specify each value.
@objc public enum TreatmentType: Int16 {
	case Insulin
	case Carbs
	case Exercise
	
	/// String representation.
	public func asString() -> String {
		switch self {
		case .Insulin:
			return Texts_TreatmentsView.insulin
		case .Carbs:
			return Texts_TreatmentsView.carbs
		case .Exercise:
			return Texts_TreatmentsView.exercise
		default:
			return Texts_TreatmentsView.questionMark
		}
	}
	
	/// The unit used for the type.
	public func unit() -> String {
		switch self {
		case .Insulin:
			return Texts_TreatmentsView.insulinUnit
		case .Carbs:
			return Texts_TreatmentsView.carbsUnit
		case .Exercise:
			return Texts_TreatmentsView.exerciseUnit
		default:
			return Texts_TreatmentsView.questionMark
		}
	}
	
    /// define TreatmentType based on string received from NightScout
	public static func fromNightscoutString(_ string: String) -> TreatmentType? {
		switch string {
		case "Correction Bolus":
			return .Insulin
		case "Meal Bolus":
			return .Carbs
		case "Exercise":
			return .Exercise
		default:
			return nil
		}
	}
}


/// Representation of a Treatment
/// Stored at CoreData.
/// .date represents the date of the treatment, not the date of creation.
/// .value represents the amount (e.g. insulin units or carbs grams)
/// the value unit is defined by the treatmentType.
/// .treatmentType see TreatmentType
/// .id is the Nightscout id, defaults to TreatmentEntry.EmptyId.
/// .uploaded tells if entry has been uploaded for Nighscout or not.
public class TreatmentEntry: NSManagedObject, Comparable {

    /// initializer with id default empty, uploaded default false
    convenience init(date: Date, value: Double, treatmentType: TreatmentType, nsManagedObjectContext:NSManagedObjectContext) {
		// Id defaults to Empty
		self.init(id: TreatmentEntry.EmptyId, date: date, value: value, treatmentType: treatmentType, uploaded: false, nsManagedObjectContext: nsManagedObjectContext)
	}
	
    /// if id = TreatmentEntry.EmptyId then uploaded will get default value false
	convenience init(id: String, date: Date, value: Double, treatmentType: TreatmentType, nsManagedObjectContext:NSManagedObjectContext) {
		
		let uploaded = id != TreatmentEntry.EmptyId
		
		self.init(id: id, date: date, value: value, treatmentType: treatmentType, uploaded: uploaded, nsManagedObjectContext: nsManagedObjectContext)
	}
	
	init(id: String, date: Date, value: Double, treatmentType: TreatmentType, uploaded: Bool, nsManagedObjectContext:NSManagedObjectContext) {
		
		let entity = NSEntityDescription.entity(forEntityName: "TreatmentEntry", in: nsManagedObjectContext)!
		super.init(entity: entity, insertInto: nsManagedObjectContext)
		
		self.date = date
		self.value = value
		self.treatmentType = treatmentType
		self.id = id
		self.uploaded = uploaded  // tracks upload to nightscout

    }

	private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
		super.init(entity: entity, insertInto: context)
	}
	
	/// Returns the displayValue: the .value with the proper unit.
	public func displayValue() -> String {
		return self.value.stringWithoutTrailingZeroes + " " + self.treatmentType.unit()
	}
	
	/// Returns the dictionary representation required for creating a new treatment @ NighScout using POST or updating an existing treatment @ NightScout using PUT
	public func dictionaryRepresentationForNightScoutUpload() -> [String: Any] {
        
		// Universal fields.
		var dict: [String: Any] = [
			"enteredBy": "xDrip4iOS",
			"eventTime": self.date.ISOStringFromDate(),
		]
		
        // if id exists, then add it also
        if id != TreatmentEntry.EmptyId {
            dict["_id"] = id
        }
        
		// Checks the treatmentType and add specific information.
		switch self.treatmentType {
		case .Insulin:
			dict["eventType"] = "Correction Bolus"
			dict["insulin"] = self.value
		case .Carbs:
			dict["eventType"] = "Meal Bolus"
			dict["carbs"] = self.value
		case .Exercise:
			dict["eventType"] = "Exercise"
			dict["duration"] = self.value
		default:
			break
		}
		
		return dict
	}

}

// MARK: - conform to Comparable

public func < (lhs: TreatmentEntry, rhs: TreatmentEntry) -> Bool {

    return lhs.date < rhs.date
    
}


