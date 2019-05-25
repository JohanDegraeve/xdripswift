import UIKit

/// viewcontroller for first settings screen
final class SettingsViewController: UIViewController {

    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    
    fileprivate var generalSettingsViewModel = SettingsViewGeneralSettingsViewModel()
    fileprivate var transmitterSettingsViewModel = SettingsViewTransmitterSettingsViewModel()
    fileprivate var nightScoutSettingsViewModel = SettingsViewNightScoutSettingsViewModel()
    fileprivate var dexcomSettingsViewModel = SettingsViewDexcomSettingsViewModel()
    fileprivate var healthKitSettingsViewModel = SettingsViewHealthKitSettingsViewModel()
    fileprivate var alarmsSettingsViewModel = SettingsViewAlertSettingsViewModel()
    fileprivate var speakSettingsViewModel = SettingsViewSpeakSettingsViewModel()
    
    private lazy var pickerViewController: PickerViewController = {
        // Instantiate View Controller
        var viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "PickerViewController") as! PickerViewController

        viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        return viewController
    }()
    
    private var coreDataManager:CoreDataManager?
    
    // MARK:- public functions
    public func configure(coreDataManager:CoreDataManager?) {
        self.coreDataManager = coreDataManager
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
            vc.configure(coreDataManager: coreDataManager)
        case .settingsToAlertSettings:
            let vc = segue.destination as! AlertsSettingsViewController
            vc.configure(coreDataManager: coreDataManager)
        }
    }

    // MARK: - Private helper functions
    
    private func setupView() {
        setupTableView()
    }

    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            tableView.separatorInset = UIEdgeInsets.zero
            tableView.dataSource = self
            tableView.delegate = self
        }
    }

    /// removes a child view controller, will be used for pickerviewcontroller
    /// see https://cocoacasts.com/managing-view-controllers-with-container-view-controllers
    private func addPickerViewController() {
        // Add Child View Controller
        addChild(pickerViewController)
        
        // Add Child View as Subview
        view.addSubview(pickerViewController.view)
        
        pickerViewController.didMove(toParent: self)
    }

}

extension SettingsViewController:UITableViewDataSource, UITableViewDelegate {
    
    private enum Section: Int, CaseIterable {
        ///General settings - language, glucose unit, high and low value
        case general
        ///transmitter type and if applicable transmitter id
        case transmitter
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
    }
    
