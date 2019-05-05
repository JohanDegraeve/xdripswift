import UIKit

/// functions that define the contents of a Section
///
/// The protocol defines the Section title, the text and detailedText to be shown in a cell of that secion, the accessoryType (none, disclosure, detail button, detail disclosure button), the UIView to be shown if applicable (eg UISwitch), the nomber of rows in the Section
protocol SettingsViewModelProtocol {
    /// what title should be shown in a section
    /// - returns:
    /// the section title, optional, for section
    func sectionTitle() -> String?
    
    /// the text to be shown for a specific row in the Section
    /// - returns:
    ///     the text
    func settingsRowText(index:Int) -> String
    
    /// the accessoryType to be shown for a specific row in the Section (none, disclosure, detail button, detail disclosure button)
    /// - returns:
    ///     the accessoryType
    func accessoryType(index:Int) -> UITableViewCell.AccessoryType
    
    /// the detailedText to be shown for a specific row in the Section
    /// - returns:
    ///     the detailedText corresponding to cel on index
    func detailedText(index:Int) -> String?
    
    /// used for adding a a view in a settings cell, for the moment only used for UISwitch (on/off) - maybe can also be used to add a button with an image ? eg + sign for alert entries
    /// - returns:
    ///     a UIView, nil if no UIView to be shown (example see SettingsViewHealthKitSettingsViewModel)
    ///     reloadSection : should section be reloaded or not - example after setting nightscoutupload to true/false a section reload is required because other rows need to be shown/hidden respectively
    func uiView(index:Int) -> (view: UIView?, reloadSection: Bool)
    
    /// what's the number of rows in the section
    /// - returns:
    ///     number of rows in the section
    func numberOfRows() -> Int
    
    /// what should happen if a row is selected
    /// - parameters:
    ///     - index: index of selected row in the Section
    /// - returns:
    ///     a selectedRowAction
    func onRowSelect(index:Int) -> SettingsSelectedRowAction
}

