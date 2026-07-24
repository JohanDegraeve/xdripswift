//
//  CalendarManager.swift
//  xdrip
//
//  Created by Paul Plant on 24/10/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import EventKit

/// One BG value stored inside the Calendar Share notes payload.
///
/// Calendar Share always writes mg/dL internally. The follower converts to the
/// user's display unit after the value has been imported.
struct CalendarSharePayloadReading: Codable {
    let timestampMillis: Int64
    let bgMgDl: Double

    init(reading: BgReading) {
        timestampMillis = Int64(reading.timeStamp.timeIntervalSince1970 * 1000.0)
        bgMgDl = reading.finalValue
    }

    var followerBgReading: FollowerBgReading {
        FollowerBgReading(timeStamp: Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0), sgv: bgMgDl)
    }
}

/// Machine-readable Calendar Share data stored in the notes field of the visible calendar event.
///
/// The top-level timestamp/bg pair is the current shared value. The optional
/// history array carries recent 5-minute readings so a follower can recover
/// short missed windows without using an external server.
struct CalendarSharePayload: Codable {
    let version: Int
    let timestampMillis: Int64
    let bgMgDl: Double
    let sourceAlias: String
    let appVersion: String?
    let buildNumber: String?
    let history: [CalendarSharePayloadReading]?

    init(reading: BgReading, historyReadings: [BgReading], sourceAlias: String) {
        version = 1
        timestampMillis = Int64(reading.timeStamp.timeIntervalSince1970 * 1000.0)
        bgMgDl = reading.finalValue
        self.sourceAlias = sourceAlias
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        history = historyReadings
            .filter { $0.timeStamp != reading.timeStamp && $0.finalValue > 0 }
            .map { CalendarSharePayloadReading(reading: $0) }
    }

    /// Current reading as expected by the shared follower pipeline.
    var followerBgReading: FollowerBgReading {
        FollowerBgReading(timeStamp: Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0), sgv: bgMgDl)
    }

    /// All readings from the payload, sorted newest first and de-duplicated by timestamp.
    var followerBgReadings: [FollowerBgReading] {
        var readings = historicalFollowerBgReadings
        readings.append(followerBgReading)

        var seenTimestamps = Set<Int64>()
        return readings
            .filter { $0.sgv > 0 }
            .sorted { $0.timeStamp > $1.timeStamp }
            .filter { reading in
                let timestampMillis = Int64(reading.timeStamp.timeIntervalSince1970 * 1000.0)
                return seenTimestamps.insert(timestampMillis).inserted
            }
    }

    /// Historical readings from the payload, sorted newest first.
    var historicalFollowerBgReadings: [FollowerBgReading] {
        (history ?? [])
            .map { $0.followerBgReading }
            .filter { $0.sgv > 0 }
            .sorted { $0.timeStamp > $1.timeStamp }
    }

    /// Encodes the payload into calendar notes.
    func encodedNotes() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return ConstantsCalendar.calendarSharePayloadPrefix + data.base64EncodedString()
    }

    /// Decodes a Calendar Share payload from event notes.
    static func decode(from notes: String?) -> CalendarSharePayload? {
        guard let notes = notes else { return nil }
        guard let range = notes.range(of: ConstantsCalendar.calendarSharePayloadPrefix) else { return nil }
        let encoded = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: encoded),
              let payload = try? JSONDecoder().decode(CalendarSharePayload.self, from: data),
              payload.version == 1,
              payload.bgMgDl > 0,
              (payload.history ?? []).allSatisfy({ $0.bgMgDl > 0 }) else {
            return nil
        }
        return payload
    }
}

/// Builds the human-visible Calendar Share event title from the current settings.
enum CalendarShareEventTitleFormatter {
    private static let previewValueMgDl = 123.0
    private static let previewDeltaMgDl = 2.0
    private static let previewTrendArrow = "↗"

    static func title(reading: BgReading, previousReading: BgReading?) -> String {
        var title = reading.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).description

        if UserDefaults.standard.displayVisualIndicatorInCalendarEvent {
            switch reading.bgRangeDescription() {
            case .inRange:
                title = ConstantsCalendar.visualIndicatorInRange + " " + title
            case .notUrgent:
                title = ConstantsCalendar.visualIndicatorNotUrgent + " " + title
            case .urgent:
                title = ConstantsCalendar.visualIndicatorUrgent + " " + title
            }
        }

