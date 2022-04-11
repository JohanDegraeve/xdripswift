//
//  DateOnly.swift
//  xdrip
//
//  Created by Eduardo Pietre on 28/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation


/// Swift has no class to represent a day
/// - NSDate will always have time information together
/// - DateOnly will act as a wrapper for this purpose.
public struct DateOnly: Comparable, Equatable, Hashable {
	
	// MARK: - Properties.
	
	/// A Date object, used for comparations.
	/// Should always have time zeroed.
	public let date: Date

	// MARK: - Public
	
	/// Creates a DateOnly from a Date object.
	init(date: Date) {
        
		let calendar = Calendar.current
		// Extracts the day, month and year for date
		let dateComponents = calendar.dateComponents([.day, .month, .year], from: date)

		// Because the values are from an existing date object,
		// we can be sure they are not invalid args
		// and use Force-unwrap ('!') .
		self.date = calendar.date(from: dateComponents)!
        
	}
	
	
	// MARK: - Protocols
	
	/// Hashable Protocol
	public func hash(into hasher: inout Hasher) {
		// Only the date is enough to identify each DateOnly.
		hasher.combine(self.date)
	}
	
	/// Comparable Protocol
	public static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
		// Just use the date object.
		return lhs.date < rhs.date
	}
	
	/// Equatable Protocol
	public static func == (lhs: Self, rhs: Self) -> Bool {
		// Just use the date object.
		return lhs.date == rhs.date
	}

}
