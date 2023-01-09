import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be spoken or not
    case speakBgReadings = 0

    ///should use workaround for iOS 16 bug
    case speakBgReadingsUseWorkaround = 1
    
    /// language to use
    case speakBgReadingLanguage = 2
    
    ///should trend be spoken or not
    case speakTrend = 3
    
    /// should delta be spoken or not
    case speakDelta = 4

    /// speak each reading, each 2 readings ...  integer value
    case speakInterval = 5
    
}

/// conforms to SettingsViewModelProtocol for all speak settings in the first sections screen
class SettingsViewSpeakSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    override init() {
        super.init()
        addObservers()
    }

    var sectionReloadClosure: (() -> Void)?

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
   func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .speakBgReadings:
            return true
        case .speakBgReadingsUseWorkaround:
            return true
        case .speakBgReadingLanguage:
            // language is locked to English when the workaround is in use
            return !UserDefaults.standard.speakReadingsUseWorkaround
        case .speakTrend:
            // trend is not available when the workaround is in use
            return !UserDefaults.standard.speakReadingsUseWorkaround
        case .speakDelta:
            // delta is not available when the workaround is in use
            return !UserDefaults.standard.speakReadingsUseWorkaround
        case .speakInterval:
            return true
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return .nothing
        case .speakBgReadingsUseWorkaround:
            return .nothing
        case .speakTrend:
            return .nothing
        case .speakDelta:
            return .nothing
        case .speakInterval:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_IntervalTitle, message: Texts_SettingsView.settingsviews_IntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.speakInterval.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
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
        case .speakBgReadingsUseWorkaround:
            return Texts_SettingsView.labelSpeakBgReadingsUseWorkaround
        case .speakBgReadingLanguage:
            return Texts_SettingsView.labelSpeakLanguage
        case .speakTrend:
            return Texts_SettingsView.labelSpeakTrend
        case .speakDelta:
            return Texts_SettingsView.labelSpeakDelta
        case .speakInterval:
            return Texts_SettingsView.settingsviews_IntervalTitle
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return UITableViewCell.AccessoryType.none
        case .speakBgReadingsUseWorkaround:
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
        case .speakBgReadingsUseWorkaround:
            return nil
        case .speakTrend:
            return nil
        case .speakDelta:
            return nil
        case .speakInterval:
            return UserDefaults.standard.speakInterval.description
        case .speakBgReadingLanguage:
            if UserDefaults.standard.speakReadingsUseWorkaround {
                // language is locked to English when the workaround is in use
                return ConstantsSpeakReadingLanguages.languageName(forLanguageCode: Texts_SpeakReading.defaultLanguageCode)
            } else {
                return Texts_SpeakReading.languageName
            }
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .speakBgReadings:
            return UISwitch(isOn: UserDefaults.standard.speakReadings, action: {(isOn:Bool) in UserDefaults.standard.speakReadings = isOn})

        case .speakBgReadingsUseWorkaround:
            return UISwitch(isOn: UserDefaults.standard.speakReadingsUseWorkaround, action: {(isOn:Bool) in UserDefaults.standard.speakReadingsUseWorkaround = isOn})

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
    
    // MARK: - observe functions
    
    private func addObservers() {
        // Listen for changes in the Speak Readings setting as it may be changed with a Quick Action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.speakReadings.rawValue, options: .new, context: nil)
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
            case UserDefaults.Key.speakReadings:
                // Speak readings setting has been changed from other model, likely by a Quick Action. Update UI to reflect current state.
                sectionReloadClosure?()

            default:
                break
        }
    }
}
