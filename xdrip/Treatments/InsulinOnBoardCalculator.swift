//
//  InsulinOnBoardCalculator.swift
//  xdrip
//
//  Created by Eduardo Pietre on 29/06/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData
import SwiftCharts



///
/// InsulinYetToBeConsumed is - and should be - a PURE FUNCTION.
/// A function is pure if given the same arguments it always returns the same output
/// AND it does not have any side effects - like accessing or modifying a property or a global variable.
///
/// Why is this calculation implemented as a PURE FUNCTION?
/// This function is called numerous time, and being a pure function allows for, IF NEEDED, safely cache the results of it.
///
/// This function is heavly based on the following sources and matches the same formula:
/// https://openaps.readthedocs.io/en/latest/docs/While%20You%20Wait%20For%20Gear/understanding-insulin-on-board-calculations.html
/// https://github.com/openaps/oref0/blob/master/lib/iob/calculate.js
/// https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473
///
fileprivate func InsulinYetToBeConsumed(insulin: Double, minutesAgo: Double, activityDuration: Double, peakTime: Double) -> Double {
	/// If minutesAgo if >= than activityDuration, the IOB will always be 0.
	if minutesAgo >= activityDuration {
		return 0
	}
	
	/// Assign variables to smaller variables names
	/// This improves readability in the next section and matches the formula sources.
	let peak = peakTime
	let end = activityDuration

	/// Math (very close to magic) happens here.
	/// Performs an exponential interpolation.
	/// Variable names are the same as used in the formula sources.
	let tau = peak * (1 - (peak / end)) / (1 - (2 * peak / end))
	let a = 2 * tau / end
	let S = 1 / (1 - a + ((1 + a) * exp(-end / tau)))
	
	let remaining = insulin * (1 - S * (1 - a) * ((pow(minutesAgo, 2) / (tau * end * (1 - a)) - minutesAgo / tau - 1) * exp(-minutesAgo / tau) + 1))
	return remaining
}


///
/// InsulinOnBoardCalculator is the
/// class interface responsible for calculating IOBs.
/// For example, given a date (or many), it is able to
/// load all insulin treatments that impact the IOB at that moment
/// and calculating it.
///
/// 'override func observeValue' requires us to inherit from NSObject.
///
public class InsulinOnBoardCalculator: NSObject {

	/// reference to coreDataManager
	private let coreDataManager: CoreDataManager
	
	/// reference to treatmentEntryAccessor
	private let treatmentEntryAccessor: TreatmentEntryAccessor
	
	/// reference to coreDataManager object context
	private let objectContext: NSManagedObjectContext
	
	/// Get activityDuration and peakTime from UserDefaults and convert them to Double
	private var activityDuration: Double = Double(UserDefaults.standard.insulinOnBoardInsulinActivityDuration)
	private var peakTime: Double = Double(UserDefaults.standard.insulinOnBoardInsulinPeakTime)
	
	
	// MARK: - initializer
	
