//
//  DataExporter.swift
//  xdrip
//
//  Created by Eduardo Pietre on 07/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData
import OSLog


/// DataExporter is tha class responsible for
/// retrieving data from CoreDataManager, converting it
/// into JSON and exporting it into a .json file.
public class DataExporter {
	
	/// Imutable file name for the export.
    private static let exportFileName: String = ConstantsHomeView.applicationName + "_ExportedData_" + Date().jsonFilenameStringFromDate() + ".json"
	
	/// This date will determine when the exported data will begin.
	private let onlyFromDate: Date
	
	/// This date determines when the exported data will stop. (Now)
	private let endDate: Date
	
	/// BgReadings instance
	private let bgReadingsAccessor: BgReadingsAccessor
	
	/// Treatments instance
	private let treatmentsAccessor: TreatmentEntryAccessor
	
	/// Calibrations instance
	private let calibrationsAccessor: CalibrationsAccessor
	
	/// Log instance
	private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataExporter)

    /// used for running the data export as task in background
    private var operationQueue: OperationQueue
    
    /// used for reading from coredata in background thread
    private var privateManagedObjectContext: NSManagedObjectContext
	
	/// The callback used to report the progress and result
	private let callback: ((_ progress: ProgressBarStatus<URL>?) -> Void)
	
	/// DateFormatter is expensive, instantiate once and reuse it.
	private let reusableISODateFormatter = Date.ISODateFormatter()
	
	/// Keep track of progress 0.0-1.0 so we can update the callback.
	private var progress: Float = 0
	

	// MARK: - initializer
	
	
	/// - parameters:
	///     - callback: ((_ progress: ProgressBarStatus<URL>?) -> Void)): a callback
	///     that will be called with the information to update the progress
	///     and the URL when done.
	init(coreDataManager: CoreDataManager, callback: @escaping ((_ progress: ProgressBarStatus<URL>?) -> Void)) {
        
		// initialize properties
        
        privateManagedObjectContext = coreDataManager.privateChildManagedObjectContext()
        
		bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
		treatmentsAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
		calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
		
		onlyFromDate = Date(timeIntervalSinceNow: -Double(UserDefaults.standard.retentionPeriodInDays*24*3600))
		endDate = Date()
        
        operationQueue = OperationQueue()
        
		self.callback = callback
	}
	
	/// Method that updates the progress and calls the callback with the new value
	private func partialUpdateCallback(_ increase: Float) {
		self.progress += increase
		self.callback(ProgressBarStatus(progress: self.progress))
	}
	
    /// exportAllData generates the JSON will all data, writes it to a file in a background thread. When finished  it calls the callback function in the UI thread with the file URL as parameter.
    /// - The callback may be called with nil in case of an internal error.
    public func exportAllData() {
        let operation = BlockOperation(block: {
        
            self.generateJSON { json in
                /// Json must not be nil.
                guard let json = json else {
                    trace("in exportAllData, json is nil", log: self.log, category: ConstantsLog.categoryDataExporter, type: .error)
					self.callback(nil)
                    return
                }
                
                // The filePath is calculated using the document directory for the app (first element returned by the array) and appending the exportFileName.
                // If exportFileName already exists, it will be overridden,
                // so there is no need to check and delete it.
                let filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(DataExporter.exportFileName)

                // Write operation may fail.
                do {
                    // Write the json to the file and, if success,
                    // call the callback with the path for the file just written.
                    try json.write(to: filePath, atomically: false, encoding: .utf8)
                    
                    // call the callback function on the main thread
                    DispatchQueue.main.async {
						self.callback(ProgressBarStatus(complete: true, progress: 1.0, data: filePath))
                    }
                    
                } catch let error {
                    trace("in exportAllData, error = %{public}@", log: self.log, category: ConstantsLog.categoryDataExporter, type: .error, error.localizedDescription)
					self.callback(nil)
                }
            }
        })
        
        operationQueue.addOperation {
            operation.start()
        }
        
    }

	/// convertToJSON takes a dictionary and returns a JSON
	/// representation of it, if possible, else returns nil.
	/// - parameters:
	///     - dict : the dict to be converted into JSON.
	/// - returns:
	///     - String? : the JSON output as a string. nil if an error happened.
	private func convertToJSON(dict: Any) -> String? {
		do {
			// Set sortedKeys, without sortedKeys the key order is random for each element.
			let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
			let asString = String(data: jsonData, encoding: .utf8)
			return asString
		} catch let error {
			trace("in convertToJSON, error = %{public}@", log: self.log, category: ConstantsLog.categoryDataExporter, type: .error, error.localizedDescription)
		}
		
		return nil
	}
	
	
	/// readingsAsDicts retrieves all bgReadings and returns them as
	/// an array of dicts, read to be converted into JSON.
	/// Must not be called from a background Thread or CoreData will crash.
	/// - returns:
	///     - [[String: Any]] : an array of dicts, each element is a reading.
	private func readingsAsDicts() -> [[String: Any]] {
        let readings = self.bgReadingsAccessor.getBgReadings(from: self.onlyFromDate, to: self.endDate, on: privateManagedObjectContext)
	
		// Figure out how frequent we must update the progress, 50 updates at total
		let amountOfUpdates: Float = 50
		let updateEveryNReadings = Int(floor(Float(readings.count) / amountOfUpdates))

		var readingsAsDicts : [[String: Any]] = []
		// reserveCapacity so the array will not be reallocated multiple times.
		readingsAsDicts.reserveCapacity(readings.count)
		
		for (index, reading) in readings.enumerated() {
			if (index % updateEveryNReadings == 0) {
				self.partialUpdateCallback(0.50 / amountOfUpdates)
			}
			
			readingsAsDicts.append(reading.dictionaryRepresentationForNightscoutUpload(reuseDateFormatter: reusableISODateFormatter))
		}
		
        return readingsAsDicts
	}
	
	
	/// treatmentsAsDicts retrieves all treatments and returns them as
	/// an array of dicts, read to be converted into JSON.
	/// Must not be called from a background Thread or CoreData will crash.
	/// - returns:
	///     - [[String: Any]] : an array of dicts, each element is a treatment.
	private func treatmentsAsDicts() -> [[String: Any]] {
		let treatments = treatmentsAccessor.getTreatments(fromDate: onlyFromDate, toDate: endDate, on: privateManagedObjectContext)
		let treatmentsAsDicts = treatments.map { treatment in
			return treatment.dictionaryRepresentationForNightscoutUpload(reuseDateFormatter: reusableISODateFormatter)
		}
		return treatmentsAsDicts
	}
	
	
	/// calibrationsAsDicts retrieves all calibrations and returns them as
	/// an array of dicts, read to be converted into JSON.
	/// Must not be called from a background Thread or CoreData will crash.
	/// - returns:
	///     - [[String: Any]] : an array of dicts, each element is a calibration.
	private func calibrationsAsDicts() -> [[String: Any]] {
		let calibrations = calibrationsAccessor.getCalibrations(from: onlyFromDate, to: endDate, on: privateManagedObjectContext)
		let calibrationsAsDicts = calibrations.map { calibration -> [String: Any] in
			// Use the Cal representation, but add the mbg key with bg value.
			var representation =  calibration.dictionaryRepresentationForCalRecordNightscoutUpload
			representation["mbg"] = calibration.bg
			return representation
		}
		return calibrationsAsDicts
	}
	
	
	/// generateJSON generates the JSON will all data and retuns it in an
	/// asynchronous way, calling the callback.
	/// The callback may be called with nil in case of an internal error.
	/// This method can be called from any thread in a safe way.
	/// - parameters:
	///     - callback: ((_ json: String?) -> Void)): a callback that will
	///     be called with the JSON as argument.
	private func generateJSON(callback: @escaping ((_ json: String?) -> Void)) {
        
        privateManagedObjectContext.performAndWait {
			
			self.partialUpdateCallback(0.01)

			///calibrations
			let calibrations = calibrationsAsDicts()
			self.partialUpdateCallback(0.09)
			
			/// treatments
			let treatments = treatmentsAsDicts()
			self.partialUpdateCallback(0.20)
			
			/// readings
			let readings = readingsAsDicts()
			self.partialUpdateCallback(0.05)

            let dataDict: [String : Any] = [
                "ExportInformation": [
                    "BeginDate:": onlyFromDate.ISOStringFromDate(),
                    "EndDate:": endDate.ISOStringFromDate(),
                ],
                "BgReadings": readings,
                "Treatments": treatments,
                "Calibrations": calibrations
            ]
            // Convert dataDict to JSON and returns it.
            let asJSON = convertToJSON(dict: dataDict)
			self.callback(ProgressBarStatus(progress: 0.90))
            callback(asJSON)

        }

    }
	
}