    // MARK: - UITableViewDataSource protocol Methods
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        switch section {
        case .general:
            return generalSettingsViewModel.sectionTitle()
        case .transmitter:
            return transmitterSettingsViewModel.sectionTitle()
        case .nightscout:
            return nightScoutSettingsViewModel.sectionTitle()
        case .dexcom:
            return dexcomSettingsViewModel.sectionTitle()
        case .healthkit:
            return healthKitSettingsViewModel.sectionTitle()
        case .alarms:
            return alarmsSettingsViewModel.sectionTitle()
        case .speak:
            return speakSettingsViewModel.sectionTitle()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // temporary returning 5 because healthkit and others are not yet ready
        return 4//Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        switch section {
        case .general:
            return generalSettingsViewModel.numberOfRows()
        case .transmitter:
            return transmitterSettingsViewModel.numberOfRows()
        case .nightscout:
            return nightScoutSettingsViewModel.numberOfRows()
        case .dexcom:
            return dexcomSettingsViewModel.numberOfRows()
        case .healthkit:
            return healthKitSettingsViewModel.numberOfRows()
        case .alarms:
            return alarmsSettingsViewModel.numberOfRows()
        case .speak:
            return speakSettingsViewModel.numberOfRows()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        var viewModel:SettingsViewModelProtocol?
        
        switch section {
        case .general:
            viewModel = generalSettingsViewModel
        case .transmitter:
            viewModel = transmitterSettingsViewModel
        case .nightscout:
            viewModel = nightScoutSettingsViewModel
        case .dexcom:
            viewModel = dexcomSettingsViewModel
        case .healthkit:
            viewModel = healthKitSettingsViewModel
        case .alarms:
            viewModel = alarmsSettingsViewModel
        case .speak:
            viewModel = speakSettingsViewModel
        }
        
        if let viewModel = viewModel {
            // Configure Cell
            cell.textLabel?.text = viewModel.settingsRowText(index: indexPath.row)

            cell.accessoryType = viewModel.accessoryType(index: indexPath.row)
            switch cell.accessoryType {
            case .checkmark, .detailButton, .detailDisclosureButton, .disclosureIndicator:
                cell.selectionStyle = .gray
            case .none:
                cell.selectionStyle = .none
            }

            cell.detailTextLabel?.text = viewModel.detailedText(index: indexPath.row)

            cell.accessoryView = viewModel.uiView(index: indexPath.row).view
            // if uiview is an uiswitch then possibly section needs reload
            if let view = cell.accessoryView as? UISwitch, viewModel.uiView(index: indexPath.row).reloadSection {
                view.addTarget(self, action: {(theSwitch:UISwitch) in tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)}, for: UIControl.Event.valueChanged)
            }
            
        } else {
            fatalError("tableView, cellforrowat Failed to create viewModel")
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate protocol Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        var selectedRowAction:SettingsSelectedRowAction?
        
        switch section {
        case .general:
            selectedRowAction = generalSettingsViewModel.onRowSelect(index: indexPath.row)
        case .transmitter:
            selectedRowAction = transmitterSettingsViewModel.onRowSelect(index: indexPath.row)
        case .nightscout:
            selectedRowAction = nightScoutSettingsViewModel.onRowSelect(index: indexPath.row)
        case .dexcom:
            selectedRowAction = dexcomSettingsViewModel.onRowSelect(index: indexPath.row)
        case .healthkit:
            selectedRowAction = healthKitSettingsViewModel.onRowSelect(index: indexPath.row)
        case .alarms:
            selectedRowAction = alarmsSettingsViewModel.onRowSelect(index: indexPath.row)
        case .speak:
            selectedRowAction = speakSettingsViewModel.onRowSelect(index: indexPath.row)
        }
        
        if let selectedRowAction = selectedRowAction {
            
            switch selectedRowAction {
                
            case let .askText(title, message, keyboardType, text, placeHolder, actionTitle, cancelTitle, actionHandler, cancelHandler):
                
                let alert = UIAlertController(title: title, message: message, keyboardType: keyboardType, text: text, placeHolder: placeHolder, actionTitle: actionTitle, cancelTitle: cancelTitle, actionHandler: { (text:String) in
                            actionHandler(text)
                            // after calling action handler, setting may have changed possibly all settings in the section, refresh the section
                            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                }, cancelHandler: cancelHandler)
                
                // present the alert
                self.present(alert, animated: true, completion: nil)

            case .nothing:
                break
                
            case let .callFunction(function):
                
                // call function
                function()
                
                // after calling action handler, setting may have changed possibly all settings in the section, refresh the section
                tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                
            case let .selectFromList(title, data, selectedRow, actionTitle, cancelTitle, actionHandler, cancelHandler):
                
                // configure pickerViewData
                let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: title, withData: data, selectedRow: selectedRow, withPriority: nil, actionButtonText: actionTitle, cancelButtonText: cancelTitle, onActionClick: {(_ index: Int) in
                    actionHandler(index)
                    tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                }, onCancelClick: {
                    if let cancelHandler = cancelHandler { cancelHandler() }
                })

                // create and present pickerviewcontroller
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)

                break
                
            case .performSegue(let withIdentifier):
                self.performSegue(withIdentifier: withIdentifier, sender: nil)
            }
        } else {
            fatalError("in tableView didSelectRowAt, selectedRowAction is nil")
        }
    }
    
}

/// defines perform segue identifiers used within settingsviewcontroller
extension SettingsViewController {
    public enum SegueIdentifiers:String {

        /// to go from general settings screen to alert types screen
        case settingsToAlertTypeSettings = "settingsToAlertTypeSettings"
        
        /// to go from general settings screen to alert screen
        case settingsToAlertSettings = "settingsToAlertSettings"
    }
}


