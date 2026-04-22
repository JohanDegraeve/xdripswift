
import UIKit
import CoreData

// MARK: - AlertSettingsViewController

/// to update an existing alertentry
final class AlertSettingsViewController: UIViewController {
    // MARK: - Properties
    
    var alertSettingsViewControllerData: AlertSettingsViewControllerData!
    
    /// the alertentry being edited - will only be used , and in the end to update the alertentry
    private var alertEntryAsNSObject: AlertEntry!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var topLabelOutlet: UILabel!
    
    /// done button, to confirm changes
    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        // Update isDisabled for all AlertEntries with the same alertKind
        let context = alertSettingsViewControllerData.coreDataManager.mainManagedObjectContext
        let fetchRequest: NSFetchRequest<AlertEntry> = AlertEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "alertkind = %i", alertSettingsViewControllerData.alertKind)
        do {
            let entries = try context.fetch(fetchRequest)
            for entry in entries {
                entry.isDisabled = alertSettingsViewControllerData.isDisabled
            }
        } catch {
            print("Failed to fetch AlertEntries for bulk isDisabled update: \(error)")
        }

        // Update other properties for the current entry
        alertEntryAsNSObject.alertkind = alertSettingsViewControllerData.alertKind
        alertEntryAsNSObject.alertType = alertSettingsViewControllerData.alertType
        alertEntryAsNSObject.start = alertSettingsViewControllerData.start
        alertEntryAsNSObject.value = alertSettingsViewControllerData.value
        alertEntryAsNSObject.triggerValue = alertSettingsViewControllerData.triggerValue

        // save the alertentries
        alertSettingsViewControllerData.coreDataManager.saveChanges()

        // if it's a missed reading alert, then set UserDefaults.standard.missedReadingAlertChanged
        // this will trigger the AlertManager to check if missed reading alert needs to be replanned
        if alertEntryAsNSObject.alertkind == AlertKind.missedreading.rawValue {
            UserDefaults.standard.missedReadingAlertChanged = true
        }

        // go back to the alerts settings screen
        performSegue(withIdentifier: SegueIdentifiers.unwindToAlertsSettingsViewController.rawValue, sender: self)
    }
    
    @IBOutlet weak var doneButtonOutlet: UIBarButtonItem!
    
    /// to delete the alertentry
    @IBAction func trashButtonAction(_ sender: UIBarButtonItem) {
        // delete the alertentry
        if let alertEntry = alertEntryAsNSObject {
            // first ask user if ok to delete and if yes delete
            let alert = UIAlertController(title: Texts_Alerts.confirmDeletionAlert, message: nil, actionHandler: {
                self.alertSettingsViewControllerData.coreDataManager.mainManagedObjectContext.delete(alertEntry)
                self.alertSettingsViewControllerData.coreDataManager.saveChanges()
                // go back to alerts settings screen
                self.performSegue(withIdentifier: SegueIdentifiers.unwindToAlertsSettingsViewController.rawValue, sender: self)
                // go back to alerts settings screen
                self.performSegue(withIdentifier: SegueIdentifiers.unwindToAlertsSettingsViewController.rawValue, sender: self)
            }, cancelHandler: nil)
            
            present(alert, animated: true, completion: nil)
            
        } else {
            // go back to alerts settings screen
            performSegue(withIdentifier: SegueIdentifiers.unwindToAlertsSettingsViewController.rawValue, sender: self)
        }
    }
    
    @IBOutlet weak var trashButtonOutlet: UIBarButtonItem!
    
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        // user clicks add button, need to perform segue to open new alertsettingsviewcontroller
        // sender = alertKind, minimumStart value for new alert = current alert + 1, maximumstart for new alert which is equal to maximumstart of current alertentry
        performSegue(withIdentifier: NewAlertSettingsViewController.SegueIdentifiers.alertToNewAlertSettings.rawValue, sender: (alertSettingsViewControllerData.alertKind, alertSettingsViewControllerData.start + 1, alertSettingsViewControllerData.maximumStart))
    }
    
    @IBOutlet weak var addButtonOutlet: UIBarButtonItem!
    
    // MARK: - public functions
    
    /// to be called by viewcontroller that opens this viewcontroller
    /// - parameters:
    ///     - alertEntry : which is to be edited here
    ///     - minimumStart : what's the minimum allowed value for the start
    ///     - maximumStart : what's the maximum allowed value for the start
    ///     - coreDataManager : reference to the coredatamanager
    public func configure(alertEntry: AlertEntry, minimumStart: Int16, maximumStart: Int16, coreDataManager: CoreDataManager) {
        // alertEntryAsNSObject will be used in the end when user clicks Trash or Done button
        alertEntryAsNSObject = alertEntry
        
        // initialize alertSettingsViewControllerData
        alertSettingsViewControllerData = AlertSettingsViewControllerData(isDisabled: alertEntry.isDisabled, start: alertEntry.start, value: alertEntry.value, triggerValue: alertEntry.triggerValue, alertKind: alertEntry.alertkind, alertType: alertEntry.alertType, minimumStart: minimumStart, maximumStart: maximumStart, uIViewController: self, toCallWhenUserResetsProperties: {
            self.addButtonOutlet.enable()
            self.doneButtonOutlet.disable()
            self.trashButtonOutlet.isEnabled = self.alertSettingsViewControllerData.start != 0
        }, toCallWhenUserChangesProperties: {
            self.addButtonOutlet.disable()
            self.doneButtonOutlet.enable()
            self.trashButtonOutlet.disable()
        }, coreDataManager: coreDataManager)
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configures the view
        setupView()
    }
    
    // MARK: - View Methods
    
    private func setupView() {
        // set title of the screen to empty string
        title = ""

        // if it's the alertEntry with start 0, then it can't be deleted, disable the trash button
        trashButtonOutlet.isEnabled = alertSettingsViewControllerData.start != 0
        
        // initially set done button to disabled, it will get enabled as soon as user changes something, this is done in AlertSettingsViewControllerData
        doneButtonOutlet.disable()

        // set toplabel text
        topLabelOutlet.text = Texts_Common.update + " " + AlertSettingsViewControllerData.getAlertKind(alertKind: alertSettingsViewControllerData.alertKind).alertTitle()
        
        /// setup tableView datasource, delegate, seperatorInset
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            tableView.dataSource = alertSettingsViewControllerData
            tableView.delegate = alertSettingsViewControllerData
        }
    }
    
    // MARK: - other overriden functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueIdentifier = segue.identifier else {
            fatalError("In AlertSettingsViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = NewAlertSettingsViewController.SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In AlertSettingsViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
        case NewAlertSettingsViewController.SegueIdentifiers.alertToNewAlertSettings:
            guard let vc = segue.destination as? NewAlertSettingsViewController, let (alertKind, minimumStart, maximumStart) = sender as? (Int16, Int16, Int16) else {
                fatalError("In AlertSettingsViewController, prepare for segue, viewcontroller is not AlertSettingsViewController or sender is not (Int16, Int16, Int16)")
            }
            
            guard let alertKindAsAlertKind = AlertKind(rawValue: Int(alertKind)) else { fatalError("in AlertSettingsViewController, prepare for segue, failed to cretae AlertKind") }
            
            // configure view controller
            vc.configure(alertKind: alertKindAsAlertKind, minimumStart: minimumStart, maximumStart: maximumStart, coreDataManager: alertSettingsViewControllerData.coreDataManager)
            
        default:
            break
        }
    }

    // MARK: - private helper functions
}

// MARK: AlertSettingsViewController.SegueIdentifiers

/// defines perform segue identifiers used within AlertSettingsViewController
extension AlertSettingsViewController {
    public enum SegueIdentifiers: String {
        /// to go from alerts settings screen to alert  settings screen
        case alertsToAlertSettings
        
        /// to go back from alert settings screen to alerts settings screen
        case unwindToAlertsSettingsViewController
    }
}
