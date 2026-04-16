import UIKit

/// overview of alert types, in a tableview, with a button top right that allows adding alert types
///
/// to edit or delete an alert type, user needs to click a row
final class AlertTypesSettingsViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func unwindToAlertTypesSettingsViewController(segue: UIStoryboardSegue) {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    // user clicks the add button, to add new alert type
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier:AlertTypeSettingsViewController.SegueIdentifiers.alertTypesToAlertTypeSettings.rawValue, sender: nil)
    }
    
    // MARK: - Private Properties
    
    /// reference to coredatamanager
    private var coreDataManager:CoreDataManager?
    
    /// reference to soundPlayer
    private var soundPlayer:SoundPlayer?
    
    private lazy var alertTypesAccessor:AlertTypesAccessor = {
            return AlertTypesAccessor(coreDataManager: getCoreDataManager())
    }()
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager:CoreDataManager?, soundPlayer:SoundPlayer?) {
        
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        
    }

    // MARK: overriden
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Texts_AlertTypeSettingsView.alertTypesScreenTitle
        
        setupView()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In AlertTypesSettingsViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = AlertTypeSettingsViewController.SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In AlertTypesSettingsViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case AlertTypeSettingsViewController.SegueIdentifiers.alertTypesToAlertTypeSettings:
            guard let vc = segue.destination as? AlertTypeSettingsViewController, let coreDataManager = coreDataManager, let soundPlayer = soundPlayer else {
                fatalError("In AlertTypesSettingsViewController, prepare for segue, viewcontroller is not AlertTypeSettingsViewController or coreDataManager is nil or soundPlayer is nil" )
            }

            vc.configure(alertType: sender as? AlertType, coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        }
    }

    // MARK: - Private Helper functions
    
    private func getCoreDataManager() -> CoreDataManager {
        if let coreDataManager = coreDataManager {
            return coreDataManager
        } else {
            fatalError("in AlertTypesSettingsViewController, coreDataManager is nil")
        }
    }
    
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

extension AlertTypesSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UITableViewDataSource and UITableViewDelegate protocol Methods
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let view = view as? UITableViewHeaderFooterView {
            
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
            
        }
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alertTypesAccessor.getAllAlertTypes().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // textLabel should be the name of the alerttype
        cell.textLabel?.text = alertTypesAccessor.getAllAlertTypes()[indexPath.row].name
        
        // no detail text to be shown
        cell.detailTextLabel?.text = alertTypesAccessor.getAllAlertTypes()[indexPath.row].enabled ? nil : ConstantsAlerts.disabledAlertSymbol
        
        // clicking the cell will always open a new screen which allows the user to edit the alert type
        cell.accessoryType = .disclosureIndicator
        
        cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // only 1 section, namely the list of alert types
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        self.performSegue(withIdentifier:AlertTypeSettingsViewController.SegueIdentifiers.alertTypesToAlertTypeSettings.rawValue, sender: alertTypesAccessor.getAllAlertTypes()[indexPath.row])
    }

}
