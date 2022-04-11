//
//  TreatmentCollection.swift
//  xdrip
//
//  Created by Eduardo Pietre on 28/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation


/// Data structure to group treatments by DateOnly (ie by day), allows retrieval by DateOnly
public class TreatmentCollection {
	
	// MARK: - Properties

	/// List that has keeps tracks of all DateOnly objects sorted from newest to oldest.
    ///
	/// Swift has no OrderedSet, so mimic it with an array.
	private var datesOnly: [DateOnly] = []
	
	/// Dictionary that maps a DateOnly to a list of TreatmentsEntry.
	private var treatmentsByDate: [DateOnly: [TreatmentEntry]] = [:]
	
	
	// MARK: - Inits

	/// Inits from a list of treatments.
    ///  - dateOnly instances are added to hold all TreatmentEntry, sorted by date, most recent  first
    ///  - treatments in every DateOnly array are sorted by date, most recent  first
	init(treatments: [TreatmentEntry]) {
        
		self.addTreatments(treatments)
        
	}
	
	// MARK: - Public methods
	
	/// Getter for datesOnly.
	public func dateOnlys() -> [DateOnly] {
		return self.datesOnly
	}

	/// Returns the treatments for a given date.
	public func getTreatmentsFor(date: DateOnly) -> [TreatmentEntry] {
		return self.treatmentsByDate[date] ?? []
	}
	
	/// Returns the DateOnly at a given index.
	public func dateOnlyAt(_ index: Int) -> DateOnly {
		return self.datesOnly[index]
	}
	
	/// Returns the treatments for the date at a given index.
	public func treatmentsForDateOnlyAt(_ index: Int) -> [TreatmentEntry] {
		let date = self.dateOnlyAt(index)
		return self.getTreatmentsFor(date: date)
	}
	
	/// Returns a single treatment at given date index and treatment index.
    ///
	/// getTreatment(dateIndex: 0, treatmentIndex: 0) will return the most recent (first) treatment.
	public func getTreatment(dateIndex: Int, treatmentIndex: Int) -> TreatmentEntry {
		return self.treatmentsForDateOnlyAt(dateIndex)[treatmentIndex]
	}
	
	
	// MARK: - Private methods
	
	/// Adds treatments to this collection.
    ///  - dateOnly instances are added to hold all TreatmentEntry, sorted by date, most recent  first
    ///  - treatments in every DateOnly array are sorted by date, most recent  first
	private func addTreatments(_ treatments: [TreatmentEntry]) {
        
		// Cannot assume treatments are sorted.
		for treatment in treatments {
            
			// Converts treatment date to a DateOnly.
			let dateOnly = DateOnly(date: treatment.date)
			
			// If is first time we see this dateOnly
			if !self.datesOnly.contains(dateOnly) {
				self.datesOnly.append(dateOnly)
				self.treatmentsByDate[dateOnly] = []
			}
			
			// Always append the treatment to the list.
			// treatmentsByDate[dateOnly] is guaranteed to be already defined.
			self.treatmentsByDate[dateOnly]?.append(treatment)
            
		}
		
		// We want datesOnly sorted in reverse order
		// so elem 0 is the most recent dateOnly.
		self.datesOnly.sort()
		self.datesOnly.reverse()
        
        // sort also the treatments in every array by date, reversed
        for dateOnly in datesOnly {
            
            self.treatmentsByDate[dateOnly]?.sort()
            
            self.treatmentsByDate[dateOnly]?.reverse()
            
        }
        
	}
	
}
