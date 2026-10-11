import os
import Foundation
import Combine
import SwiftUI

/// Settings commands are wired to the coordinator-owned uploader, never a second networking instance.
struct DexcomShareUploadActions {
    let state: DexcomShareUploadState
    let testConnection: @MainActor () async -> Void

    static var none: DexcomShareUploadActions {
        DexcomShareUploadActions(state: DexcomShareUploadState(), testConnection: {})
    }
}

/// Keeps both the Services summary and the upload child sections in sync with the same state.
final class DexcomShareUploadSettingsRefresh {
    var reload: (() -> Void)?
    private var stateObserver: AnyCancellable?
    private var defaultsObserver: NSObjectProtocol?

    init(state: DexcomShareUploadState, defaults: UserDefaults = .standard) {
        stateObserver = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.reload?() }
        }
        // Defaults notifications are synchronous on the writer's thread. Delivering this observer
        // on `.main` makes every background writer wait for main, including Libre 2's unlock-count
        // update during reconnect. Receive inline and enqueue only the UI refresh asynchronously.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.reload?() }
        }
    }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    }
}

/// Relative ages only tick while a relevant Settings list is visible and the app is active.
struct DexcomShareUploadAgeRefresh: ViewModifier {
    let isRelevant: Bool
    let refresh: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        // Enabling uploads can add the connection rows without recreating the Settings list.
        // Restart the refresh task when those rows appear as well as when the app becomes active.
        content.task(id: isRelevant && scenePhase == .active) { @MainActor in
            guard isRelevant, scenePhase == .active else { return }
            refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) }
                catch { return }
                refresh()
            }
        }
    }
}

enum DexcomShareUploadRowGroup: CaseIterable {
    case enabled, account, connection, activity, options
}

/// The same resolver drives the child status row and the Services summary dot.
struct DexcomShareUploadPresentation {
    enum Status: Equatable { case disabled, unavailable, incomplete, unchecked, checking, verified, stale, failed, paused }
    let status: Status
    let title: String
    let color: Color

    var indicator: SettingsIndicator? {
        status == .disabled ? nil : SettingsIndicator(color: color, accessibilityLabel: title)
    }

    static func resolve(defaults: UserDefaults = .standard, state: DexcomShareUploadState, now: Date = Date()) -> Self {
        guard defaults.uploadReadingstoDexcomShare else {
            return .init(status: .disabled, title: Texts_Common.disabled, color: .gray)
        }
        guard defaults.isMaster else {
            return .init(status: .unavailable, title: Texts_Common.disabled, color: .gray)
        }
        guard defaults.dexcomShareAccountName?.isEmpty == false,
              defaults.dexcomSharePassword?.isEmpty == false,
              defaults.dexcomShareUploadSerialNumber?.isEmpty == false else {
            return .init(status: .incomplete, title: Texts_SettingsView.followerNotConfigured, color: .gray)
        }
        if state.isChecking {
            return .init(status: .checking, title: Texts_Common.checking, color: ConstantsAppColors.warning)
        }
        if state.authenticationError != nil || state.uploadError != nil {
            return .init(status: .failed, title: state.authenticationError != nil ? Texts_SettingsView.followerConnectionFailed : Texts_SettingsView.shareUploadFailed, color: ConstantsAppColors.urgent)
        }
        if defaults.dexcomShareUploadUseSchedule,
           defaults.dexcomShareUploadSchedule?.indicatesOn(forWhen: now) == false {
            return .init(status: .paused, title: Texts_SettingsView.shareUploadPaused, color: .gray)
        }
        guard let lastConnection = state.lastConnection else {
            return .init(status: .unchecked, title: Texts_SettingsView.shareUploadUnchecked, color: .gray)
        }
        if now.timeIntervalSince(lastConnection) > 310 {
            return .init(status: .stale, title: Texts_SettingsView.followerStale, color: .orange)
        }
        return .init(status: .verified, title: Texts_SettingsView.shareUploadAccountVerified, color: ConstantsAppColors.normal)
    }
}

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

