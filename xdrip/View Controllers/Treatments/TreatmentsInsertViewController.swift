//
//  TreatmentsInsertViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

class TreatmentsInsertViewController: UIViewController {
    @IBOutlet weak var titleNavigation: UINavigationItem!
    
    @IBOutlet weak var carbsLabel: UILabel!
    @IBOutlet weak var insulinLabel: UILabel!
    @IBOutlet weak var exerciseLabel: UILabel!
    @IBOutlet weak var basalRateLabel: UILabel!
    @IBOutlet weak var bgCheckLabel: UILabel!
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
    @IBOutlet weak var carbsTextField: UITextField!
    @IBOutlet weak var insulinTextField: UITextField!
    @IBOutlet weak var exerciseTextField: UITextField!
    @IBOutlet weak var basalRateTextField: UITextField! // not currently used
    @IBOutlet weak var bgCheckTextField: UITextField!
    
    @IBOutlet weak var carbsUnitLabel: UILabel!
    @IBOutlet weak var insulinUnitLabel: UILabel!
    @IBOutlet weak var exerciseUnitLabel: UILabel!
    @IBOutlet weak var basalRateUnitLabel: UILabel! // not currently used
    @IBOutlet weak var bgCheckUnitLabel: UILabel!
    
    @IBOutlet weak var carbsStackView: UIStackView!
    @IBOutlet weak var insulinStackView: UIStackView!
    @IBOutlet weak var exerciseStackView: UIStackView!
    @IBOutlet weak var basalRateStackView: UIStackView! // not currently used
    @IBOutlet weak var bgCheckStackView: UIStackView!
    
    @IBOutlet weak var enteredByStackView: UIStackView!
    @IBOutlet weak var enteredByLabel: UILabel!
    @IBOutlet weak var enteredByValue: UILabel!
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager: CoreDataManager!
	
    /// handler to be executed when user clicks okButton
    private var completionHandler: (() -> Void)?
    
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
        // let's hide the basal rates when adding a new treatment as it's not needed whilst we're just using it in Nightscout follower mode
        basalRateStackView.isHidden = true
        
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            datePicker.date = treatMentEntryToUpdate.date
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		
        // Fixes dark mode issues
        if let navigationBar = navigationController?.navigationBar {
            navigationBar.barStyle = UIBarStyle.black
            navigationBar.isTranslucent = true
            navigationBar.barTintColor = UIColor.black
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        }
		
        // Title
        titleNavigation.title = Texts_TreatmentsView.newEntryTitle
        
        // update the BG Check placeholder text depending on BG unit being used
        bgCheckTextField.placeholder = Double(0).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        // Labels for each TextField
        carbsLabel.text = Texts_TreatmentsView.carbs
        insulinLabel.text = Texts_TreatmentsView.insulin
        exerciseLabel.text = Texts_TreatmentsView.exercise
        bgCheckLabel.text = Texts_TreatmentsView.bgCheck
        basalRateLabel.text = Texts_TreatmentsView.basalRate
		
