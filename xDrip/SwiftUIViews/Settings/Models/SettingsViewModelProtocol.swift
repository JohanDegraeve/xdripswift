struct SettingsToggleControl {
    let isOn: () -> Bool
    let setIsOn: (Bool) -> Void
    var confirmation: ((Bool) -> SettingsToggleConfirmationContent?)? = nil

    init(isOn: @escaping () -> Bool, setIsOn: @escaping (Bool) -> Void, confirmation: ((Bool) -> SettingsToggleConfirmationContent?)? = nil) {
        self.isOn = isOn
        self.setIsOn = setIsOn
        self.confirmation = confirmation
    }
}

struct SettingsToggleConfirmationContent {
    let title: String?
    let message: String?
    let actionTitle: String
    let cancelTitle: String
}

/// functions that define the contents of a Section
///
/// The protocol defines the section title, row text, detail text, accessory, toggle control, number of rows and whether each setting is enabled.
///
/// in case isEnabled returns false, then the didSelectRow action will never be applied
protocol SettingsViewModelProtocol {
    
    /// what title should be shown in a section
    /// - returns:
    /// the section title, optional, for section
    func sectionTitle() -> String?
    
    /// what title should be shown in a section footer
    /// - returns:
    /// the section title, optional, for section
    func sectionFooter() -> String?

    /// the text to be shown for a specific row in the Section
    /// - returns:
    ///     the text
    func settingsRowText(index:Int) -> String
    
    /// the accessoryType to be shown for a specific row in the Section (none, disclosure, detail button, detail disclosure button)
    /// - returns:
    ///     the accessoryType
    func accessoryType(index:Int) -> SettingsAccessory
    
    /// the detailedText to be shown for a specific row in the Section
    /// - returns:
    ///     the detailedText corresponding to cel on index
    func detailedText(index:Int) -> String?
    
    /// Native toggle state and action for SwiftUI Settings rows.
    func settingsToggle(index: Int) -> SettingsToggleControl?

    /// Optional marker shown before the row title.
    func rowIndicator(index: Int) -> SettingsIndicator?
    
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
    
    /// is the setting enabled or not
    ///
    /// if not enabled, then clicking the setting should not have any reaction, also it should be made clear in UI that setting is not enabled (ey gray color)
    func isEnabled(index:Int) -> Bool
    
    /// does a change of the setting need a refresh of the complete settings screen yes or no
    ///
    /// example switching from master to follower in the general settings, requires changing the UI for Nightscout settings - in this case a complete refresh of all settings is needed
    ///
    /// Goal is to minimize the refresh to the section if possible and to avoid refreshing the whole screen as much as possible.
    /// This function will verify if complete reload is needed or not
    func completeSettingsViewRefreshNeeded(index:Int) -> Bool
    
    /// a view model may want to pass information back to the viewcontroller asynchronously. Example SettingsViewNightscoutSettingsViewModel will initiate a credential test. The response will come asynchronously and a text needs to return to the viewcontroller, to be shown to the user.
    ///
    /// The viewmodel must call the messageHandler on the main thread.
    /// - parameters:
    ///     - two strings, a title and a message.
    func storeMessageHandler(messageHandler : @escaping ((String, String) -> Void))
    
    /// closure to call to reload a row specified by index in the section that the viewmodel is implementing (ie not in another section)
    ///
    /// just an additional method to force row reloads, (there's also the method completeSettingsViewRefreshNeeded which may return true or false depending on row number and which will be called from within the SettingsViewController. The rowReloadClosure is useful when the reload needs to be handled asynchronously
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void))
    
    /// closure to call to reload the current section that the viewmodel is implementing
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void))
}

// Add default implementations here so that ViewModels don't need to implement empty methods
extension SettingsViewModelProtocol {
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {}

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        nil
    }

    func rowIndicator(index: Int) -> SettingsIndicator? {
        nil
    }
    
    func sectionFooter() -> String? {
        nil
    }
}

/// to make the coding a bit easier, just one function defined for now, which is to get the viewModel for a specific setting
protocol SettingsProtocol {
    
    /// returns a SettingsViewModelProtocol
    func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol
    
}
