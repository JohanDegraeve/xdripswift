import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// to enable NSLog
    case NSLogEnabled = 0
    
    /// to enable OSLog
    case OSLogEnabled = 1
    
    /// libreValueSmoothing
    case libreValueSmoothing = 2
    
}

struct SettingsViewDevelopmentSettingsViewModel:SettingsViewModelProtocol {
    
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
            
        case .libreValueSmoothing:
            return "smooth Libre OOP Values"
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .libreValueSmoothing:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return nil
            
        case .OSLogEnabled:
            return nil
            
        case .libreValueSmoothing:
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
            
        case .libreValueSmoothing:
            return UISwitch(isOn: !UserDefaults.standard.libreValueSmoothingIsOff, action: {
                
                (isOn:Bool) in
                
                UserDefaults.standard.libreValueSmoothingIsOff = !isOn
                
            })
            
        }
        
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .libreValueSmoothing:
            return .nothing
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
