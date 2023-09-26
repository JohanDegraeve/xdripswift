import Foundation
import UIKit
import EventKit
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// create calendar event yes or no
    case createCalendarEvent = 0
    
    /// selected calender id (name of the calendar) in which the event should be created
    case calenderId = 1
    
    /// should trend be displayed yes or no
    case displayTrend = 2
    
    /// should delta be displayed yes or no
    case displayDelta = 3
    
    /// should units be displayed yes or no
    case displayUnits = 4
    
    /// should a visual indicator be shown on the calendar title
    case displayVisualIndicator = 5
    
    /// minimum time between two readings, for which event should be created (in minutes)
    case calendarInterval = 6

}

class SettingsViewAppleWatchSettingsViewModel: SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewAppleWatchSettingsViewModel)
    
    /// used for requesting authorization to access calendar
    let eventStore = EKEventStore()
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.calendarEventsSectionTitle
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .createCalendarEvent:
            return Texts_SettingsView.createCalendarEvent
            
        case .calenderId:
            return Texts_SettingsView.calenderId
            
        case .displayTrend:
            return Texts_SettingsView.displayTrendInCalendarEvent
            
        case .displayDelta:
            return Texts_SettingsView.displayDeltaInCalendarEvent
            
        case .displayUnits:
            return Texts_SettingsView.displayUnitInCalendarEvent
            
        case .displayVisualIndicator:
            return Texts_SettingsView.displayVisualIndicatorInCalendar
            
        case .calendarInterval:
            return Texts_SettingsView.settingsviews_CalenderIntervalTitle

        }

    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .createCalendarEvent:
            // if access to Calendar was previously denied by user, then show disclosure indicator, clicking the row will give info how user should authorize access
            // also if access is restricted
            
            switch EKEventStore.authorizationStatus(for: .event) {
            case .denied:
                // by clicking row, show info how to authorized
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            case .notDetermined:
                return UITableViewCell.AccessoryType.none
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            case .writeOnly:
                // by clicking row, show that the permission is restricted to Add Events Only instead of Full Access
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            case .authorized, .fullAccess:
                return UITableViewCell.AccessoryType.none
                
            @unknown default:
                trace("in SettingsViewAppleWatchSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                return UITableViewCell.AccessoryType.none
                
            }
            
        case .calenderId:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .displayTrend, .displayDelta, .displayUnits, .displayVisualIndicator:
            return UITableViewCell.AccessoryType.none
            
        case .calendarInterval:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }

    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .calenderId:
            return UserDefaults.standard.calenderId
            
        case .createCalendarEvent, .displayTrend, .displayDelta, .displayUnits, .displayVisualIndicator:
            return nil
            
        case .calendarInterval:
            return UserDefaults.standard.calendarInterval.description

        }
    }

    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .createCalendarEvent:
            
            // if authorizationStatus is denied or restricted, then don't show the uiswitch
            let authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if authorizationStatus == .denied || authorizationStatus == .restricted {return nil}
            
            return UISwitch(isOn: UserDefaults.standard.createCalendarEvent, action: {
                (isOn:Bool) in
                
                // if setting to false, then no need to check authorization status
                if !isOn {
                    UserDefaults.standard.createCalendarEvent = false
                    return
                }
                
                // check authorization status
                switch EKEventStore.authorizationStatus(for: .event) {
                    
                case .notDetermined:
                    if #available(iOS 17.0, *) {
                        // if iOS17 then run the new access request method
                        // https://developer.apple.com/documentation/eventkit/accessing_calendar_using_eventkit_and_eventkitui#4250785
                        self.eventStore.requestFullAccessToEvents(completion:
                                                                    {(granted: Bool, error: Error?) -> Void in
                            if !granted {
                                trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access not granted", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                                UserDefaults.standard.createCalendarEvent = false
                            } else {
                                trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access granted", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                                UserDefaults.standard.createCalendarEvent = true
                            }
                        })
                    } else {
                        // Fallback on earlier versions as .requestAccess() was deprecated in iOS17 and doesn't work anymore
                        self.eventStore.requestAccess(to: .event, completion:
                                                        {(granted: Bool, error: Error?) -> Void in
                            if !granted {
                                trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access not granted", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                                UserDefaults.standard.createCalendarEvent = false
                            } else {
                                trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access granted", log: self.log, category: ConstantsLog.categoryRootView, type: .info)
                                UserDefaults.standard.createCalendarEvent = true
                            }
                        })
                    }
                    
                case .restricted:
                    // authorize not possible, according to apple doc "possibly due to active restrictions such as parental controls being in place", no need to change value of UserDefaults.standard.createCalendarEvent
                    // we will probably never come here because if it's restricted, the uiview is not shown
                    trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.createCalendarEvent = false
                    
                case .writeOnly:
                    // Full Access permission has not been granted to the app so we won't be able to delete old BG events, no need to change value of UserDefaults.standard.createCalendarEvent
                    trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access is 'Write Only', the user must update this to 'Full Access'", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.createCalendarEvent = false

                case .denied:
                    // access denied by user, need to change value of UserDefaults.standard.createCalendarEvent
                    // we will probably never come here because if it's denied, the uiview is not shown
                    trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access denied by user", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.createCalendarEvent = false

                case .authorized, .fullAccess:
                    // authorize successful (or fullAccess is granted), no need to change value of UserDefaults.standard.createCalendarEvent
                    trace("in SettingsViewAppleWatchSettingsViewModel, EKEventStore access authorized", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    UserDefaults.standard.createCalendarEvent = true

                @unknown default:
                    trace("in SettingsViewAppleWatchSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                    
                }
                
            })
            
        case .calenderId:
            return nil
            
        case .displayTrend:
            return UISwitch(isOn: UserDefaults.standard.displayTrendInCalendarEvent, action: {(isOn:Bool) in UserDefaults.standard.displayTrendInCalendarEvent = isOn})
            
        case .displayDelta:
            return UISwitch(isOn: UserDefaults.standard.displayDeltaInCalendarEvent, action: {(isOn:Bool) in UserDefaults.standard.displayDeltaInCalendarEvent = isOn})
            
        case .displayUnits:
            return UISwitch(isOn: UserDefaults.standard.displayUnitInCalendarEvent, action: {(isOn:Bool) in UserDefaults.standard.displayUnitInCalendarEvent = isOn})
            
        case .displayVisualIndicator:
            return UISwitch(isOn: UserDefaults.standard.displayVisualIndicatorInCalendarEvent, action: {(isOn:Bool) in UserDefaults.standard.displayVisualIndicatorInCalendarEvent = isOn})
            
        case .calendarInterval:
            return nil
            
        }
        
    }
    
    func numberOfRows() -> Int {
        
        // if create calendar event not enabled, then all other settings can be hidden
        if UserDefaults.standard.createCalendarEvent {
            
            // user may have removed the authorization, in that case set setting to false and return 1 row
            if EKEventStore.authorizationStatus(for:.event) != .authorized {
                
                UserDefaults.standard.createCalendarEvent = false
                
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
            
        case .createCalendarEvent, .displayDelta, .displayTrend, .displayUnits, .displayVisualIndicator:
            
            // depending on status of authorization, we will either do nothing or show a message
            
            switch EKEventStore.authorizationStatus(for: .event) {
                
            case .denied:
                // by clicking row, show info how to authorized
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessDeniedByUser)
                
            case .notDetermined, .authorized, .fullAccess:
                // if notDetermined, fullAccess or authorized, the uiview is shown, and app should only react on clicking the uiview, not the row
                break
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessRestricted)
                
            case .writeOnly:
                // by clicking row, show how to update the permissions
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessWriteOnly)
                
            @unknown default:
                trace("in SettingsViewAppleWatchSettingsViewModel, unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categoryRootView, type: .error)
                
            }

            return SettingsSelectedRowAction.nothing
        
        case .calenderId:
            
            // data to be displayed in list from which user needs to pick a calendar
            var data = [String]()

            var selectedRow:Int?

            var index = 0
            // get all calendars, add title to data. And search for calendar that matches id currently stored in userdefaults.
            for calendar in eventStore.calendars(for: .event){
                
                if calendar.allowsContentModifications {
                    
                    data.append(calendar.title)
                    
                    if calendar.title == UserDefaults.standard.calenderId {
                        selectedRow = index
                    }
                    
                    index += 1
                    
                }
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.calenderId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.calenderId = data[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

        case .calendarInterval:
        
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_CalenderIntervalTitle, message: Texts_SettingsView.settingsviews_CalenderIntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.calendarInterval.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.calendarInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)

        }
        
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
}
