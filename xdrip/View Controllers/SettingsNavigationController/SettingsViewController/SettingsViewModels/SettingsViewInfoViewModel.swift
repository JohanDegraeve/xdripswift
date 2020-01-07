import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// version Number
    case versionNumber = 0
    
    /// build Number
    case buildNumber = 1
    
    /// licenseInfo
    case licenseInfo = 2
    
    //webServicesInfo1
    case webServicesInfo1 = 3
    
    //webServicesInfo2
    case webServicesInfo2 = 4

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
            
        case .webServicesInfo1:
            return Texts_SettingsView.webServices1

        case .webServicesInfo2:
            return Texts_SettingsView.webServices2
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
            
        case .webServicesInfo1:
            return .none
  
        case .webServicesInfo2:
            return .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let isSecure = appDelegate.wsManager?.server.isSecure
        let proto = isSecure ?? false ? "https" : "http"

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
 
        case .webServicesInfo1:
            let address = ConstantsWebServices.webServicesLo
            
            return "\(proto)://\(address):\(ConstantsWebServices.webServicesPort)"
            
        case .webServicesInfo2:
            let address = SystemInfoHelper.ipAddress()
            
            return "\(proto)://\(address):\(ConstantsWebServices.webServicesPort)"
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        return nil
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let isSecure = appDelegate.wsManager?.server.isSecure
        let proto = isSecure ?? false ? "https" : "http"

        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            return SettingsSelectedRowAction.nothing
            
        case .buildNumber:
            return .nothing
            
        case .licenseInfo:
            return SettingsSelectedRowAction.showInfoText(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress)

        case .webServicesInfo1:
            return .callFunction(function: {
                let address = ConstantsWebServices.webServicesLo
                if let url = URL(string: "\(proto)://\(address):\(ConstantsWebServices.webServicesPort)") {
                
                  UIApplication.shared.open(url)
                }
            })
            
        case .webServicesInfo2:
            return .callFunction(function: {
                let address = SystemInfoHelper.ipAddress()
                if let url = URL(string: "\(proto)://\(address):\(ConstantsWebServices.webServicesPort)") {
                
                  UIApplication.shared.open(url)
                }
            })
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    
    
}

