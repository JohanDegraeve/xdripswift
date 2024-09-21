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
	private var coreDataManager: CoreDataManager!
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor!
    
    /// keep track of whether the observers were already added/registered (to make sure before we try to remove them)
    private var didAddObservers: Bool = false
	
	// Outlets
	@IBOutlet weak var titleNavigation: UINavigationItem!
    
	@IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var filterLabelOutlet: UILabel!
    
    @IBOutlet weak var filterSmallBolusButtonOutlet: UIButton!
    
    @IBOutlet weak var filterBolusButtonOutlet: UIButton!
    
    @IBOutlet weak var filterCarbsButtonOutlet: UIButton!
    
    @IBOutlet weak var filterBgCheckButtonOutlet: UIButton!
    
    // Actions
    @IBAction func filterSmallBolusButtonAction(_ sender: UIButton) {
        
        // invert the value. Changing this UserDefault will also trigger the observer to update the table
        UserDefaults.standard.showSmallBolusTreatmentsInList = !UserDefaults.standard.showSmallBolusTreatmentsInList
        
        // set the button state
        filterSmallBolusButtonOutlet.isSelected = UserDefaults.standard.showSmallBolusTreatmentsInList
        
    }
    
    @IBAction func filterBolusButtonAction(_ sender: UIButton) {
        
        // invert the value. Changing this UserDefault will also trigger the observer to update the table
        UserDefaults.standard.showBolusTreatmentsInList = !UserDefaults.standard.showBolusTreatmentsInList
        
        // set the button state
        filterBolusButtonOutlet.isSelected = UserDefaults.standard.showBolusTreatmentsInList
        
        // if the user chooses to hide all boluses, then also disable the showSmallBolus button as it is irrelavant
        if !UserDefaults.standard.showBolusTreatmentsInList {
            
            filterSmallBolusButtonOutlet.disable()
            
        } else {
            
            // if not, then enable it
            filterSmallBolusButtonOutlet.enable()
            
        }
        
    }
    
    @IBAction func filterCarbsButtonAction(_ sender: UIButton) {
        
        // invert the value. Changing this UserDefault will also trigger the observer to update the table
        UserDefaults.standard.showCarbsTreatmentsInList = !UserDefaults.standard.showCarbsTreatmentsInList
        
        // set the button state
        filterCarbsButtonOutlet.isSelected = UserDefaults.standard.showCarbsTreatmentsInList
        
    }
    
    @IBAction func filterBgCheckButtonAction(_ sender: UIButton) {
        
        // invert the value. Changing this UserDefault will also trigger the observer to update the table
        UserDefaults.standard.showBgCheckTreatmentsInList = !UserDefaults.standard.showBgCheckTreatmentsInList
        
        // set the button state
        filterBgCheckButtonOutlet.isSelected = UserDefaults.standard.showBgCheckTreatmentsInList
        
    }
    
	
    // MARK: - View Life Cycle
    
	override func viewWillAppear(_ animated: Bool) {
        
		super.viewWillAppear(animated)
		
		// Fixes dark mode issues
		if let navigationBar = navigationController?.navigationBar {
			navigationBar.barStyle = UIBarStyle.black
            navigationBar.isTranslucent = true
			navigationBar.barTintColor  = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
		}
        
        // set the initial filter button states as per the values in UserDefaults
        filterSmallBolusButtonOutlet.isSelected = UserDefaults.standard.showSmallBolusTreatmentsInList
        filterBolusButtonOutlet.isSelected = UserDefaults.standard.showBolusTreatmentsInList
        filterCarbsButtonOutlet.isSelected = UserDefaults.standard.showCarbsTreatmentsInList
        filterBgCheckButtonOutlet.isSelected = UserDefaults.standard.showBgCheckTreatmentsInList
        
        // set up the button configuration to show the correct image (per state), text (i.e. nothing!) and size. The empty title is just a fix to prevent the default label being shown at runtime (it's doesn't happen in UIBuilder)
        filterBolusButtonOutlet.setImage(UIImage(systemName: "arrowtriangle.down"), for: .normal)
        filterBolusButtonOutlet.setImage(UIImage(systemName: "arrowtriangle.down.fill"), for: .selected)
        filterBolusButtonOutlet.setTitle("", for: .normal)
        
        filterSmallBolusButtonOutlet.setImage(UIImage(systemName: "arrowtriangle.down"), for: .normal)
        filterSmallBolusButtonOutlet.setImage(UIImage(systemName: "arrowtriangle.down.fill"), for: .selected)
        filterSmallBolusButtonOutlet.setTitle("", for: .normal)
        
        // let's also scale down the micro-bolus button image as even though it is initially set in UIBuilder, once we manipulate the image to show it filled, or not, then we lose the symbol scale attribute.
        filterSmallBolusButtonOutlet.imageView?.layer.transform = CATransform3DMakeScale(0.6, 0.6, 0.6)
        
        filterCarbsButtonOutlet.setImage(UIImage(systemName: "circle"), for: .normal)
        filterCarbsButtonOutlet.setImage(UIImage(systemName: "circle.fill"), for: .selected)
        filterCarbsButtonOutlet.setTitle("", for: .normal)
        
        filterBgCheckButtonOutlet.setImage(UIImage(systemName: "drop"), for: .normal)
        filterBgCheckButtonOutlet.setImage(UIImage(systemName: "drop.fill"), for: .selected)
        filterBgCheckButtonOutlet.setTitle("", for: .normal)
        
        filterLabelOutlet.text = Texts_TreatmentsView.filterTreatmentsLabel
        
		self.titleNavigation.title = Texts_TreatmentsView.treatmentsTitle
        
        // check if the observers have already been added. If not, then add them
        if !didAddObservers {
            // add observer for nightscoutTreatmentsUpdateCounter, to reload the screen whenever the value changes
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutTreatmentsUpdateCounter.rawValue, options: .new, context: nil)
            
            // add observer for bloodGlucoseUnitIsMgDl, to reload the screen whenever the bg unit changes
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
            
            // add observer for smallBolusTreatmentThreshold, to reload the screen whenever the user changes the threshold value (this can mean we need to show more, or less, bolus treatments)
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.smallBolusTreatmentThreshold.rawValue, options: .new, context: nil)
            
            // add observer for showSmallBolusTreatmentsInList, to reload the screen whenever the user wants to show or hide the micro-bolus treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showSmallBolusTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showBolusTreatmentsInList, to reload the screen whenever the user wants to show or hide the normal bolus treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showBolusTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showCarbsTreatmentsInList, to reload the screen whenever the user wants to show or hide the carb treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showCarbsTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showBgCheckTreatmentsInList, to reload the screen whenever the user wants to show or hide the BG Check treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showBgCheckTreatmentsInList.rawValue, options: .new, context: nil)
            
            // change the flag to true so that we know they exist before we try and remove them later
            didAddObservers = true
        }
	}
    
    override func viewWillDisappear(_ animated: Bool) {
        // we need to remove all observers from the view controller before removing it from the navigation stack
        // otherwise the app crashes when one of the userdefault values changes and the observer tries to
        // update the UI (which isn't available any more)
        
        // as viewWillAppear could get called (or maybe not) several times, we need to check that the observers
        // have really been registered before we try and remove them
        if didAddObservers {
            // add observer for nightscoutTreatmentsUpdateCounter, to reload the screen whenever the value changes
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutTreatmentsUpdateCounter.rawValue, options: .new, context: nil)
            
            // add observer for bloodGlucoseUnitIsMgDl, to reload the screen whenever the bg unit changes
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue, options: .new, context: nil)
            
            // add observer for smallBolusTreatmentThreshold, to reload the screen whenever the user changes the threshold value (this can mean we need to show more, or less, bolus treatments)
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.smallBolusTreatmentThreshold.rawValue, options: .new, context: nil)
            
            // add observer for showSmallBolusTreatmentsInList, to reload the screen whenever the user wants to show or hide the micro-bolus treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showSmallBolusTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showBolusTreatmentsInList, to reload the screen whenever the user wants to show or hide the normal bolus treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showBolusTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showCarbsTreatmentsInList, to reload the screen whenever the user wants to show or hide the carb treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showCarbsTreatmentsInList.rawValue, options: .new, context: nil)
            
            // add observer for showBgCheckTreatmentsInList, to reload the screen whenever the user wants to show or hide the BG Check treatments
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showBgCheckTreatmentsInList.rawValue, options: .new, context: nil)
            
            // change the flag back to false so that we don't accidentally try and remove them again before they are re-added
            didAddObservers = false
        }
    }
	

	/// Override prepare for segue, we must call configure on the TreatmentsInsertViewController.
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
		// Check if is the segueIdentifier to TreatmentsInsert.
		guard let segueIndentifier = segue.identifier, segueIndentifier == TreatmentsViewController.SegueIdentifiers.TreatmentsToNewTreatmentsSegue.rawValue else {
			return
		}
		
		// Cast the destination to TreatmentsInsertViewController (if possible).
		// And assures the destination and coreData are valid.
		guard let insertViewController = segue.destination as? TreatmentsInsertViewController else {

			fatalError("In TreatmentsInsertViewController, prepare for segue, viewcontroller is not TreatmentsInsertViewController" )
		}

		// Configure insertViewController with CoreData instance and complete handler.
        insertViewController.configure(treatMentEntryToUpdate: sender as? TreatmentEntry, coreDataManager: coreDataManager, completionHandler: {
            self.reload()
        })
        
	}
	
	
	// MARK: - public functions
	
	/// Configure will be called before this view is presented for the user.
	public func configure(coreDataManager: CoreDataManager) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
	
		self.reload()
        
	}
	

	// MARK: - private functions
	
	/// Reloads treatmentCollection and calls reloadData on tableView.
	private func reload() {
        
        // set an array to hold the latest 21 days worth of treatments. Filter out any deleted treatments.
        var treatmentsArray = treatmentEntryAccessor.getLatestTreatments(howOld: TimeInterval(days: 21)).filter( { !$0.treatmentdeleted } )
        
        // filter out boluses if required
        if !UserDefaults.standard.showBolusTreatmentsInList {
            
            treatmentsArray = treatmentsArray.filter( { (($0.treatmentType != .Insulin) || ($0.treatmentType != .Insulin && $0.value >= UserDefaults.standard.smallBolusTreatmentThreshold)) } )
            
        } else if !UserDefaults.standard.showSmallBolusTreatmentsInList {
            
            // as the user wants to show boluses, let's check if they also want to just filter out micro-boluses
            treatmentsArray = treatmentsArray.filter( { ($0.treatmentType != .Insulin) || ($0.treatmentType == .Insulin && $0.value >= UserDefaults.standard.smallBolusTreatmentThreshold) } )
        }

        // filter out carbs if required
        if !UserDefaults.standard.showCarbsTreatmentsInList {
            treatmentsArray = treatmentsArray.filter( { $0.treatmentType != .Carbs } )
        }
        
        // filter out BG Checks if required
        if !UserDefaults.standard.showBgCheckTreatmentsInList {
            treatmentsArray = treatmentsArray.filter( { $0.treatmentType != .BgCheck } )
        }

        // assign the filtered treatmentsArray to the treatmentCollection and reload
        self.treatmentCollection = TreatmentCollection(treatments: treatmentsArray)
        
		self.tableView.reloadData()
        
	}
    
    // MARK: - overriden functions

    /// when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.nightscoutTreatmentsUpdateCounter, UserDefaults.Key.bloodGlucoseUnitIsMgDl, UserDefaults.Key.smallBolusTreatmentThreshold, UserDefaults.Key.showSmallBolusTreatmentsInList,  UserDefaults.Key.showBolusTreatmentsInList,  UserDefaults.Key.showCarbsTreatmentsInList,  UserDefaults.Key.showBgCheckTreatmentsInList:
                    // Reloads data and table.
                    self.reload()
                    
                default:
                    break
                }
            }
        }
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
            // set this to 44 (the IB row height) instead of 0 to avoid the layout warning in Xcode.
			return 44
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
        
        // clicking the cell will always open a new screen which allows the user to edit the treatment
        cell.accessoryType = .disclosureIndicator
        
        // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
        cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
		return cell
	}
	
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
            
			guard let treatmentCollection = treatmentCollection else {
				return
			}

			// Get the treatment the user wants to delete.
			let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
			
			// set treatmentDelete to true in coredata.
            treatment.treatmentdeleted = true
            
            // set uploaded to false, so that at next nightscout sync, the treatment will be deleted at Nightscout
            treatment.uploaded = false
			
            coreDataManager.saveChanges()
            
            // trigger nightscoutsync
            if (UserDefaults.standard.timeStampLatestNightscoutTreatmentSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
                UserDefaults.standard.timeStampLatestNightscoutTreatmentSyncRequest = .now
                UserDefaults.standard.nightscoutSyncTreatmentsRequired = true
            }
            
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
        formatter.setLocalizedDateFormatFromTemplate(ConstantsUI.dateFormatDayMonthYear)

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
			textLabel.font = textLabel.font.withSize(16)
		}
	}

	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 32.0
	}
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.performSegue(withIdentifier: TreatmentsViewController.SegueIdentifiers.TreatmentsToNewTreatmentsSegue.rawValue, sender: treatmentCollection?.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row))
        
    }
    
}