        if !reading.hideSlope && UserDefaults.standard.displayTrendInCalendarEvent {
            title = title + " " + reading.slopeArrow()
        }

        if UserDefaults.standard.displayDeltaInCalendarEvent, let previousReading = previousReading {
            return title + " " + reading.unitizedDeltaString(previousBgReading: previousReading, showUnit: UserDefaults.standard.displayUnitInCalendarEvent, highGranularity: true, mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        }

        if UserDefaults.standard.displayUnitInCalendarEvent {
            return title + " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
        }

        return title
    }

    /// Deterministic settings preview using fixed sample values.
    static func previewTitle() -> String {
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        var title = previewValueMgDl.mgDlToMmolAndToString(mgDl: isMgDl)

        if UserDefaults.standard.displayVisualIndicatorInCalendarEvent {
            switch previewBgRangeDescription {
            case .inRange:
                title = ConstantsCalendar.visualIndicatorInRange + " " + title
            case .notUrgent:
                title = ConstantsCalendar.visualIndicatorNotUrgent + " " + title
            case .urgent:
                title = ConstantsCalendar.visualIndicatorUrgent + " " + title
            }
        }

        if UserDefaults.standard.displayTrendInCalendarEvent {
            title = title + " " + previewTrendArrow
        }

        if UserDefaults.standard.displayDeltaInCalendarEvent {
            return title + " " + previewDeltaString(showUnit: UserDefaults.standard.displayUnitInCalendarEvent, mgDl: isMgDl)
        }

        if UserDefaults.standard.displayUnitInCalendarEvent {
            return title + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
        }

        return title
    }

    private static var previewBgRangeDescription: BgRangeDescription {
        if previewValueMgDl <= UserDefaults.standard.urgentLowMarkValue || previewValueMgDl >= UserDefaults.standard.urgentHighMarkValue {
            return .urgent
        } else if previewValueMgDl <= UserDefaults.standard.lowMarkValue || previewValueMgDl >= UserDefaults.standard.highMarkValue {
            return .notUrgent
        } else {
            return .inRange
        }
    }

    private static func previewDeltaString(showUnit: Bool, mgDl: Bool) -> String {
        let convertedDelta = previewDeltaMgDl.mgDlToMmol(mgDl: mgDl)
        let deltaText = mgDl ? convertedDelta.mgDlToMmolAndToString(mgDl: mgDl) : convertedDelta.mmolToString()
        return "+" + deltaText + (showUnit ? (" " + (mgDl ? Texts_Common.mgdl : Texts_Common.mmol)) : "")
    }
}

class CalendarManager: NSObject {
    
    // MARK: - private properties
    
    /// CoreDataManager to use
    private let coreDataManager:CoreDataManager

