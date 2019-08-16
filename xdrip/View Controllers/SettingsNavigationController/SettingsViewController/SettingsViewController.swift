import UIKit

/// viewcontroller for first settings screen
final class SettingsViewController: UIViewController {

    // MARK: - IBOutlet's and IPAction's
    
    @IBOutlet weak var tableView: UITableView!
    
    fileprivate var generalSettingsViewModel = SettingsViewGeneralSettingsViewModel()
    fileprivate var transmitterSettingsViewModel = SettingsViewTransmitterSettingsViewModel()
    fileprivate var nightScoutSettingsViewModel = SettingsViewNightScoutSettingsViewModel()
    fileprivate var dexcomSettingsViewModel = SettingsViewDexcomSettingsViewModel()
    fileprivate var healthKitSettingsViewModel = SettingsViewHealthKitSettingsViewModel()
    fileprivate var alarmsSettingsViewModel = SettingsViewAlertSettingsViewModel()
    fileprivate var speakSettingsViewModel = SettingsViewSpeakSettingsViewModel()
    fileprivate var developmentSettingsViewModel = SettingsViewDevelopmentSettingsViewModel()
    fileprivate var infoSettingsViewModel = SettingsViewInfoViewModel()
    
    private lazy var pickerViewController: PickerViewController = {
        // Instantiate View Controller
        var viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "PickerViewController") as! PickerViewController

        viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        return viewController
    }()

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

    /// for specified UITableView, viewModel, rowIndex and sectionIndex, check if a refresh of just the section is needed or the complete settings view, and refresh so
    ///
    /// Changing one setting value, may need hiding or masking or other setting rows. Goal is to minimize the refresh to the section if possible and to avoid refreshing the whole screen as much as possible.
    /// This function will verify if complete reload is needed or not
    private func checkIfReloadNeededAndReloadIfNeeded(tableView: UITableView, viewModel:SettingsViewModelProtocol, rowIndex:Int, sectionIndex:Int ) {

        if viewModel.completeSettingsViewRefreshNeeded(index: rowIndex) {
            tableView.reloadSections(IndexSet(integersIn: 0..<tableView.numberOfSections), with: .none)
        } else {
            tableView.reloadSections(IndexSet(integer: sectionIndex), with: .none)
        }
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
        /// info
        case info
        /// developper settings
        case developer
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
        case .developer:
            return developmentSettingsViewModel.sectionTitle()
        case .info:
            return infoSettingsViewModel.sectionTitle()
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
        case .developer:
            return developmentSettingsViewModel.numberOfRows()
        case .info:
            return infoSettingsViewModel.numberOfRows()
            
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
        case .developer:
            viewModel = developmentSettingsViewModel
        case .info:
            viewModel = infoSettingsViewModel
        }

        
        // Configure Cell
        if let viewModel = viewModel {
            
            // start setting textColor to black, could change to gray if setting is not enabled
            cell.textLabel?.textColor = UIColor.black
            cell.detailTextLabel?.textColor = UIColor.black
            
            // first the two textfields
            cell.textLabel?.text = viewModel.settingsRowText(index: indexPath.row)
            cell.detailTextLabel?.text = viewModel.detailedText(index: indexPath.row)

            // if not enabled, then no need to adding anything else
            if viewModel.isEnabled(index: indexPath.row) {
                
                // setting enabled, get accessory type and accessory view
                cell.accessoryType = viewModel.accessoryType(index: indexPath.row)
                
                switch cell.accessoryType {
                case .checkmark, .detailButton, .detailDisclosureButton, .disclosureIndicator:
                    cell.selectionStyle = .gray
                case .none:
                    cell.selectionStyle = .none
                @unknown default:
                    cell.selectionStyle = .none
                }
                
                cell.accessoryView = viewModel.uiView(index: indexPath.row)
                
                // if uiview is an uiswitch then initiate a reload, either complete view or just the section
                if let view = cell.accessoryView as? UISwitch {
                    view.addTarget(self, action: {
                        (theSwitch:UISwitch) in
                        
                        self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: viewModel, rowIndex: indexPath.row, sectionIndex: indexPath.section)
                        
                    }, for: UIControl.Event.valueChanged)
                }
                
            } else {
                
                // setting not enabled, set color to grey, no accessory type to be added
                cell.textLabel?.textColor = UIColor.gray
                cell.detailTextLabel?.textColor = UIColor.gray
                
                // set accessory and selectionStyle to none, because no action is required when user clicks the row
                cell.accessoryType = .none
                cell.selectionStyle = .none
                
                // set accessoryView to nil
                cell.accessoryView = nil
                
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
        case .developer:
            viewModel = developmentSettingsViewModel
        case .info:
            viewModel = infoSettingsViewModel
        }
        
        if let viewModel = viewModel {
            
            if viewModel.isEnabled(index: indexPath.row) {
                
                let selectedRowAction = viewModel.onRowSelect(index: indexPath.row)
                
                switch selectedRowAction {
                    
                case let .askText(title, message, keyboardType, text, placeHolder, actionTitle, cancelTitle, actionHandler, cancelHandler):
                    
                    let alert = UIAlertController(title: title, message: message, keyboardType: keyboardType, text: text, placeHolder: placeHolder, actionTitle: actionTitle, cancelTitle: cancelTitle, actionHandler: { (text:String) in
                        
                        // do the action
                        actionHandler(text)
                        
                        // check if refresh is needed, either complete settingsview or individual section
                        self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: viewModel, rowIndex: indexPath.row, sectionIndex: indexPath.section)

                    }, cancelHandler: cancelHandler)
                    
                    // present the alert
                    self.present(alert, animated: true, completion: nil)
                    
                case .nothing:
                    break
                    
                case let .callFunction(function):
                    
                    // call function
                    function()
                    
                    // check if refresh is needed, either complete settingsview or individual section
                    self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: viewModel, rowIndex: indexPath.row, sectionIndex: indexPath.section)

                case let .selectFromList(title, data, selectedRow, actionTitle, cancelTitle, actionHandler, cancelHandler, didSelectRowHandler):
                    
                    // configure pickerViewData
                    let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: title, withData: data, selectedRow: selectedRow, withPriority: nil, actionButtonText: actionTitle, cancelButtonText: cancelTitle, onActionClick: {(_ index: Int) in
                        actionHandler(index)
                        
                        // check if refresh is needed, either complete settingsview or individual section
                        self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: viewModel, rowIndex: indexPath.row, sectionIndex: indexPath.section)

                    }, onCancelClick: {
                        if let cancelHandler = cancelHandler { cancelHandler() }
                    }, didSelectRowHandler: {(_ index: Int) in
                        
                        if let didSelectRowHandler = didSelectRowHandler {
                            didSelectRowHandler(index)
                        }
                        
                    })
                    
                    // create and present pickerviewcontroller
                    PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
                    
                    break
                    
                case .performSegue(let withIdentifier):
                    self.performSegue(withIdentifier: withIdentifier, sender: nil)

                case let .showInfoText(title, message):
                    
                    UIAlertController(title: title, message: message, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
                    
                }

            } else {
                // setting not enabled, nothing to do
            }
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
    }
}


