//
//  CalendarFollowManager.swift
//  xdrip
//
//  Created by Paul Plant on 19/07/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import EventKit
import Foundation
import os

/// Follower manager that reads the latest BG payload from the selected shared calendar.
///
/// Calendar Share writes one current event with a machine-readable payload in the
/// notes field. Calendar Follow polls the selected shared calendar using the
/// same keep-alive structure as the other follower managers, then passes valid
/// values downstream as normal follower BG readings.
class CalendarFollowManager: NSObject {
    
    // MARK: - Private Properties
    
    /// to solve problem that sometimes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)
    
    /// reference to coredatamanager
    private let coreDataManager: CoreDataManager
    
    /// reference to BgReadingsAccessor
    private let bgReadingsAccessor: BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private weak var followerDelegate: FollowerDelegate?
    
    /// EventKit store used to read selected calendar events
    private let eventStore = EKEventStore()

    /// The root-owned shared keep-alive engine. This follower reports operational state and supplies
    /// only its existing throttled Calendar read; it does not own audio or lifecycle callbacks.
    private let backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging

    /// Allows wiring tests to reconcile real manager state without querying EventKit.
    private let startsInitialDownload: Bool
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground
    private let applicationManagerKeyDownloadWhenAppWillEnterForeground = "CalendarFollowManager-DownloadWhenAppWillEnterForeground"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    /// observer for calendar changes synced by iOS
    private var eventStoreChangedObserver: NSObjectProtocol?
    
    // MARK: - Initializer
    
    init(
        coreDataManager: CoreDataManager,
        followerDelegate: FollowerDelegate,
        backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging,
        startsInitialDownload: Bool = true
    ) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.backgroundKeepAliveManager = backgroundKeepAliveManager
        self.startsInitialDownload = startsInitialDownload
        
