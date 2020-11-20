import UIKit

final class SnoozeViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    
    // reference to alertManager
    private var alertManager:AlertManager?
    
    // MARK: - Public functions
    
    public func configure(alertManager:AlertManager?) {
        self.alertManager = alertManager
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Texts_Alerts.alertsScreenTitle
        setupView()
    }
    
    // MARK: - private helper functions
    
    // setup the view
    private func setupView() {
        setupTableView()
    }
    
    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            tableView.dataSource = self
            tableView.delegate = self
            
        }
    }
    
}

// MARK: - Conform to UITableViewDataSource

extension SnoozeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // number of sections corresponds to number of alarm types
        return AlertKind.allCases.count
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // just one row per alarm type
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // alertKind corresponds to section number
        guard let alertKind = AlertKind(forSection: indexPath.section) else {
            fatalError("In SnoozeViewController, cellForRowAt, could not create alertKind")
        }
        
        // unwrap alertManager
        guard let alertManager = alertManager else {
            fatalError("In SnoozeViewController, cellForRowAt, alertmanager is nil")
        }
        
        // get snoozeParameters for the alertKind
        let (isSnoozed, remainingSeconds) = alertManager.getSnoozeParameters(alertKind: alertKind).getSnoozeValue() 

        if isSnoozed {
            
            guard let remainingSeconds = remainingSeconds else {
                fatalError("In SnoozeViewController, remainingSeconds is nil but alert is snoozed")
            }

            // if snooze period longer than 24 hours then show data and time when it ends, if less than only show time
            cell.textLabel?.text = TextsSnooze.snoozed_until + " " + Date(timeIntervalSinceNow: Double(remainingSeconds)).toString(timeStyle: .short, dateStyle: remainingSeconds > 24 * 60 * 60 ? .short : .none)
            
        } else {

            cell.textLabel?.text = TextsSnooze.not_snoozed

        }
        
        // no detailed text to be shown, the snooze time is already given in the textLabel
        cell.detailTextLabel?.text = nil
        
        // no accessory type to be shown
        cell.accessoryType = .none
        
        // uiswitch will be on if currently snoozed, off if currently not snoozed
        cell.accessoryView = UISwitch(isOn: isSnoozed, action: { (isOn:Bool) in
            
            // closure to reload the row after user clicked form on to off, or from off to on and selected a snoozeperiod
            let reloadRow = { tableView.reloadRows(at: [IndexPath(row: 0, section: indexPath.section)], with: .none)}
            
            // changing from off to on. Means user wants to pre-snooze
            if isOn {

                // create and display pickerViewData
                PickerViewController.displayPickerViewController(pickerViewData: alertManager.createPickerViewData(forAlertKind: alertKind, content: nil, actionHandler: { reloadRow() }, cancelHandler: { reloadRow() }), parentController: self)
                
            } else {
                // changing from on to off. Means user wants to unsnooze

                alertManager.unSnooze(alertKind: alertKind)
                
                reloadRow()
                
            }
                
        })
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        // alertKind corresponds to section number
        guard let alertKind = AlertKind(forSection: section) else {
            fatalError("In titleForHeaderInSection, could not create alertKind")
        }
        
        return alertKind.alertTitle()
        
    }

}

// MARK: - Conform to UITableViewDelegate

extension SnoozeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
}

// MARK: - SegueIdentifiers

extension SnoozeViewController {
    
    public enum SegueIdentifiers: String {
        
        /// to go from RootViewController to SnoozeViewController
        case RootViewToSnoozeView = "RootViewToSnoozeView"
        
    }
    
}
