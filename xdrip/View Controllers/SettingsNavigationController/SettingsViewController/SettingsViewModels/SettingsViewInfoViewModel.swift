import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// version Number
    case versionNumber = 0
    
    /// licenseInfo
    case licenseInfo = 1
    
}

struct SettingsViewInfoViewModel:SettingsViewModelProtocol {
    
    func sectionTitle() -> String? {
        return Texts_HomeView.info
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            
            return Texts_SettingsView.version
            
        case .licenseInfo:
            return Texts_SettingsView.license

        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .versionNumber:
            return UITableViewCell.AccessoryType.none
            
        case .licenseInfo:
            return UITableViewCell.AccessoryType.detailButton

        }
        
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            
            guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
            
            guard let version = dictionary["CFBundleShortVersionString"] as? String else {return "unknown"}
            
            return version
            
        case .licenseInfo:
            
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
            
        case .versionNumber:
            return SettingsSelectedRowAction.nothing
            
        case .licenseInfo:
            
            return SettingsSelectedRowAction.showInfoText(title: Constants.HomeView.applicationName, message: Texts_HomeView.licenseInfo + Constants.HomeView.infoEmailAddress)

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    
    
}

