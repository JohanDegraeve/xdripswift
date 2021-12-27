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
	
	// Will store the recent treatments to be displayed
	private var treatments: [TreatmentEntry] = []
	
	/// reference to coreDataManager
	private var coreDataManager: CoreDataManager?
	
	/// reference to nightScoutUploadManager
	private var nightScoutUploadManager: NightScoutUploadManager?
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor?
	
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var newButton: UIButton!
	@IBOutlet weak var tableView: UITableView!
	
	@IBAction func newButtonTapped(_ sender: UIButton) {
		self.presentTreatmentsInsert()
	}
	
	@IBAction func uploadButtonTapped(_ sender: UIButton) {
		nightScoutUploadManager?.uploadTreatmentsToNightScout()
		let alert = UIAlertController(title: Texts_Common.Ok, message: Texts_Common.Ok, actionHandler: nil)
						
		self.present(alert, animated: true, completion: nil)
	}
	
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		self.titleLabel.text = Texts_TreatmentsView.treatmentsTitle
		self.newButton.setTitle(Texts_TreatmentsView.newButton, for: .normal)
	}
	
	
	// MARK: - public functions
	
	public func configure(coreDataManager: CoreDataManager, nightScoutUploadManager: NightScoutUploadManager, treatmentEntryAccessor: TreatmentEntryAccessor) {
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.nightScoutUploadManager = nightScoutUploadManager
		self.treatmentEntryAccessor = treatmentEntryAccessor
	
		self.reloadTreatments()
		self.tableView.reloadData()
	}
	
	// MARK: - private functions
	
	private func reloadTreatments() {
		guard let treatmentEntryAccessor = treatmentEntryAccessor else { return }
		self.treatments = treatmentEntryAccessor.getLatestTreatments()
	}
	
	private func presentTreatmentsInsert() {
		let insertViewController = UIStoryboard.main.instantiateViewController(withIdentifier: "TreatmentsInsertViewController") as! TreatmentsInsertViewController
		insertViewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
		
		let entryHandler = { (entries : [TreatmentEntry]) in
			self.coreDataManager?.saveChanges()
			insertViewController.dismiss(animated: true, completion: nil)
			self.reloadTreatments()
			self.tableView.reloadData()
		}
		
		let cancelHandler = {
			insertViewController.dismiss(animated: true, completion: nil)
		}
		
		//configure insertViewController
		insertViewController.configure(coreDataManager: coreDataManager, entryHandler: entryHandler, cancelHandler: cancelHandler)

		// present it
		self.present(insertViewController, animated: true)
	}
}


// MARK: - UITableView related

extension TreatmentsViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.treatments.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "TreatmentsCell", for: indexPath) as? TreatmentTableViewCell else {
			fatalError("Unexpected Table View Cell")
		}
		
		let treatment = self.treatments[indexPath.row]
		cell.setupWithTreatment(treatment)
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
			guard let treatmentEntryAccessor = treatmentEntryAccessor, let coreDataManager = coreDataManager else {
				return
			}
			let treatment = treatments[indexPath.row]
			
			treatmentEntryAccessor.delete(treatmentEntry: treatment, on: coreDataManager.mainManagedObjectContext)
			
			treatments.remove(at: indexPath.row)
			
			self.reloadTreatments()
			self.tableView.reloadData()
		}
	}
}

