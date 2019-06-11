import UIKit

fileprivate enum Setting:Int, CaseIterable {
    ///should readings be uploaded or not
    case uploadReadingstoDexcomShare = 0
    ///dexcomShareAccountName
    case dexcomShareAccountName = 1
    /// dexcomSharePassword
    case dexcomSharePassword = 2
    /// should us url be used true or false
    case useUSDexcomShareurl = 3
    /// dexcomShareSerialNumber
    case dexcomShareSerialNumber = 4
}

/// conforms to SettingsViewModelProtocol for all Dexcom settings in the first sections screen
class SettingsViewDexcomSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return false
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return SettingsSelectedRowAction.nothing
        case .dexcomShareAccountName:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelDexcomShareAccountName, message: Texts_SettingsView.giveDexcomShareAccountName, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in UserDefaults.standard.dexcomShareAccountName = accountName}, cancelHandler: nil)
        case .dexcomSharePassword:
            return SettingsSelectedRowAction.askText(title: Texts_Common.password, message: Texts_SettingsView.giveDexcomSharePassword, keyboardType: UIKeyboardType.alphabet, text: nil, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in UserDefaults.standard.dexcomSharePassword = password}, cancelHandler: nil)
        case .useUSDexcomShareurl:
            return SettingsSelectedRowAction.nothing
        case .dexcomShareSerialNumber:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelDexcomShareSerialNumber, message: Texts_SettingsView.giveDexcomShareSerialNumber, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomShareSerialNumber, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.dexcomShareSerialNumber = serialNumber}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleDexcomShare
    }

    func numberOfRows() -> Int {
        if !UserDefaults.standard.uploadReadingstoDexcomShare {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return Texts_SettingsView.labelUploadReadingstoDexcomShare
        case .dexcomSharePassword:
            return Texts_Common.password
        case .dexcomShareSerialNumber:
            return Texts_SettingsView.labelDexcomShareSerialNumber
        case .useUSDexcomShareurl:
            return Texts_SettingsView.labelUseUSDexcomShareurl
        case .dexcomShareAccountName:
            return Texts_SettingsView.labelDexcomShareAccountName
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return UITableViewCell.AccessoryType.none
        case .dexcomShareAccountName:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .dexcomSharePassword:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .useUSDexcomShareurl:
            return UITableViewCell.AccessoryType.none
        case .dexcomShareSerialNumber:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return nil
        case .dexcomShareAccountName:
            return UserDefaults.standard.dexcomShareAccountName
        case .dexcomSharePassword:
            return UserDefaults.standard.dexcomSharePassword
        case .useUSDexcomShareurl:
            return nil
        case .dexcomShareSerialNumber:
            return UserDefaults.standard.dexcomShareSerialNumber
        }
    }
    
    func uiView(index:Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return UISwitch(isOn: UserDefaults.standard.uploadReadingstoDexcomShare, action: {(isOn:Bool) in UserDefaults.standard.uploadReadingstoDexcomShare = isOn})
        case .useUSDexcomShareurl:
            return UISwitch(isOn: UserDefaults.standard.useUSDexcomShareurl, action: {(isOn:Bool) in UserDefaults.standard.useUSDexcomShareurl = isOn})
        case .dexcomShareAccountName,.dexcomSharePassword,.dexcomShareSerialNumber:
            return nil
        }
    }
}