        super.init()
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.calendarFollowCalendarId.rawValue, options: .new, context: nil)
        
        eventStoreChangedObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            self?.eventStoreChanged()
        }
        
        verifyUserDefaultsAndStartOrStopFollowMode()
    }
    
    // MARK: - Public Functions
    
    /// creates a bgReading for a reading imported from Calendar Follow
    /// - parameters:
    ///     - followGlucoseData : glucose data from which new BgReading needs to be created
    /// - returns:
    ///     - BgReading : the new reading, not saved in the coredata
    func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        let bgReading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.sgv, deviceName: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        
        bgReading.calculatedValue = followGlucoseData.sgv
        
        let (calculatedValueSlope, hideSlope) = findSlope()
        bgReading.calculatedValueSlope = calculatedValueSlope
        bgReading.hideSlope = hideSlope
        
        return bgReading
    }
    
    /// reads the selected shared calendar and passes the latest valid Calendar Share payload to the follower delegate
    @objc func download() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.download()
            }
            return
        }
        
        trace("in download", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, troubleshooting: .detailed(.follower(source: .calendar, activity: .downloadStarted)))
        
        guard !UserDefaults.standard.isMaster else {
            trace("    not follower", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }
        
        guard UserDefaults.standard.followerDataSourceType == .calendar else {
            trace("    followerDataSourceType is not Calendar Follow", log: log, category: ConstantsLog.categoryCalendarManager, type: .debug)
            return
        }
        
        guard calendarAccessIsAuthorized else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.error.rawValue
            trace("    calendar access is not authorized", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, troubleshooting: .standard(.follower(source: .calendar, activity: .downloadFailed)))
            scheduleNewDownload()
            return
        }
        
        refreshEventStoreSources()
        
        guard let calendar = getCalendar() else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.notConfigured.rawValue
            trace("    no Calendar Follow calendar selected", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, troubleshooting: .standard(.follower(source: .calendar, activity: .downloadFailed)))
            scheduleNewDownload()
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSinceNow: -24 * 3600), end: Date(timeIntervalSinceNow: 30 * 60), calendars: [calendar])
        let payloads = eventStore.events(matching: predicate).compactMap { CalendarSharePayload.decode(from: $0.notes) }.sorted { $0.timestampMillis > $1.timestampMillis }
        
        guard let latestPayload = payloads.first else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.noData.rawValue
            trace("    no Calendar Share payload found", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, troubleshooting: .standard(.follower(source: .calendar, activity: .noReadings)))
            scheduleNewDownload()
            return
        }
        
        guard abs(latestPayload.followerBgReading.timeStamp.timeIntervalSinceNow) < 7 * 60 else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.stale.rawValue
            trace("    latest Calendar Share payload is stale", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, troubleshooting: .standard(.follower(source: .calendar, activity: .downloadFailed)))
            scheduleNewDownload()
            return
        }
        
        let sourceAlias = latestPayload.sourceAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceAlias.isEmpty, UserDefaults.standard.followerPatientName != sourceAlias {
            UserDefaults.standard.followerPatientName = sourceAlias
            // Calendar payloads may carry a patient alias. The consumer log records the state change
            // but deliberately excludes the alias, event notes and calendar identity.
            trace(
                "Calendar Share changed the patient alias",
                log: log,
                category: ConstantsLog.categoryCalendarManager,
                type: .info,
                troubleshooting: .standard(.configuration(.patientAliasChanged(isSet: true)))
            )
        }
        
        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
        UserDefaults.standard.calendarFollowLastRead = Date()
        UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.active.rawValue
        
        var followGlucoseDataArray = latestPayload.followerBgReadings
        trace("    received %{public}@ Calendar Share reading(s), including history", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, troubleshooting: .standard(.follower(source: .calendar, activity: .downloadSucceeded(readingCount: followGlucoseDataArray.count))), followGlucoseDataArray.count.description)
        followerDelegate?.followerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)
        
        scheduleNewDownload()
    }
    
    // MARK: - Private Functions
    
    /// refresh EventKit sources before querying events
    private func refreshEventStoreSources() {
        eventStore.refreshSourcesIfNecessary()
    }
    
    /// called when EventKit reports that calendar data changed
    private func eventStoreChanged() {
        guard keyValueObserverTimeKeeper.verifyKey(forKey: "CalendarFollowManager-EventStoreChanged", withMinimumDelayMilliSeconds: 1000) else { return }
        
        trace("in eventStoreChanged", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
        download()
    }
    
    /// check the shared calendar from the keep-alive wake cycle
    private func downloadFromKeepAliveTick() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  !UserDefaults.standard.isMaster,
                  UserDefaults.standard.followerDataSourceType == .calendar,
                  self.keyValueObserverTimeKeeper.verifyKey(forKey: "CalendarFollowManager-KeepAliveDownload", withMinimumDelayMilliSeconds: 14_000) else {
                return
            }
            
            trace("in downloadFromKeepAliveTick", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .info)
            self.download()
        }
    }
    
    /// check the shared calendar when the app comes to foreground
    private func downloadWhenAppWillEnterForeground() {
        guard !UserDefaults.standard.isMaster,
              UserDefaults.standard.followerDataSourceType == .calendar else {
            return
        }
        
        trace("in downloadWhenAppWillEnterForeground", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
        download()
    }
    
    /// check the shared calendar when Calendar Follow is enabled or reconfigured
    private func downloadWhenFollowModeStarts() {
        trace("in downloadWhenFollowModeStarts", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
        download()
    }
    
    private func getCalendar() -> EKCalendar? {
        guard let selectedCalendarTitle = UserDefaults.standard.calendarFollowCalendarId else { return nil }
        
        return eventStore.calendars(for: .event).first { $0.title == selectedCalendarTitle }
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
    
    /// taken from xdripplus
    ///
    /// updates bgreading
    private func findSlope() -> (calculatedValueSlope: Double, hideSlope: Bool) {
        var hideSlope = true
        var calculatedValueSlope = 0.0
        
        let last2Readings = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true)
        
        if last2Readings.count >= 2 {
            let (slope, hide) = last2Readings[0].calculateSlope(lastBgReading: last2Readings[1])
            calculatedValueSlope = slope
            hideSlope = hide
        }
        
        return (calculatedValueSlope, hideSlope)
    }
    
    /// schedule new download with timer, when timer expires download() will be called
    private func scheduleNewDownload() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        
        invalidateDownLoadTimerClosure?()
        
        trace("in scheduleNewDownload", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
        
        let downloadTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(download), userInfo: nil, repeats: false)
        invalidateDownLoadTimerClosure = {
            downloadTimer.invalidate()
        }
    }
    
    /// verifies values of applicable UserDefaults and either starts or stops follower mode
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .calendar && UserDefaults.standard.calendarFollowCalendarId != nil {
            ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyDownloadWhenAppWillEnterForeground, closure: { [weak self] in
                self?.downloadWhenAppWillEnterForeground()
            })
            
            backgroundKeepAliveManager.start(for: .sharedCalendar) { [weak self] in
                self?.downloadFromKeepAliveTick()
            }
            
            if startsInitialDownload {
                downloadWhenFollowModeStarts()
            }
        } else {
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .calendar {
                UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.notConfigured.rawValue
            }
            
            backgroundKeepAliveManager.stop(for: .sharedCalendar)
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyDownloadWhenAppWillEnterForeground)
            invalidateDownLoadTimerClosure?()
        }
    }
    
    // MARK: - Overridden Functions
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath),
              keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200) else {
            return
        }
        
        switch keyPathEnum {
        case .isMaster, .followerDataSourceType, .calendarFollowCalendarId:
            verifyUserDefaultsAndStartOrStopFollowMode()
            
        default:
            break
        }
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.calendarFollowCalendarId.rawValue)
        if let eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(eventStoreChangedObserver)
        }
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyDownloadWhenAppWillEnterForeground)
        invalidateDownLoadTimerClosure?()
        backgroundKeepAliveManager.stop(for: .sharedCalendar)
    }
}
