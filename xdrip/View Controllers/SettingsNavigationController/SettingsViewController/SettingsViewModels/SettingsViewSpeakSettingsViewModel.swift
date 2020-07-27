import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be spoken or not
    case speakBgReadings = 0
    
    /// language to use
    case speakBgReadingLanguage = 1
    
    ///should trend be spoken or not
    case speakTrend = 2
    
    /// should delta be spoken or not
    case speakDelta = 3
    
    /// speak each reading, each 2 readings ...  integer value
    case speakInterval = 4
    
}

/// conforms to SettingsViewModelProtocol for all speak settings in the first sections screen
class SettingsViewSpeakSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
   func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
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
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelSpeakInterval, message: Texts_SettingsView.speakIntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.speakInterval.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
        case .speakBgReadingLanguage:
            
            //find index for languageCode type currently stored in userdefaults
            var selectedRow:Int?
            if let languageCode = UserDefaults.standard.speakReadingLanguageCode {
                selectedRow = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes.firstIndex(of:languageCode)
            } else {
                selectedRow = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes.firstIndex(of:Texts_SpeakReading.defaultLanguageCode)
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.speakReadingLanguageSelection, data: ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.names, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.speakReadingLanguageCode = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

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
        case .speakBgReadingLanguage:
            return Texts_SettingsView.labelSpeakLanguage
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
        case .speakBgReadingLanguage:
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
        case .speakBgReadingLanguage:
            return Texts_SpeakReading.languageName
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .speakBgReadings:
            return UISwitch(isOn: UserDefaults.standard.speakReadings, action: {(isOn:Bool) in UserDefaults.standard.speakReadings = isOn
            })

        case .speakTrend:
            return UISwitch(isOn: UserDefaults.standard.speakTrend, action: {(isOn:Bool) in UserDefaults.standard.speakTrend = isOn})

        case .speakDelta:
            return UISwitch(isOn: UserDefaults.standard.speakDelta, action: {(isOn:Bool) in UserDefaults.standard.speakDelta = isOn})

        case .speakInterval:
            return nil
            
        case .speakBgReadingLanguage:
            return nil
        }
    }
}
