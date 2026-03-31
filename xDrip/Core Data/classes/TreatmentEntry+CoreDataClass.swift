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
    case BgCheck
    case Basal
    case SiteChange
    case SensorStart
    case PumpBatteryChange
	
	/// String representation.
	public func asString() -> String {
		switch self {
		case .Insulin:
			return Texts_TreatmentsView.insulin
		case .Carbs:
			return Texts_TreatmentsView.carbs
		case .Exercise:
			return Texts_TreatmentsView.exercise
        case .BgCheck:
            return Texts_TreatmentsView.bgCheck
        case .Basal:
            return Texts_TreatmentsView.basalRate
        case .SiteChange:
            return Texts_TreatmentsView.siteChange
        case .SensorStart:
            return Texts_TreatmentsView.sensorStart
        case .PumpBatteryChange:
            return Texts_TreatmentsView.pumpBatteryChange
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
        case .Basal:
            return Texts_TreatmentsView.basalRateUnit
        case .BgCheck:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        case .SiteChange, .SensorStart, .PumpBatteryChange:
            return ""
		default:
			return Texts_TreatmentsView.questionMark
		}
	}
    
    /// returns "-insulin", "-carbs", "-exercise", according to treatment type
    public func idExtension() -> String {
        
        return "-" + self.nightscoutFieldname()
        
    }
    
    /// return the name of the attribute used in Nightscout for the TreatmentType
    public func nightscoutFieldname() -> String {
        switch self {
        case .Insulin:
            return "insulin"
        case .Carbs:
            return "carbs"
        case .Exercise:
            return "exericse"
        case .BgCheck:
            return "glucose"
        case .Basal:
            return "rate"
        default:
            return ""
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
    /// - parameters:
    ///     -     nightscoutEventType : if it's a treatmentEntry that was downloaded from Nightscout, then this is the eventType as it was received form Nightscout. nil if not known or if it's a treatmentType that was not downloaded from Nightscout
    convenience init(date: Date, value: Double, valueSecondary: Double? = 0.0, treatmentType: TreatmentType, nightscoutEventType: String?, enteredBy: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
		// Id defaults to Empty
        self.init(id: TreatmentEntry.EmptyId, date: date, value: value, valueSecondary: valueSecondary, treatmentType: treatmentType, uploaded: false, nightscoutEventType: nightscoutEventType, enteredBy: enteredBy, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
    /// if id = TreatmentEntry.EmptyId then uploaded will get default value false
	convenience init(id: String, date: Date, value: Double, valueSecondary: Double? = 0.0, treatmentType: TreatmentType, nightscoutEventType: String?, enteredBy: String?, nsManagedObjectContext:NSManagedObjectContext) {
		
		let uploaded = id != TreatmentEntry.EmptyId
		
        self.init(id: id, date: date, value: value, valueSecondary: valueSecondary, treatmentType: treatmentType, uploaded: uploaded, nightscoutEventType: nightscoutEventType, enteredBy: enteredBy, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
    init(id: String, date: Date, value: Double, valueSecondary: Double? = 0.0, treatmentType: TreatmentType, uploaded: Bool, nightscoutEventType: String?, enteredBy: String?, nsManagedObjectContext:NSManagedObjectContext) {
		
		let entity = NSEntityDescription.entity(forEntityName: "TreatmentEntry", in: nsManagedObjectContext)!
		super.init(entity: entity, insertInto: nsManagedObjectContext)
		
		self.date = date
		self.value = value
        self.valueSecondary = valueSecondary ?? 0.0
		self.treatmentType = treatmentType
		self.id = id
		self.uploaded = uploaded  // tracks upload to nightscout
        self.nightscoutEventType = nightscoutEventType
        self.enteredBy = enteredBy

    }

	private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
		super.init(entity: entity, insertInto: context)
	}
	
	/// - get the dictionary representation required for creating a new treatment @ Nightscout using POST or updating an existing treatment @ Nightscout using PUT
    /// - splits of "-carbs" "-insulin" or "-exercise" from the id
	func dictionaryRepresentationForNightscoutUpload(reuseDateFormatter: DateFormatter? = nil) -> [String: Any] {
        
        let enteredByString = enteredBy ?? "xDrip4iOS"
        
		// Universal fields.
		var dict: [String: Any] = [
			"enteredBy": enteredByString,
			"eventTime": self.date.ISOStringFromDate(reuseDateFormatter: reuseDateFormatter),
		]
		
        // if id exists, then add it also
        // split off the "-carbs", "-insulin" or "-exercise"
        if id != TreatmentEntry.EmptyId {
            dict["_id"] = id.split(separator: "-")[0]
        }
        
		// Checks the treatmentType and add specific information.
        // eventType may be overwritten in next step
		switch self.treatmentType {
		case .Insulin:
			dict["eventType"] = "Bolus" // maybe overwritten in next statement
			dict["insulin"] = self.value
		case .Carbs:
			dict["eventType"] = "Carbs" // maybe overwritten in next statement
			dict["carbs"] = self.value
		case .Exercise:
			dict["eventType"] = "Exercise" // maybe overwritten in next statement
			dict["duration"] = self.value
        case .BgCheck:
            dict["eventType"] = "BG Check" // maybe overwritten in next statement
            dict["glucose"] = self.value
            dict["glucoseType"] = "Finger" + String(!UserDefaults.standard.bloodGlucoseUnitIsMgDl ? ": " + self.value.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + Texts_Common.mmol : "")
            dict["units"] = ConstantsNightscout.mgDlNightscoutUnitString
        case .Basal:
            dict["eventType"] = "Temp Basal" // maybe overwritten in next statement
            dict["rate"] = self.value
            dict["duration"] = self.valueSecondary
        case .SiteChange:
            dict["eventType"] = "Site Change" // maybe overwritten in next statement
        case .SensorStart:
            dict["eventType"] = "Sensor Start" // maybe overwritten in next statement
        case .PumpBatteryChange:
            dict["eventType"] = "Pump Battery Change" // maybe overwritten in next statement
		default:
			break
		}
        
        // if nightscoutEventType not nil, then this is a treatment that was downloaded form NS, set the eventType as it was set at NS
        if let nightscoutEventType = nightscoutEventType {
            dict["eventType"] = nightscoutEventType
        }
		
		return dict
	}

}

// MARK: - conform to Comparable

public func < (lhs: TreatmentEntry, rhs: TreatmentEntry) -> Bool {

    return lhs.date < rhs.date
    
}


