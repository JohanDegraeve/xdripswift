import UIKit

fileprivate enum Setting:Int, CaseIterable {
    ///should readings be uploaded or not
    case uploadReadingsToNightScout = 0
    ///nightscout url
    case nightScoutUrl = 1
    /// nightscout api key
    case nightScoutAPIKey = 2
}

class SettingsViewNightScoutSettingsViewModel:SettingsViewModelProtocol {
    
    func onRowSelect(index: Int) -> SelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingsToNightScout:
            return SelectedRowAction.nothing
        case .nightScoutUrl:
            return SelectedRowAction.askText(title: Texts_SettingsViews.nightScoutUrl, message: UserDefaults.standard.nightScoutUrl, keyboardType: .URL, text: UserDefaults.standard.nightScoutUrl, placeHolder: "yoursitename", actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.nightScoutUrl = serialNumber}, cancelHandler: nil)

        case .nightScoutAPIKey:
            return SelectedRowAction.askText(title: Texts_SettingsViews.nightScoutAPIKey, message: UserDefaults.standard.nightScoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightScoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.nightScoutAPIKey = serialNumber}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleNightScout
    }

    func numberOfRows() -> Int {
        // if nightscout upload not enabled then only one row to be shown
        if UserDefaults.standard.uploadReadingsToNightScout {
            return Setting.allCases.count
        } else {
            return 1
        }
    }
    
    func text(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutAPIKey:
            return Texts_SettingsViews.nightScoutAPIKey
        case .nightScoutUrl:
            return Texts_SettingsViews.nightScoutUrl
        case .uploadReadingsToNightScout:
            return Texts_SettingsViews.uploadReadingsToNightScout
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingsToNightScout:
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
        case .uploadReadingsToNightScout:
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
        case .uploadReadingsToNightScout:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.uploadReadingsToNightScout, animated: true)
            uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.uploadReadingsToNightScout = theSwitch.isOn}, for: UIControl.Event.valueChanged)
            return (uiSwitch, true)
        default:
            return (nil, false)
        }
    }
}


