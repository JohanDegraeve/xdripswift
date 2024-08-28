import UIKit

fileprivate enum Setting:Int, CaseIterable {
    ///should readings be uploaded or not
    case uploadReadingstoDexcomShare = 0
    ///dexcomShareAccountName
    case dexcomShareAccountName = 1
    /// dexcomSharePassword
    case dexcomSharePassword = 2
    /// dexcomShareSerialNumber
    case dexcomShareSerialNumber = 3
    /// should us url be used true or false
    case useUSDexcomShareurl = 4
    /// use dexcom share schedule or not
    case useSchedule = 5
    /// open uiviewcontroller to edit schedule
    case schedule = 6

}

/// conforms to SettingsViewModelProtocol for all Dexcom Share settings in the first sections screen
class SettingsViewDexcomShareSettingsViewModel:SettingsViewModelProtocol {
    
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
            
        case .uploadReadingstoDexcomShare:
            return SettingsSelectedRowAction.nothing
            
        case .dexcomShareAccountName:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelDexcomShareAccountName, message: Texts_SettingsView.giveDexcomShareAccountName, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in UserDefaults.standard.dexcomShareAccountName = accountName.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .dexcomSharePassword:
            return SettingsSelectedRowAction.askText(title: Texts_Common.password, message: Texts_SettingsView.giveDexcomSharePassword, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.dexcomSharePassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in UserDefaults.standard.dexcomSharePassword = password.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
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

            }, cancelHandler: nil, inputValidator: nil)
            
        case .useUSDexcomShareurl:
            return SettingsSelectedRowAction.nothing
            
        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToSchedule.rawValue, sender: self)
            
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.dexcomSettingsIcon + " " + Texts_SettingsView.sectionTitleDexcomShare
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.uploadReadingstoDexcomShare {
            return 1
        }
        else {
            if !UserDefaults.standard.dexcomShareUseSchedule {
                return Setting.allCases.count - 1
            }
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
        case .useSchedule:
            return Texts_SettingsView.useSchedule
        case .schedule:
            return Texts_SettingsView.schedule
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
        case .dexcomShareSerialNumber:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .useUSDexcomShareurl:
            return UITableViewCell.AccessoryType.none
        case .useSchedule:
            return UITableViewCell.AccessoryType.none
        case .schedule:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return nil
        case .dexcomShareAccountName:
            return UserDefaults.standard.dexcomShareAccountName ?? Texts_SettingsView.valueIsRequired
        case .dexcomSharePassword:
            return UserDefaults.standard.dexcomSharePassword?.obscured() ?? Texts_SettingsView.valueIsRequired
        case .useUSDexcomShareurl:
            return nil
        case .dexcomShareSerialNumber:
            return UserDefaults.standard.dexcomShareSerialNumber ?? Texts_SettingsView.valueIsRequired
        case .useSchedule:
            return nil
        case .schedule:
            return nil
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
        case .useSchedule:
            return UISwitch(isOn: UserDefaults.standard.dexcomShareUseSchedule, action: {(isOn:Bool) in UserDefaults.standard.dexcomShareUseSchedule = isOn})
            
        case .schedule:
            return nil
        }
    }
}

extension SettingsViewDexcomShareSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "Dexcom Share"
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
    
    
}

