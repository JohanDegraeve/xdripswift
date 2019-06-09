import UIKit

/// conforms to SettingsViewModelProtocol for all healthkit settings in the first sections screen
class SettingsViewHealthKitSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        return SettingsSelectedRowAction.nothing
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleHealthKit
    }

    func numberOfRows() -> Int {
        return 1
    }

    func settingsRowText(index: Int) -> String {
        return Texts_SettingsView.labelHealthKit
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.none
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
    
    func uiView(index:Int) -> UIView? {
        return UISwitch(isOn: UserDefaults.standard.storeReadingsInHealthkit, action: {
            (isOn:Bool) in
            UserDefaults.standard.storeReadingsInHealthkit = isOn
            
        })
    }
}


