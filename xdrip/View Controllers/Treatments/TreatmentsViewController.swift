//
//  TreatmentsViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit


class TreatmentsViewController : UIViewController {
	
	// MARK: - private properties
	
	/// TreatmentCollection is used to get and sort data.
	private var treatmentCollection: TreatmentCollection?
	
	/// reference to coreDataManager
	private var coreDataManager: CoreDataManager?
	
	/// reference to nightScoutUploadManager
	private var nightScoutUploadManager: NightScoutUploadManager?
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor?
	
	// Outlets
	@IBOutlet weak var titleNavigation: UINavigationItem!
	@IBOutlet weak var tableView: UITableView!
	
	/// Upload button action.
	@IBAction func uploadButtonTapped(_ sender: UIBarButtonItem) {
		// Uploads to nighscout and if sucess display an alert.
		nightScoutUploadManager?.uploadTreatmentsToNightScout(sucessHandler: {
			// Make sure to run alert in the correct thread.
			DispatchQueue.main.async {
				let alert = UIAlertController(title: Texts_TreatmentsView.success, message: Texts_TreatmentsView.uploadCompleted, actionHandler: nil)

				self.present(alert, animated: true, completion: nil)
			}
		})
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// Fixes dark mode issues
		if let navigationBar = navigationController?.navigationBar {
			navigationBar.barStyle = UIBarStyle.blackTranslucent
			navigationBar.barTintColor  = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
		}
		
		self.titleNavigation.title = Texts_TreatmentsView.treatmentsTitle
	}
	

	/// Override prepare for segue, we must call configure on the TreatmentsInsertViewController.
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		// Check if is the segueIdentifier to TreatmentsInsert.
		guard let segueIndentifier = segue.identifier, segueIndentifier == TreatmentsViewController.SegueIdentifiers.TreatmentsToNewTreatmentsSegue.rawValue else {
			return
		}
		
		// Cast the destination to TreatmentsInsertViewController (if possible).
		// And assures the destination and coreData are valid.
		guard let insertViewController = segue.destination as? TreatmentsInsertViewController, let coreDataManager = coreDataManager else {

			fatalError("In TreatmentsInsertViewController, prepare for segue, viewcontroller is not TreatmentsInsertViewController or coreDataManager is nil" )
		}
		
		// Handler that will be called when entries are created.
		// No need to use the variable, reload will load from CoreData.
		let entryHandler = { (entries : [TreatmentEntry]) in
			self.coreDataManager?.saveChanges()
			insertViewController.dismiss(animated: true, completion: nil)
			self.reload()
		}
		
		// Configure insertViewController with CoreData instance and complete handler.
		insertViewController.configure(coreDataManager: coreDataManager, entryHandler: entryHandler)
	}
	
	
	// MARK: - public functions
	
	/// Configure will be called before this view is presented for the user.
	public func configure(coreDataManager: CoreDataManager, nightScoutUploadManager: NightScoutUploadManager, treatmentEntryAccessor: TreatmentEntryAccessor) {
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.nightScoutUploadManager = nightScoutUploadManager
		self.treatmentEntryAccessor = treatmentEntryAccessor
	
		self.reload()
	}
	

	// MARK: - private functions
	
	/// Reloads treatmentCollection and calls reloadData on tableView.
	private func reload() {
		guard let treatmentEntryAccessor = treatmentEntryAccessor else { return }
		let treatments = treatmentEntryAccessor.getLatestTreatments()
		self.treatmentCollection = TreatmentCollection(treatments: treatments)

		self.tableView.reloadData()
	}
}


/// defines perform segue identifiers used within TreatmentsViewController
extension TreatmentsViewController {
	
	public enum SegueIdentifiers:String {
		/// to go from TreatmentsViewController to TreatmentsInsertViewController
		case TreatmentsToNewTreatmentsSegue = "TreatmentsToNewTreatmentsSegue"
	}
	
}


// MARK: - conform to UITableViewDelegate and UITableViewDataSource

extension TreatmentsViewController: UITableViewDelegate, UITableViewDataSource {
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return self.treatmentCollection?.dateOnlys().count ?? 0
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let treatmentCollection = treatmentCollection else {
			return 0
		}
		// Gets the treatments given the section as the date index.
		let treatments = treatmentCollection.treatmentsForDateOnlyAt(section)
		return treatments.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "TreatmentsCell", for: indexPath) as? TreatmentTableViewCell, let treatmentCollection = treatmentCollection else {
			fatalError("Unexpected Table View Cell")
		}
		
		let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
		cell.setupWithTreatment(treatment)
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
            
			guard let treatmentCollection = treatmentCollection, let treatmentEntryAccessor = treatmentEntryAccessor, let coreDataManager = coreDataManager else {
				return
			}

			// Get the treatment the user wants to delete.
			let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
			
			// Deletes the treatment from CoreData.
			treatmentEntryAccessor.delete(treatmentEntry: treatment, on: coreDataManager.mainManagedObjectContext)
			
            coreDataManager.saveChanges()
            
			// Reloads data and table.
			self.reload()
            
		}
	}
	
	func tableView( _ tableView : UITableView,  titleForHeaderInSection section: Int) -> String? {
		
		guard let treatmentCollection = treatmentCollection else {
			return ""
		}
		
		// Title will be the date formatted.
		let date = treatmentCollection.dateOnlyAt(section).date

		let formatter = DateFormatter()
		formatter.dateFormat = "dd/MM/yyyy"

		return formatter.string(from: date)
	}
	
	func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard let titleView = view as? UITableViewHeaderFooterView else {
			return
		}
		
		// Header background color
		titleView.tintColor = UIColor.gray
		
		// Set textcolor to white and increase font
		if let textLabel = titleView.textLabel {
			textLabel.textColor = UIColor.white
			textLabel.font = textLabel.font.withSize(18)
		}
	}

	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
}

