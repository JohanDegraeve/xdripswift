import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    //blood glucose  unit
    case blePassword
    
}

struct SettingsViewM5StackBluetoothSettingsViewModel: SettingsViewModelProtocol {
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.m5StackBluetoothSettingsIcon + " " + Texts_SettingsView.m5StackSectionTitleBluetooth
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .blePassword:
            return Texts_Common.password
        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .blePassword:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .blePassword:
            return UserDefaults.standard.m5StackBlePassword
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .blePassword:
            return nil
        }
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .blePassword:
            return SettingsSelectedRowAction.askText(title: Texts_Common.password, message: Texts_SettingsView.giveBlueToothPassword, keyboardType: .default, text: UserDefaults.standard.m5StackBlePassword, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler:
                {(blepassword:String) in
                
                    if blepassword == Texts_Common.default0 {
                        UserDefaults.standard.m5StackBlePassword = nil
                    } else {
                        UserDefaults.standard.m5StackBlePassword = blepassword.toNilIfLength0()
                    }
                
            }, cancelHandler: nil, inputValidator: nil)
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
