import Foundation
import os

fileprivate enum Setting:Int, CaseIterable {

    /// to enable developer settings
    case showDeveloperSettings = 0
    
    /// to enable NSLog
    case NSLogEnabled = 1
    
    /// to enable OSLog
    case OSLogEnabled = 2
    
    /// for Libre 2 only, to suppress that app sends unlock payload to Libre 2, in which case xDrip4iOS can run in parallel with other app(s)
    case suppressUnLockPayLoad = 3

    /// should the BG values be written to a shared app group?
    case loopShareType = 4
    
    /// to create artificial delay in readings stored in sharedUserDefaults for loop. Minutes.
    ///
    /// Default value 0, if used then recommended value is multiple of 5 (eg 5 ot 10)
    case loopDelay = 5
    
    /// LibreLinkUp version number that will be used for the LLU follower mode http request headers
    case libreLinkUpVersion = 6
    
    /// how many hours until the canula "expires"? Will show the default value until edited here
    case CAGEMaxHours = 7
    
    /// allow StandBy mode to show a high contrast version of the widget at night
    case allowStandByHighContrast = 8
    
    /// force StandBy mode to show a big number version of the widget
    case forceStandByBigNumbers = 9
    
    /// should we allow 60-second writes to Nightscout (in the case of Libre 2 Direct as an example)?
    case storeFrequentReadingsInNightscout = 10
    
    /// should we allow 60-second writes to HealthKit (in the case of Libre 2 Direct as an example)?
    case storeFrequentReadingsInHealthKit = 11

    /// should the online help be automatically translated?
    case translateOnlineHelp = 12

    /// allow OS-AID sharing to use smoothed/final glucose values
    case loopShareSmoothedData = 13

    /// allow OS-AID sharing to use Medtrum Nano glucose values
    case loopShareMedtrumNano = 14

    /// CarePartner mobile app version used by both personal and Care Partner account requests
    case careLinkVersion = 15

}

enum SettingsViewDevelopmentSettingsRowGroup {
    case advanced
    case osAidLoopShare
    case osAidLoopShareWarning
}

class SettingsViewDevelopmentSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    var sectionReloadClosure: (() -> Void)?

    private let rowGroup: SettingsViewDevelopmentSettingsRowGroup
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDevelopmentSettingsViewModel)

    init(rowGroup: SettingsViewDevelopmentSettingsRowGroup = .advanced) {
        self.rowGroup = rowGroup

        super.init()
    }
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let developerRowsVisible = UserDefaults.standard.showDeveloperSettings
        let loopShareTypes = LoopShareType.allCases
        var loopShareTypeRow = nativeSettingsRow(id: "developer.loopShareType", index: Setting.loopShareType.rawValue, sectionID: sectionID)
        loopShareTypeRow.accessory = .none
        if UserDefaults.standard.canConfigureOSAidSharing {
            loopShareTypeRow.control = .menu(
                options: {
                    loopShareTypes.map {
                        SettingsMenuOption(title: $0.description, isSelected: $0 == UserDefaults.standard.loopShareType)
                    }
                },
                selectOption: { index in
                    guard loopShareTypes.indices.contains(index) else { return }
                    UserDefaults.standard.loopShareType = loopShareTypes[index]
                }
            )
        }

        let advancedRows = [
            nativeSettingsRow(id: "developer.showDeveloperSettings", index: Setting.showDeveloperSettings.rawValue, sectionID: sectionID),
            SettingsRow(
                id: "developer.issueReport",
                title: Texts_SettingsView.issueReportTitle,
                accessory: .disclosure,
                isVisible: developerRowsVisible,
                action: .settingsScreen {
                    SettingsScreen(
                        title: Texts_SettingsView.issueReportTitle,
                        onlineHelpTopic: .issueReporting,
                        providers: {
                            [SettingsViewTraceSettingsViewModel(rowGroup: .developerReport)]
                        }
                    )
                }
            ),
            nativeSettingsRow(id: "developer.translateOnlineHelp", index: Setting.translateOnlineHelp.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.storeFrequentReadingsInNightscout", index: Setting.storeFrequentReadingsInNightscout.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.storeFrequentReadingsInHealthKit", index: Setting.storeFrequentReadingsInHealthKit.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.suppressUnLockPayLoad", index: Setting.suppressUnLockPayLoad.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.allowStandByHighContrast", index: Setting.allowStandByHighContrast.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.forceStandByBigNumbers", index: Setting.forceStandByBigNumbers.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.NSLogEnabled", index: Setting.NSLogEnabled.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.OSLogEnabled", index: Setting.OSLogEnabled.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.libreLinkUpVersion", index: Setting.libreLinkUpVersion.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.careLinkVersion", index: Setting.careLinkVersion.rawValue, sectionID: sectionID, isVisible: developerRowsVisible),
            nativeSettingsRow(id: "developer.CAGEMaxHours", index: Setting.CAGEMaxHours.rawValue, sectionID: sectionID, isVisible: developerRowsVisible)
        ]

        let osAidLoopShareRows = [
            loopShareTypeRow,
            nativeSettingsRow(id: "developer.loopDelay", index: Setting.loopDelay.rawValue, sectionID: sectionID, isVisible: UserDefaults.standard.canConfigureOSAidSharing && UserDefaults.standard.loopShareType != .disabled),
            nativeSettingsRow(id: "developer.loopShareMedtrumNano", index: Setting.loopShareMedtrumNano.rawValue, sectionID: sectionID, isVisible: UserDefaults.standard.loopShareMedtrumNanoAvailable),
            nativeSettingsRow(id: "developer.loopShareSmoothedData", index: Setting.loopShareSmoothedData.rawValue, sectionID: sectionID, isVisible: showLoopShareSmoothedDataRow)
        ]

        let osAidLoopShareWarningRows = loopShareWarningBanners()

        switch rowGroup {
        case .advanced:
            return advancedRows
        case .osAidLoopShare:
            return osAidLoopShareRows
        case .osAidLoopShareWarning:
            return osAidLoopShareWarningRows
        }
    }

    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func sectionTitle() -> String? {
        if rowGroup == .osAidLoopShare || rowGroup == .osAidLoopShareWarning {
            return nil
        }

        return Texts_SettingsView.developerSettings
    }

    func sectionFooter() -> String? {
        return nil
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings:
            return Texts_SettingsView.showDeveloperSettings

        case .NSLogEnabled:
            return Texts_SettingsView.nsLog
            
        case .OSLogEnabled:
            return Texts_SettingsView.osLog
            
        case .suppressUnLockPayLoad:
            return Texts_SettingsView.suppressUnLockPayLoad
            
        case .loopShareType:
            return Texts_SettingsView.loopShare

        case .loopShareSmoothedData:
            return Texts_SettingsView.loopShareSmoothedData

        case .loopShareMedtrumNano:
            return Texts_SettingsView.loopShareMedtrumNano
            
        case .loopDelay:
            return Texts_SettingsView.loopDelaysScreenTitle
            
        case .libreLinkUpVersion:
            return Texts_SettingsView.libreLinkUpVersion

        case .careLinkVersion:
            return Texts_SettingsView.careLinkVersion
            
        case .CAGEMaxHours:
            return Texts_SettingsView.CAGEMaxHours
            
        case .allowStandByHighContrast:
            return Texts_SettingsView.allowStandByHighContrast
            
        case .forceStandByBigNumbers:
            return Texts_SettingsView.forceStandByBigNumbers
            
        case .storeFrequentReadingsInNightscout:
            return Texts_SettingsView.labelStoreFrequentReadingsInNightscout
            
        case .storeFrequentReadingsInHealthKit:
            return Texts_SettingsView.labelStoreFrequentReadingsInHealthKit

        case .translateOnlineHelp:
            return Texts_SettingsView.translateOnlineHelp
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .allowStandByHighContrast, .forceStandByBigNumbers, .storeFrequentReadingsInNightscout, .storeFrequentReadingsInHealthKit, .translateOnlineHelp, .loopShareSmoothedData, .loopShareMedtrumNano:
            return .none
            
        case .loopDelay, .libreLinkUpVersion, .careLinkVersion, .CAGEMaxHours:
            return .disclosure
            
        case .loopShareType:
            return .disclosure
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .loopDelay, .allowStandByHighContrast, .forceStandByBigNumbers, .storeFrequentReadingsInNightscout, .storeFrequentReadingsInHealthKit, .translateOnlineHelp, .loopShareSmoothedData, .loopShareMedtrumNano:
            return nil

        case .loopShareType:
            return UserDefaults.standard.canConfigureOSAidSharing ? UserDefaults.standard.loopShareType.description : Texts_Common.disabled
            
        case .libreLinkUpVersion:
            return UserDefaults.standard.libreLinkUpVersion

        case .careLinkVersion:
            return UserDefaults.standard.careLinkVersion
            
        case .CAGEMaxHours:
            return "\(UserDefaults.standard.CAGEMaxHours.description) \(Texts_Common.hours)"
        }
        
    }

    func rowIndicator(index: Int) -> SettingsIndicator? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .loopShareMedtrumNano:
            return SettingsIndicator(
                color: ConstantsUI.warningBannerIndicatorColor,
                symbolName: "exclamationmark.triangle.fill",
                accessibilityLabel: Texts_SettingsView.loopShareMedtrumNanoTitle
            )

        case .loopShareSmoothedData:
            return SettingsIndicator(
                color: ConstantsUI.warningBannerIndicatorColor,
                symbolName: "exclamationmark.triangle.fill",
                accessibilityLabel: Texts_SettingsView.loopShareSmoothedDataEnabledTitle
            )

        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .loopShareType, .loopDelay, .libreLinkUpVersion, .careLinkVersion, .CAGEMaxHours, .allowStandByHighContrast, .forceStandByBigNumbers, .storeFrequentReadingsInNightscout, .storeFrequentReadingsInHealthKit, .translateOnlineHelp:
            return nil
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .showDeveloperSettings:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showDeveloperSettings },
                setIsOn: { [weak self] isOn in
                    UserDefaults.standard.showDeveloperSettings = isOn

                    // this is a bit messy, but seems to be the best way to reset the setting to false
                    // this will usually happen when the view is not on screen anyway
                    if isOn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                            UserDefaults.standard.showDeveloperSettings = false
                            self?.sectionReloadClosure?()
                        }
                    }
                }
            )
        case .NSLogEnabled:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.NSLogEnabled },
                setIsOn: { UserDefaults.standard.NSLogEnabled = $0 }
            )
        case .OSLogEnabled:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.OSLogEnabled },
                setIsOn: { UserDefaults.standard.OSLogEnabled = $0 }
            )
        case .suppressUnLockPayLoad:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.suppressUnLockPayLoad },
                setIsOn: { UserDefaults.standard.suppressUnLockPayLoad = $0 }
            )
        case .allowStandByHighContrast:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.allowStandByHighContrast },
                setIsOn: { UserDefaults.standard.allowStandByHighContrast = $0 }
            )
        case .forceStandByBigNumbers:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.forceStandByBigNumbers },
                setIsOn: { UserDefaults.standard.forceStandByBigNumbers = $0 }
            )
        case .storeFrequentReadingsInNightscout:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.storeFrequentReadingsInNightscout },
                setIsOn: { UserDefaults.standard.storeFrequentReadingsInNightscout = $0 }
            )
        case .storeFrequentReadingsInHealthKit:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.storeFrequentReadingsInHealthKit },
                setIsOn: { UserDefaults.standard.storeFrequentReadingsInHealthKit = $0 }
            )
        case .translateOnlineHelp:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.translateOnlineHelp },
                setIsOn: { UserDefaults.standard.translateOnlineHelp = $0 }
            )
        case .loopShareSmoothedData:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.loopShareSmoothedData },
                setIsOn: { UserDefaults.standard.loopShareSmoothedData = $0 },
                confirmation: { isOn in
                    guard isOn else { return nil }

                    return SettingsToggleConfirmationContent(
                        title: Texts_Common.warning,
                        message: Texts_SettingsView.loopShareSmoothedDataWarning,
                        actionTitle: Texts_SettingsView.loopShareSmoothedDataConfirm,
                        cancelTitle: Texts_Common.Cancel
                    )
                }
            )
        case .loopShareMedtrumNano:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.loopShareMedtrumNano },
                setIsOn: { isOn in
                    UserDefaults.standard.loopShareMedtrumNano = isOn
                    if isOn {
                        UserDefaults.standard.loopShareSmoothedData = false
                    }
                },
                confirmation: { isOn in
                    guard isOn else { return nil }

                    return SettingsToggleConfirmationContent(
                        title: Texts_Common.warning,
                        message: Texts_SettingsView.loopShareMedtrumNanoWarning,
                        actionTitle: Texts_SettingsView.loopShareMedtrumNanoConfirm,
                        cancelTitle: Texts_Common.Cancel
                    )
                }
            )
        case .loopShareType, .loopDelay, .libreLinkUpVersion, .careLinkVersion, .CAGEMaxHours:
            return nil
        }
    }
    

    func numberOfRows() -> Int {
        return  UserDefaults.standard.showDeveloperSettings ? Setting.allCases.count : 1
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .allowStandByHighContrast, .forceStandByBigNumbers, .translateOnlineHelp, .loopShareSmoothedData, .loopShareMedtrumNano:
            return .nothing
            
        case .loopShareType:
            // data to be displayed in list from which user needs to pick a loop share type
            var data = [String]()
            
            var selectedRow: Int?
            
            var index = 0
            
            let currentLoopShareType = UserDefaults.standard.loopShareType
            
            // get all loop share types and add the description to data. Search for the type that matches the LoopShareType that is currently stored in userdefaults.
            for loopShareType in LoopShareType.allCases {
                
                data.append(loopShareType.description)
                
                if loopShareType == currentLoopShareType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.loopShare, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    
                    UserDefaults.standard.loopShareType = LoopShareType(rawValue: index) ?? .disabled
                    
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .loopDelay:
            return .performSegue(withIdentifier: SettingsSegueIdentifier.settingsToLoopDelaySchedule.rawValue, sender: self)
            
        case .libreLinkUpVersion:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.libreLinkUpVersion, message:  Texts_SettingsView.libreLinkUpVersionMessage, keyboardType: .default, text: UserDefaults.standard.libreLinkUpVersion, placeHolder: nil, fieldTitle: Texts_Common.enterValue, actionTitle: nil, cancelTitle: nil, actionHandler: {(libreLinkUpVersion: String) in
                
                self.storeFollowerVersion(
                    libreLinkUpVersion,
                    previousVersion: UserDefaults.standard.libreLinkUpVersion,
                    source: .libreLinkUp
                ) { UserDefaults.standard.libreLinkUpVersion = $0 }
                
            }, cancelHandler: nil, inputValidator: self.followerVersionValidationMessage)

        case .careLinkVersion:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.careLinkVersion, message: Texts_SettingsView.careLinkVersionMessage(defaultVersion: ConstantsCareLink.carePartnerAppVersionDefault), keyboardType: .default, text: UserDefaults.standard.careLinkVersion, placeHolder: nil, fieldTitle: Texts_Common.enterValue, actionTitle: nil, cancelTitle: nil, actionHandler: {(careLinkVersion: String) in

                self.storeFollowerVersion(
                    careLinkVersion,
                    previousVersion: UserDefaults.standard.careLinkVersion,
                    source: .careLink
                ) { UserDefaults.standard.careLinkVersion = $0 }

            }, cancelHandler: nil, inputValidator: self.followerVersionValidationMessage)
            
        case .CAGEMaxHours:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.CAGEMaxHours, message:  Texts_SettingsView.CAGEMaxHoursMessage, keyboardType: .numberPad, text: UserDefaults.standard.CAGEMaxHours.description, placeHolder: "0", fieldTitle: Texts_Common.enterValue, unitText: Texts_Common.hours, actionTitle: nil, cancelTitle: nil, actionHandler: {(CAGEMaxHoursString: String) in
                
                // check that the user entered a plausible value although set it to the default if zero is entered
                if let CAGEMaxHours = Int(CAGEMaxHoursString) {
                    if CAGEMaxHours == 0 {
                        UserDefaults.standard.CAGEMaxHours = ConstantsHomeView.CAGEDefaultMaxHours
                    } else if CAGEMaxHours > 0 && CAGEMaxHours < 300 {
                        UserDefaults.standard.CAGEMaxHours = CAGEMaxHours
                    }
                }
            }, cancelHandler: nil, inputValidator: nil)

        case .storeFrequentReadingsInHealthKit:
            // unfortunately this won't do anything when the use enables the option, but
            // it will show if the tap the row itself. Not perfect, but better than nothing.
            return .showInfoText(title: Texts_SettingsView.labelStoreFrequentReadingsInHealthKit, message: "\n" + Texts_SettingsView.labelStoreFrequentReadingsInHealthKitMessage)
            
        case .storeFrequentReadingsInNightscout:
            // unfortunately this won't do anything when the use enables the option, but
            // it will show if the tap the row itself. Not perfect, but better than nothing.
            return .showInfoText(title: Texts_SettingsView.labelStoreFrequentReadingsInNightscout, message: "\n" + Texts_SettingsView.labelStoreFrequentReadingsInNightscoutKitMessage)
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        if setting == .loopShareType {
            return UserDefaults.standard.canConfigureOSAidSharing
        }

        return true
    }

    private func loopShareWarningBanners() -> [SettingsRow] {
        var rows = [SettingsRow]()

        if UserDefaults.standard.loopShareMedtrumNanoAvailable {
            rows.append(SettingsRow(
                id: "developer.loopShareMedtrumNanoWarning",
                title: Texts_SettingsView.loopShareMedtrumNanoTitle,
                control: .warningBanner(
                    message: UserDefaults.standard.loopShareMedtrumNano ? Texts_SettingsView.loopShareMedtrumNanoEnabledMessage : Texts_SettingsView.loopShareMedtrumNanoBlockedMessage,
                    severity: UserDefaults.standard.loopShareMedtrumNano ? .caution : .normal
                )
            ))
        }

        guard showLoopShareSmoothedDataRow else { return rows }

        if UserDefaults.standard.loopShareSmoothedData {
            rows.append(SettingsRow(
                id: "developer.loopShareSmoothedDataEnabledWarning",
                title: Texts_SettingsView.loopShareSmoothedDataEnabledTitle,
                control: .warningBanner(message: Texts_SettingsView.loopShareSmoothedDataEnabledMessage, severity: .caution)
            ))

            return rows
        }

        rows.append(SettingsRow(
            id: "developer.loopShareSmoothedDataDifferenceWarning",
            title: Texts_SettingsView.loopShareSmoothedDataDifferenceTitle,
            control: .warningBanner(message: Texts_SettingsView.loopShareSmoothedDataDifferenceMessage, severity: .normal)
        ))

        return rows
    }

    private var showLoopShareSmoothedDataRow: Bool {
        return UserDefaults.standard.canPublishOSAidData
            && UserDefaults.standard.enableSmoothing
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        if rowGroup == .osAidLoopShare && (index == Setting.loopShareType.rawValue || index == Setting.loopShareSmoothedData.rawValue || index == Setting.loopShareMedtrumNano.rawValue) {
            return true
        }

        return false
    }
    
    /// Applies the same version rule to LibreLinkUp and CareLink before either value is stored.
    func checkFollowerVersionFormat(for text: String) -> Bool {
        ConstantsFollower.isValidAppVersion(text)
    }

    /// Returning nil is the shared text editor's valid state. The same closure both disables OK
    /// while invalid and protects the commit path if the editor is submitted programmatically.
    private func followerVersionValidationMessage(_ text: String) -> String? {
        checkFollowerVersionFormat(for: text) ? nil : Texts_SettingsView.followerVersionFormatMessage
    }

    /// Stores and records only a genuine, validated user transition. The structured event feeds
    /// the Activity Log while the same trace call remains available in developer diagnostics.
    private func storeFollowerVersion(
        _ version: String,
        previousVersion: String?,
        source: TroubleshootingLogSource,
        store: (String) -> Void
    ) {
        guard checkFollowerVersionFormat(for: version), previousVersion != version else { return }
        let previousVersion = previousVersion ?? "nil"
        store(version)
        trace(
            "%{public}@ versions changed by user from %{public}@ to %{public}@",
            log: log,
            category: ConstantsLog.categorySettingsViewDevelopmentSettingsViewModel,
            type: .info,
            troubleshooting: .standard(.configuration(.followerVersionChanged(source: source, previousVersion: previousVersion, newVersion: version))),
            source.name,
            previousVersion,
            version
        )
    }
}
