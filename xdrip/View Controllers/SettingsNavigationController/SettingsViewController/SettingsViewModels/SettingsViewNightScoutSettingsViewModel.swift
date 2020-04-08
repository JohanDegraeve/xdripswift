import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be uploaded or not
    case nightScoutEnabled = 0
    
    ///nightscout url
    case nightScoutUrl = 1
    
    /// nightscout api key
    case nightScoutAPIKey = 2
    
    /// should sensor start time be uploaded to NS yes or no
    case uploadSensorStartTime = 3
    
    /// use nightscout schedule or not
    case useSchedule = 4
    
    /// open uiviewcontroller to edit schedule
    case schedule = 5
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
class SettingsViewNightScoutSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .nightScoutEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .nightScoutUrl:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutUrl, message: Texts_SettingsView.giveNightScoutUrl, keyboardType: .URL, text: UserDefaults.standard.nightScoutUrl, placeHolder: "yoursitename", actionTitle: nil, cancelTitle: nil, actionHandler: {(nightscouturl:String) in
                
                // if user gave empty string then set to nil
                // if not nil, and if not starting with http, add https, and remove ending /
                UserDefaults.standard.nightScoutUrl = nightscouturl.toNilIfLength0().addHttpsIfNeeded()
                
                if let url = UserDefaults.standard.nightScoutUrl {
                    debuglogging("url = " + url)
                } else {
                    debuglogging("url is nil")
                }
                
            }, cancelHandler: nil, inputValidator: nil)

        case .nightScoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutAPIKey, message:  Texts_SettingsView.giveNightScoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightScoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(apiKey:String) in
                UserDefaults.standard.nightScoutAPIKey = apiKey.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToSchedule.rawValue, sender: self)
            
        case .uploadSensorStartTime:
            return SettingsSelectedRowAction.nothing
            
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleNightScout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightScoutEnabled {
            
            // in follower mode, only two first rows to be shown : nightscout enabled button and url
            if !UserDefaults.standard.isMaster {
                return 2
            }
            
            // if schedule not enabled then show all rows except the last which is to edit the schedule
            if !UserDefaults.standard.nightScoutUseSchedule {
                return Setting.allCases.count - 1
            }
            
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
        case .useSchedule:
            return Texts_SettingsView.useSchedule
        case .schedule:
            return Texts_SettingsView.schedule
        case .uploadSensorStartTime:
            return Texts_SettingsView.uploadSensorStartTime
            
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
        case .useSchedule:
            return UITableViewCell.AccessoryType.none
        case .schedule:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .uploadSensorStartTime:
            return UITableViewCell.AccessoryType.none
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
        case .useSchedule:
            return nil
        case .schedule:
            return nil
        case .uploadSensorStartTime:
            return nil
            
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .nightScoutEnabled:
            return UISwitch(isOn: UserDefaults.standard.nightScoutEnabled, action: {(isOn:Bool) in UserDefaults.standard.nightScoutEnabled = isOn})
        
        case .nightScoutUrl:
            return nil
            
        case .nightScoutAPIKey:
            return nil
            
        case .useSchedule:
            return UISwitch(isOn: UserDefaults.standard.nightScoutUseSchedule, action: {(isOn:Bool) in UserDefaults.standard.nightScoutUseSchedule = isOn})
            
        case .schedule:
            return nil
            
        case .uploadSensorStartTime:
            return UISwitch(isOn: UserDefaults.standard.uploadSensorStartTimeToNS, action: {(isOn:Bool) in UserDefaults.standard.uploadSensorStartTimeToNS = isOn})
            
        }
    }
    
}

extension SettingsViewNightScoutSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "NightScout"
    }
    
    func getSchedule() -> [Int] {

        var schedule = [Int]()
        
        if let scheduleInSettings = UserDefaults.standard.nightScoutSchedule {
            
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
        
        UserDefaults.standard.nightScoutSchedule = scheduleToStore
        
    }
    
    
}


