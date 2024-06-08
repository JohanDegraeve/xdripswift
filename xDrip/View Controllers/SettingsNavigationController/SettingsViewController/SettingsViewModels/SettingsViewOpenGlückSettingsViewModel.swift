import UIKit

fileprivate enum Setting:Int, CaseIterable {
    case openGlückEnabled = 0
    case openGlückUploadEnabled = 3
    case openGlückHostname = 1
    case openGlückToken = 2

}

/// conforms to SettingsViewModelProtocol for all OpenGlück settings in the first sections screen
class SettingsViewOpenGlückSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return true
    }
    
    func isEnabled(index: Int) -> Bool {

        return true
        
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .openGlückEnabled, .openGlückUploadEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .openGlückHostname:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelOpenGlückHostname, message: Texts_SettingsView.giveOpenGlückHostname, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.openGlückHostname, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(hostname:String) in UserDefaults.standard.openGlückHostname = hostname.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .openGlückToken:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelOpenGlückToken, message: Texts_SettingsView.giveOpenGlückToken, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.openGlückToken, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(token:String) in UserDefaults.standard.openGlückToken = token.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
                        
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.openGlückSettingsIcon + " " + Texts_SettingsView.sectionTitleOpenGlück
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.openGlückEnabled {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled:
            return Texts_SettingsView.labelOpenGlückEnabled
        case .openGlückUploadEnabled:
            return Texts_SettingsView.labelOpenGlückUploadEnabled
        case .openGlückHostname:
            return Texts_SettingsView.labelOpenGlückHostname
        case .openGlückToken:
            return Texts_SettingsView.labelOpenGlückToken
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled:
            return UITableViewCell.AccessoryType.none
        case .openGlückUploadEnabled:
            return UITableViewCell.AccessoryType.none
        case .openGlückHostname:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .openGlückToken:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled, .openGlückUploadEnabled:
            return nil
        case .openGlückHostname:
            return UserDefaults.standard.openGlückHostname
        case .openGlückToken:
            return UserDefaults.standard.openGlückToken != nil ? "***********" : nil
        }
    }
    
    func uiView(index:Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled:
            return UISwitch(isOn: UserDefaults.standard.openGlückEnabled, action: {(isOn:Bool) in UserDefaults.standard.openGlückEnabled = isOn})
        case .openGlückUploadEnabled:
            return UISwitch(isOn: UserDefaults.standard.openGlückUploadEnabled, action: {(isOn:Bool) in UserDefaults.standard.openGlückUploadEnabled = isOn})
        case .openGlückHostname:
            return nil
        case .openGlückToken:
            return nil
        }
    }
}
/*
extension SettingsViewDexcomSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "OpenGlück"
    }
    
    func getSchedule() -> [Int] {
        
        var schedule = [Int]()
        
        if let scheduleInSettings = UserDefaults.standard.dexcomShareSchedule {
            
            schedule = scheduleInSettings.split(separator: "-").map({Int($0) ?? 0})
            
        }
        
        return schedule
        
    }
    
    func storeSchedule(schedule: [Int]) {
        
        var scheduleToStore: String?
        
        for entry in schedule {
            
            if scheduleToStore == nil {
                
                scheduleToStore = entry.description
                
            } else {
                
                scheduleToStore = scheduleToStore! + "-" + entry.description
                
            }
            
        }
        
        UserDefaults.standard.dexcomShareSchedule = scheduleToStore
        
    }
    
    
}*/

