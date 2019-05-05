import UIKit

fileprivate enum Setting:Int, CaseIterable {
    // alert types
    case alertTypes = 0
    // alerts
    case alerts = 1
}

/// conforms to SettingsViewModelProtocol for all alert settings in the first sections screen
struct SettingsViewAlertSettingsViewModel:SettingsViewModelProtocol {
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewAlertSettingsViewModel onRowSelect") }

        switch setting {
        case .alertTypes:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToAlertTypeSettings.rawValue)
        case .alerts:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToAlertSettings.rawValue)
        }
    }
    
    func getUIViewController(index: Int) -> UIViewController? {
        return nil
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleAlerting
    }
    
    func numberOfRows() -> Int {
        return 2
    }
    
    func uiView(index: Int) -> (view: UIView?, reloadSection: Bool) {
        return (nil, false)
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewAlertSettingsViewModel onRowSelect") }
        
        switch setting {
            
        case .alertTypes:
            return Texts_SettingsView.labelAlertTypes
        case .alerts:
            return Texts_SettingsView.labelAlerts
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.none
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
}
