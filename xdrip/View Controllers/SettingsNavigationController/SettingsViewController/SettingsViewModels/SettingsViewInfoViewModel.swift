import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// version Number
    case versionNumber = 0
    
    /// build Number
    case buildNumber = 1
    
    /// licenseInfo
    case licenseInfo = 2
    
    /// link to icons8
    case icons8 = 3
    
}

struct SettingsViewInfoViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleAbout
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
            
        case .icons8:
            return "Icons By icons8.com"

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
            
        case .icons8:
            return .disclosureIndicator
            
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
            
        case .icons8:
            
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

        case .icons8:
            guard let url = URL(string: "https://icons8.com") else { return .nothing}
            
            UIApplication.shared.open(url)
            
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

