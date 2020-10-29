import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// to enable NSLog
    case NSLogEnabled = 0
    
    /// to enable OSLog
    case OSLogEnabled = 1
    
    /// if webOOP enabled, what site to use
    case webOOPsite = 2
    
    /// if webOOP enabled, value of the token
    case webOOPtoken = 3

    /// in case Libre 2 users want to use the local calibration algorithm
    case overrideWebOOPCalibration = 4
    
}

struct SettingsViewDevelopmentSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func sectionTitle() -> String? {
        return "Developer Settings"
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return "NSLog"
            
        case .OSLogEnabled:
            return "OSLog"

        case .webOOPsite:
            
            return Texts_SettingsView.labelWebOOPSite
            
        case .webOOPtoken:
            
            return Texts_SettingsView.labelWebOOPtoken
            
        case .overrideWebOOPCalibration:
            
            return "Override Web OOP Calibration"
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .overrideWebOOPCalibration:
            return UITableViewCell.AccessoryType.none
            
        case .webOOPsite:
            return .disclosureIndicator
            
        case .webOOPtoken:
            return .disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return nil
            
        case .OSLogEnabled:
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

        case .overrideWebOOPCalibration:
            return nil
            
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return UISwitch(isOn: UserDefaults.standard.NSLogEnabled, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.NSLogEnabled = isOn
                
            })
            
        case .OSLogEnabled:
            return UISwitch(isOn: UserDefaults.standard.OSLogEnabled, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.OSLogEnabled = isOn
                
            })
            
        case .webOOPsite:
            return nil
            
        case .webOOPtoken:
            return nil
           
        case .overrideWebOOPCalibration:
            return UISwitch(isOn: UserDefaults.standard.overrideWebOOPCalibration, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.overrideWebOOPCalibration = isOn
                
            })
            
        }
        
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .overrideWebOOPCalibration:
            return .nothing
            
        case .webOOPsite:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPSiteExplainingText, keyboardType: .URL, text: UserDefaults.standard.webOOPSite, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebsiteurl:String) in UserDefaults.standard.webOOPSite = oopwebsiteurl.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .webOOPtoken:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPtokenExplainingText, keyboardType: .default, text: UserDefaults.standard.webOOPtoken, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebtoken:String) in UserDefaults.standard.webOOPtoken = oopwebtoken.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
