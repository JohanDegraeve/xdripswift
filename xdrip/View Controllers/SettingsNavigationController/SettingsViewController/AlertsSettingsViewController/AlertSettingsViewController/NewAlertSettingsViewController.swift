import UIKit

// MARK: - NewAlertSettingsViewController

/// to create a new alertentry
final class NewAlertSettingsViewController: UIViewController {
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var topLabelOutlet: UILabel!
    
    // MARK: - Properties
    
    var alertSettingsViewControllerData: AlertSettingsViewControllerData!

    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        // initialize new alertentry, will be saved in coredata when calling coreDataManager.savechanges()
        _ = AlertEntry(isDisabled: alertSettingsViewControllerData.isDisabled, value: Int(alertSettingsViewControllerData.value), triggerValue: Int(alertSettingsViewControllerData.triggerValue), alertKind: AlertSettingsViewControllerData.getAlertKind(alertKind: alertSettingsViewControllerData.alertKind), start: Int(alertSettingsViewControllerData.start), alertType: alertSettingsViewControllerData.alertType, nsManagedObjectContext: alertSettingsViewControllerData.coreDataManager.mainManagedObjectContext)

        // save the alertentry
        alertSettingsViewControllerData.coreDataManager.saveChanges()
        
        // go back to the alerts settings screen
        performSegue(withIdentifier: SegueIdentifiers.unwindToAlertsSettingsViewController.rawValue, sender: self)
    }
    
    @IBOutlet weak var doneButtonOutlet: UIBarButtonItem!
    
    /// to be called by viewcontroller that opens this viewcontroller
    /// - parameters:
    ///     - alertKind : used to create default alertentry
    ///     - minimumStart : what's the minimum allowed value for the start
    ///     - maximumStart : what's the maximum allowed value for the start
    ///     - coreDataManager : reference to the coredatamanager
    public func configure(alertKind: AlertKind, minimumStart: Int16, maximumStart: Int16, coreDataManager: CoreDataManager) {
        // initialize alertSettingsViewControllerData
        alertSettingsViewControllerData = AlertSettingsViewControllerData(isDisabled: false, start: minimumStart, value: Int16(alertKind.defaultAlertValue()), triggerValue: Int16(alertKind.defaultAlertTriggerValue()), alertKind: Int16(alertKind.rawValue), alertType: AlertTypesAccessor(coreDataManager: coreDataManager).getDefaultAlertType(), minimumStart: minimumStart, maximumStart: maximumStart, uIViewController: self, toCallWhenUserResetsProperties: {
            self.doneButtonOutlet.disable()
        }, toCallWhenUserChangesProperties: {
            self.doneButtonOutlet.enable()
        }, coreDataManager: coreDataManager)
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
    }
    
    // MARK: - View Methods
    
    private func setupView() {
        // set title of the screen to empty string
        title = ""
        
        // set toplabel text
        topLabelOutlet.text = Texts_Common.add + " " + AlertSettingsViewControllerData.getAlertKind(alertKind: alertSettingsViewControllerData.alertKind).alertTitle()
        
        /// setup tableView datasource, delegate, seperatorInset
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            tableView.dataSource = alertSettingsViewControllerData
            tableView.delegate = alertSettingsViewControllerData
        }
    }
    
    // MARK: - private helper functions
}

// MARK: NewAlertSettingsViewController.SegueIdentifiers

// alertToNewAlertSettings
/// defines perform segue identifiers used within AlertSettingsViewController
extension NewAlertSettingsViewController {
    public enum SegueIdentifiers: String {
        /// to go from alert settings screen to new alert  settings screen
        case alertToNewAlertSettings
        /// to go back from newalert settings screen to alerts settings screen
        /// value is actually the same as in AlertSettingsViewController
        case unwindToAlertsSettingsViewController
    }
}
