import Foundation
import os
import EventKit

class WatchManager: NSObject {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
    
    /// to create and delete events
    private let eventStore = EKEventStore()
    
    /// timestamp of last reading for which calendar event is created, initially set to 1 jan 1970
    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
    }
    
    // MARK: - public functions
    
    /// process new readings
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect - if nil then  1 1 1970 is used
    public func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        
        // check if createCalenderEvent is enabled in the settings and if so create calender event
        if UserDefaults.standard.createCalendarEvent  {
            createCalendarEvent(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        }
        
    }
    
    // MARK: - private functions
    
    private func createCalendarEvent(lastConnectionStatusChangeTimeStamp: Date?) {
        
        // check that access to calendar is authorized by the user
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            trace("in createCalendarEvent, createCalendarEvent is enabled but access to calendar is not authorized, setting UserDefaults.standard.createCalendarEvent to false", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return
        }
        
        // check that there is a calendar (should be)
        guard let calendar = getCalendar() else {
            trace("in createCalendarEvent, there's no calendar", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return
        }
        
        // get 2 last Readings, with a calculatedValue
        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // there should be at least one reading
        guard lastReading.count > 0 else {
            trace("in createCalendarEvent, there are no new readings to process", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return
        }
        
        // check if timeStampLastProcessedReading is at least minimiumTimeBetweenTwoReadingsInMinutes earlier than now (or it's at least minimiumTimeBetweenTwoReadingsInMinutes minutes ago that event was created for reading) - otherwise don't create event
        // exception : there's been a disconnect/reconnect after the last processed reading (if lastConnectionStatusChangeTimeStamp != nil)
        if (abs(timeStampLastProcessedReading.timeIntervalSince(Date())) < ConstantsWatch.minimiumTimeBetweenTwoReadingsInMinutes * 60.0 && (lastConnectionStatusChangeTimeStamp != nil ? lastConnectionStatusChangeTimeStamp! : Date(timeIntervalSince1970: 0)).timeIntervalSince(timeStampLastProcessedReading) < 0) {
            
            trace("in createCalendarEvent, no new calendar event will be created because it's too close to previous event", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return
            
        }

        // latest reading should be less than 5 minutes old
        guard abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            trace("in createCalendarEvent, the latest reading is older than 5 minutes", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return        }
        
        // time to delete any existing events
        deleteAllEvents(in: calendar)
        
        // compose the event title
        // start with the reading in correct unit
        var title = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).description
        
        // add trend if needed and available
        if (!lastReading[0].hideSlope && UserDefaults.standard.displayTrendInCalendarEvent) {
            title = title + " " + lastReading[0].slopeArrow()
        }
        
        // add delta if needed
        if UserDefaults.standard.displayDeltaInCalendarEvent && lastReading.count > 1 {
            
            title = title + " " + lastReading[0].unitizedDeltaString(previousBgReading: lastReading[1], showUnit: UserDefaults.standard.displayUnitInCalendarEvent, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        } else if UserDefaults.standard.displayUnitInCalendarEvent {
            
            // add unit if needed
            title = title + " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            
        }
        
        // create an event now
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = ConstantsWatch.textInCreatedEvent
        event.startDate = Date()
        event.endDate = Date(timeIntervalSinceNow: 60 * 10)
        event.calendar = calendar
        
        do{
            try eventStore.save(event, span: .thisEvent)
        } catch let error {
            trace("in createCalendarEvent, error while saving : %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
        }

    }
    
    /// - gets all calendars on the device, if one of them has a title that matches the name stored in  UserDefaults.standard.calenderId, then it returns that calendar.
    /// - else returns the default calendar and sets the value in the UserDefaults to that default value
    /// - also if currently there's no value in the UserDefaults, then value will be assigned here to UserDefaults.standard.calenderId
    /// - nil as return value should normally not happen, because there should always be at least one calendar on the device
    private func getCalendar() -> EKCalendar? {
        
        // get calendar title stored in the settings and compare to list
        if let calendarIdInUserDefaults = UserDefaults.standard.calenderId {
            
            // get all calendars, if there's one having the same title return that one
            for calendar in eventStore.calendars(for: .event) {
                
                if calendar.title == calendarIdInUserDefaults {
                    return calendar
                }
            }
            
        }
        
        // so there's no value in UserDefaults.standard.calenderId or there isn't a calendar that has a title as stored in UserDefaults.standard.calenderId
        // set now UserDefaults.standard.calenderId to default calendar and return that one
        UserDefaults.standard.calenderId = eventStore.defaultCalendarForNewEvents?.title
        
        return eventStore.defaultCalendarForNewEvents

    }
    
    // deletes all xdrip events in the calendar, for the last 24 hours
    private func deleteAllEvents(in calendar:EKCalendar) {
        
        let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSinceNow: -24*3600), end: Date(), calendars: [calendar])
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if let notes = event.notes {
                if notes.contains(find: ConstantsWatch.textInCreatedEvent) {
                    do{
                        try eventStore.remove(event, span: .thisEvent)
                    } catch let error {
                        trace("in deleteAllEvents, error while removing : %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
                    }
                }
            }
        }
    }
    
}
