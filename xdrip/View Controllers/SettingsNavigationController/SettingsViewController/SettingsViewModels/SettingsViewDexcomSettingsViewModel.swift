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
        return true
    }
    
    func isEnabled(index: Int) -> Bool {
        
        // if it's a G5 (or maybe later G6) , then user doesn't need to set the serial number, because value of transmitterId is used in that case
        if index == Setting.dexcomShareSerialNumber.rawValue {
            
            if let transmitterType = UserDefaults.standard.transmitterType  {
                switch transmitterType {
                    
                case .dexcomG4, .miaomiao, .GNSentry, .Blucon, .Bubble:
                    return true
                    
                case .dexcomG5, .dexcomG6:
                    return false
                }
            } else {
                return true
            }
            
        } else {
            return true
        }
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .uploadReadingstoDexcomShare:
            return SettingsSelectedRowAction.nothing
            
        case .dexcomShareAccountName:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelDexcomShareAccountName, message: Texts_SettingsView.giveDexcomShareAccountName, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in UserDefaults.standard.dexcomShareAccountName = accountName.toNilIfLength0()}, cancelHandler: nil)
            
        case .dexcomSharePassword:
            return SettingsSelectedRowAction.askText(title: Texts_Common.password, message: Texts_SettingsView.giveDexcomSharePassword, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomSharePassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in UserDefaults.standard.dexcomSharePassword = password.toNilIfLength0()}, cancelHandler: nil)
            
        case .useUSDexcomShareurl:
            return SettingsSelectedRowAction.nothing
            
        case .dexcomShareSerialNumber:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelDexcomShareSerialNumber, message: Texts_SettingsView.giveDexcomShareSerialNumber, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomShareSerialNumber, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in
                
                // convert to uppercase
                let serialNumberUpper = serialNumber.uppercased()
                
                // if changed then store new value
                if let currentSerialNumber = UserDefaults.standard.dexcomShareSerialNumber {
                    if currentSerialNumber != serialNumberUpper {
                        UserDefaults.standard.dexcomShareSerialNumber = serialNumberUpper.toNilIfLength0()
                    }
                } else {
                    UserDefaults.standard.dexcomShareSerialNumber = serialNumberUpper.toNilIfLength0()
                }

            }, cancelHandler: nil)
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
