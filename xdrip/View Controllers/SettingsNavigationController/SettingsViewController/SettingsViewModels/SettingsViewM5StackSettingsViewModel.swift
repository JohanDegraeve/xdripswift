import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// M5Stack - the only settings it to open the M5StackSettingsViewController
    case m5stack = 0
    
}

struct SettingsViewM5StackSettingsViewModel: SettingsViewModelProtocol {
    
    func sectionTitle() -> String? {
        return "M5Stack"
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .m5stack:
            
            return Texts_SettingsView.m5StackSettingsViewScreenTitle
            
        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .m5stack:
            return UITableViewCell.AccessoryType.none
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .m5stack:
            
            return nil
            
        }
    }
    
    func uiView(index: Int) -> UIView? {
        return nil
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .m5stack:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToM5StackSettings.rawValue)
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    

}
