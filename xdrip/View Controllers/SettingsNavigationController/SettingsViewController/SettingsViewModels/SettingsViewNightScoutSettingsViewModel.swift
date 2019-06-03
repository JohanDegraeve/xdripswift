import UIKit

fileprivate enum Setting:Int, CaseIterable {
    ///should readings be uploaded or not
    case nightScoutEnabled = 0
    ///nightscout url
    case nightScoutUrl = 1
    /// nightscout api key
    case nightScoutAPIKey = 2
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
class SettingsViewNightScoutSettingsViewModel:SettingsViewModelProtocol {
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return SettingsSelectedRowAction.nothing
        case .nightScoutUrl:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutUrl, message: Texts_SettingsView.giveNightScoutUrl, keyboardType: .URL, text: UserDefaults.standard.nightScoutUrl, placeHolder: "yoursitename", actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.nightScoutUrl = serialNumber}, cancelHandler: nil)

        case .nightScoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutAPIKey, message:  Texts_SettingsView.giveNightScoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightScoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in
                UserDefaults.standard.nightScoutAPIKey = serialNumber}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleNightScout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightScoutEnabled {
            return Setting.allCases.count
        } else {
            return 1
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutAPIKey:
            return Texts_SettingsView.labelNightScoutAPIKey
        case .nightScoutUrl:
            return Texts_SettingsView.labelNightScoutUrl
        case .nightScoutEnabled:
            return Texts_SettingsView.labelNightScoutEnabled
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return UITableViewCell.AccessoryType.none
        case .nightScoutUrl:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .nightScoutAPIKey:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return nil
        case .nightScoutAPIKey:
            return UserDefaults.standard.nightScoutAPIKey
        case .nightScoutUrl:
            return UserDefaults.standard.nightScoutUrl
        }
    }
    
    func uiView(index: Int) -> (view: UIView?, reloadSection: Bool) {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return (UISwitch(isOn: UserDefaults.standard.nightScoutEnabled, action: {(isOn:Bool) in UserDefaults.standard.nightScoutEnabled = isOn}), true)
        default:
            return (nil, false)
        }
    }
}


