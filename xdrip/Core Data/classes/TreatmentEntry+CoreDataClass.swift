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
@objc public enum TreatmentType: Int16 {
	case Insulin
	case Carbs
	case Exercise
	
	public func asString() -> String {
		switch self {
		case .Insulin:
			return "Insulin"
		case .Carbs:
			return "Carbs"
		case .Exercise:
			return "Exercise"
		default:
			return "Unknown"
		}
	}
	
	public func unit() -> String {
		switch self {
		case .Insulin:
			return "u"
		case .Carbs:
			return "g"
		case .Exercise:
			return "min"
		default:
			return ""
		}
	}
}


public class TreatmentEntry: NSManagedObject {

	init(date: Date, value: Double, treatmentType: TreatmentType, nsManagedObjectContext:NSManagedObjectContext) {
		
		let entity = NSEntityDescription.entity(forEntityName: "TreatmentEntry", in: nsManagedObjectContext)!
		super.init(entity: entity, insertInto: nsManagedObjectContext)
		
		self.date = date
		self.value = value
		self.treatmentType = treatmentType
		self.uploaded = false  // tracks upload to nightscout
	}

	private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
		super.init(entity: entity, insertInto: context)
	}
	
	public func displayValue() -> String {
		var string = String(self.value)
		// Checks prevents .0 from being displayed
		if string.suffix(2) == ".0" {
			string = String(string.dropLast(2))
		}
		return string + " " + self.treatmentType.unit()
	}
	
	public func dictionaryRepresentationForNightScoutUpload() -> [String: Any] {
		var dict: [String: Any] = [
			"enteredBy": "xDrip4iOS",
			"eventTime": self.date.ISOStringFromDate(),
		]
		
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
