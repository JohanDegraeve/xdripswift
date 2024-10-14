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
    
    /// id received from Nightscout , incusive the extension "-insulin", "-carbs" or "-exercise"
	public let id: String
    
	public let createdAt: Date
    
    /// - eventType either insulin, carbs or exercise
    /// - only used internally in the app
	public let eventType: TreatmentType
    
    /// - eventType received from Nightscout (for downloaded treatments) or uploaded to Nightscout (for treatments created in xdrip4ios)
    public let nightscoutEventType: String?
	
    public let value: Double
    
	/// Takes a NSDictionary from nightscout response and returns an array TreatmentNSResponse. Can be more than one, eg Nightscout treatment of type 'Snack Bolus' could contain an insulin value and a carbs value
    ///
    /// id will be the id retrieved from nightscout + "-insulin", "-carbs", "-exercise", according to treatment type
    public static func fromNightscout(dictionary: NSDictionary) -> [TreatmentNSResponse] {
        
        var treatmentNSResponses: [TreatmentNSResponse] = []
        
        // we need this to be optional in case the created_at string cannot be transformed successfully into a valid date
        var nightscoutDate: Date?
        
        if let createdAt = dictionary["created_at"] as? String {
            
            let dateFormatter = DateFormatter()
            
            // add the locale and timeZone properties as per dateFromISOString()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            // let's check which date format is return by Nightscout and deal with it accordingly
            // if the date string contains a decimal point, then it must contain milliseconds
            // if we don't take this into account, .date(from: string) will be returned as nil if the milliseconds (.SSS) are missing
            if createdAt.contains(".") {
                
                // this is the way Loop, FreeAPS (Loop), OpenAPS and FreeAPS X store the created_at date/time
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                
            } else {
                
                // and AndroidAPS stores it without milliseconds
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                
            }
            
            // assign the date to the optional nightscoutDate
            nightscoutDate = dateFormatter.date(from: createdAt)
            
        }
        
        // first check that _id exists and that created_at was successfully converted into a Date
		if let id = dictionary["_id"] as? String, let date = nightscoutDate {
			
            // retrieve nightscoutEventType from the nightscout response
            // if not present then it's set to nil (it should be present)
            let nightscoutEventType: String? = dictionary["eventType"] as? String
            
            if let carbs = dictionary["carbs"] as? Double {
                
                treatmentNSResponses.append(TreatmentNSResponse(id: id + TreatmentType.Carbs.idExtension(), createdAt: date, eventType: .Carbs, nightscoutEventType: nightscoutEventType, value: carbs))
                
            }
            
            if let insulin = dictionary["insulin"] as? Double {
                
                treatmentNSResponses.append(TreatmentNSResponse(id: id + TreatmentType.Insulin.idExtension(), createdAt: date, eventType: .Insulin, nightscoutEventType: nightscoutEventType, value: insulin))
                
            }
            
            if nightscoutEventType == "Exercise", let duration = dictionary["duration"] as? Double {
                    
                treatmentNSResponses.append(TreatmentNSResponse(id: id + TreatmentType.Carbs.idExtension(), createdAt: date, eventType: .Exercise, nightscoutEventType: nightscoutEventType, value: duration))
                
            }
            
            if let glucose = dictionary["glucose"] as? Double, let units = dictionary["units"] as? String {
                
                treatmentNSResponses.append(TreatmentNSResponse(id: id + TreatmentType.BgCheck.idExtension(), createdAt: date, eventType: .BgCheck, nightscoutEventType: nightscoutEventType, value: units == "mg/dl" ? glucose : glucose.mmolToMgdl()))
                
            }
            
		}
        
		return treatmentNSResponses
        
	}
	
	/// Instantiates multiples TreatmentNSResponse from a NSArray of NSDictionary.
	public static func arrayFromNSArray(_ array: NSArray) -> [TreatmentNSResponse] {
        
		var responses: [TreatmentNSResponse] = []

		for element in array {
			if let dictionary = element as? NSDictionary {
                
                responses = responses + TreatmentNSResponse.fromNightscout(dictionary: dictionary)
                
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
        
        return TreatmentEntry(id: id, date: createdAt, value: value, treatmentType: eventType, nightscoutEventType: nightscoutEventType, nsManagedObjectContext: nsManagedObjectContext)
        
	}
	
}
