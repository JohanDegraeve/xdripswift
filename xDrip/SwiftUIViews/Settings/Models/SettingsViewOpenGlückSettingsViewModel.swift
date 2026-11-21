import Foundation

fileprivate enum Setting:Int, CaseIterable {
    case openGlückEnabled = 0
    case openGlückUploadEnabled = 3
    case openGlückHostname = 1
    case openGlückToken = 2

}

/// conforms to SettingsViewModelProtocol for all OpenGlück settings in the first sections screen
class SettingsViewOpenGlückSettingsViewModel:SettingsViewModelProtocol {
    
    // MARK: - Native SwiftUI rows
    
    func settingsRows(sectionID: Int) -> [SettingsRow] {
        // only show the other rows once OpenGlück is enabled
        let isEnabled = UserDefaults.standard.openGlückEnabled
        
        return [
            nativeSettingsRow(id: "openGlück.enabled", index: Setting.openGlückEnabled.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "openGlück.hostname", index: Setting.openGlückHostname.rawValue, sectionID: sectionID, isVisible: isEnabled),
            nativeSettingsRow(id: "openGlück.token", index: Setting.openGlückToken.rawValue, sectionID: sectionID, isVisible: isEnabled),
            nativeSettingsRow(id: "openGlück.uploadEnabled", index: Setting.openGlückUploadEnabled.rawValue, sectionID: sectionID, isVisible: isEnabled)
        ]
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return true
    }
    
    func isEnabled(index: Int) -> Bool {

        return true
        
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .openGlückEnabled, .openGlückUploadEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .openGlückHostname:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelOpenGlückHostname, message: Texts_SettingsView.giveOpenGlückHostname, keyboardType: .alphabet, text: UserDefaults.standard.openGlückHostname, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(hostname:String) in UserDefaults.standard.openGlückHostname = hostname.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .openGlückToken:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelOpenGlückToken, message: Texts_SettingsView.giveOpenGlückToken, keyboardType: .alphabet, text: UserDefaults.standard.openGlückToken, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(token:String) in UserDefaults.standard.openGlückToken = token.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
                        
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleOpenGlück
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.openGlückEnabled {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled:
            return Texts_SettingsView.labelOpenGlückEnabled
        case .openGlückUploadEnabled:
            return Texts_SettingsView.labelOpenGlückUploadEnabled
        case .openGlückHostname:
            return Texts_SettingsView.labelOpenGlückHostname
        case .openGlückToken:
            return Texts_SettingsView.labelOpenGlückToken
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled, .openGlückUploadEnabled:
            return .none
        case .openGlückHostname, .openGlückToken:
            return .disclosure
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled, .openGlückUploadEnabled:
            return nil
        case .openGlückHostname:
            return UserDefaults.standard.openGlückHostname
        case .openGlückToken:
            return UserDefaults.standard.openGlückToken != nil ? "***********" : nil
        }
    }
    
    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .openGlückEnabled:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.openGlückEnabled },
                setIsOn: { UserDefaults.standard.openGlückEnabled = $0 }
            )
        case .openGlückUploadEnabled:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.openGlückUploadEnabled },
                setIsOn: { UserDefaults.standard.openGlückUploadEnabled = $0 }
            )
        case .openGlückHostname, .openGlückToken:
            return nil
        }
    }
}

extension SettingsViewOpenGlückSettingsViewModel: SettingsNativeSectionProvider {}
