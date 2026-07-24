import Foundation
import Contacts
import os

fileprivate enum Setting: Int, CaseIterable {
    /// enable contact image yes or no
    case enableContactImage = 0
    
    /// should trend be displayed yes or no
    case displayTrend = 1
    
    /// should a black/white contact image be used? yes or no
    case useHighContrastContactImage = 2
}

class SettingsViewContactImageSettingsViewModel: NSObject, SettingsViewModelProtocol {
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel)
    
    /// used for requesting authorization to access contacts
    let contactStore = CNContactStore()
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let contactImageRowsVisible = contactImageRowsVisible

        return [
            nativeSettingsRow(id: "contactImage.enableContactImage", index: Setting.enableContactImage.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "contactImage.displayTrend", index: Setting.displayTrend.rawValue, sectionID: sectionID, isVisible: contactImageRowsVisible),
            nativeSettingsRow(id: "contactImage.useHighContrastContactImage", index: Setting.useHighContrastContactImage.rawValue, sectionID: sectionID, isVisible: contactImageRowsVisible)
        ]
    }

    // MARK: - Initialization

    override init() {
        super.init()
        addObservers()
    }
    
    // MARK: - General View Model declarations/functions
    
    var sectionReloadClosure: (() -> Void)?
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    
    // this ViewModel does need to send back messages to the viewcontroller asynchronously
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {}
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.contactImageSectionTitle
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enableContactImage:
            return Texts_SettingsView.enableContactImage
            
        case .displayTrend:
            return Texts_SettingsView.displayTrendInContactImage
            
        case .useHighContrastContactImage:
            return Texts_SettingsView.useHighContrastContactImage
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let _ = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        return .none
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enableContactImage:
            // if authorizationStatus is denied or restricted, then show a warning
            let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            if #available(iOS 18.0, *) {
                if authorizationStatus == .denied || authorizationStatus == .restricted || authorizationStatus == .limited {
                    return "⚠️ "
                }
            } else {
                if authorizationStatus == .denied || authorizationStatus == .restricted {
                    return "⚠️ "
                }
            }
            
            // check if enabled and (in follower and keep-alive is not using a heartbeat)). If so, show a warning. If not, then don't show anything
            return (UserDefaults.standard.enableContactImage && !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled) ? "⚠️ " : nil
            
        case .displayTrend, .useHighContrastContactImage:
            return nil
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .enableContactImage:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.enableContactImage },
                setIsOn: { [weak self] isOn in
                    self?.setContactImageEnabled(isOn)
                }
            )
        case .displayTrend:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.displayTrendInContactImage },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("displayTrend changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.displayTrendInContactImage = isOn
                }
            )
        case .useHighContrastContactImage:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.useHighContrastContactImage },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("useHighContrastContactImage changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.useHighContrastContactImage = isOn
                }
            )
        }
    }


    private func setContactImageEnabled(_ isOn: Bool) {
        trace("enableContactImage changed by user to %{public}@", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)

        // if setting to false, then no need to check authorization status
        if !isOn {
            UserDefaults.standard.enableContactImage = false
            return
        }

        let status = CNContactStore.authorizationStatus(for: .contacts)

        // check authorization status
        switch status {
        case .notDetermined:
            contactStore.requestAccess(for: .contacts) { (granted, error) in
                DispatchQueue.main.async {
                    if !granted {
                        trace("CNContactStore access not granted", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel , type: .error)
                        UserDefaults.standard.enableContactImage = false
                    } else {
                        trace("CNContactStore access granted", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info)
                        UserDefaults.standard.enableContactImage = true
                    }
                }
            }

        case .restricted:
            trace("CNContactStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
            UserDefaults.standard.enableContactImage = false

        case .denied:
            trace("CNContactStore access denied by user", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
            UserDefaults.standard.enableContactImage = false

        case .limited:
            trace("CNContactStore access is limited by user, Full Access is required", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
            UserDefaults.standard.enableContactImage = false

        case .authorized:
            trace("CNContactStore access authorized", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
            UserDefaults.standard.enableContactImage = true

        default:
            trace("unknown case returned when authorizing EKEventStore ", log: log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
        }
    }
    
    func numberOfRows() -> Int {
        // if contact image is not enabled, then all other settings can be hidden
        if UserDefaults.standard.enableContactImage {
            // user may have removed the authorization, in that case set setting to false and return 1 row
            if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
                UserDefaults.standard.enableContactImage = false
                return 1
            }
            
            // check if in follower with keep-alive disabled. If so, hide all rows except the first one
//            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
//                return 1
//            }
            
            return Setting.allCases.count
        } else {
            return 1
        }
    }

    private var contactImageRowsVisible: Bool {
        guard UserDefaults.standard.enableContactImage else { return false }

        if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
            UserDefaults.standard.enableContactImage = false
            return false
        }

        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enableContactImage:
            if UserDefaults.standard.enableContactImage && !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
                // by clicking row, show info as to why the error happens
                return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsKeepAliveDisabled)
            }
            
            // depending on status of authorization, we will either do nothing or show a message
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .denied:
                // by clicking row, show info how to authorize
                return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsAccessDeniedByUser)
                
            case .limited:
                // by clicking row, show info how to authorize
                return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsAccessLimited)
                
            case .notDetermined, .authorized:
                // if notDetermined or authorized, the uiview is shown, and app should only react on clicking the uiview, not the row
                return .nothing
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsAccessRestricted)
                
            default:
                trace("unknown case returned when authorizing CNContactStore ", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                return .nothing
            }
            
        default:
            return .nothing
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    // MARK: - observe functions
    
    private func addObservers() {
        // Listen for changes in the contact image is enabled to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.enableContactImage.rawValue, options: .new, context: nil)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.enableContactImage:
            // run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
        }
    }
}
