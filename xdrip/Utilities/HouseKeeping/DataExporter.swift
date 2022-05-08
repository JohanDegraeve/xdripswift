//
//  DataExporter.swift
//  xdrip
//
//  Created by Eduardo Pietre on 07/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation


public class DataExporter {
	
	/// This date will determine when the exported data will begin.
	private let onlyFromDate: Date
	
	/// BgReadings instance
	private let bgReadingsAccessor: BgReadingsAccessor
	
	/// Treatments instance
	private let treatmentsAccessor: TreatmentEntryAccessor
	
	/// Calibrations instance
	private let calibrationsAccessor: CalibrationsAccessor
	
	// MARK: - initializer
	
	init(coreDataManager: CoreDataManager) {
		// initialize properties
		self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
		self.treatmentsAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
		self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
		
		self.onlyFromDate = Date(timeIntervalSinceNow: -Double(UserDefaults.standard.retentionPeriodInDays*24*3600))
	}
	
	
	private func convertToJSON(dict: Any) -> String? {
		do {
			let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
			return String(data: jsonData, encoding: .utf8)
		} catch let error {
			// TODO: add trace
			// trace("in convertToJSON, error = %{public}@", log: self.log, category: ConstantsLog., type: .error, error.localizedDescription)
		}
		
		return nil
	}
	
	
	private func readingsAsJSON() -> String? {
		let readings = self.bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: self.onlyFromDate, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
		let readingsAsDicts = readings.map { reading in
			return reading.dictionaryRepresentationForNightScoutUpload
		}
		return convertToJSON(dict: readingsAsDicts)
	}
	
	
	private func treatmentsAsJSON() -> String? {
		let treatments = self.treatmentsAccessor.getLatestTreatments(limit: nil, fromDate: self.onlyFromDate)
		let treatmentsAsDicts = treatments.map { treatment in
			return treatment.dictionaryRepresentationForNightScoutUpload()
		}
		return convertToJSON(dict: treatmentsAsDicts)
	}
	
	
	private func calibrationsAsJSON() -> String? {
		let calibrations = self.calibrationsAccessor.getLatestCalibrations(howManyDays: UserDefaults.standard.retentionPeriodInDays, forSensor: nil)
		let calibrationsAsDicts = calibrations.map { calibration -> [String: Any] in
			/// Use the Cal representation, but add the mbg key with bg value.
			var representation =  calibration.dictionaryRepresentationForCalRecordNightScoutUpload
			representation["mbg"] = calibration.bg
			return representation
		}
		return convertToJSON(dict: calibrationsAsDicts)
	}
	
	
	private func generateJSON(callback: @escaping ((_ json: String?) -> Void)) {
		DispatchQueue.global(qos: .background).async {
			let dataDict: [String : Any] = [
				"ExportInformation": [
					"BeginDate:": self.onlyFromDate.ISOStringFromDate(),
					"EndDate:": Date().ISOStringFromDate(),
				],
				"BgReadings": self.readingsAsJSON() ?? "[]",
				"Treatments": self.treatmentsAsJSON() ?? "[]",
				"Calibrations": self.calibrationsAsJSON() ?? "[]"
			]
			let asJSON = self.convertToJSON(dict: dataDict)
			callback(asJSON)
		}
	}
	
	
	public func exportAllData() {
		generateJSON { json in
			print(json)
		}
	}
	
}
