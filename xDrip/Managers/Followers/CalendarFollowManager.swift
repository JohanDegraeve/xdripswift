//
//  CalendarFollowManager.swift
//  xdrip
//
//  Created by Paul Plant on 19/07/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import AudioToolbox
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
    
    /// AVAudioPlayer to use for suspension prevention
    private var audioPlayer: AVAudioPlayer?
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground
    private let applicationManagerKeyResumePlaySoundTimer = "CalendarFollowManager-ResumePlaySoundTimer"
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground
    private let applicationManagerKeySuspendPlaySoundTimer = "CalendarFollowManager-SuspendPlaySoundTimer"
    
    /// closure to call when downloadtimer needs to be invalidated, eg when changing from master to follower
    private var invalidateDownLoadTimerClosure: (() -> Void)?
    
    /// timer for playsound
    private var playSoundTimer: RepeatingTimer?
    
    // MARK: - Initializer
    
    init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
        }
        
        super.init()
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.calendarFollowCalendarId.rawValue, options: .new, context: nil)
        
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
        
        trace("in download", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
        
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
            trace("    calendar access is not authorized", log: log, category: ConstantsLog.categoryCalendarManager, type: .error)
            scheduleNewDownload()
            return
        }
        
        guard let calendar = getCalendar() else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.notConfigured.rawValue
            trace("    no Calendar Follow calendar selected", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            scheduleNewDownload()
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSinceNow: -24 * 3600), end: Date(timeIntervalSinceNow: 30 * 60), calendars: [calendar])
        let payloads = eventStore.events(matching: predicate).compactMap { CalendarSharePayload.decode(from: $0.notes) }.sorted { $0.timestampMillis > $1.timestampMillis }
        
        guard let latestPayload = payloads.first else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.noData.rawValue
            trace("    no Calendar Share payload found", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            scheduleNewDownload()
            return
        }
        
        guard abs(latestPayload.followerBgReading.timeStamp.timeIntervalSinceNow) < 7 * 60 else {
            UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.stale.rawValue
            trace("    latest Calendar Share payload is stale", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            scheduleNewDownload()
            return
        }
        
        if !latestPayload.sourceAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.followerPatientName = latestPayload.sourceAlias
        }
        
        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
        UserDefaults.standard.calendarFollowLastRead = Date()
        UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.active.rawValue
        
        var followGlucoseDataArray = latestPayload.followerBgReadings
        trace("    received %{public}@ Calendar Share reading(s), including history", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, followGlucoseDataArray.count.description)
        followerDelegate?.followerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)
        
        scheduleNewDownload()
    }
    
    // MARK: - Private Functions
    
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
    
    /// disable suspension prevention by removing the closures from ApplicationManager.shared
    private func disableSuspensionPrevention() {
        playSoundTimer?.suspend()
        
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer)
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer)
    }
    
    /// launches timer that will regularly play sound when the app is in the background and keep-alive is enabled
    private func enableSuspensionPrevention() {
        guard UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive else {
            trace("not enabling suspension prevention as keep-alive type is: %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .debug, UserDefaults.standard.followerBackgroundKeepAliveType.description)
            return
        }
        
        disableSuspensionPrevention()
        
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal ? ConstantsSuspensionPrevention.intervalNormal : ConstantsSuspensionPrevention.intervalAggressive
        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval)), eventHandler: { [weak self] in
            guard let self = self else { return }
            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                trace("playing audio every %{public}@ seconds. Calendar Follow keep-alive: %{public}@", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .info, interval.description, UserDefaults.standard.followerBackgroundKeepAliveType.description)
                audioPlayer.play()
            }
        })
        
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer, closure: { [weak self] in
            guard let self = self else { return }
            
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                self.playSoundTimer?.resume()
                
                if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
            }
        })
        
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer, closure: { [weak self] in
            guard let self = self else { return }
            self.playSoundTimer?.suspend()
        })
    }
    
    /// verifies values of applicable UserDefaults and either starts or stops follower mode
    private func verifyUserDefaultsAndStartOrStopFollowMode() {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .calendar && UserDefaults.standard.calendarFollowCalendarId != nil {
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                enableSuspensionPrevention()
            } else {
                disableSuspensionPrevention()
            }
            
            download()
        } else {
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .calendar {
                UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.notConfigured.rawValue
            }
            
            disableSuspensionPrevention()
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
        case .isMaster, .followerDataSourceType, .followerBackgroundKeepAliveType, .calendarFollowCalendarId:
            verifyUserDefaultsAndStartOrStopFollowMode()
            
        default:
            break
        }
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.calendarFollowCalendarId.rawValue)
        invalidateDownLoadTimerClosure?()
        playSoundTimer?.suspend()
    }
}