/// Provides the account, connection, activity and schedule sections for Dexcom Share uploads.
class SettingsViewDexcomShareUploadSettingsViewModel: SettingsViewModelProtocol {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel)
    
    private let defaults: UserDefaults
    private let rowGroup: DexcomShareUploadRowGroup
    private let actions: DexcomShareUploadActions
    private let refresh: DexcomShareUploadSettingsRefresh

    init(rowGroup: DexcomShareUploadRowGroup = .enabled, actions: DexcomShareUploadActions = .none, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.rowGroup = rowGroup
        self.actions = actions
        self.refresh = DexcomShareUploadSettingsRefresh(state: actions.state, defaults: defaults)
    }

    // MARK: - Native SwiftUI rows

    func settingsSectionTitle() -> String? {
        switch rowGroup {
        case .enabled: return Texts_SettingsView.dexcomShareUploadSectionTitle
        case .account: return Texts_SettingsView.followerSectionAccount
        case .connection: return Texts_SettingsView.followerSectionConnection
        case .activity: return Texts_SettingsView.followerSectionActivity
        case .options: return Texts_SettingsView.nightscoutUploadOptionsSectionTitle
        }
    }

    func settingsSectionFooter() -> String? {
        if rowGroup == .enabled && !self.defaults.isMaster { return Texts_SettingsView.shareUploadLocalOnly }
        guard rowGroup == .connection else { return nil }
        let verified = actions.state.lastConnection != nil && actions.state.authenticationError == nil && defaults.dexcomShareUploadSerialNumber?.isEmpty != false
        return (verified ? Texts_SettingsView.shareUploadAccountVerified + ". " : "") + Texts_SettingsView.shareUploadCheckFooter
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let enabled = self.defaults.uploadReadingstoDexcomShare && self.defaults.isMaster
        guard rowGroup == .enabled || enabled else { return [] }
        switch rowGroup {
        case .enabled:
            var row = nativeSettingsRow(id: "dexcomShare.uploadReadingstoDexcomShare", index: Setting.uploadReadingstoDexcomShare.rawValue, sectionID: sectionID)
            row.isEnabled = self.defaults.isMaster
            return [row]
        case .account:
            return [
                nativeSettingsRow(id: "dexcomShare.accountName", index: Setting.dexcomShareAccountName.rawValue, sectionID: sectionID),
                nativeSettingsRow(id: "dexcomShare.password", index: Setting.dexcomSharePassword.rawValue, sectionID: sectionID)
            ]
        case .connection:
            let presentation = DexcomShareUploadPresentation.resolve(defaults: defaults, state: actions.state)
            let hasCredentials = self.defaults.dexcomShareAccountName?.isEmpty == false && self.defaults.dexcomSharePassword?.isEmpty == false
            return [
                nativeSettingsRow(id: "dexcomShare.useUSUrl", index: Setting.useUSDexcomShareurl.rawValue, sectionID: sectionID),
                nativeSettingsRow(id: "dexcomShare.serialNumber", index: Setting.dexcomShareUploadSerialNumber.rawValue, sectionID: sectionID),
                SettingsRow(id: "dexcomShare.connection.status", title: Texts_SettingsView.followerServiceStatus,
                            detail: presentation.title, detailIndicator: presentation.indicator, accessory: .none),
                SettingsRow(id: "dexcomShare.connection.test", title: Texts_SettingsView.testUrlAndAPIKey,
                            icon: SettingsIcon(symbolName: "link.icloud", color: .accentColor), titleColor: .accentColor,
                            accessory: .none, isEnabled: hasCredentials && !actions.state.isChecking,
                            action: .run { Task { @MainActor in await self.actions.testConnection() } })
            ]
        case .activity:
            var rows = [
                SettingsRow(id: "dexcomShare.activity.connection", title: Texts_SettingsView.shareUploadLastConnection,
                            detail: actions.state.lastConnection?.daysAndHoursAgo(appendAgo: true) ?? Texts_SettingsView.shareUploadNever, accessory: .none),
                SettingsRow(id: "dexcomShare.activity.upload", title: Texts_SettingsView.shareUploadLastUpload,
                            detail: actions.state.lastUpload?.daysAndHoursAgo(appendAgo: true) ?? Texts_SettingsView.shareUploadNever, accessory: .none)
            ]
            if let error = actions.state.authenticationError {
                rows.append(SettingsRow(id: "dexcomShare.activity.authenticationError", title: Texts_DexcomShareTestResult.verificationErrorAlertTitle,
                                        accessory: .none, control: .warningBanner(message: error)))
            }
            if let error = actions.state.uploadError {
                rows.append(SettingsRow(id: "dexcomShare.activity.uploadError", title: Texts_SettingsView.shareUploadError,
                                        accessory: .none, control: .warningBanner(message: error)))
            }
            if DexcomShareUploadPresentation.resolve(defaults: defaults, state: actions.state).status == .incomplete {
                rows.append(SettingsRow(id: "dexcomShare.activity.configuration", title: Texts_SettingsView.shareUploadConfigurationRequired, accessory: .none))
            }
            return rows
        case .options:
            return [
                nativeSettingsRow(id: "dexcomShare.useSchedule", index: Setting.useSchedule.rawValue, sectionID: sectionID),
                nativeSettingsRow(id: "dexcomShare.schedule", index: Setting.schedule.rawValue, sectionID: sectionID,
                                  isVisible: self.defaults.dexcomShareUploadUseSchedule)
            ]
        }
    }

    func storeSectionReloadClosure(sectionReloadClosure: @escaping () -> Void) {
        refresh.reload = sectionReloadClosure
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // Account checks report their result through the shared upload state.
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
            if !self.defaults.isMaster {
                return .showInfoText(title: Texts_SettingsView.sectionTitleDexcomShareUpload, message: Texts_SettingsView.shareUploadLocalOnly)
            } else {
                return .nothing
            }
            
        case .dexcomShareAccountName:
            return .askText(title: Texts_SettingsView.labelDexcomShareAccountName, message: Texts_SettingsView.giveDexcomShareAccountName, keyboardType: .credential, text: self.defaults.dexcomShareAccountName, placeHolder: ConstantsSettingsPlaceholders.usernamePlaceholder, actionTitle: nil, cancelTitle: nil, actionHandler: {(accountName:String) in self.defaults.dexcomShareAccountName = accountName.trimmingCharacters(in: .whitespaces).toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .dexcomSharePassword:
            return .askText(title: Texts_Common.password, message: Texts_SettingsView.giveDexcomSharePassword, keyboardType: .credential, text: self.defaults.dexcomSharePassword, placeHolder: ConstantsSettingsPlaceholders.passwordPlaceholder, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in self.defaults.dexcomSharePassword = password.trimmingCharacters(in: .whitespaces).toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .dexcomShareUploadSerialNumber:
            return .askText(title: Texts_SettingsView.labeldexcomShareUploadSerialNumber, message: Texts_SettingsView.givedexcomShareUploadSerialNumber, keyboardType: .alphabet, text: self.defaults.dexcomShareUploadSerialNumber, placeHolder: "AB12345678", actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in
                
                // convert to uppercase
                let serialNumberUpper = serialNumber.trimmingCharacters(in: .whitespaces).uppercased()
                
                // if changed then store new value
                if let currentSerialNumber = self.defaults.dexcomShareUploadSerialNumber {
                    if currentSerialNumber != serialNumberUpper {
                        self.defaults.dexcomShareUploadSerialNumber = serialNumberUpper.toNilIfLength0()
                    }
                } else {
                    self.defaults.dexcomShareUploadSerialNumber = serialNumberUpper.toNilIfLength0()
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
        
        if !self.defaults.uploadReadingstoDexcomShare {
            return 1
        }
        else {
            if !self.defaults.dexcomShareUploadUseSchedule {
                return Setting.allCases.count - 1
            }
            return Setting.allCases.count
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .uploadReadingstoDexcomShare:
            return Texts_Common.enable
        case .dexcomSharePassword:
            return Texts_Common.password
        case .dexcomShareUploadSerialNumber:
            return Texts_SettingsView.labeldexcomShareUploadSerialNumber
        case .useUSDexcomShareurl:
            return Texts_SettingsView.labelUseUSDexcomShareurl
        case .dexcomShareAccountName:
            return Texts_SettingsView.labelDexcomShareAccountName
        case .useSchedule:
            return Texts_SettingsView.enableSchedule
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
            // Uploading is unavailable in all follower modes.
            return (!self.defaults.isMaster) ? Texts_Common.disabled : nil
        case .dexcomShareAccountName:
            return self.defaults.dexcomShareAccountName ?? Texts_SettingsView.valueIsRequired
        case .dexcomSharePassword:
            return self.defaults.dexcomSharePassword?.obscured() ?? Texts_SettingsView.valueIsRequired
        case .useUSDexcomShareurl:
            return nil
        case .dexcomShareUploadSerialNumber:
            return self.defaults.dexcomShareUploadSerialNumber ?? Texts_SettingsView.valueIsRequired
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
            if !self.defaults.isMaster {
                return nil
            }

            return SettingsToggleControl(
                isOn: { self.defaults.uploadReadingstoDexcomShare },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("uploadReadingstoDexcomShare changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel, type: .info, isOn.description)
                    self.defaults.uploadReadingstoDexcomShare = isOn
                }
            )
        case .useUSDexcomShareurl:
            return SettingsToggleControl(
                isOn: { self.defaults.useUSDexcomShareurl },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("useUSDexcomShareurl changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDexcomShareUploadSettingsViewModel, type: .info, isOn.description)
                    self.defaults.useUSDexcomShareurl = isOn
                }
            )
        case .useSchedule:
            return SettingsToggleControl(
                isOn: { self.defaults.dexcomShareUploadUseSchedule },
                setIsOn: { self.defaults.dexcomShareUploadUseSchedule = $0 }
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
        
        if let scheduleInSettings = self.defaults.dexcomShareUploadSchedule {
            
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
        
        self.defaults.dexcomShareUploadSchedule = scheduleToStore
        
    }
    
    
}
