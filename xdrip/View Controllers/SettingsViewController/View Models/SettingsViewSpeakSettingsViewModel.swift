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

class SettingsViewSpeakSettingsViewModel:SettingsViewModelProtocol {
    func onRowSelect(index: Int) -> SelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return .nothing
        case .speakTrend:
            return .nothing
        case .speakDelta:
            return .nothing
        case .speakInterval:
            return SelectedRowAction.askText(title: Texts_SettingsViews.speakInterval, message: nil, keyboardType: .numberPad, placeHolder: UserDefaults.standard.speakInterval.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleSpeak
    }

    func numberOfRows() -> Int {
        if !UserDefaults.standard.speakReadings {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }

    func text(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return Texts_SettingsViews.speakBgReadings
        case .speakTrend:
            return Texts_SettingsViews.speakTrend
        case .speakDelta:
            return Texts_SettingsViews.speakDelta
        case .speakInterval:
            return Texts_SettingsViews.speakInterval
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
    
    func uiView(index: Int) -> (view: UIView?, reloadSection: Bool) {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .speakBgReadings:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.speakReadings, animated: true)
            uiSwitch.addTarget(self, action: {
                (theSwitch:UISwitch) in
                UserDefaults.standard.speakReadings = theSwitch.isOn
                // if speakreadings is set to off, then also set speaktrend and speak delta to off
                if !theSwitch.isOn {
                    UserDefaults.standard.speakTrend = false
                    UserDefaults.standard.speakDelta = false
                }
            }, for: UIControl.Event.valueChanged)
            return (uiSwitch, true)
            
        case .speakTrend:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.speakTrend, animated: true)
            uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.speakTrend = theSwitch.isOn}, for: UIControl.Event.valueChanged)
            return (uiSwitch, false)
            
        case .speakDelta:
            let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
            uiSwitch.setOn(UserDefaults.standard.speakDelta, animated: true)
            uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.speakDelta = theSwitch.isOn}, for: UIControl.Event.valueChanged)
            return (uiSwitch, false)
            
        case .speakInterval:
            return (nil, false)
        }
    }
}
