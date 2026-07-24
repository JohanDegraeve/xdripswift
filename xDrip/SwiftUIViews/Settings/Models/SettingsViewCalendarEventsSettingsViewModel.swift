//
//  SettingsViewCalendarEventsSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 24/10/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import EventKit
import os
import SwiftUI

fileprivate enum Setting:Int, CaseIterable {
    
    /// create calendar event yes or no
    case createCalendarEvent = 0
    
    /// selected calender id (name of the calendar) in which the event should be created
    case calenderId = 1

    /// alias sent to Calendar Follow devices
    case alias = 2

    /// last Calendar Share write status
    case status = 3

    /// last Calendar Share payload value
    case lastValue = 4

    /// last Calendar Share payload timestamp
    case timestamp = 5
    
    /// should trend be displayed yes or no
    case displayTrend = 6
    
    /// should delta be displayed yes or no
    case displayDelta = 7
    
    /// should units be displayed yes or no
    case displayUnits = 8
    
    /// should a visual indicator be shown on the calendar title
    case displayVisualIndicator = 9

    /// history window included in the Calendar Share payload
    case includeHistory = 10
    
    /// minimum time between two readings, for which event should be created (in minutes)
    case calendarInterval = 11

}

enum CalendarEventsRowGroup {
    case connection
    case status
    case preview
    case settings
}

