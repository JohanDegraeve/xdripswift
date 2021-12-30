//
//  TreatmentsInsertViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation


class TreatmentsInsertViewController : UIViewController {
	
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var carbsLabel: UILabel!
	@IBOutlet weak var insulinLabel: UILabel!
	@IBOutlet weak var exerciseLabel: UILabel!
	@IBOutlet weak var cancelButton: UIButton!
	@IBOutlet weak var okButton: UIButton!
	@IBOutlet weak var datePicker: UIDatePicker!
	@IBOutlet weak var carbsTextField: UITextField!
	@IBOutlet weak var insulinTextField: UITextField!
	@IBOutlet weak var exerciseTextField: UITextField!
	
	// MARK: - private properties
    
	/// reference to coreDataManager
	private var coreDataManager:CoreDataManager?
	
	/// handler to be executed when user clicks okButton
	private var entryHandler:((_ entries: [TreatmentEntry]) -> Void)?
	
	/// handler to be executed when user clicks cancelButton
	private var cancelHandler:(() -> Void)?
	
	// MARK: - overrides
    
	// set the status bar content colour to light to match new darker theme
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// Title
		self.titleLabel.text = Texts_TreatmentsView.newEntryTitle
        
		// Labels for each TextField
		self.carbsLabel.text = Texts_TreatmentsView.carbsWithUnit
		self.insulinLabel.text = Texts_TreatmentsView.insulinWithUnit
		self.exerciseLabel.text = Texts_TreatmentsView.exerciseWithUnit
        
		// Buttons
		self.cancelButton.setTitle(Texts_Common.Cancel, for: .normal)
		self.okButton.setTitle(Texts_Common.Ok, for: .normal)
		
		self.addDoneButtonOnNumpad(textField: self.carbsTextField)
		self.addDoneButtonOnNumpad(textField: self.insulinTextField)
		self.addDoneButtonOnNumpad(textField: self.exerciseTextField)
        
		self.setDismissKeyboard()
        
	}

	// MARK: - buttons actions
	
	@IBAction func okButtonTapped(_ sender: UIButton) {
        
		guard let coreDataManager = coreDataManager, let entryHandler = entryHandler else {
			return
		}
		
		var treatments: [TreatmentEntry] = []
		let date = datePicker.date
		
		if let carbsText = carbsTextField.text, let carbs = Double(carbsText) {
			let treatment = TreatmentEntry(date: date, value: carbs, treatmentType: .Carbs, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let insulinText = insulinTextField.text, let insulin = Double(insulinText) {
			let treatment = TreatmentEntry(date: date, value: insulin, treatmentType: .Insulin, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let exerciseText = exerciseTextField.text, let exercise = Double(exerciseText) {
			let treatment = TreatmentEntry(date: date, value: exercise, treatmentType: .Exercise, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		entryHandler(treatments)
        
	}
	
	
	@IBAction func cancelButtonTapped(_ sender: UIButton) {
		if let cancelHandler = cancelHandler {
			cancelHandler()
		}
	}
	
	
	// MARK: - public functions
	
	public func configure(coreDataManager: CoreDataManager?, entryHandler: ((_ entries: [TreatmentEntry]) -> Void)?, cancelHandler:(() -> Void)?) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.entryHandler = entryHandler
		self.cancelHandler = cancelHandler
        
	}
	
	
	// MARK: - private functions
	
	private func addDoneButtonOnNumpad(textField: UITextField) {
		
		let keypadToolbar: UIToolbar = UIToolbar()
		
		// add a done button to the numberpad
		keypadToolbar.items = [
			UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil),
			UIBarButtonItem(title: Texts_Common.Ok, style: UIBarButtonItem.Style.done, target: textField, action: #selector(UITextField.resignFirstResponder))
		]
		keypadToolbar.sizeToFit()
		// add a toolbar with a done button above the number pad
		textField.inputAccessoryView = keypadToolbar
        
	}
	
	func setDismissKeyboard() {
	   let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action:    #selector(self.dismissKeyboardTouchOutside))
	   tap.cancelsTouchesInView = false
	   view.addGestureRecognizer(tap)
	}
	
	@objc private func dismissKeyboardTouchOutside() {
	   view.endEditing(true)
	}
	
}