        // Unit labels for each TextField
        carbsUnitLabel.text = Texts_TreatmentsView.carbsUnit
        insulinUnitLabel.text = Texts_TreatmentsView.insulinUnit
        exerciseUnitLabel.text = Texts_TreatmentsView.exerciseUnit
        bgCheckUnitLabel.text = String(UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
        basalRateUnitLabel.text = Texts_TreatmentsView.basalRateUnit
        
        // Done button
        addDoneButtonOnNumpad(textField: carbsTextField)
        addDoneButtonOnNumpad(textField: insulinTextField)
        addDoneButtonOnNumpad(textField: exerciseTextField)
        addDoneButtonOnNumpad(textField: bgCheckTextField)
        
        // Entered by field if needed
        enteredByLabel.text = Texts_TreatmentsView.enteredBy
        enteredByValue.text = treatMentEntryToUpdate?.enteredBy ?? "Unknown"
        enteredByValue.textColor = treatMentEntryToUpdate?.enteredBy != nil ? UIColor(resource: .colorSecondary) : UIColor(resource: .colorTertiary)
        
        setDismissKeyboard()

        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            switch treatMentEntryToUpdate.treatmentType {
            case .Carbs:
                // set text to value of treatMentEntryToUpdate
                carbsTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other stack views
                insulinStackView.isHidden = true
                exerciseStackView.isHidden = true
                basalRateStackView.isHidden = true
                bgCheckStackView.isHidden = true
                
            case .Exercise:
                // set text to value of treatMentEntryToUpdate
                exerciseTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other stack views
                carbsStackView.isHidden = true
                insulinStackView.isHidden = true
                basalRateStackView.isHidden = true
                bgCheckStackView.isHidden = true
                
            case .Insulin:
                // set text to value of treatMentEntryToUpdate
                insulinTextField.text = (round(treatMentEntryToUpdate.value * 100) / 100).stringWithoutTrailingZeroes
                
                // hide the other stack views
                carbsStackView.isHidden = true
                exerciseStackView.isHidden = true
                basalRateStackView.isHidden = true
                bgCheckStackView.isHidden = true
                
            case .BgCheck:
                // set text to value of treatMentEntryToUpdate
                // as the BG Check values are always stored in coredata as mg/dl, the number must be converted and rounded as needed
                bgCheckTextField.text = treatMentEntryToUpdate.value.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).stringWithoutTrailingZeroes
                
                // hide the other stack views
                insulinStackView.isHidden = true
                carbsStackView.isHidden = true
                basalRateStackView.isHidden = true
                exerciseStackView.isHidden = true
                
            case .Basal:
                // set text to value of treatMentEntryToUpdate
                basalRateTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other stack views
                insulinStackView.isHidden = true
                carbsStackView.isHidden = true
                exerciseStackView.isHidden = true
                bgCheckStackView.isHidden = true
                
            default:
                break
            }
        }
    }

    // MARK: - buttons actions
	
    @IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
        // if treatMentEntryToUpdate not nil, then assign new value or delete it
        // it's either type carbs, insulin, exercise or a BG check
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            // code reused three times
            // checks if text in textfield exists, has value > 0.
            // if yes, assigns value to treatMentEntryToUpdate.value
            // if no deletes treatMentEntryToUpdate
            let updateFunction = { (textField: UITextField) in
                
                // the values are stored in coredate with a "." decimal point. We need to just ensure the decimal separator is a point and not a comma (which some locales use)
                if let text = textField.text, let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 {
                    // keep track if changed or not
                    var treatMentEntryToUpdateChanged = false
                    
                    if treatMentEntryToUpdate.value != value {
                        if treatMentEntryToUpdate.treatmentType == .BgCheck {
                            treatMentEntryToUpdate.value = value.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                            
                        } else {
                            treatMentEntryToUpdate.value = value
                        }
                        
                        // sets text in textField to "0" to avoid that new treatmentEntry is created
                        textField.text = "0"
                        
                        treatMentEntryToUpdateChanged = true
                    }
                    
                    // check if the user is editing a future bg check or trying to edit one into the future. This can be dangerous for some APS systems that use BG checks as well as CGM values for their predictions. Set the current time to now.
                    if treatMentEntryToUpdate.treatmentType == .BgCheck && (treatMentEntryToUpdate.date > Date() || self.datePicker.date > Date()) {
                        self.datePicker.setDate(Date(), animated: true)
                        
                        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_TreatmentsView.cannotStoreFutureBGCheck, actionHandler: nil)
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                    
                    if treatMentEntryToUpdate.date != self.datePicker.date {
                        treatMentEntryToUpdate.date = self.datePicker.date
                        
                        treatMentEntryToUpdateChanged = true
                    }
                    
                    if treatMentEntryToUpdateChanged {
                        // permenant save in coredata
                        self.coreDataManager.saveChanges()
                        
                        // set uploaded to false so that the entry is synced with Nightscout
                        treatMentEntryToUpdate.uploaded = false

                        // trigger nightscoutsync
                        self.setNightscoutSyncRequiredToTrue()
                        
                        // trigger prediction update
                        UserDefaults.standard.predictionsUpdateNeeded = true
                    }
                    
                } else {
                    // even though there is not a valid/useable number entered, only delete the treatment if the user has really changed it to zero. If they didn't enter zero then just disregard the input.
                    if let text = textField.text, let value = Double(text.replacingOccurrences(of: ",", with: ".")), value == 0 {
                        // text is nil or "0", set treatmentdeleted to true
                        treatMentEntryToUpdate.treatmentdeleted = true
                        
                        // set uploaded to false so that the entry is synced with Nightscout
                        treatMentEntryToUpdate.uploaded = false
                        
                        // trigger nightscoutsync
                        self.setNightscoutSyncRequiredToTrue()
                        
                        // trigger prediction update
                        UserDefaults.standard.predictionsUpdateNeeded = true
                        
                        self.treatMentEntryToUpdate = nil
                    }
                }
            }

            switch treatMentEntryToUpdate.treatmentType {
            case .Carbs:
                updateFunction(carbsTextField)
                    
            case .Insulin:
                updateFunction(insulinTextField)
                
            case .Exercise:
                updateFunction(exerciseTextField)
                
            case .BgCheck:
                updateFunction(bgCheckTextField)
                
            case .Basal, .SiteChange, .SensorStart, .PumpBatteryChange:
                break
            }
            
        } else {
            // viewcontroller is opened to create a new treatmentEntry
            
            // if there's more than one new treatmentEntry being created here, then each will be created with a small difference in timestamp, ie 1 millisecond
            // because, after uploading to Nightscout, the timestamp is is used to recognize/find back the actualy event, and so to find the id assigned by Nightscout
            // (probably it's better that xDrip4iOS would assign the id)
            // dateOffset is used to keep track of the offset to use
            var dateOffset = TimeInterval(0.0)
            
            // code reused three times
            // checks if text is not nil, has value > 0.
            // if yes, creates a new TreatmentEntry
            let createFunction = { [self] (text: String?, treatmentType: TreatmentType) in
                
                if let text = text, var value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 {
                    if treatmentType == .BgCheck {
                        value = value.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                            
                        // For safety in some APS systems, ensure the user isn't trying to add a future BG Check. If so, warn/inform them and set the datePicker date to the actual date/time.
                        if datePicker.date > Date() {
                            datePicker.setDate(Date(), animated: true)
                                
                            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_TreatmentsView.cannotStoreFutureBGCheck, actionHandler: nil)
                                
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                    
                    // create the treatment and append to treatments
                    _ = TreatmentEntry(date: Date(timeInterval: dateOffset, since: datePicker.date), value: value, treatmentType: treatmentType, nightscoutEventType: nil, enteredBy: nil, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)
                    
                    // trigger nightscoutsync
                    setNightscoutSyncRequiredToTrue()
                    
                    // save to coredata
                    coreDataManager.saveChanges()

                    // increase dateOffset in case a next/new treatment will be be created
                    dateOffset = dateOffset + TimeInterval(0.001)
                }
            }
            
            // call createFunction for each TextField
            createFunction(carbsTextField.text, .Carbs)
            createFunction(insulinTextField.text, .Insulin)
            createFunction(exerciseTextField.text, .Exercise)
            createFunction(bgCheckTextField.text, .BgCheck)
        }
        
        // call completionHandler
        if let completionHandler = completionHandler {
            completionHandler()
        }
		
        // Pops the current view (this)
        navigationController?.popViewController(animated: true)
    }
	
    // MARK: - public functions
	
    /// - parameters:
    ///     - treatMentEntryToUpdate
    public func configure(treatMentEntryToUpdate: TreatmentEntry?, coreDataManager: CoreDataManager, completionHandler: @escaping (() -> Void)) {
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.completionHandler = completionHandler
        
        self.treatMentEntryToUpdate = treatMentEntryToUpdate
    }
	
    // MARK: - private functions
	
    private func addDoneButtonOnNumpad(textField: UITextField) {
        let keypadToolbar = UIToolbar()
		
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTouchOutside))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
	
    @objc private func dismissKeyboardTouchOutside() {
        view.endEditing(true)
    }
    
    // set the flag to sync Nightscout treatments if a short time has passed since the last time
    // as accessing userdefaults is not thread-safe
    private func setNightscoutSyncRequiredToTrue() {
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
            UserDefaults.standard.timeStampLatestTreatmentModification = Date()
        }
    }
}
