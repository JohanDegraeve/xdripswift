import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// version Number
    case versionNumber = 0
    
    /// build Number
    case buildNumber = 1
    
    /// licenseInfo
    case licenseInfo = 2
    
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
            
        case .buildNumber:
            return Texts_SettingsView.build

        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .versionNumber:
            return .none
            
        case .buildNumber:
            return .none

        case .licenseInfo:
            return .detailButton
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            
            guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
            
            guard let version = dictionary["CFBundleShortVersionString"] as? String else {return "unknown"}
            
            return version
            
        case .buildNumber:

            guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
            
            guard let version = dictionary["CFBundleVersion"] as? String else {return "unknown"}

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
            
        case .buildNumber:
            return .nothing
            
        case .licenseInfo:
            return SettingsSelectedRowAction.showInfoText(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress)

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    
    
}

