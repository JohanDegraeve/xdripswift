import Foundation
import Contacts
import UIKit
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// enable contact image yes or no
    case enableContactImage = 0
    
    /// selected contact  id
    case contactImageContactId = 1
    
    /// should trend be displayed yes or no
    case displayTrend = 2
    
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
        return Texts_SettingsView.contactImageSectionTitle
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactImage:
            return Texts_SettingsView.enableContactImage
            
        case .contactImageContactId:
            return Texts_SettingsView.contactImageContactId
            
        case .displayTrend:
            return Texts_SettingsView.displayTrendInContactImage

        }

    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .enableContactImage:
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
                trace("in SettingsViewContactImageSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                return UITableViewCell.AccessoryType.none
                
            }
            
        case .contactImageContactId, .displayTrend:
            return UITableViewCell.AccessoryType.none
         
        }
    }

    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .contactImageContactId:
            if UserDefaults.standard.contactImageContactId != nil {
                
                let keysToFetch = [CNContactEmailAddressesKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
                do {
                    let contact = try contactStore.unifiedContact(withIdentifier: UserDefaults.standard.contactImageContactId!, keysToFetch: keysToFetch)
                    if contact.emailAddresses.isEmpty {
                        return contact.identifier
                    }
                    return "\(contact.emailAddresses.first!.value)"
                } catch {
                    trace("in SettingsViewContactImageSettingsViewModel, an error has been thrown while fetching the selected contact", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    return UserDefaults.standard.contactImageContactId
                }
            }
            return nil
            
        case .enableContactImage, .displayTrend:
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
                (isOn:Bool) in
                
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
                                trace("in SettingsViewContactImageSettingsViewModel, CNContactStore access not granted", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                                UserDefaults.standard.enableContactImage = false
                            } else {
                                trace("in SettingsViewContactImageSettingsViewModel, CNContactStore access granted", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                                UserDefaults.standard.enableContactImage = true
                            }
                        }
                    }
                    
                case .restricted:
                    trace("in SettingsViewContactImageSettingsViewModel, CNContactStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactImage = false
                    
                case .denied:
                    trace("in SettingsViewContactImageSettingsViewModel, CNContactStore access denied by user", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactImage = false

                case .authorized:
                    trace("in SettingsViewContactImageSettingsViewModel, CNContactStore access authorized", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.enableContactImage = true
                    
                @unknown default:
                    trace("in SettingsViewContactImageSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    
                }
                
            })
            
        case .contactImageContactId:
            return nil
            
        case .displayTrend:
            return UISwitch(isOn: UserDefaults.standard.displayTrendInContactImage, action: {(isOn:Bool) in UserDefaults.standard.displayTrendInContactImage = isOn})

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
            
        case .enableContactImage, .displayTrend:
            
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
                trace("in SettingsViewContactImageSettingsViewModel, unknown case returned when authorizing CNContactStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                
            }

            return SettingsSelectedRowAction.nothing
        
        case .contactImageContactId:
            
            let keysToFetch = [CNContactEmailAddressesKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            var contacts = [CNContact]()
            var selectedRow:Int?

            var index = 0
            do {
                try contactStore.enumerateContacts(with: fetchRequest) { (contact, stop) in
                    if !contact.emailAddresses.isEmpty || !contact.givenName.isEmpty {
                        contacts.append(contact)
                        if contact.identifier == UserDefaults.standard.contactImageContactId {
                            selectedRow = index
                        }
                        index += 1
                    }
                }
            } catch {
                trace("in SettingsViewContactImageSettingsViewModel, an error has been thrown while fetching the contacts", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
            }
                        
            let _ = contacts.partition { c in
                let s = (c.emailAddresses.isEmpty ? c.givenName : "\(c.emailAddresses.first!.value)").lowercased()
                return !(s.contains(find: "bg") || s.contains(find: "xdrip") || s.contains(find: "glucos"))
            }
            
            let data = contacts.map { c -> String in
                c.emailAddresses.isEmpty ? c.givenName : "\(c.emailAddresses.first!.value)"
            }
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.contactImageContactId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.contactImageContactId = contacts[index].identifier
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
