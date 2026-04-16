import UIKit


final class M5StackSettingsViewController: UIViewController {
    
    // MARK: - Outlets, ..
    
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Private Properties

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Texts_SettingsView.m5StackSettingsViewScreenTitle
        
        setupView()
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

extension M5StackSettingsViewController {
    
    private enum Section: Int, CaseIterable, SettingsProtocol {
        
        ///General settings, display color
        case general
        
        /// wifi settings
        case wifi
        
        /// bluetooth settings
        case bluetooth
        
        func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol {
            
            switch self {
                
            case .general:
                return SettingsViewM5StackGeneralSettingsViewModel()
                
            case .bluetooth:
                return SettingsViewM5StackBluetoothSettingsViewModel()
                
            case .wifi:
                return SettingsViewM5StackWiFiSettingsViewModel()

            }
        }

    }
}

extension M5StackSettingsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let view = view as? UITableViewHeaderFooterView {
            
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
            
        }
        
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        // coredatamanager not needed in this viewmodel
        let viewModel = section.viewModel(coreDataManager: nil)
        
        if viewModel.isEnabled(index: indexPath.row) {
            
            let selectedRowAction = viewModel.onRowSelect(index: indexPath.row)
            
            SettingsViewUtilities.runSelectedRowAction(selectedRowAction: selectedRowAction, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: viewModel, tableView: tableView, forUIViewController: self)
            
        }
    }
    
}

extension M5StackSettingsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel(coreDataManager: nil).numberOfRows()
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        guard var cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        let viewModel = section.viewModel(coreDataManager: nil)
        
        // Configure Cell
        SettingsViewUtilities.configureSettingsCell(cell: &cell, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withViewModel: viewModel, tableView: tableView)
        
        return cell

    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel(coreDataManager: nil).sectionTitle()
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return Section.allCases.count
        
    }

}