    /// BgReadingsAccessor instance
    private let bgReadingsAccessor:BgReadingsAccessor

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)
    
    /// to create and delete events
    private let eventStore = EKEventStore()
    
    /// timestamp of last reading for which calendar event is created, initially set to 1 jan 1970
    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)

    /// prevents duplicate writes from closely spaced UserDefaults observer callbacks
    private let keyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)

        super.init()

        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.calendarShareAlias.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.calenderId.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.calendarShareHistoryInMinutes.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        
    }
    
    // MARK: - public functions
    
    /// process new readings
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect - if nil then  1 1 1970 is used
    public func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        guard calendarShareIsAvailable else {
            if UserDefaults.standard.createCalendarEvent {
                UserDefaults.standard.createCalendarEvent = false
                UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            }
            return
        }
        
        // check if createCalenderEvent is enabled in the settings and if so create calender event
        if UserDefaults.standard.createCalendarEvent  {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.createCalendarEvent(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
            }
        }
        
    }
    
    // MARK: - private functions
    
    private func createCalendarEvent(lastConnectionStatusChangeTimeStamp: Date?, force: Bool = false) {
        
        // check that access to calendar is authorized by the user
        guard calendarAccessIsAuthorized else {
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
            trace("in createCalendarEvent, createCalendarEvent is enabled but access to calendar is not authorized", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }
        
        // check that there is a calendar (should be)
        guard let calendar = getCalendar() else {
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            trace("in createCalendarEvent, there's no calendar", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }
        
        let candidateReadings = candidateReadingsForCalendarShare()
        
        // there should be at least one reading
        guard candidateReadings.count > 0 else {
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.waiting.rawValue
            trace("in createCalendarEvent, there are no new readings to process", log: log, category: ConstantsLog.categoryCalendarManager, type: .debug)
            return
        }

        let cadenceFilteredHistoryReadings = cadenceFilteredHistoryReadings(from: candidateReadings)
        let readingsToShare = readingsToShare(
            from: candidateReadings,
            cadenceFilteredHistoryReadings: cadenceFilteredHistoryReadings,
            lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp,
            force: force
        )

        guard let latestReadingToShare = readingsToShare.first else {
            trace("in createCalendarEvent, latest reading is too close to the last shared reading, will not create a new event", log: log, category: ConstantsLog.categoryCalendarManager, type: .debug)
            return
        }
        
        // latest reading should be less than 5 minutes old
        guard abs(latestReadingToShare.timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.stale.rawValue
            trace("in createCalendarEvent, the latest reading is older than 5 minutes", log: log, category: ConstantsLog.categoryCalendarManager, type: .debug)
            return
        }
        
        // time to delete any existing events
        deleteAllEvents(in: calendar)
        
        // create an event now
        let event = EKEvent(eventStore: eventStore)
        event.title = CalendarShareEventTitleFormatter.title(reading: latestReadingToShare, previousReading: readingsToShare.dropFirst().first)
        let alias = UserDefaults.standard.calendarShareAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let historyReadings = historyReadingsForPayload(from: cadenceFilteredHistoryReadings, latestReadingToShare: latestReadingToShare)
        let payload = CalendarSharePayload(reading: latestReadingToShare, historyReadings: historyReadings, sourceAlias: alias.isEmpty ? "Calendar Share" : alias)
        guard let notes = payload.encodedNotes() else {
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
            trace("in createCalendarEvent, failed to encode Calendar Share payload", log: log, category: ConstantsLog.categoryCalendarManager, type: .error)
            return
        }
        event.notes = notes
        event.startDate = Date()
        event.endDate = Date(timeIntervalSinceNow: 60 * 10)
        event.calendar = calendar
        
        do{
            
            try eventStore.save(event, span: .thisEvent)
            
            timeStampLastProcessedReading = latestReadingToShare.timeStamp
            UserDefaults.standard.calendarShareLastUpload = Date()
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.active.rawValue
            
        } catch let error {
            
            UserDefaults.standard.calendarShareStatus = CalendarShareStatus.error.rawValue
            trace("in createCalendarEvent, error while saving : %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
            
        }

    }

    /// Returns all possible readings for the selected Calendar Share payload window.
    private func candidateReadingsForCalendarShare() -> [BgReading] {
        // Always look back far enough to find the latest value, even when the user
        // has selected 0 minutes of history for the payload.
        let lookBackInMinutes = max(UserDefaults.standard.calendarShareHistoryInMinutes, 10)
        return bgReadingsAccessor.getLatestBgReadings(
            limit: nil,
            fromDate: Date(timeIntervalSinceNow: -TimeInterval(minutes: Double(lookBackInMinutes))),
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: false
        )
    }

    /// Applies the fixed Calendar Share cadence to the history payload.
    ///
    /// This prevents one-minute source data from being written into the calendar
    /// notes field and then imported as one-minute follower data.
    private func cadenceFilteredHistoryReadings(from readings: [BgReading]) -> [BgReading] {
        readings.filter(
            minimumTimeBetweenTwoReadingsInMinutes: ConstantsCalendar.minimumTimeBetweenTwoSharedReadingsInMinutes,
            lastConnectionStatusChangeTimeStamp: nil,
            timeStampLastProcessedBgReading: nil
        )
    }

    /// Returns the bounded history window to include in the Calendar Share payload.
    private func historyReadingsForPayload(from cadenceFilteredHistoryReadings: [BgReading], latestReadingToShare: BgReading) -> [BgReading] {
        let historyInMinutes = UserDefaults.standard.calendarShareHistoryInMinutes
        guard historyInMinutes > 0 else { return [] }

        let historyStartDate = latestReadingToShare.timeStamp.addingTimeInterval(-TimeInterval(minutes: Double(historyInMinutes)))
        return cadenceFilteredHistoryReadings.filter { $0.timeStamp >= historyStartDate && $0.timeStamp <= latestReadingToShare.timeStamp }
    }

    /// Selects the current reading to write and keeps Calendar Share on the normal app cadence.
    ///
    /// A forced rewrite is used when settings such as alias or calendar are changed. In that case
    /// we prefer the previously shared timestamp when it is still available, so editing settings
    /// does not advance the follower with a one-minute source value.
    private func readingsToShare(from candidateReadings: [BgReading], cadenceFilteredHistoryReadings: [BgReading], lastConnectionStatusChangeTimeStamp: Date?, force: Bool) -> [BgReading] {
        let timeStampLastProcessedBgReading: Date? = timeStampLastProcessedReading.timeIntervalSince1970 > 0 ? timeStampLastProcessedReading : nil

        if force {
            if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading,
               let previouslySharedReading = candidateReadings.first(where: { abs($0.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading)) < 1.0 }) {
                return [previouslySharedReading] + cadenceFilteredHistoryReadings.filter { $0.timeStamp < previouslySharedReading.timeStamp }
            }

            return cadenceFilteredHistoryReadings
        }

        let shareIntervalInMinutes = max(ConstantsCalendar.minimumTimeBetweenTwoSharedReadingsInMinutes, Double(UserDefaults.standard.calendarInterval))
        return candidateReadings.filter(
            minimumTimeBetweenTwoReadingsInMinutes: shareIntervalInMinutes,
            lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp,
            timeStampLastProcessedBgReading: timeStampLastProcessedBgReading
        )
    }

    /// - gets all calendars on the device, if one of them has a title that matches the name stored in  UserDefaults.standard.calenderId, then it returns that calendar.
    /// - else returns the default calendar and sets the value in the UserDefaults to that default value
    /// - also if currently there's no value in the UserDefaults, then value will be assigned here to UserDefaults.standard.calenderId
    /// - nil as return value should normally not happen, because there should always be at least one calendar on the device
    private func getCalendar() -> EKCalendar? {
        getCalendar(title: UserDefaults.standard.calenderId, setSelectedTitle: { UserDefaults.standard.calenderId = $0 })
    }

    private func getCalendar(title: String?, setSelectedTitle: (String?) -> Void) -> EKCalendar? {
        
        // get calendar title stored in the settings and compare to list
        if let calendarIdInUserDefaults = title {
            
            // get all calendars, if there's one having the same title return that one
            for calendar in eventStore.calendars(for: .event) {
                
                if calendar.title == calendarIdInUserDefaults {
                    return calendar
                }
            }
            
        }
        
        // so there's no value in UserDefaults.standard.calenderId or there isn't a calendar that has a title as stored in UserDefaults.standard.calenderId
        // set now UserDefaults.standard.calenderId to default calendar and return that one
        setSelectedTitle(eventStore.defaultCalendarForNewEvents?.title)
        
        return eventStore.defaultCalendarForNewEvents

    }
    
    // deletes all Calendar Share events in the calendar, for the last 24 hours
    private func deleteAllEvents(in calendar:EKCalendar) {
        deleteEvents(in: calendar, marker: ConstantsCalendar.calendarSharePayloadPrefix, endDate: Date())
    }

    private func deleteEvents(in calendar: EKCalendar, marker: String, endDate: Date) {
        
        let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSinceNow: -24*3600), end: endDate, calendars: [calendar])
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if let notes = event.notes {
                if notes.contains(find: marker) {
                    do{
                        try eventStore.remove(event, span: .thisEvent)
                    } catch let error {
                        trace("in deleteAllEvents, error while removing : %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
                    }
                }
            }
        }
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

    private var calendarShareIsAvailable: Bool {
        UserDefaults.standard.isMaster || UserDefaults.standard.followerDataSourceType != .calendar
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath),
              keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) else {
            return
        }

        switch keyPathEnum {
        case .calendarShareAlias, .calenderId, .calendarShareHistoryInMinutes:
            if UserDefaults.standard.createCalendarEvent && calendarShareIsAvailable {
                DispatchQueue.main.async { [weak self] in
                    self?.createCalendarEvent(lastConnectionStatusChangeTimeStamp: nil, force: true)
                }
            }
        case .isMaster, .followerDataSourceType:
            if UserDefaults.standard.createCalendarEvent && !calendarShareIsAvailable {
                UserDefaults.standard.createCalendarEvent = false
                UserDefaults.standard.calendarShareStatus = CalendarShareStatus.notConfigured.rawValue
            }
        default:
            break
        }
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.calendarShareAlias.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.calenderId.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.calendarShareHistoryInMinutes.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
    }
    
}
