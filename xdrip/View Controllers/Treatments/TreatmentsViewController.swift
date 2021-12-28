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
	
	// TreatmentCollection is used to get and sort data.
	private var treatmentCollection: TreatmentCollection?
	
	/// reference to coreDataManager
	private var coreDataManager: CoreDataManager?
	
	/// reference to nightScoutUploadManager
	private var nightScoutUploadManager: NightScoutUploadManager?
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor?
	
	// Outlets
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var newButton: UIButton!
	@IBOutlet weak var tableView: UITableView!
	
	// 'New' button action.
	@IBAction func newButtonTapped(_ sender: UIButton) {
		self.presentTreatmentsInsert()
	}
	
	// Upload button action.
	@IBAction func uploadButtonTapped(_ sender: UIButton) {
		// Uploads to nighscout and if sucess display an alert.
		nightScoutUploadManager?.uploadTreatmentsToNightScout(sucessHandler: {
			// Make sure to run alert in the correct thread.
			DispatchQueue.main.async {
				let alert = UIAlertController(title: Texts_TreatmentsView.success, message: Texts_TreatmentsView.uploadCompleted, actionHandler: nil)

				self.present(alert, animated: true, completion: nil)
			}
		})
	}
	
	// Overide viewWillAppear and do localization.
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		self.titleLabel.text = Texts_TreatmentsView.treatmentsTitle
		self.newButton.setTitle(Texts_TreatmentsView.newButton, for: .normal)
	}
	
	
	// MARK: - public functions
	
	// Configure will be called before this view is presented for the user.
	public func configure(coreDataManager: CoreDataManager, nightScoutUploadManager: NightScoutUploadManager, treatmentEntryAccessor: TreatmentEntryAccessor) {
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.nightScoutUploadManager = nightScoutUploadManager
		self.treatmentEntryAccessor = treatmentEntryAccessor
	
		self.reload()
	}
	

	// MARK: - private functions
	
	// Reloads treatmentCollection and calls reloadData on tableView.
	private func reload() {
		guard let treatmentEntryAccessor = treatmentEntryAccessor else { return }
		let treatments = treatmentEntryAccessor.getLatestTreatments()
		self.treatmentCollection = TreatmentCollection(treatments: treatments)

		self.tableView.reloadData()
	}
	

	// Presents the TreatmentsInsertViewController.
	private func presentTreatmentsInsert() {
		// Controller instance created from storyboard identifier.
		let insertViewController = UIStoryboard.main.instantiateViewController(withIdentifier: "TreatmentsInsertViewController") as! TreatmentsInsertViewController
		insertViewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
		
		// Handler that will be called when entries are created.
		// No need to use the variable, reload will load from CoreData.
		let entryHandler = { (entries : [TreatmentEntry]) in
			self.coreDataManager?.saveChanges()
			insertViewController.dismiss(animated: true, completion: nil)
			self.reload()
		}
		
		// Handler that will be called when user cancels in TreatmentsInsertViewController.
		// Just dismiss the view.
		let cancelHandler = {
			insertViewController.dismiss(animated: true, completion: nil)
		}
		
		// Configure insertViewController with CoreData instance and handlers.
		insertViewController.configure(coreDataManager: coreDataManager, entryHandler: entryHandler, cancelHandler: cancelHandler)

		// present it
		self.present(insertViewController, animated: true)
	}
}


// MARK: - UITableView related

extension TreatmentsViewController: UITableViewDelegate, UITableViewDataSource {
	
	// Number of sections will be the number of days in data.
	// TreatmentCollection will take care of it for us.
	func numberOfSections(in tableView: UITableView) -> Int {
		return self.treatmentCollection?.dateOnlys().count ?? 0
	}
	
	// Number of rows in section will be the number of treatments at a given date
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let treatmentCollection = treatmentCollection else {
			return 0
		}
		// Gets the treatments given the section as the date index.
		let treatments = treatmentCollection.treatmentsForDateOnlyAt(section)
		return treatments.count
	}
	
	// Setups and returns a cell for given indexPath.
	// indexPath.section will be interpreted as the index of the date
	// indexPath.row will be interpreted as the treatment index for treatments at the date
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "TreatmentsCell", for: indexPath) as? TreatmentTableViewCell, let treatmentCollection = treatmentCollection else {
			fatalError("Unexpected Table View Cell")
		}
		
		let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
		cell.setupWithTreatment(treatment)
		
		return cell
	}
	
	// Enables cell deletion.
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	// Called when user edits a cell.
	// Only used for deletion.
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
			guard let treatmentCollection = treatmentCollection, let treatmentEntryAccessor = treatmentEntryAccessor, let coreDataManager = coreDataManager else {
				return
			}

			// Get the treatment the user wants to delete.
			let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
			
			// Deletes the treatment from CoreData.
			treatmentEntryAccessor.delete(treatmentEntry: treatment, on: coreDataManager.mainManagedObjectContext)
			
			// Reloads data and table.
			self.reload()
		}
	}
	
	
	// Returns the title for a given table section.
	func tableView( _ tableView : UITableView,  titleForHeaderInSection section: Int) -> String? {
		
		guard let treatmentCollection = treatmentCollection else {
			return ""
		}
		
		// Title will be the date formated.
		let date = treatmentCollection.dateOnlyAt(section).date

		let formatter = DateFormatter()
		formatter.dateFormat = "dd/MM/yyyy"

		return formatter.string(from: date)
	}
	
	// Called before each section header is displayed.
	// Can be used to set font, text color, background color and other properties.
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

	// The height for each section header.
	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
}

