//
//  TreatmentNSResponse.swift
//  xdrip
//
//  Created by Eduardo Pietre on 11/01/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

/// Class that represents the Nightscout response for adding a single new treatment.
///
/// NS API docs states:
/// "The client should not create the identifier, the server automatically assigns it when the document is inserted."
public struct TreatmentNSResponse {
    
	public let id: String
	public let createdAt: Date
	public let eventType: TreatmentType
	public let value: Double
	
	/// Takes a NSDictionary from nightscout response and returns a TreatmentNSResponse, if fields are valid.
	public static func fromNighscout(dictionary: NSDictionary) -> TreatmentNSResponse? {
        
		if let id = dictionary["_id"] as? String, let createdAt = dictionary["created_at"] as? String, let eventTypeStr = dictionary["eventType"] as? String, let eventType = TreatmentType.fromNightscoutString(eventTypeStr), let date = Date.fromISOString(createdAt) {
			
			var value: Double?
            
			switch eventType {
			case .Insulin:
				value = dictionary["insulin"] as? Double
			case .Carbs:
				value = dictionary["carbs"] as? Double
			case .Exercise:
				value = dictionary["duration"] as? Double
			}
			
			if let value = value {
				return TreatmentNSResponse(id: id, createdAt: date, eventType: eventType, value: value)
			}
            
		}
        
		return nil
        
	}
	
	/// Instantiates multiples TreatmentNSResponse from a NSArray of NSDictionary.
	public static func arrayFromNSArray(_ array: NSArray) -> [TreatmentNSResponse] {
        
		var responses: [TreatmentNSResponse] = []

		for element in array {
			if let dicionary = element as? NSDictionary, let treatmentNSResponse = TreatmentNSResponse.fromNighscout(dictionary: dicionary) {
				responses.append(treatmentNSResponse)
			}
		}
		
		return responses
        
	}
	
	/// Instantiates multiples TreatmentNSResponse from Data response.
    ///
	/// JSONSerialization may throw an exception.
	public static func arrayFromData(_ data: Data?) throws -> [TreatmentNSResponse]? {
        
		if let data = data, let array = try JSONSerialization.jsonObject(with: data, options: []) as? NSArray {
			
			return TreatmentNSResponse.arrayFromNSArray(array)
            
		}
		
		return nil
        
	}
	
	/// Compares this TreatmentNSResponse to a given TreatmentEntry
	public func matchesTreatmentEntry(_ entry: TreatmentEntry) -> Bool {
        
        return entry.date.toMillisecondsAsInt64() == self.createdAt.toMillisecondsAsInt64() && entry.treatmentType == self.eventType && entry.value == self.value
        
	}
	
	/// Converts self (TreatmentNSResponse) to TreatmentEntry and creates a TreatmentEntry
    ///
	/// Be extra carefull when creating new TreatmentEntry, will create the new entry in CoreData but does not save in CoreData
	public func asNewTreatmentEntry(nsManagedObjectContext: NSManagedObjectContext) -> TreatmentEntry? {
        
		return TreatmentEntry(id: id, date: createdAt, value: value, treatmentType: eventType, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
}
