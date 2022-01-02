//
//  TreatmentsInsertViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation


class TreatmentsInsertViewController : UIViewController {
	
	@IBOutlet weak var titleNavigation: UINavigationItem!
	@IBOutlet weak var carbsLabel: UILabel!
	@IBOutlet weak var insulinLabel: UILabel!
	@IBOutlet weak var exerciseLabel: UILabel!
	@IBOutlet weak var doneButton: UIBarButtonItem!
	@IBOutlet weak var datePicker: UIDatePicker!
	@IBOutlet weak var carbsTextField: UITextField!
	@IBOutlet weak var insulinTextField: UITextField!
	@IBOutlet weak var exerciseTextField: UITextField!
	
	// MARK: - private properties
    
	/// reference to coreDataManager
	private var coreDataManager:CoreDataManager?
	
	/// handler to be executed when user clicks okButton
	private var entryHandler:((_ entries: [TreatmentEntry]) -> Void)?
	
	// MARK: - overrides
    
	// set the status bar content colour to light to match new darker theme
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// Fixes dark mode issues
		if let navigationBar = navigationController?.navigationBar {
			navigationBar.barStyle = UIBarStyle.blackTranslucent
			navigationBar.barTintColor  = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
		}
		
		// Title
		self.titleNavigation.title = Texts_TreatmentsView.newEntryTitle
        
		// Labels for each TextField
		self.carbsLabel.text = Texts_TreatmentsView.carbsWithUnit
		self.insulinLabel.text = Texts_TreatmentsView.insulinWithUnit
		self.exerciseLabel.text = Texts_TreatmentsView.exerciseWithUnit
		
		// Done button
//		self.doneButton.title = Texts_Common.
        
		self.addDoneButtonOnNumpad(textField: self.carbsTextField)
		self.addDoneButtonOnNumpad(textField: self.insulinTextField)
		self.addDoneButtonOnNumpad(textField: self.exerciseTextField)
        
		self.setDismissKeyboard()
	}

	// MARK: - buttons actions
	
	@IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
		guard let coreDataManager = coreDataManager, let entryHandler = entryHandler else {
			return
		}
		
		var treatments: [TreatmentEntry] = []
		let date = datePicker.date
		
		if let carbsText = carbsTextField.text, let carbs = Double(carbsText), carbs > 0 {
			let treatment = TreatmentEntry(date: date, value: carbs, treatmentType: .Carbs, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let insulinText = insulinTextField.text, let insulin = Double(insulinText), insulin > 0 {
			let treatment = TreatmentEntry(date: date, value: insulin, treatmentType: .Insulin, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let exerciseText = exerciseTextField.text, let exercise = Double(exerciseText), exercise > 0 {
			let treatment = TreatmentEntry(date: date, value: exercise, treatmentType: .Exercise, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		entryHandler(treatments)
		
		// Pops the current view (this)
		self.navigationController?.popViewController(animated: true)
	}
	
	
	// MARK: - public functions
	
	public func configure(coreDataManager: CoreDataManager?, entryHandler: ((_ entries: [TreatmentEntry]) -> Void)?) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.entryHandler = entryHandler
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