	/// initializer
	/// - parameters:
	///     - coreDataManager : needed to get the treatments
	init(coreDataManager: CoreDataManager) {
		self.coreDataManager = coreDataManager
		self.objectContext = coreDataManager.mainManagedObjectContext
		self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
		
		super.init()
		
		/// Add observers for ActivityDuration and PeakTime.
		UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.insulinOnBoardInsulinActivityDuration.rawValue, options: .new, context: nil)
		UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.insulinOnBoardInsulinPeakTime.rawValue, options: .new, context: nil)
	}

	
	/// deinitializer, used to free the UserDefaults observers.
	/// If these observers are not removed, them being called after
	/// the destruction of self will result in an EXC_BAD_ACCESS exception.
	deinit {
		UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.insulinOnBoardInsulinActivityDuration.rawValue)
		UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.insulinOnBoardInsulinPeakTime.rawValue)
	}
	

	// MARK: - public functions
	
	
	/// InsulinYetToBeConsumedAt - given a date, returns a double that represents
	/// how many insulins units are yet to be consumed (IOB).
	/// All insulin treatments in the last insulinOnBoardInsulinActivityDuration
	/// are taken into account for it.
	///
	/// - parameters:
	///     - date : the moment of time to calculate the insulin yet to be consumed.
	/// - returns: a double representing in units the insulin yet to be consumed.
	///
	public func insulinYetToBeConsumedAt(date: Date) -> Double {
		/// We must take into account all insulin treatments in the last insulinOnBoardInsulinActivityDuration period.
		let startDate: Date = date - (activityDuration * 60)
		
		/// Variable to receive the IOB value.
		var yetToBeConsumed: Double = 0.0
		objectContext.performAndWait {
			/// get treaments between the two timestamps from coredata
			/// filter so no deleted treatments are included and only of type .Insulin.
			let treatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: startDate, toDate: date, on: objectContext).filter({
				!$0.treatmentdeleted && $0.treatmentType == .Insulin
			})

			/// Use multipleInsulinYetToBeConsumed to calculate, but with only one date.
			let insulinsYetToBeConsumed: [Double] = self.multipleInsulinYetToBeConsumed(treatmentEntries, atDates: [date])
			
			/// Check if .first is not nil and sets yetToBeConsumed to it.
			if let insulin = insulinsYetToBeConsumed.first {
				yetToBeConsumed = insulin
			}
		}
		
		return yetToBeConsumed
	}
	
	
	///
	/// InsulinYetToBeConsumed - given two dates, number of steps and if should surround treatments, returns:
	/// 	- a list of N dates between those two dates.
	///		- a list of the IOB at each of those returned dates.
	/// The first IOB double corresponds to the first date, and so on.
	///
	/// - parameters:
	///     - startDate : the start date (not guaranteed to be included).
	///     - endDate : the end date (not guaranteed to be included). Must be after startDate.
	///     - steps: the min amount of dates and IOB wanted.
	///     - surroundTreatments: a bool, if true will also calculate and include the date and IOB right before and after each insulin treatment. This results in a more polished line when plotting. However, if the number of treatments at the interval is way to big, may cause lag. If false, the .count of the output is guaranteed to be equal to steps.
	/// - returns: a pair: a list of the dates and a list of the iob at each date, the first IOB double corresponds to the first date, and so on.
	///
	public func insulinYetToBeConsumed(startDate: Date, endDate: Date, steps: Int, surroundTreatments: Bool) -> (dates: [Date], iob: [Double]) {
		
		/// Safe guard to ensure endDate is after startDate.
		guard endDate > startDate else {
			return ([], [])
		}
		
		/// Use roundModulus as 5 * 60 to aproximate to multiples of 5 minutes.
		/// Having the dates selected at regular intervals and from regular points
		/// prevents the result having small inconsistent flutuations when startDate
		/// changes by a small value.
		var dates: [Date] = self.determinedEvenlySpacedDates(startDate: startDate, endDate: endDate, steps: steps, roundModulus: 5 * 60)
		
		/// Define a variable to receive the result of multipleInsulinYetToBeConsumed
		var yetToBeConsumed: [Double] = []
		objectContext.performAndWait {
			/// fromDate is calculated based on startDate and activityDuration
			/// will be used to load the treatments that impact the IOB.
			let fromDate: Date = startDate - (activityDuration * 60)
			
			/// get treaments between the two timestamps from coredata
			/// filter so no deleted treatments are included and only of type .Insulin.
			let treatments = treatmentEntryAccessor.getTreatments(fromDate: fromDate, toDate: endDate, on: objectContext).filter({
				!$0.treatmentdeleted && $0.treatmentType == .Insulin
			})
			
			/// Even though we now have equally spaced dates, for a better "looking"
			/// if surroundTreatments is true also add a date 10 seconds before
			/// each insulin treatment and another 10 seconds after the treatment.
			/// This ensures that the line slope right where it intersepts the insulin
			/// treatment is not influenced by the offset to the closest x date.
			if surroundTreatments {
				for treatment in treatments {
					let date = treatment.date
					/// 10 seconds before and after
					dates.append(date - 10.0)
					dates.append(date + 10.0)
				}
				/// remember to sort dates again
				dates.sort()  // In place
			}
						
			/// Calls multipleInsulinYetToBeConsumed to calculate the IOB.
			yetToBeConsumed = self.multipleInsulinYetToBeConsumed(treatments, atDates: dates)
		}
		
		return (dates, yetToBeConsumed)
	}
	

	///
	/// InsulinYetToBeConsumed - given a treatment and a date, returns a double that represents how many insulins units of this treatment are yet to be consumed (IOB).
	///
	/// - parameters:
	/// 	- treatment : the insulin treatment to calculate the IOB of.
	///     - date : the moment of time to calculate the insulin yet to be consumed.
	/// - returns: a double representing in units the insulin yet to be consumed.
	///
	public func insulinYetToBeConsumed(_ treatment: TreatmentEntry, atDate: Date) -> Double {
		
		/// If the treatmentType is not .Insulin, the IOB is 0.
		guard treatment.treatmentType == .Insulin else {
			return 0
		}
		
		/// atDate must not be before treatment.date, or the IOB will also be always 0.
		guard atDate >= treatment.date else {
			return 0
		}
		
		/// Calculate how many minutes have elapsed from the treatment date to atDate.
		let minutesAgo: Double = (atDate.timeIntervalSince1970 - treatment.date.timeIntervalSince1970) / 60

		/// InsulinYetToBeConsumed will do the remaining of the calculation.
		let insulin = treatment.value
		return InsulinYetToBeConsumed(insulin: insulin, minutesAgo: minutesAgo, activityDuration: activityDuration, peakTime: peakTime)
	}
	
	
	///
	/// MultipleInsulinYetToBeConsumed - given a list of treatments and a list of dates, returns a list of doubles that represents how many insulins units of these treatments are yet to be consumed at each date (IOB).
	/// The first double corresponds to the first date, and so on.
	///
	/// - parameters:
	/// 	- treatments : list of treatments to be taken into account.
	///     - atDates : list of points in time (Dates) to calculate the IOB.
	/// - returns: a list of doubles representing in units the insulin yet to be consumed at each date.
	///
	public func multipleInsulinYetToBeConsumed(_ treatments: [TreatmentEntry], atDates: [Date]) -> [Double] {
		
		/// If treatments is empty, IOB will be 0 for all dates.
		guard !treatments.isEmpty else {
			return [Double](repeating: 0.0, count: atDates.count)
		}
		
		/// First, we must calculate for each treatment the IOB at each date.
		/// Use a list to keep track of it.
		/// Each element in this list is in itself a list of doubles,
		/// each double element representing the IOB at one point in time.
		///
		/// calculatedRemainings[N][I] represents the IOB of the treatment at index N and at date atDates[I].
		var calculatedRemainings: [[Double]] = []
		for treatment in treatments {
			/// Calculate the IOB at each date for this treatment.
			var newPartials: [Double] = []
			for date in atDates {
				let yetToBeConsumed = self.insulinYetToBeConsumed(treatment, atDate: date)
				newPartials.append(yetToBeConsumed)
			}
			/// Append the list of doubles to calculatedRemainings
			calculatedRemainings.append(newPartials)
		}
		
		/// Now that we have the calculatedRemainings, we must sum the IOB of all treatments at each date.
		/// For this, iterate over the indices of the first sublist (since all sublists have the same length and indices) and sum the remainings of all treatments at each index.
		var mergedRemainings: [Double] = []
		if let first = calculatedRemainings.first {
			for i in first.indices {
				var total: Double = 0.0
				for calculatedRemaining in calculatedRemainings {
					total += calculatedRemaining[i]
				}
				mergedRemainings.append(total)
			}
		}
		
		/// mergedRemainings now has the result we want.
		return mergedRemainings
	}
	
	
	// MARK: - private functions
	

	///
	/// DeterminedEvenlySpacedDates - returns N evenly spaced dates between start date and end date.
	/// The timeIntervalSince1970 representation of these dates are guaranteed to be a multiple of roundModulus.
	///
	/// For example, if roundModulus = 5 * 60 (5 min)
	/// 	and starDate = ...10:44:31
	///		the roundDate to start calculating will be 10:40:00
	///		10:40:00 will not be the first returned value, but the start point to calculate the evenly spaced dates.
	///
	/// - parameters:
	/// 	- startDate : the start point for the sequence (not necessary included).
	///     - endDate : the end point for the sequence (not necessary included).
	///     - steps : amount of evenly spaced dates to calculate.
	///     - roundModulus : used to round the startDate to the previous second multiple of roundModulus. E.g.: (10 * 60) will round to the previous multiple of 10 minutes.
	/// - returns: a list of dates evenly spaced and determined from a reproducible roundDate as start point.
	///
	private func determinedEvenlySpacedDates(startDate: Date, endDate: Date, steps: Int, roundModulus: Int) -> [Date] {
		
		var dates: [Date] = []
		
		/// Round the startDate by subtracting the modulus of it by roundModulus.
		let roundedDate = startDate - Double(Int(startDate.timeIntervalSince1970) % roundModulus)
		
		/// Calculate the interval size by diving the time diff in seconds by the N of steps.
		let intervalSize = (endDate.timeIntervalSince1970 - roundedDate.timeIntervalSince1970) / Double(steps)
		
		/// Calculate the dates from roundedDate and append to xAxisDates
		/// +1 so the line goes up to the graph border, instead of stopping before endDate.
		for i in 0..<Int(steps + 1) {
			let date = roundedDate + (intervalSize * Double(i))
			dates.append(date)
		}
		
		return dates
	}
	
	
	// MARK: - overriden functions
	
	/// Watch for UserDefaults changes and updates activityDuration and peakTime if they change.
	public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

		guard let keyPath = keyPath else {return}
		guard let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else {return}
		
		// Check if insulinOnBoardInsulinActivityDuration or insulinOnBoardInsulinPeakTime
		// were updated and if so update the properties.
		switch keyPathEnum {

		case .insulinOnBoardInsulinActivityDuration:
			activityDuration = Double(UserDefaults.standard.insulinOnBoardInsulinActivityDuration)
		
		case .insulinOnBoardInsulinPeakTime:
			peakTime = Double(UserDefaults.standard.insulinOnBoardInsulinPeakTime)
			
		default:
			break
		}
	}
	
}
