import UIKit

/// viewcontroller for first settings screen
final class SettingsViewController: UIViewController {

    // MARK: - IBOutlet's and IPAction's
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Private Properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// reference to soundPlayer
    private var soundPlayer:SoundPlayer?
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager:CoreDataManager?, soundPlayer:SoundPlayer?) {
        
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        
    }

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Texts_SettingsView.screenTitle
        
        setupView()
    }
    
    // MARK: - other overriden functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In SettingsViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In SettingsViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case .settingsToAlertTypeSettings:
            let vc = segue.destination as! AlertTypesSettingsViewController
            vc.configure(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
            
        case .settingsToAlertSettings:
            let vc = segue.destination as! AlertsSettingsViewController
            vc.configure(coreDataManager: coreDataManager)
            
        case .settingsToM5StackSettings:
            // nothing to configure
            break
            
        case .settingsToSchedule:
            if let vc = segue.destination as? TimeScheduleViewController, let sender = sender as? TimeSchedule {
                vc.configure(timeSchedule: sender)
            }
            
        }
    }

    // MARK: - Private helper functions
    
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

extension SettingsViewController:UITableViewDataSource, UITableViewDelegate {
    
    private enum Section: Int, CaseIterable, SettingsProtocol {
        
        ///General settings - language, glucose unit, high and low value
        case general
        
        /// alarms
        case alarms

        ///nightscout settings
        case nightscout

        ///dexcom share settings
        case dexcom

        /// healthkit
        case healthkit

        /// store bg values in healthkit
        case speak

        /// M5 stack settings
        case M5stack
        
        
        /// Apple Watch settings
        case AppleWatch
        
        /// info
        case info

        /// developper settings
        case developer
        
        func viewModel() -> SettingsViewModelProtocol {
            switch self {
                
            case .general:
                return SettingsViewGeneralSettingsViewModel()
            case .alarms:
                return SettingsViewAlertSettingsViewModel()
            case .nightscout:
                return SettingsViewNightScoutSettingsViewModel()
            case .dexcom:
                return SettingsViewDexcomSettingsViewModel()
            case .healthkit:
                return SettingsViewHealthKitSettingsViewModel()
            case .speak:
                return SettingsViewSpeakSettingsViewModel()
            case .M5stack:
                return SettingsViewM5StackSettingsViewModel()
            case .info:
                return SettingsViewInfoViewModel()
            case .developer:
                return SettingsViewDevelopmentSettingsViewModel()
            case .AppleWatch:
                return SettingsViewAppleWatchSettingsViewModel()
            }
        }

    }
    
    // MARK: - UITableViewDataSource protocol Methods
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel().sectionTitle()

    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel().numberOfRows()
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        guard var cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // Configure Cell

        SettingsViewUtilities.configureSettingsCell(cell: &cell, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withViewModel: section.viewModel(), tableView: tableView)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate protocol Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
 
        let viewModel = section.viewModel()
        
        if viewModel.isEnabled(index: indexPath.row) {
            
            let selectedRowAction = viewModel.onRowSelect(index: indexPath.row)
            
            SettingsViewUtilities.runSelectedRowAction(selectedRowAction: selectedRowAction, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: viewModel, tableView: tableView, forUIViewController: self)
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        // apple doc says : Use this method to respond to taps in the detail button accessory view of a row. The table view does not call this method for other types of accessory views.
        // when user clicks on of the detail buttons, then consider this as row selected, for now - as it's only license that is using this button for now
        self.tableView(tableView, didSelectRowAt: indexPath)
        
    }
}

/// defines perform segue identifiers used within settingsviewcontroller
extension SettingsViewController {
    public enum SegueIdentifiers:String {

        /// to go from general settings screen to alert types screen
        case settingsToAlertTypeSettings = "settingsToAlertTypeSettings"
        
        /// to go from general settings screen to alert screen
        case settingsToAlertSettings = "settingsToAlertSettings"
        
        /// to go from general settings screen to M5Stack settings screen
        case settingsToM5StackSettings = "settingsToM5StackSettings"
        
        /// to go from general settings to schedule screen
        case settingsToSchedule = "settingsToSchedule"
        
    }
}


