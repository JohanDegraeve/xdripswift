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
	private var completionHandler:(() -> Void)?
    
    /// used if this viewcontroller is used to update an existing entry
    /// - if nil then viewcontroller is used to add a (or mote) new entry (or entries)
    private var treatMentEntryToUpdate: TreatmentEntry?
	
    // MARK: - View Life Cycle
    
	// set the status bar content colour to light to match new darker theme
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
    // will assign datePicker.date to treatMentEntryToUpdate.date
    override func viewDidLoad() {
    
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            
            datePicker.date = treatMentEntryToUpdate.date
            
        }
        
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
		self.addDoneButtonOnNumpad(textField: self.carbsTextField)
		self.addDoneButtonOnNumpad(textField: self.insulinTextField)
		self.addDoneButtonOnNumpad(textField: self.exerciseTextField)
        
		self.setDismissKeyboard()

        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            
            switch treatMentEntryToUpdate.treatmentType {
                
            case .Carbs:
                carbsTextField.text = treatMentEntryToUpdate.value.description
                
            case .Exercise:
                exerciseTextField.text = treatMentEntryToUpdate.value.description
                
            case .Insulin:
                insulinTextField.text = treatMentEntryToUpdate.value.description
                
            }
            
        }
	}

	// MARK: - buttons actions
	
	@IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
        
		guard let coreDataManager = coreDataManager, let completionHandler = completionHandler else {
			return
		}
		
		var treatments: [TreatmentEntry] = []
        
        // if treatMentEntryToUpdate not nil, then assign new value or delete it
        // it's either type carbs, insulin or exercise
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {

            // code reused three times
            // checks if text in textfield exists, has value > 0.
            // if yes, assigns value to treatMentEntryToUpdate.value
            // if no deletes treatMentEntryToUpdate
            // sets text in textField to "0" to avoid that new treatmentEntry is created
            let updateFunction = { (textField: UITextField) in
                
                if let text = textField.text, let value = Double(text), value > 0 {
                    treatMentEntryToUpdate.value = value
                    textField.text = "0"
                } else {
                    coreDataManager.mainManagedObjectContext.delete(treatMentEntryToUpdate)
                    self.treatMentEntryToUpdate = nil
                }
            }

            switch treatMentEntryToUpdate.treatmentType {
               
            case .Carbs:
                updateFunction(carbsTextField)
                    
            case .Insulin:
                updateFunction(insulinTextField)
                
            case .Exercise:
                updateFunction(exerciseTextField)
                
            }
            
        }
        
		if let carbsText = carbsTextField.text, let carbs = Double(carbsText), carbs > 0 {
			let treatment = TreatmentEntry(date: datePicker.date, value: carbs, treatmentType: .Carbs, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let insulinText = insulinTextField.text, let insulin = Double(insulinText), insulin > 0 {
			let treatment = TreatmentEntry(date: datePicker.date, value: insulin, treatmentType: .Insulin, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
		if let exerciseText = exerciseTextField.text, let exercise = Double(exerciseText), exercise > 0 {
			let treatment = TreatmentEntry(date: datePicker.date, value: exercise, treatmentType: .Exercise, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
			treatments.append(treatment)
		}
		
        // permenant save in coredata
        coreDataManager.saveChanges()
        
        // call
		completionHandler()
		
		// Pops the current view (this)
		self.navigationController?.popViewController(animated: true)
        
	}
	
	
	// MARK: - public functions
	
    /// - parameters:
    ///     - treatMentEntryToUpdate
    public func configure(treatMentEntryToUpdate: TreatmentEntry?, coreDataManager: CoreDataManager?, completionHandler: @escaping (() -> Void)) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.completionHandler = completionHandler
        
        self.treatMentEntryToUpdate = treatMentEntryToUpdate
        
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
