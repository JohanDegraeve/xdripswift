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
        case .BgCheck:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
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
            
        }
        
    }
    
    /// return the y-axis offset for the treatment type (as set in ConstantsGlucoseChart.swift) - if it isn't required for the treatment type, it should return 0
    public func chartPointYAxisOffset() -> Double {
        
        switch self {
            
        case .Insulin:
            return ConstantsGlucoseChart.bolusTreatmentChartPointYAxisOffsetInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
            // if no offset is defined or needed for this treatment type, just return zero offset
        default:
            return 0
            
        }
        
    }
    
    /// return the y-axis scale factor for the treatment type (as set in ConstantsGlucoseChart.swift) - if it isn't required for the treatment type, it should return 1
    public func chartPointYAxisScaleFactor() -> Double {
        
        switch self {
            
        case .Insulin:
            return ConstantsGlucoseChart.bolusTreatmentChartPointYAxisScaleFactor.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
            // if no scale is defined or needed for this treatment type, just return a unity scale factor
        default:
            return 1
            
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
    convenience init(date: Date, value: Double, treatmentType: TreatmentType, nightscoutEventType: String?, nsManagedObjectContext:NSManagedObjectContext) {
        
		// Id defaults to Empty
        self.init(id: TreatmentEntry.EmptyId, date: date, value: value, treatmentType: treatmentType, uploaded: false, nightscoutEventType: nightscoutEventType, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
    /// if id = TreatmentEntry.EmptyId then uploaded will get default value false
	convenience init(id: String, date: Date, value: Double, treatmentType: TreatmentType, nightscoutEventType: String?, nsManagedObjectContext:NSManagedObjectContext) {
		
		let uploaded = id != TreatmentEntry.EmptyId
		
        self.init(id: id, date: date, value: value, treatmentType: treatmentType, uploaded: uploaded, nightscoutEventType: nightscoutEventType, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
    init(id: String, date: Date, value: Double, treatmentType: TreatmentType, uploaded: Bool, nightscoutEventType: String?, nsManagedObjectContext:NSManagedObjectContext) {
		
		let entity = NSEntityDescription.entity(forEntityName: "TreatmentEntry", in: nsManagedObjectContext)!
		super.init(entity: entity, insertInto: nsManagedObjectContext)
		
		self.date = date
		self.value = value
		self.treatmentType = treatmentType
		self.id = id
		self.uploaded = uploaded  // tracks upload to nightscout
        self.nightscoutEventType = nightscoutEventType

    }

	private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
		super.init(entity: entity, insertInto: context)
	}
	
	/// - get the dictionary representation required for creating a new treatment @ NighScout using POST or updating an existing treatment @ Nightscout using PUT
    /// - splits of "-carbs" "-insulin" or "-exercise" from the id
	func dictionaryRepresentationForNightscoutUpload(reuseDateFormatter: DateFormatter? = nil) -> [String: Any] {
        
		// Universal fields.
		var dict: [String: Any] = [
			"enteredBy": "xDrip4iOS",
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


