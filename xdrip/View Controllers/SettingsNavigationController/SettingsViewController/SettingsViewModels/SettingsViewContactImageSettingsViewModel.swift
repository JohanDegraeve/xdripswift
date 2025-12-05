import Foundation
import Contacts
import UIKit
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// enable contact image yes or no
    case enableContactImage = 0
    
    /// should trend be displayed yes or no
    case displayTrend = 1
    
    /// should a black/white contact image be used? yes or no
    case useHighContrastContactImage = 2
    
}

class SettingsViewContactImageSettingsViewModel: SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel)
    
    /// used for requesting authorization to access contacts
    let contactStore = CNContactStore()
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.contactImageSettingsIcon + " " + Texts_SettingsView.contactImageSectionTitle
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
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactImage:
            // check if in follower with keep-alive disabled. If so, disable this option
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
                return .detailButton
            }
            
            // if access to Contacts was previously denied by user, then show disclosure indicator, clicking the row will give info how user should authorize access
            // also if access is restricted
            
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .denied:
                // by clicking row, show info how to authorized
                return .disclosureIndicator
                
            case .notDetermined:
                return .none
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return .disclosureIndicator
                
            case .authorized:
                return .none
                
            default:
                trace("unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                return .none
                
            }
            
        case .displayTrend, .useHighContrastContactImage:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enableContactImage:
            // check if in follower with keep-alive disabled. If so, disable this option
            return (UserDefaults.standard.enableContactImage && !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled) ? "⚠️ No keep-alive" : nil
        case .displayTrend, .useHighContrastContactImage:
            return nil
        }
    }

    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .enableContactImage:
            
            // if authorizationStatus is denied or restricted, then don't show the uiswitch
            let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            if authorizationStatus == .denied || authorizationStatus == .restricted {return nil}
            
            return UISwitch(isOn: UserDefaults.standard.enableContactImage, action: {
                (isOn: Bool) in
                trace("enableContactImage changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)
                
                // if setting to false, then no need to check authorization status
                if !isOn {
                    UserDefaults.standard.enableContactImage = false
                    return
                }
                
                let status = CNContactStore.authorizationStatus(for: .contacts)
                
                // check authorization status
                switch status {
                    
                case .notDetermined:
                    self.contactStore.requestAccess(for: .contacts) { (granted, error) in
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
                    trace("CNContactStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                    UserDefaults.standard.enableContactImage = false
                    
                case .denied:
                    trace("CNContactStore access denied by user", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                    UserDefaults.standard.enableContactImage = false
                    
                case .authorized:
                    trace("CNContactStore access authorized", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                    UserDefaults.standard.enableContactImage = true
                    
                default:
                    trace("unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                    
                }
                
            })
            
        case .displayTrend:
            return UISwitch(isOn: UserDefaults.standard.displayTrendInContactImage, action: {(isOn:Bool) in
                trace("displayTrend changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)
                UserDefaults.standard.displayTrendInContactImage = isOn})
            
        case .useHighContrastContactImage:
            return UISwitch(isOn: UserDefaults.standard.useHighContrastContactImage, action: {(isOn:Bool) in
                trace("useHighContrastContactImage changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .info, isOn.description)
                UserDefaults.standard.useHighContrastContactImage = isOn})
            
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
            
            return Setting.allCases.count
            
        } else {
            
            return 1
            
        }
        
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactImage, .displayTrend, .useHighContrastContactImage:
            
            // depending on status of authorization, we will either do nothing or show a message
            switch CNContactStore.authorizationStatus(for: .contacts) {
                
            case .denied:
                // by clicking row, show info how to authorized
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsAccessDeniedByUser)
                
            case .notDetermined, .authorized:
                // if notDetermined or authorized, the uiview is shown, and app should only react on clicking the uiview, not the row
                break
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoContactsAccessRestricted)
                
            default:
                trace("unknown case returned when authorizing CNContactStore ", log: self.log, category: ConstantsLog.categorySettingsViewContactImageSettingsViewModel, type: .error)
                
            }
            
            return SettingsSelectedRowAction.nothing
        }
        
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
}
