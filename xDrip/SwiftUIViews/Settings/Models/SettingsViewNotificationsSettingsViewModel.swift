import Foundation
import OSLog
import ActivityKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// should reading be shown in notification
    case showReadingInNotification = 0
    
    /// - minimum time between two readings, for which notification should be created (in minutes)
    /// - except if there's been a disconnect, in that case this value is not taken into account
    case notificationInterval = 1
    
    /// show live activities type, if any
    case liveActivityType = 2
    
    /// show reading in app badge
    case showReadingInAppBadge = 3
    
    /// if reading is shown in app badge, should value be multiplied with 10 yes or no
    case multipleAppBadgeValueWith10 = 4
    
}

enum NotificationSettingsRowGroup {
    case notifications
    case appBadge
    case liveActivities
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewNotificationsSettingsViewModel: NSObject, SettingsViewModelProtocol, SettingsNativeSectionProvider {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel)

    private let rowGroup: NotificationSettingsRowGroup
    
    // MARK: - Native SwiftUI rows

    func settingsSectionTitle() -> String? {
        switch rowGroup {
        case .notifications:
            return Texts_SettingsView.sectionTitleNotifications
        case .appBadge, .liveActivities:
            return nil
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        switch rowGroup {
        case .notifications:
            return [
                SettingsRow(
                    id: "notifications.showReadingInNotification",
                    title: Texts_SettingsView.showReadingInNotification,
                    control: .toggle(
                        isOn: { UserDefaults.standard.showReadingInNotification },
                        setIsOn: { isOn in
                            trace("showReadingInNotification changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                            UserDefaults.standard.showReadingInNotification = isOn
                        }
                    )
                ),
                SettingsRow(
                    id: "notifications.notificationInterval",
                    title: Texts_SettingsView.settingsviews_IntervalTitle,
                    detail: notificationIntervalDetailText,
                    action: .textEntry(notificationIntervalTextEntry)
                )
            ]
        case .appBadge:
            return [
                SettingsRow(
                    id: "notifications.showReadingInAppBadge",
                    title: Texts_SettingsView.labelShowReadingInAppBadge,
                    control: .toggle(
                        isOn: { UserDefaults.standard.showReadingInAppBadge },
                        setIsOn: { isOn in
                            trace("showReadingInAppBadge changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                            UserDefaults.standard.showReadingInAppBadge = isOn
                        }
                    )
                ),
                SettingsRow(
                    id: "notifications.multipleAppBadgeValueWith10",
                    title: Texts_SettingsView.multipleAppBadgeValueWith10,
                    control: .toggle(
                        isOn: { UserDefaults.standard.multipleAppBadgeValueWith10 },
                        setIsOn: { isOn in
                            trace("multipleAppBadgeValueWith10 changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                            UserDefaults.standard.multipleAppBadgeValueWith10 = isOn
                        }
                    ),
                    isVisible: !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.showReadingInAppBadge
                )
            ]
        case .liveActivities:
            return [
                SettingsRow(
                    id: "notifications.liveActivityType",
                    title: Texts_SettingsView.labelLiveActivityType,
                    detail: UserDefaults.standard.liveActivityType.description,
                    isVisible: liveActivitiesAvailable,
                    action: .selectionList(liveActivitySelectionList)
                )
            ]
        }
    }

    // MARK: - Initialization

    init(rowGroup: NotificationSettingsRowGroup) {
        self.rowGroup = rowGroup
        super.init()
        addObservers()
    }

    override init() {
        self.rowGroup = .notifications
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
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return .nothing
            
        case .notificationInterval:
            
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_IntervalTitle, message: Texts_SettingsView.settingsviews_IntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.notificationInterval.description, placeHolder: "0", fieldTitle: Texts_Common.enterValue, unitText: Texts_Common.minutes, actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.notificationInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
            
        case .liveActivityType:
            // live activities can only be used in master mode as follower mode
            // will not allow updates whilst the app is in the background
            if UserDefaults.standard.isMaster || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                
                // data to be displayed in list from which user needs to pick a live activity type
                var data = [String]()
                
                var selectedRow: Int?
                
                var index = 0
                
                let currentLiveActivityType = UserDefaults.standard.liveActivityType
                
                // get all data source types and add the description to data. Search for the type that matches the FollowerDataSourceType that is currently stored in userdefaults.
                for liveActivityType in LiveActivityType.allCasesForList {
                    
                    data.append(liveActivityType.description)
                    
                    if liveActivityType == currentLiveActivityType {
                        selectedRow = index
                    }
                    
                    index += 1
                    
                }
                
                return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelLiveActivityType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                    
                    // we'll set this here so that we can use it in the else statement for logging
                    let oldLiveActivityType = UserDefaults.standard.liveActivityType
                    
                    if index != selectedRow {
                        
                        UserDefaults.standard.liveActivityType = LiveActivityType(forRowAt: index) ?? .disabled
                        
                        let newLiveActivityType = UserDefaults.standard.liveActivityType
                        
                        trace("Live activity type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, oldLiveActivityType.description, newLiveActivityType.description)
                        
                    }
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
            } else {
                
                return .showInfoText(title: Texts_SettingsView.labelLiveActivityType, message: Texts_SettingsView.liveActivityDisabledInFollowerModeMessage, actionHandler: {})
                
            }
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleNotifications
    }

    func numberOfRows() -> Int {
        
        // if unit is mmol and if show value in app badge is on and if showReadingInNotification is not on, then show also if to be multiplied by 10 yes or no
        // (if showReadingInNotification is on, then badge counter will be set via notification, in this case we can use NSNumber so we don't need to multiply by 10)
        if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.showReadingInAppBadge {
            return Setting.allCases.count
        } else {
            return Setting.allCases.count - 1
        }
        
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .showReadingInNotification:
            return Texts_SettingsView.showReadingInNotification
            
        case .notificationInterval:
            return Texts_SettingsView.settingsviews_IntervalTitle
            
        case .liveActivityType:
            return Texts_SettingsView.labelLiveActivityType
            
        case .showReadingInAppBadge:
            return Texts_SettingsView.labelShowReadingInAppBadge
            
        case .multipleAppBadgeValueWith10:
            return Texts_SettingsView.multipleAppBadgeValueWith10
            
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return .none
            
        case .notificationInterval:
            return .disclosure
            
        case .liveActivityType:
            return UserDefaults.standard.isMaster || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat ? .disclosure : .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return nil
            
        case .notificationInterval:
            return UserDefaults.standard.notificationInterval.description + " " + Texts_Common.minutes
            
        case .liveActivityType:
            return UserDefaults.standard.isMaster || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat ? UserDefaults.standard.liveActivityType.description : Texts_SettingsView.liveActivityDisabledInFollowerMode
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .showReadingInNotification:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showReadingInNotification },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("showReadingInNotification changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.showReadingInNotification = isOn
                }
            )
        case .showReadingInAppBadge:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showReadingInAppBadge },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("showReadingInAppBadge changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.showReadingInAppBadge = isOn
                }
            )
        case .multipleAppBadgeValueWith10:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.multipleAppBadgeValueWith10 },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("multipleAppBadgeValueWith10 changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.multipleAppBadgeValueWith10 = isOn
                }
            )
        case .notificationInterval, .liveActivityType:
            return nil
        }
    }
    

    func settingsSectionFooter() -> String? {
        rowGroup == .liveActivities && !liveActivitiesAvailable ? Texts_SettingsView.liveActivityDisabledInFollowerModeMessage : nil
    }

    private var notificationIntervalDetailText: String {
        UserDefaults.standard.notificationInterval.description + " " + Texts_Common.minutes
    }

    private var liveActivitiesAvailable: Bool {
        UserDefaults.standard.isMaster || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat
    }

    private func notificationIntervalTextEntry() -> SettingsTextEntryContent {
        SettingsTextEntryContent(
            title: Texts_SettingsView.settingsviews_IntervalTitle,
            message: Texts_SettingsView.settingsviews_IntervalMessage,
            keyboardType: .numberPad,
            text: UserDefaults.standard.notificationInterval.description,
            placeholder: "0",
            fieldTitle: Texts_Common.enterValue,
            unitText: Texts_Common.minutes,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { interval in
                if let interval = Int(interval) {
                    UserDefaults.standard.notificationInterval = Int(interval)
                    self.sectionReloadClosure?()
                }
            },
            cancel: nil,
            validator: nil
        )
    }

    private func liveActivitySelectionList() -> SettingsSelectionListContent {
        var data = [String]()
        var selectedRow: Int?
        var index = 0
        let currentLiveActivityType = UserDefaults.standard.liveActivityType

        for liveActivityType in LiveActivityType.allCasesForList {
            data.append(liveActivityType.description)

            if liveActivityType == currentLiveActivityType {
                selectedRow = index
            }

            index += 1
        }

        return SettingsSelectionListContent(
            title: Texts_SettingsView.labelLiveActivityType,
            data: data,
            selectedRow: selectedRow,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { index in
                let oldLiveActivityType = UserDefaults.standard.liveActivityType

                if index != selectedRow {
                    UserDefaults.standard.liveActivityType = LiveActivityType(forRowAt: index) ?? .disabled

                    let newLiveActivityType = UserDefaults.standard.liveActivityType

                    trace("Live activity type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel, type: .info, oldLiveActivityType.description, newLiveActivityType.description)

                    self.sectionReloadClosure?()
                }
            },
            cancel: nil,
            didSelectRow: nil
        )
    }
    
    // MARK: - observe functions
    
    private func addObservers() {
        
        // Listen for changes in the active sensor value to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.followerBackgroundKeepAliveType:
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
            
        }
    }
}
