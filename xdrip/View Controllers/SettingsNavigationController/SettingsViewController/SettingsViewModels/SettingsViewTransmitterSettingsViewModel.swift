import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// is webOOP enabled or not
    case webOOP = 0
    
    /// if webOOP enabled, what site to use
    case webOOPsite = 1
    
    /// if webOOP enabled, value of the token
    case webOOPtoken = 2

}

/// conforms to SettingsViewModelProtocol for all transmitter settings in the first sections screen
struct SettingsViewTransmitterSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // in follower mode, all transmitter settings can be disabled
        if UserDefaults.standard.isMaster && UserDefaults.standard.transmitterType?.canWebOOP() ?? false {
            return true
        } else {
            return false
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Setting in SettingsViewTransmitterSettingsViewModel onRowSelect") }
        
        switch setting {
            
        case .webOOP:
            return SettingsSelectedRowAction.nothing

        case .webOOPsite:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPSiteExplainingText, keyboardType: .URL, text: UserDefaults.standard.webOOPSite, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebsiteurl:String) in UserDefaults.standard.webOOPSite = oopwebsiteurl.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .webOOPtoken:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPtokenExplainingText, keyboardType: .default, text: UserDefaults.standard.webOOPtoken, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebtoken:String) in UserDefaults.standard.webOOPtoken = oopwebtoken.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)

        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleTransmitter
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.isMaster {
            // follower mode, no need to show all settings
            return 1
        }

        return Setting.allCases.count
        
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }

        switch (setting) {
            
        case .webOOP:
            return Texts_SettingsView.labelWebOOPTransmitter
            
        case .webOOPsite:
            return Texts_SettingsView.labelWebOOPSite
            
        case .webOOPtoken:
            return Texts_SettingsView.labelWebOOPtoken
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .webOOP:
            return UITableViewCell.AccessoryType.none
        case .webOOPsite:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .webOOPtoken:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }

    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch (setting) {
            
        case .webOOP:
            return nil
        case .webOOPsite:
            if let site = UserDefaults.standard.webOOPSite {
                return site
            } else {
                return Texts_Common.default0
            }
        case .webOOPtoken:
            if let token = UserDefaults.standard.webOOPtoken {
                return token
            } else {
                return Texts_Common.default0
            }

        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .webOOP:
            return UISwitch(isOn: UserDefaults.standard.webOOPEnabled, action: {(isOn:Bool) in UserDefaults.standard.webOOPEnabled = isOn})
        default:
            return nil
        }
    }
    
    // MARK: - private helper functions
    
    /// if it's a transmitterType that canWebOOP, then when user clicks second row or highter (ie index >= 1), then fix to index + 2 is done
    private func fixWebOOPIndex(_ index: Int) -> Int {
        
        var index = index
        
        if let transmitterType = UserDefaults.standard.transmitterType {
            if transmitterType.canWebOOP() && index >= 1 {
                index = index + 2
            }
        }
        
        return index
    }
    
}
