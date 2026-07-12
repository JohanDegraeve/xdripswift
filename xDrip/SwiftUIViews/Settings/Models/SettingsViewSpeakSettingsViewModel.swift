import os
import Foundation

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
class SettingsViewSpeakSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel)
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            nativeSettingsRow(id: "speak.speakBgReadings", index: Setting.speakBgReadings.rawValue, sectionID: sectionID),
            nativeSettingsRow(
                id: "speak.speakBgReadingLanguage",
                index: Setting.speakBgReadingLanguage.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakTrend",
                index: Setting.speakTrend.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakDelta",
                index: Setting.speakDelta.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakInterval",
                index: Setting.speakInterval.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            )
        ]
    }

    override init() {
        super.init()
        addObservers()
    }

    var sectionReloadClosure: (() -> Void)?

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    
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
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_SpeakIntervalTitle, message: Texts_SettingsView.settingsviews_SpeakIntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.speakInterval.description, placeHolder: "0", fieldTitle: Texts_Common.enterValue, unitText: Texts_Common.minutes, actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
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
            return Texts_SettingsView.settingsviews_SpeakIntervalTitle
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return SettingsAccessory.none
        case .speakTrend:
            return SettingsAccessory.none
        case .speakDelta:
            return SettingsAccessory.none
        case .speakInterval:
            return SettingsAccessory.disclosure
        case .speakBgReadingLanguage:
            return SettingsAccessory.disclosure
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
            return UserDefaults.standard.speakInterval.description + " " + Texts_Common.minutes
        case .speakBgReadingLanguage:
            return Texts_SpeakReading.languageName
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .speakBgReadings:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakReadings },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakBgReadings changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakReadings = isOn
                }
            )
        case .speakTrend:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakTrend },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakTrend changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakTrend = isOn
                }
            )
        case .speakDelta:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakDelta },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakDelta changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakDelta = isOn
                }
            )
        case .speakInterval, .speakBgReadingLanguage:
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
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                // Speak readings setting has been changed from other model, likely by a Quick Action. Update UI to reflect current state.
                self.sectionReloadClosure?()
            }

            default:
                break
        }
    }
}
