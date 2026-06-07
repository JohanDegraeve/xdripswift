import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// name of wifi 1
    case wifi1Name
    
    /// Password of wifi 1
    case wifi1Password
    
    /// name of wifi 2
    case wifi2Name
    
    /// Password of wifi 2
    case wifi2Password
    
    /// name of wifi 3
    case wifi3Name
    
    /// Password of wifi 3
    case wifi3Password
    
}

struct SettingsViewM5StackWiFiSettingsViewModel: SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.m5StackWiFiSettingsIcon + " " + Texts_Common.WiFi
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .wifi1Name:
            return Texts_Common.WiFi + " 1 : " + Texts_Common.name
        case .wifi2Name:
            return Texts_Common.WiFi + " 2 : " + Texts_Common.name
        case .wifi3Name:
            return Texts_Common.WiFi + " 3 : " + Texts_Common.name
        case .wifi1Password:
            return Texts_Common.WiFi + " 1 : " + Texts_Common.password
        case .wifi2Password:
            return Texts_Common.WiFi + " 2 : " + Texts_Common.password
        case .wifi3Password:
            return Texts_Common.WiFi + " 3 : " + Texts_Common.password
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .wifi1Name, .wifi2Name, .wifi3Name, .wifi1Password, .wifi2Password, .wifi3Password:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .wifi1Name:
            return UserDefaults.standard.m5StackWiFiName1
        case .wifi2Name:
            return UserDefaults.standard.m5StackWiFiName2
        case .wifi3Name:
            return UserDefaults.standard.m5StackWiFiName3
        case .wifi1Password:
            return UserDefaults.standard.m5StackWiFiPassword1
        case .wifi2Password:
            return UserDefaults.standard.m5StackWiFiPassword2
        case .wifi3Password:
            return UserDefaults.standard.m5StackWiFiPassword3
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .wifi1Name, .wifi2Name, .wifi3Name, .wifi1Password, .wifi2Password, .wifi3Password:
            return nil
        }
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .wifi1Name, .wifi2Name, .wifi3Name, .wifi1Password, .wifi2Password, .wifi3Password:
            return createSettingsSelectedRowActionForWifiNameOrPassword(wifiNumber: setting)
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
   
    // MARK: Private helper functions
    
    /// functionality being used more than once
    /// - parameters:
    ///     - wifiNumber : used to get the wifi number
    private func createSettingsSelectedRowActionForWifiNameOrPassword(wifiNumber: Setting) -> SettingsSelectedRowAction {
        
        var wifiNumberAsInt:Int?
        var text:String?
        var actionHandler:((String) -> Void)?
        var titlePart = Texts_Common.name
        
        switch wifiNumber {
        case .wifi1Name:
            wifiNumberAsInt = 1
            text = UserDefaults.standard.m5StackWiFiName1
            actionHandler = {(name:String) in UserDefaults.standard.m5StackWiFiName1 = name.toNilIfLength0()}
        case .wifi2Name:
            wifiNumberAsInt = 2
            text = UserDefaults.standard.m5StackWiFiName2
            actionHandler = {(name:String) in UserDefaults.standard.m5StackWiFiName2 = name.toNilIfLength0()}
        case .wifi3Name:
            wifiNumberAsInt = 3
            text = UserDefaults.standard.m5StackWiFiName3
            actionHandler = {(name:String) in UserDefaults.standard.m5StackWiFiName3 = name.toNilIfLength0()}
        case .wifi1Password:
            wifiNumberAsInt = 1
            text = UserDefaults.standard.m5StackWiFiPassword1
            actionHandler = {(password:String) in UserDefaults.standard.m5StackWiFiPassword1 = password.toNilIfLength0()}
            titlePart = Texts_Common.password
        case .wifi2Password:
            wifiNumberAsInt = 2
            text = UserDefaults.standard.m5StackWiFiPassword2
            actionHandler = {(password:String) in UserDefaults.standard.m5StackWiFiPassword2 = password.toNilIfLength0()}
            titlePart = Texts_Common.password
        case .wifi3Password:
            wifiNumberAsInt = 3
            text = UserDefaults.standard.m5StackWiFiPassword3
            actionHandler = {(password:String) in UserDefaults.standard.m5StackWiFiPassword3 = password.toNilIfLength0()}
            titlePart = Texts_Common.password
        }
        
        return SettingsSelectedRowAction.askText(title: Texts_Common.WiFi + " " + titlePart + " " + wifiNumberAsInt!.description, message: nil, keyboardType: .default, text: text, placeHolder: "", actionTitle: nil, cancelTitle: nil, actionHandler: actionHandler!, cancelHandler: nil, inputValidator: nil)
    }
    
}
