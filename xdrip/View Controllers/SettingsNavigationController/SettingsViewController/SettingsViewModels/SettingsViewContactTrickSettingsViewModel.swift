import Foundation
import Contacts
import UIKit
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// enable contact trick yes or no
    case enableContactTrick = 0
    
    /// selected contact  id
    case contactTrickContactId = 1
    
    /// should trend be displayed yes or no
    case displayTrend = 2

    /// should the range indicator be displayed yes or no
    case rangeIndicator = 3
    
}

class SettingsViewContactTrickSettingsViewModel: SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewContactTrickSettingsViewModel)
    
    /// used for requesting authorization to access contacts
    let contactStore = CNContactStore()
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.contactTrickSectionTitle
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactTrick:
            return Texts_SettingsView.enableContactTrick
            
        case .contactTrickContactId:
            return Texts_SettingsView.contactTrickContactId
            
        case .displayTrend:
            return Texts_SettingsView.displayTrendInContactTrick

        case .rangeIndicator:
            return Texts_SettingsView.rangeIndicatorInContactTrick

        }

    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactTrick:
            // if access to Contacts was previously denied by user, then show disclosure indicator, clicking the row will give info how user should authorize access
            // also if access is restricted
            
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .denied:
                // by clicking row, show info how to authorized
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            case .notDetermined:
                return UITableViewCell.AccessoryType.none
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            case .authorized:
                return UITableViewCell.AccessoryType.none
                
            @unknown default:
                trace("in SettingsViewContactTrickSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                return UITableViewCell.AccessoryType.none
                
            }
            
        case .contactTrickContactId, .displayTrend, .rangeIndicator:
            return UITableViewCell.AccessoryType.none
         
        }
    }

    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .contactTrickContactId:
            if UserDefaults.standard.contactTrickContactId != nil {
                
                let keysToFetch = [CNContactEmailAddressesKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
                do {
                    let contact = try contactStore.unifiedContact(withIdentifier: UserDefaults.standard.contactTrickContactId!, keysToFetch: keysToFetch)
                    if contact.emailAddresses.isEmpty {
                        return contact.identifier
                    }
                    return "\(contact.emailAddresses.first!.value)"
                } catch {
                    trace("in SettingsViewContactTrickSettingsViewModel, an error has been thrown while fetching the selected contact", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    return UserDefaults.standard.contactTrickContactId
                }
            }
            return nil
            
        case .enableContactTrick, .displayTrend, .rangeIndicator:
            return nil
            
        }
    }

    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .enableContactTrick:
            
            // if authorizationStatus is denied or restricted, then don't show the uiswitch
            let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            if authorizationStatus == .denied || authorizationStatus == .restricted {return nil}
            
            return UISwitch(isOn: UserDefaults.standard.enableContactTrick, action: {
                (isOn:Bool) in
                
                // if setting to false, then no need to check authorization status
                if !isOn {
                    UserDefaults.standard.enableContactTrick = false
                    return
                }
                
                let status = CNContactStore.authorizationStatus(for: .contacts)
                
                // check authorization status
                switch status {
                    
                case .notDetermined:
                    self.contactStore.requestAccess(for: .contacts) { (granted, error) in
                        DispatchQueue.main.async {
                            if !granted {
                                trace("in SettingsViewContactTrickSettingsViewModel, CNContactStore access not granted", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                                UserDefaults.standard.enableContactTrick = false
                            } else {
                                trace("in SettingsViewContactTrickSettingsViewModel, CNContactStore access granted", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                                UserDefaults.standard.enableContactTrick = true
                            }
                        }
                    }
                    
                case .restricted:
                    trace("in SettingsViewContactTrickSettingsViewModel, CNContactStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactTrick = false
                    
                case .denied:
                    trace("in SettingsViewContactTrickSettingsViewModel, CNContactStore access denied by user", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactTrick = false

                case .authorized:
                    trace("in SettingsViewContactTrickSettingsViewModel, CNContactStore access authorized", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactTrick = true
                    
                @unknown default:
                    trace("in SettingsViewContactTrickSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    
                }
                
            })
            
        case .contactTrickContactId:
            return nil
            
        case .displayTrend:
            return UISwitch(isOn: UserDefaults.standard.displayTrendInContactTrick, action: {(isOn:Bool) in UserDefaults.standard.displayTrendInContactTrick = isOn})

        case .rangeIndicator:
            return UISwitch(isOn: UserDefaults.standard.rangeIndicatorInContactTrick, action: {(isOn:Bool) in UserDefaults.standard.rangeIndicatorInContactTrick = isOn})

        }
        
    }
    
    func numberOfRows() -> Int {
        
        // if contact trick is not enabled, then all other settings can be hidden
        if UserDefaults.standard.enableContactTrick {
            
            // user may have removed the authorization, in that case set setting to false and return 1 row
            if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
                
                UserDefaults.standard.enableContactTrick = false
                
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
            
        case .enableContactTrick, .displayTrend, .rangeIndicator:
            
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
                
            @unknown default:
                trace("in SettingsViewContactTrickSettingsViewModel, unknown case returned when authorizing CNContactStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                
            }

            return SettingsSelectedRowAction.nothing
        
        case .contactTrickContactId:
            
            let keysToFetch = [CNContactEmailAddressesKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            var contacts = [CNContact]()
            var selectedRow:Int?

            var index = 0
            do {
                try contactStore.enumerateContacts(with: fetchRequest) { (contact, stop) in
                    if !contact.emailAddresses.isEmpty || !contact.givenName.isEmpty {
                        contacts.append(contact)
                        if contact.identifier == UserDefaults.standard.contactTrickContactId {
                            selectedRow = index
                        }
                        index += 1
                    }
                }
            } catch {
                trace("in SettingsViewContactTrickSettingsViewModel, an error has been thrown while fetching the contacts", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
            }
                        
            let _ = contacts.partition { c in
                let s = (c.emailAddresses.isEmpty ? c.givenName : "\(c.emailAddresses.first!.value)").lowercased()
                return !(s.contains(find: "bg") || s.contains(find: "xdrip") || s.contains(find: "glucos"))
            }
            
            let data = contacts.map { c -> String in
                c.emailAddresses.isEmpty ? c.givenName : "\(c.emailAddresses.first!.value)"
            }
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.contactTrickContactId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.contactTrickContactId = contacts[index].identifier
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

        }
        
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
}
