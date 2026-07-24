import os
import Foundation

fileprivate enum Setting: Int, CaseIterable {
    ///should readings be uploaded or not
    case uploadReadingstoDexcomShare = 0
    ///dexcomShareAccountName
    case dexcomShareAccountName = 1
    /// dexcomSharePassword
    case dexcomSharePassword = 2
    /// dexcomShareUploadSerialNumber
    case dexcomShareUploadSerialNumber = 3
    /// should us url be used true or false
    case useUSDexcomShareurl = 4
    /// use dexcom share schedule or not
    case useSchedule = 5
    /// open uiviewcontroller to edit schedule
    case schedule = 6

}

/// conforms to SettingsViewModelProtocol for all Dexcom Share Upload settings in the first sections screen
class SettingsViewDexcomShareUploadSettingsViewModel: SettingsViewModelProtocol {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel)
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let uploadEnabled = UserDefaults.standard.uploadReadingstoDexcomShare

        return [
            nativeSettingsRow(id: "dexcomShare.uploadReadingstoDexcomShare", index: Setting.uploadReadingstoDexcomShare.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "dexcomShare.accountName", index: Setting.dexcomShareAccountName.rawValue, sectionID: sectionID, isVisible: uploadEnabled),
            nativeSettingsRow(id: "dexcomShare.password", index: Setting.dexcomSharePassword.rawValue, sectionID: sectionID, isVisible: uploadEnabled),
            nativeSettingsRow(id: "dexcomShare.serialNumber", index: Setting.dexcomShareUploadSerialNumber.rawValue, sectionID: sectionID, isVisible: uploadEnabled),
            nativeSettingsRow(id: "dexcomShare.useUSUrl", index: Setting.useUSDexcomShareurl.rawValue, sectionID: sectionID, isVisible: uploadEnabled),
            nativeSettingsRow(id: "dexcomShare.useSchedule", index: Setting.useSchedule.rawValue, sectionID: sectionID, isVisible: uploadEnabled),
            nativeSettingsRow(
                id: "dexcomShare.schedule",
                index: Setting.schedule.rawValue,
                sectionID: sectionID,
                isVisible: uploadEnabled && UserDefaults.standard.dexcomShareUploadUseSchedule
            )
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
            
        case .uploadReadingstoDexcomShare:
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .dexcomShare {
                return .showInfoText(title: Texts_SettingsView.sectionTitleDexcomShareUpload, message: Texts_SettingsView.labelUploadReadingstoDexcomShareDisabledMessage)
            } else {
                return .nothing
            }
            
        case .dexcomShareAccountName:
            return .askText(title: Texts_SettingsView.labelDexcomShareAccountName, message: Texts_SettingsView.giveDexcomShareAccountName, keyboardType: .alphabet, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: ConstantsSettingsPlaceholders.usernamePlaceholder, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in UserDefaults.standard.dexcomShareAccountName = accountName.trimmingCharacters(in: .whitespaces).toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .dexcomSharePassword:
            return .askText(title: Texts_Common.password, message: Texts_SettingsView.giveDexcomSharePassword, keyboardType: .alphabet, text: UserDefaults.standard.dexcomSharePassword, placeHolder: ConstantsSettingsPlaceholders.passwordPlaceholder, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in UserDefaults.standard.dexcomSharePassword = password.trimmingCharacters(in: .whitespaces).toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .dexcomShareUploadSerialNumber:
            return .askText(title: Texts_SettingsView.labeldexcomShareUploadSerialNumber, message: Texts_SettingsView.givedexcomShareUploadSerialNumber, keyboardType: .alphabet, text: UserDefaults.standard.dexcomShareUploadSerialNumber, placeHolder: "AB12345678", actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in
                
                // convert to uppercase
                let serialNumberUpper = serialNumber.trimmingCharacters(in: .whitespaces).uppercased()
                
                // if changed then store new value
                if let currentSerialNumber = UserDefaults.standard.dexcomShareUploadSerialNumber {
                    if currentSerialNumber != serialNumberUpper {
                        UserDefaults.standard.dexcomShareUploadSerialNumber = serialNumberUpper.toNilIfLength0()
                    }
                } else {
                    UserDefaults.standard.dexcomShareUploadSerialNumber = serialNumberUpper.toNilIfLength0()
                }

            }, cancelHandler: nil, inputValidator: nil)
            
        case .useUSDexcomShareurl:
            return .nothing
            
        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsSegueIdentifier.settingsToSchedule.rawValue, sender: self)
            
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleDexcomShareUpload
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.uploadReadingstoDexcomShare {
            return 1
        }
        else {
            if !UserDefaults.standard.dexcomShareUploadUseSchedule {
                return Setting.allCases.count - 1
            }
            return Setting.allCases.count
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return Texts_SettingsView.labelUploadReadingstoDexcomShare
        case .dexcomSharePassword:
            return Texts_Common.password
        case .dexcomShareUploadSerialNumber:
            return Texts_SettingsView.labeldexcomShareUploadSerialNumber
        case .useUSDexcomShareurl:
            return Texts_SettingsView.labelUseUSDexcomShareurl
        case .dexcomShareAccountName:
            return Texts_SettingsView.labelDexcomShareAccountName
        case .useSchedule:
            return Texts_SettingsView.useSchedule
        case .schedule:
            return Texts_SettingsView.schedule
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return SettingsAccessory.none
        case .dexcomShareAccountName:
            return SettingsAccessory.disclosure
        case .dexcomSharePassword:
            return SettingsAccessory.disclosure
        case .dexcomShareUploadSerialNumber:
            return SettingsAccessory.disclosure
        case .useUSDexcomShareurl:
            return SettingsAccessory.none
        case .useSchedule:
            return SettingsAccessory.none
        case .schedule:
            return SettingsAccessory.disclosure
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            // show the disabled text if we're in dexcom share follower mode
            return (!UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .dexcomShare) ? Texts_Common.disabled : nil
        case .dexcomShareAccountName:
            return UserDefaults.standard.dexcomShareAccountName ?? Texts_SettingsView.valueIsRequired
        case .dexcomSharePassword:
            return UserDefaults.standard.dexcomSharePassword?.obscured() ?? Texts_SettingsView.valueIsRequired
        case .useUSDexcomShareurl:
            return nil
        case .dexcomShareUploadSerialNumber:
            return UserDefaults.standard.dexcomShareUploadSerialNumber ?? Texts_SettingsView.valueIsRequired
        case .useSchedule:
            return nil
        case .schedule:
            return nil
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .uploadReadingstoDexcomShare:
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .dexcomShare {
                return nil
            }

            return SettingsToggleControl(
                isOn: { UserDefaults.standard.uploadReadingstoDexcomShare },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("uploadReadingstoDexcomShare changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.uploadReadingstoDexcomShare = isOn
                }
            )
        case .useUSDexcomShareurl:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.useUSDexcomShareurl },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("useUSDexcomShareurl changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.useUSDexcomShareurl = isOn
                }
            )
        case .useSchedule:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.dexcomShareUploadUseSchedule },
                setIsOn: { UserDefaults.standard.dexcomShareUploadUseSchedule = $0 }
            )
        case .dexcomShareAccountName, .dexcomSharePassword, .dexcomShareUploadSerialNumber, .schedule:
            return nil
        }
    }
    
}

extension SettingsViewDexcomShareUploadSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "Dexcom Share"
    }
    
    func getSchedule() -> [Int] {
        
        var schedule = [Int]()
        
        if let scheduleInSettings = UserDefaults.standard.dexcomShareUploadSchedule {
            
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
        
        UserDefaults.standard.dexcomShareUploadSchedule = scheduleToStore
        
    }
    
    
}
