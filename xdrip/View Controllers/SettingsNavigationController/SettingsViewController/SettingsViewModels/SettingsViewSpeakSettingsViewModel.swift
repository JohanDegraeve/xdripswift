import UIKit

fileprivate enum Setting:Int, CaseIterable {
    ///should readings be spoken or not
    case speakBgReadings = 0
    ///should trend be spoken or not
    case speakTrend = 1
    /// should delta be spoken or not
    case speakDelta = 2
    /// speak each reading, each 2 readings ...  integer value
    case speakInterval = 3
}

/// conforms to SettingsViewModelProtocol for all speak settings in the first sections screen
class SettingsViewSpeakSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return false
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return .nothing
        case .speakTrend:
            return .nothing
        case .speakDelta:
            return .nothing
        case .speakInterval:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelSpeakInterval, message: nil, keyboardType: .numberPad, text: UserDefaults.standard.speakInterval.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleSpeak
    }

    func numberOfRows() -> Int {
        if !UserDefaults.standard.speakReadings {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return Texts_SettingsView.labelSpeakBgReadings
        case .speakTrend:
            return Texts_SettingsView.labelSpeakTrend
        case .speakDelta:
            return Texts_SettingsView.labelSpeakDelta
        case .speakInterval:
            return Texts_SettingsView.labelSpeakInterval
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return UITableViewCell.AccessoryType.none
        case .speakTrend:
            return UITableViewCell.AccessoryType.none
        case .speakDelta:
            return UITableViewCell.AccessoryType.none
        case .speakInterval:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return nil
        case .speakTrend:
            return nil
        case .speakDelta:
            return nil
        case .speakInterval:
            return UserDefaults.standard.speakInterval.description
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .speakBgReadings:
            return UISwitch(isOn: UserDefaults.standard.speakReadings, action: {(isOn:Bool) in UserDefaults.standard.speakReadings = isOn
                // if speakreadings is set to off, then also set speaktrend and speak delta to off
                if !isOn {
                    UserDefaults.standard.speakTrend = false
                    UserDefaults.standard.speakDelta = false
                }
            })

        case .speakTrend:
            return UISwitch(isOn: UserDefaults.standard.speakTrend, action: {(isOn:Bool) in UserDefaults.standard.speakTrend = isOn})

        case .speakDelta:
            return UISwitch(isOn: UserDefaults.standard.speakDelta, action: {(isOn:Bool) in UserDefaults.standard.speakDelta = isOn})

        case .speakInterval:
            return nil
        }
    }
}
