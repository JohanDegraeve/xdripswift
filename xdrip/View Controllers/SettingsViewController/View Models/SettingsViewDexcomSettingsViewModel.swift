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

class SettingsViewDexcomSettingsViewModel:SettingsViewModelProtocol {
    
    func onRowSelect(index: Int) -> SelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return SelectedRowAction.nothing
        case .dexcomShareAccountName:
            var textAddon = ""
            if let currentValue = UserDefaults.standard.dexcomShareAccountName {textAddon = "\n" + currentValue}
            return SelectedRowAction.askText(title: Texts_SettingsViews.dexcomShareAccountName, message: Texts_SettingsViews.giveDexcomShareAccountName + textAddon, keyboardType: UIKeyboardType.alphabet, placeHolder: UserDefaults.standard.dexcomShareAccountName, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in UserDefaults.standard.dexcomShareAccountName = accountName}, cancelHandler: nil)
        case .dexcomSharePassword:
            return SelectedRowAction.askText(title: Texts_Common.password, message: Texts_SettingsViews.giveDexcomSharePassword, keyboardType: UIKeyboardType.alphabet, placeHolder: "", actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in UserDefaults.standard.dexcomSharePassword = password}, cancelHandler: nil)
        case .useUSDexcomShareurl:
            return SelectedRowAction.nothing
        case .dexcomShareSerialNumber:
            var textAddon = ""
            if let currentValue = UserDefaults.standard.dexcomShareSerialNumber {textAddon = "\n" + currentValue}
            return SelectedRowAction.askText(title: Texts_SettingsViews.dexcomShareSerialNumber, message: Texts_SettingsViews.giveDexcomShareSerialNumber + textAddon, keyboardType: UIKeyboardType.alphabet, placeHolder: UserDefaults.standard.dexcomShareSerialNumber, actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.dexcomShareSerialNumber = serialNumber}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleDexcomShare
    }

    func numberOfRows() -> Int {
        if !UserDefaults.standard.uploadReadingstoDexcomShare {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }
    
    func text(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return Texts_SettingsViews.uploadReadingstoDexcomShare
        case .dexcomSharePassword:
            return Texts_Common.password
        case .dexcomShareSerialNumber:
            return Texts_SettingsViews.dexcomShareSerialNumber
        case .useUSDexcomShareurl:
            return Texts_SettingsViews.useUSDexcomShareurl
        case .dexcomShareAccountName:
            return Texts_SettingsViews.dexcomShareAccountName
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
    
    func uiView(index:Int) -> (view: UIView?, reloadSection: Bool) {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.uploadReadingstoDexcomShare, animated: true)
            uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.uploadReadingstoDexcomShare = theSwitch.isOn}, for: UIControl.Event.valueChanged)
            return (uiSwitch, true)
        case .useUSDexcomShareurl:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.useUSDexcomShareurl, animated: true)
            uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.useUSDexcomShareurl = theSwitch.isOn}, for: UIControl.Event.valueChanged)
            return (uiSwitch, false)
        case .dexcomShareAccountName,.dexcomSharePassword,.dexcomShareSerialNumber:
            return (nil, false)
        }
    }
}