class SettingsViewCalendarEventsSettingsViewModel: SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel)
    
    /// used for requesting authorization to access calendar
    private let eventStore = EKEventStore()

    private let rowGroup: CalendarEventsRowGroup

    init(rowGroup: CalendarEventsRowGroup = .connection) {
        self.rowGroup = rowGroup
    }
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let calendarRowsVisible = calendarEventRowsVisible

        switch rowGroup {
        case .connection:
            return [
                nativeSettingsRow(id: "calendarEvents.createCalendarEvent", index: Setting.createCalendarEvent.rawValue, sectionID: sectionID, isVisible: calendarShareIsAvailable),
                nativeSettingsRow(id: "calendarEvents.calendarId", index: Setting.calenderId.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.alias", index: Setting.alias.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible)
            ]
        case .status:
            return [
                SettingsRow(
                    id: "calendarEvents.status",
                    title: settingsRowText(index: Setting.status.rawValue),
                    detail: calendarShareStatus.description,
                    detailIndicator: SettingsIndicator(color: calendarShareStatusIndicatorColor),
                    accessory: .none,
                    isVisible: calendarRowsVisible
                ),
                nativeSettingsRow(id: "calendarEvents.lastValue", index: Setting.lastValue.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.timestamp", index: Setting.timestamp.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.includeHistory", index: Setting.includeHistory.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible)
            ]
        case .preview:
            return [
                SettingsRow(
                    id: "calendarEvents.preview",
                    title: calendarEventPreviewTitle,
                    centerTitle: true,
                    accessory: .none,
                    isVisible: calendarRowsVisible
                )
            ]
        case .settings:
            return [
                nativeSettingsRow(id: "calendarEvents.displayTrend", index: Setting.displayTrend.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.displayDelta", index: Setting.displayDelta.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.displayUnits", index: Setting.displayUnits.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.displayVisualIndicator", index: Setting.displayVisualIndicator.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible),
                nativeSettingsRow(id: "calendarEvents.calendarInterval", index: Setting.calendarInterval.rawValue, sectionID: sectionID, isVisible: calendarRowsVisible)
            ]
        }
    }

    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does not need to send back messages to the viewcontroller asynchronously
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        switch rowGroup {
        case .connection:
            return nil
        case .status:
            return Texts_SettingsView.calendarShareStatus
        case .preview:
            return Texts_SettingsView.calendarEventPreview
        case .settings:
            return nil
        }
    }

    func sectionFooter() -> String? {
        switch rowGroup {
        case .connection:
            return Texts_SettingsView.calendarShareConnectionFooter
        case .status:
            return Texts_SettingsView.calendarShareStatusFooter
        case .preview:
            return nil
        case .settings:
            return Texts_SettingsView.calendarEventSettingsFooter
        }
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .createCalendarEvent:
            return "Enable"
            
        case .calenderId:
            return Texts_SettingsView.calenderId

        case .alias:
            return Texts_SettingsView.calendarShareAlias

        case .status:
            return Texts_SettingsView.calendarShareStatus

        case .lastValue:
            return Texts_SettingsView.calendarShareLastValue

        case .timestamp:
            return Texts_BgReadings.timestamp
            
        case .displayTrend:
            return Texts_SettingsView.displayTrendInCalendarEvent
            
        case .displayDelta:
            return Texts_SettingsView.displayDeltaInCalendarEvent
            
        case .displayUnits:
            return Texts_SettingsView.displayUnitInCalendarEvent
            
        case .displayVisualIndicator:
            return Texts_SettingsView.displayVisualIndicatorInCalendar

        case .includeHistory:
            return Texts_SettingsView.calendarShareIncludeHistory
            
        case .calendarInterval:
            return Texts_SettingsView.settingsviews_CalenderIntervalTitle

        }

    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .createCalendarEvent:
            // if access to Calendar was previously denied by user, then show disclosure indicator, clicking the row will give info how user should authorize access
            // also if access is restricted
            
            switch EKEventStore.authorizationStatus(for: .event) {
            case .denied:
                // by clicking row, show info how to authorized
                return SettingsAccessory.disclosure
                
            case .notDetermined:
                return SettingsAccessory.none
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return SettingsAccessory.disclosure
                
            case .authorized:
                return SettingsAccessory.none
                
#if swift(>=5.9)
            case .writeOnly:
                // by clicking row, show that the permission is restricted to Add Events Only instead of Full Access
                return SettingsAccessory.disclosure
                
            case .fullAccess:
                return SettingsAccessory.none
#endif
                
            @unknown default:
                trace("unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
                return SettingsAccessory.none
                
            }
            
        case .calenderId, .alias:
            return SettingsAccessory.disclosure
            
        case .displayTrend, .displayDelta, .displayUnits, .displayVisualIndicator, .status, .lastValue, .timestamp:
            return SettingsAccessory.none
            
        case .includeHistory, .calendarInterval:
            return SettingsAccessory.disclosure
            
        }
    }

    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .calenderId:
            return UserDefaults.standard.calenderId

        case .alias:
            return UserDefaults.standard.calendarShareAlias

        case .status:
            return calendarShareStatus.description

        case .lastValue:
            return lastPayloadValueDetail

        case .timestamp:
            return lastPayloadTimeDetail
            
        case .createCalendarEvent, .displayTrend, .displayDelta, .displayUnits, .displayVisualIndicator:
            return nil
            
        case .includeHistory:
            return UserDefaults.standard.calendarShareHistoryInMinutes.description + " " + Texts_Common.minutes

        case .calendarInterval:
            return UserDefaults.standard.calendarInterval.description + " " + Texts_Common.minutes

        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .createCalendarEvent:
            let authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if authorizationStatus == .denied || authorizationStatus == .restricted { return nil }

            return SettingsToggleControl(
                isOn: { UserDefaults.standard.createCalendarEvent },
                setIsOn: { [weak self] isOn in
                    self?.setCreateCalendarEvent(isOn)
                }
            )
        case .displayTrend:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.displayTrendInCalendarEvent },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("displayTrend changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.displayTrendInCalendarEvent = isOn
                }
            )
        case .displayDelta:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.displayDeltaInCalendarEvent },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("displayDelta changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.displayDeltaInCalendarEvent = isOn
                }
            )
        case .displayUnits:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.displayUnitInCalendarEvent },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("displayUnits changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.displayUnitInCalendarEvent = isOn
                }
            )
        case .displayVisualIndicator:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.displayVisualIndicatorInCalendarEvent },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("displayVisualIndicator changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.displayVisualIndicatorInCalendarEvent = isOn
                }
            )
        case .calenderId, .alias, .status, .lastValue, .timestamp, .includeHistory, .calendarInterval:
            return nil
        }
    }

    private var calendarShareStatus: CalendarShareStatus {
        if !UserDefaults.standard.createCalendarEvent || UserDefaults.standard.calenderId == nil {
            return .notConfigured
        }

        return CalendarShareStatus(rawValue: UserDefaults.standard.calendarShareStatus) ?? .notConfigured
    }

    private var calendarShareStatusIndicatorColor: Color {
        switch calendarShareStatus {
        case .active:
            return .green
        case .waiting:
            return .yellow
        case .noData:
            return .gray
        case .stale:
            return .orange
        case .error:
            return .red
        case .notConfigured:
            return .gray
        }
    }


    private func setCreateCalendarEvent(_ isOn: Bool) {
        trace("createCalendarEvent changed by user to %{public}@", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info, isOn.description)

        guard calendarShareIsAvailable else {
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            return
        }

        // if setting to false, then no need to check authorization status
        if !isOn {
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            return
        }

        // check authorization status
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
#if swift(>=5.9)
            // the user is building with Xcode 15 so may be building to >=iOS17 (with the new EventKit calendar access methods), or to <=iOS16 or earlier so we must use the old methods
            if #available(iOS 17.0, *) {
                // if >=iOS17 then run the new access request method
                // https://developer.apple.com/documentation/eventkit/accessing_calendar_using_eventkit_and_eventkitui#4250785
                eventStore.requestFullAccessToEvents(completion: { (granted: Bool, error: Error?) -> Void in
                    if !granted {
                        trace("EKEventStore access not granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
                        UserDefaults.standard.createCalendarEvent = false
                        UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
                    } else {
                        trace("EKEventStore access granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info)
                        UserDefaults.standard.createCalendarEvent = true
                        UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
                    }
                })
            } else {
                // Fallback on earlier versions as .requestAccess() was deprecated in iOS17 and doesn't work anymore. We can still use it with <=iOS16
                eventStore.requestAccess(to: .event, completion: { (granted: Bool, error: Error?) -> Void in
                    if !granted {
                        trace("EKEventStore access not granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
                        UserDefaults.standard.createCalendarEvent = false
                        UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
                    } else {
                        trace("EKEventStore access granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info)
                        UserDefaults.standard.createCalendarEvent = true
                        UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
                    }
                })
            }
#else
            // so here we are still using <= Xcode14 or earlier so we can assume the user is also using <= iOS16 and must use the old methods
            eventStore.requestAccess(to: .event, completion: { (granted: Bool, error: Error?) -> Void in
                if !granted {
                    trace("EKEventStore access not granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
                    UserDefaults.standard.createCalendarEvent = false
                    UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
                } else {
                    trace("EKEventStore access granted", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .info)
                    UserDefaults.standard.createCalendarEvent = true
                    UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
                }
            })
#endif

        case .restricted:
            // authorize not possible, according to apple doc "possibly due to active restrictions such as parental controls being in place", no need to change value of UserDefaults.standard.createCalendarEvent
            // we will probably never come here because if it's restricted, the uiview is not shown
            trace("EKEventStore access restricted, according to apple doc 'possibly due to active restrictions such as parental controls being in place'", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue

#if swift(>=5.9)
        case .writeOnly:
            // Full Access permission has not been granted to the app so we won't be able to delete old BG events, no need to change value of UserDefaults.standard.createCalendarEvent
            trace("EKEventStore access is 'Write Only', the user must update this to 'Full Access'", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue

        case .fullAccess:
            // fullAccess is granted, no need to change value of UserDefaults.standard.createCalendarEvent
            trace("EKEventStore access authorized", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
            UserDefaults.standard.createCalendarEvent = true
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
#endif

        case .denied:
            // access denied by user, need to change value of UserDefaults.standard.createCalendarEvent
            // we will probably never come here because if it's denied, the uiview is not shown
            trace("EKEventStore access denied by user", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue

        case .authorized:
            // authorize successful, no need to change value of UserDefaults.standard.createCalendarEvent
            trace("EKEventStore access authorized", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
            UserDefaults.standard.createCalendarEvent = true
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue

        @unknown default:
            trace("unknown case returned when authorizing EKEventStore ", log: log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
        }
    }
    
    func numberOfRows() -> Int {
        guard calendarShareIsAvailable else {
            if UserDefaults.standard.createCalendarEvent {
                UserDefaults.standard.createCalendarEvent = false
                UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            }
            return 0
        }

        switch rowGroup {
        case .connection:
            return UserDefaults.standard.createCalendarEvent ? 3 : 1
        case .status:
            return UserDefaults.standard.createCalendarEvent && calendarAccessIsAuthorized ? 4 : 0
        case .preview:
            return UserDefaults.standard.createCalendarEvent && calendarAccessIsAuthorized ? 1 : 0
        case .settings:
            return UserDefaults.standard.createCalendarEvent && calendarAccessIsAuthorized ? 5 : 0
        }
    }

    private var calendarEventRowsVisible: Bool {
        guard calendarShareIsAvailable else { return false }
        guard UserDefaults.standard.createCalendarEvent else { return false }

        if !calendarAccessIsAuthorized {
            UserDefaults.standard.createCalendarEvent = false
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
            return false
        }

        return true
    }

    private var calendarShareIsAvailable: Bool {
        UserDefaults.standard.isMaster || UserDefaults.standard.followerDataSourceType != .calendar
    }

    private var calendarEventPreviewTitle: String {
        CalendarShareEventTitleFormatter.previewTitle()
    }

    private var lastPayloadTimeDetail: String? {
        guard let payload = latestPayload else {
            return "-"
        }

        return payload.followerBgReading.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
    }

    private var lastPayloadValueDetail: String? {
        guard let payload = latestPayload else {
            return "-"
        }

        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        return payload.bgMgDl.mgDlToMmolAndToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private var latestPayload: CalendarSharePayload? {
        guard calendarAccessIsAuthorized,
              let selectedCalendarTitle = UserDefaults.standard.calenderId,
              let calendar = eventStore.calendars(for: .event).first(where: { $0.title == selectedCalendarTitle }) else {
            return nil
        }

        let predicate = eventStore.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24 * 3600),
            end: Date(timeIntervalSinceNow: 30 * 60),
            calendars: [calendar]
        )

        return eventStore.events(matching: predicate)
            .compactMap { CalendarSharePayload.decode(from: $0.notes) }
            .sorted { $0.timestampMillis > $1.timestampMillis }
            .first
    }

    private var calendarAccessIsAuthorized: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            return true
#if swift(>=5.9)
        case .fullAccess:
            return true
#endif
        default:
            return false
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
                
            case .notDetermined, .authorized:
                // if notDetermined or authorized, the uiview is shown, and app should only react on clicking the uiview, not the row
                break
                
            case .restricted:
                // by clicking row, show what it means to be restricted, according to Apple doc
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessRestricted)
                
#if swift(>=5.9)
            case .writeOnly:
                // by clicking row, show how to update the permissions
                return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessWriteOnly)
                
            case .fullAccess:
                // if fullAccess, the uiview is shown, and app should only react on clicking the uiview, not the row
                break
#endif
                
            @unknown default:
                trace("unknown case returned when authorizing EKEventStore ", log: self.log, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel, type: .error)
                
            }

            return SettingsSelectedRowAction.nothing

        case .status, .lastValue, .timestamp:
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
                    UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

        case .alias:
            return .askText(title: Texts_SettingsView.calendarShareAlias, message: Texts_SettingsView.calendarShareAliasMessage, keyboardType: .default, text: UserDefaults.standard.calendarShareAlias, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { alias in
                let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedAlias.isEmpty {
                    UserDefaults.standard.calendarShareAlias = trimmedAlias
                    UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
                }
            }, cancelHandler: nil, inputValidator: nil)

        case .includeHistory:
            let options = [0, 30, 60, 120, 240]
            let data = options.map { $0.description + " " + Texts_Common.minutes }
            let selectedRow = options.firstIndex(of: UserDefaults.standard.calendarShareHistoryInMinutes)

            return .selectFromList(title: Texts_SettingsView.calendarShareIncludeHistory, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: { index in
                guard index >= 0, index < options.count else { return }
                UserDefaults.standard.calendarShareHistoryInMinutes = options[index]
                UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
            }, cancelHandler: nil, didSelectRowHandler: nil)

        case .calendarInterval:
        
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_CalenderIntervalTitle, message: Texts_SettingsView.settingsviews_CalenderIntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.calendarInterval.description, placeHolder: "0", fieldTitle: Texts_Common.enterValue, unitText: Texts_Common.minutes, actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.calendarInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)

        }
        
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .displayTrend, .displayDelta, .displayUnits, .displayVisualIndicator, .calendarInterval:
            return true
        case .createCalendarEvent, .calenderId, .alias, .status, .lastValue, .timestamp, .includeHistory:
            return false
        }
    }
    
}
