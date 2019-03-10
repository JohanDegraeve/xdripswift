import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    
    fileprivate var generalSettingsViewModel = SettingsViewGeneralSettingsViewModel()
    fileprivate var transmitterSettingsViewModel = SettingsViewTransmitterSettingsViewModel()
    fileprivate var nightScoutSettingsViewModel = SettingsViewNightScoutSettingsViewModel()
    fileprivate var dexcomSettingsViewModel = SettingsViewDexcomSettingsViewModel()
    fileprivate var healthKitSettingsViewModel = SettingsViewHealthKitSettingsViewModel()
    fileprivate var alarmsSettingsViewModel = SettingsViewAlarmsSettingsViewModel()
    fileprivate var speakSettingsViewModel = SettingsViewSpeakSettingsViewModel()
    
    private lazy var pickerViewController: PickerViewController = {
        // Instantiate View Controller
        var viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "PickerViewController") as! PickerViewController

        viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        return viewController
    }()
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Settings"
        
        setupView()
    }
    
    // MARK: - View Methods
    
    private func setupView() {
        setupTableView()
    }

    // MARK: -
    
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

    /// removes a child view controller, will be used for pickerviewcontroller
    /// see https://cocoacasts.com/managing-view-controllers-with-container-view-controllers
    private func removePickerViewController() {
        // Notify Child View Controller
        pickerViewController.willMove(toParent: nil)
        
        // Remove Child View From Superview
        pickerViewController.view.removeFromSuperview()
        
        // Notify Child View Controller
        pickerViewController.removeFromParent()
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
        return Section.allCases.count
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
            cell.textLabel?.text = viewModel.text(index: indexPath.row)

            cell.accessoryType = viewModel.accessoryType(index: indexPath.row)
            switch cell.accessoryType {
            case .checkmark, .detailButton, .detailDisclosureButton, .disclosureIndicator:
                cell.selectionStyle = .gray
            case .none:
                cell.selectionStyle = .none
            }

            cell.detailTextLabel?.text = viewModel.detailedText(index: indexPath.row)

            cell.accessoryView = viewModel.uiView(index: indexPath.row).view
            // if uiview is an uiswitch then possible section needs reload
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
        
        var selectedRowAction:SelectedRowAction?
        
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
                
            case let .askText(title, message, keyboardType, placeHolder, actionTitle, cancelTitle, actionHandler, cancelHandler):
                
                //create uialertcontroller
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addTextField { (textField:UITextField) in
                    if let placeHolder = placeHolder { textField.placeholder = placeHolder }
                    if let keyboardType = keyboardType { textField.keyboardType = keyboardType }
                }
                // add actions Ok and Cancel
                var Ok = actionTitle
                if Ok == nil { Ok = Texts_Common.Ok }
                var cancel = cancelTitle
                if cancel == nil { cancel = Texts_Common.Cancel }
                alert.addAction(UIAlertAction(title: Ok!, style: .default, handler: { (action:UIAlertAction) in
                    if let textFields = alert.textFields {
                        if let text = textFields[0].text {
                            actionHandler(text)
                            // after calling action handler, setting may have changed possibly all settings in the section, refresh the section
                            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                        } //if there's no text then there's no reason to call actionHandler
                    } //if there's no text then there's no reason to call actionHandler
                }))
                alert.addAction(UIAlertAction(title: cancel!, style: .cancel, handler: (cancelHandler != nil) ? {(action:UIAlertAction) in cancelHandler!()}:nil))

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
                
                //configure pickerViewController
                pickerViewController.pickerTitle = title
                pickerViewController.dataSource = data
                pickerViewController.selectedRow = selectedRow
                pickerViewController.addButtonTitle = actionTitle
                pickerViewController.cancelButtonTitle = cancelTitle
                pickerViewController.addHandler = {(_ index: Int) in
                    actionHandler(index)
                    self.removePickerViewController()
                    tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                }
                pickerViewController.cancelHandler = {
                    if let cancelHandler = cancelHandler { cancelHandler() }
                    self.removePickerViewController()
                }
                
                // display controller's view
                addPickerViewController()

                break
            }
        } else {
            fatalError("in tableView didSelectRowAt, selectedRowAction is nil")
        }
    }
}
