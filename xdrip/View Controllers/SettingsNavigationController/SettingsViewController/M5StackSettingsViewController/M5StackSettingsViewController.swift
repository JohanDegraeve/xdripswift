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
            tableView.separatorInset = UIEdgeInsets.zero
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
        
        func viewModel() -> SettingsViewModelProtocol {
            
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        let viewModel = section.viewModel()
        
        if viewModel.isEnabled(index: indexPath.row) {
            
            let selectedRowAction = viewModel.onRowSelect(index: indexPath.row)
            
            SettingsViewUtilities.runSelectedRowAction(selectedRowAction: selectedRowAction, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withViewModel: viewModel, tableView: tableView, forUIViewController: self)
            
        }
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        // apple doc says : Use this method to respond to taps in the detail button accessory view of a row. The table view does not call this method for other types of accessory views.
        // when user clicks on of the detail buttons, then consider this as row selected, for now - as it's only license that is using this button for now
        self.tableView(tableView, didSelectRowAt: indexPath)
        
    }
}

extension M5StackSettingsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel().numberOfRows()
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let section = Section(rawValue: indexPath.section) else { fatalError("Unexpected Section") }
        
        guard var cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        let viewModel = section.viewModel()
        
        // Configure Cell
        SettingsViewUtilities.configureSettingsCell(cell: &cell, forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withViewModel: viewModel, tableView: tableView)
        
        return cell

    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        guard let section = Section(rawValue: section) else { fatalError("Unexpected Section") }
        
        return section.viewModel().sectionTitle()
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return Section.allCases.count
        
    }

}

