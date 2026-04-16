//
//  WatchManager.swift
//  xdrip
//
//  Created by Paul Plant on 9/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import OSLog
import WatchConnectivity
import WidgetKit

final class WatchManager: NSObject, ObservableObject {
    // MARK: - private properties
    
    /// a watch connectivity session instance
    private var session: WCSession
    
    /// a BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// a coreDataManager instance (must be passed from RVC in the initializer)
    private var coreDataManager: CoreDataManager
    
    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager
    
    /// hold the current watch state model
    private var watchState = WatchState()
    
    /// keep track of when we last forced a complication update from within the code
    private var lastForcedComplicationUpdateTimeStamp: Date = .distantPast
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
    
    // MARK: - intializer
    
    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager, session: WCSession = .default) {
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.nightscoutSyncManager = nightscoutSyncManager
        
        self.session = session
        
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        // add observer to sync to the watch once the device status was updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue, options: .new, context: nil)
        
        processWatchState(forceComplicationUpdate: false)
    }
    
    // MARK: - overriden functions
    
    /// when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.nightscoutDeviceStatusWasUpdated:
                    // only ejecute if the key was set to true (to avoid a get-set loop)
                    // if so, process the watch state and set it back to false
                    if UserDefaults.standard.nightscoutDeviceStatusWasUpdated {
                        DispatchQueue.main.async { [weak self] in
                            self?.processWatchState(forceComplicationUpdate: false)
                        }
                        UserDefaults.standard.nightscoutDeviceStatusWasUpdated = false
                    }
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - private functions
    
    private func processWatchState(forceComplicationUpdate: Bool) {
        // create two simple arrays to send to the live activiy. One with the bg values in mg/dL and another with the corresponding timestamps
        // this is needed due to the not being able to pass structs that are not codable/hashable
        let hoursOfBgReadingsToSend: Double = 12
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        let bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: .now.addingTimeInterval(-3600 * hoursOfBgReadingsToSend), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        let slopeOrdinal: Int = !bgReadings.isEmpty ? bgReadings[0].slopeOrdinal() : 1
        
        var previousValueInUserUnit = 0.0
        var actualValueInUserUnit = 0.0
        var deltaValueInUserUnit = 0.0
        
        // add delta if available
        if bgReadings.count > 1 {
            previousValueInUserUnit = bgReadings[1].calculatedValue.mgDlToMmol(mgDl: isMgDl)
            actualValueInUserUnit = bgReadings[0].calculatedValue.mgDlToMmol(mgDl: isMgDl)
            
            // if the values are in mmol/L, then round them to the nearest decimal point in order to get the same precision out of the next operation
            if !isMgDl {
                previousValueInUserUnit = (previousValueInUserUnit * 10).rounded() / 10
                actualValueInUserUnit = (actualValueInUserUnit * 10).rounded() / 10
            }
            
            deltaValueInUserUnit = actualValueInUserUnit - previousValueInUserUnit
        }
        
        var bgReadingValues: [Double] = []
        var bgReadingDatesAsDouble: [Double] = []
        
        for bgReading in bgReadings {
            bgReadingValues.append(bgReading.calculatedValue)
            bgReadingDatesAsDouble.append(bgReading.timeStamp.timeIntervalSince1970)
        }
        
        // now process the WatchState
        watchState.bgReadingValues = bgReadingValues
        watchState.bgReadingDatesAsDouble = bgReadingDatesAsDouble
        watchState.isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        watchState.slopeOrdinal = slopeOrdinal
        watchState.deltaValueInUserUnit = deltaValueInUserUnit
        watchState.urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
        watchState.lowLimitInMgDl = UserDefaults.standard.lowMarkValue
        watchState.highLimitInMgDl = UserDefaults.standard.highMarkValue
        watchState.urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
        watchState.activeSensorDescription = UserDefaults.standard.activeSensorDescription
        watchState.isMaster = UserDefaults.standard.isMaster
        watchState.followerDataSourceTypeRawValue = UserDefaults.standard.followerDataSourceType.rawValue
        watchState.followerBackgroundKeepAliveTypeRawValue = UserDefaults.standard.followerBackgroundKeepAliveType.rawValue
        watchState.keepAliveIsDisabled = !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled
        watchState.liveDataIsEnabled = UserDefaults.standard.showDataInWatchComplications
        
        if let sensorStartDate = UserDefaults.standard.activeSensorStartDate {
            let minutes = Calendar.current.dateComponents([.minute], from: sensorStartDate, to: .now).minute ?? 0
            watchState.sensorAgeInMinutes = Double(minutes)
        } else {
            watchState.sensorAgeInMinutes = 0
        }
        
        watchState.sensorMaxAgeInMinutes = (UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0) * 24 * 60
        
        // let's set the state values if we're using a heartbeat
        if let timeStampOfLastHeartBeat = UserDefaults.standard.timeStampOfLastHeartBeat?.timeIntervalSince1970, let secondsUntilHeartBeatDisconnectWarning = UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning {
            watchState.secondsUntilHeartBeatDisconnectWarning = Int(secondsUntilHeartBeatDisconnectWarning)
            watchState.timeStampOfLastHeartBeat = timeStampOfLastHeartBeat
        }
        
        // let's set the follower server connection values if we're using follower mode
        if let timeStampOfLastFollowerConnection = UserDefaults.standard.timeStampOfLastFollowerConnection?.timeIntervalSince1970 {
            watchState.secondsUntilFollowerDisconnectWarning = UserDefaults.standard.followerDataSourceType.secondsUntilFollowerDisconnectWarning
            watchState.timeStampOfLastFollowerConnection = timeStampOfLastFollowerConnection
        }
        
        // add AID/loop status data
        if UserDefaults.standard.nightscoutFollowType != .none {
            watchState.deviceStatusCreatedAt = nightscoutSyncManager.deviceStatus.createdAt.timeIntervalSince1970
            watchState.deviceStatusLastLoopDate = nightscoutSyncManager.deviceStatus.lastLoopDate.timeIntervalSince1970
            watchState.deviceStatusIOB = nightscoutSyncManager.deviceStatus.iob
            watchState.deviceStatusCOB = nightscoutSyncManager.deviceStatus.cob
        } else {
            watchState.deviceStatusLastLoopDate = nil
        }
        
        watchState.remainingComplicationUserInfoTransfers = session.remainingComplicationUserInfoTransfers
        
        sendStateToWatch(forceComplicationUpdate: false)
    }
    
    func sendStateToWatch(forceComplicationUpdate: Bool) {
        guard session.isPaired else {
            trace("no Watch is paired", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
            return
        }
        
        guard session.isWatchAppInstalled else {
            trace("watch app is not installed", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
            return
        }
        
        guard session.activationState == .activated else {
            let activationStateString = "\(session.activationState)"
            trace("watch session activationState = %{public}@. Reactivating", log: log, category: ConstantsLog.categoryWatchManager, type: .debug, activationStateString)
            session.activate()
            return
        }
        
        // if the WCSession is reachable it means that Watch app is in the foreground so send the watch state as a message
        // if it's not reachable, then it means it's in the background so send the state as a userInfo
        // if more than x minutes have passed since the last complication update, call transferCurrentComplicationUserInfo to force an update
        // if not, then just send it as a normal priority transferUserInfo (but limit the sending to once every 5 minutes!) which will be queued and sent as soon as the watch app is reachable again (this will help get the app showing data quicker)
        if let userInfo: [String: Any] = watchState.asDictionary {
            if session.isReachable {
                session.sendMessage(["watchState": userInfo], replyHandler: nil, errorHandler: { [weak self] error in
                    guard let self = self else { return }
                    trace("error sending watch state, error = %{public}@", log: self.log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
                })
            } else {
                if (lastForcedComplicationUpdateTimeStamp < .now.addingTimeInterval(-Double(UserDefaults.standard.forceComplicationUpdateInMinutes * 60)) && session.isComplicationEnabled && UserDefaults.standard.showDataInWatchComplications) || forceComplicationUpdate {
                    let updateType: String = forceComplicationUpdate ? "forcing" : "sending"
                    
                    trace("%{public}@ background complication update every %{public}@ minutes, remaining complication transfers left today: %{public}@ / 50", log: log, category: ConstantsLog.categoryWatchManager, type: .info, updateType, UserDefaults.standard.forceComplicationUpdateInMinutes.description, session.remainingComplicationUserInfoTransfers.description)
                    
                    session.transferCurrentComplicationUserInfo(["watchState": userInfo])
                    lastForcedComplicationUpdateTimeStamp = .now
                    UserDefaults.standard.remainingComplicationUserInfoTransfers = session.remainingComplicationUserInfoTransfers
                } else {
                    trace("sending background watch state update", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
                    
                    session.transferUserInfo(["watchState": userInfo])
                }
            }
        }
    }
    
    // MARK: - Public functions
    
    func updateWatchApp(forceComplicationUpdate: Bool) {
        processWatchState(forceComplicationUpdate: forceComplicationUpdate)
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue)
    }
}

// MARK: - conform to WCSessionDelegate protocol

extension WatchManager: WCSessionDelegate {
    func sessionDidBecomeInactive(_: WCSession) {}
    
    func sessionDidDeactivate(_: WCSession) {
        session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    // process any received messages from the watch app
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // check which type of update the Watch is requesting and call the correct sending function as needed
        if let requestWatchUpdate = message["requestWatchUpdate"] as? String {
            switch requestWatchUpdate {
            case "watchState":
                DispatchQueue.main.async {
                    self.sendStateToWatch(forceComplicationUpdate: false)
                }
            default:
                break
            }
        }
    }
    
    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {}
    
    func session(_: WCSession, didReceiveMessageData _: Data) {}
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            DispatchQueue.main.async {
                self.sendStateToWatch(forceComplicationUpdate: false)
            }
        }
    }
}
