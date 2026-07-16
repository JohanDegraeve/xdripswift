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

    /// prevents duplicate activate calls while WatchConnectivity is already processing one
    private let sessionActivationLock = NSLock()
    private var sessionActivationRequested = false

    /// a BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor

    /// a coreDataManager instance (must be passed from RVC in the initializer)
    private var coreDataManager: CoreDataManager

    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager

    /// hold the current watch status model
    private var status = WatchStatus()

    /// hold the current watch BG readings model
    private var bgReadings = WatchBgReadings()

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
            activateSessionIfNeeded()
        }

        // add observer to sync to the watch once the device status was updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue, options: .new, context: nil)

        processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
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
                            self?.processWatchUpdate(updateTypes: [.status], forceComplicationUpdate: false)
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

    private enum WatchUpdateType: Hashable {
        case status
        case bgReadings
    }

    private func activateSessionIfNeeded() {
        sessionActivationLock.lock()
        let shouldActivate = !sessionActivationRequested
        sessionActivationRequested = true
        sessionActivationLock.unlock()

        if shouldActivate {
            session.activate()
        }
    }

    private func completeSessionActivationRequest() {
        sessionActivationLock.lock()
        sessionActivationRequested = false
        sessionActivationLock.unlock()
    }

    private func processWatchUpdate(updateTypes: Set<WatchUpdateType>, forceComplicationUpdate: Bool) {
        if updateTypes.contains(.status) {
            status = currentStatus()
        }

        if updateTypes.contains(.bgReadings) {
            bgReadings = currentBgReadings()
        }

        sendUpdateToWatch(updateTypes: updateTypes, forceComplicationUpdate: forceComplicationUpdate)
    }

    private func currentBgReadings() -> WatchBgReadings {
        // create two simple arrays to send to the watch. One with the bg values in mg/dL and another with the corresponding timestamps
        // this is needed due to the not being able to pass structs that are not codable/hashable
        let hoursOfBgReadingsToSend: Double = 12

        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl

        let bgReadingSnapshots = bgReadingsAccessor.getLatestBgReadingSnapshots(limit: nil, fromDate: .now.addingTimeInterval(-3600 * hoursOfBgReadingsToSend), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        let slopeOrdinal: Int = !bgReadingSnapshots.isEmpty ? bgReadingSnapshots[0].slopeOrdinal() : 1

        var previousValueInUserUnit = 0.0
        var actualValueInUserUnit = 0.0
        var deltaValueInUserUnit = 0.0

        // add delta if available
        if bgReadingSnapshots.count > 1 {
            previousValueInUserUnit = bgReadingSnapshots[1].finalValue.mgDlToMmol(mgDl: isMgDl)
            actualValueInUserUnit = bgReadingSnapshots[0].finalValue.mgDlToMmol(mgDl: isMgDl)

            // if the values are in mmol/L, then round them to the nearest decimal point in order to get the same precision out of the next operation
            if !isMgDl {
                previousValueInUserUnit = (previousValueInUserUnit * 10).rounded() / 10
                actualValueInUserUnit = (actualValueInUserUnit * 10).rounded() / 10
            }

            deltaValueInUserUnit = actualValueInUserUnit - previousValueInUserUnit
        }

        var bgReadingValues: [Double] = []
        var bgReadingDatesAsDouble: [Double] = []

        for bgReading in bgReadingSnapshots {
            bgReadingValues.append(bgReading.finalValue)
            bgReadingDatesAsDouble.append(bgReading.timeStamp.timeIntervalSince1970)
        }

        return WatchBgReadings(generatedAt: Date().timeIntervalSince1970, hoursIncluded: hoursOfBgReadingsToSend, bgReadingValues: bgReadingValues, bgReadingDatesAsDouble: bgReadingDatesAsDouble, slopeOrdinal: slopeOrdinal, deltaValueInUserUnit: deltaValueInUserUnit)
    }

    private func currentStatus() -> WatchStatus {
        var status = WatchStatus()

        status.generatedAt = Date().timeIntervalSince1970
        status.isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        status.urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
        status.lowLimitInMgDl = UserDefaults.standard.lowMarkValue
        status.highLimitInMgDl = UserDefaults.standard.highMarkValue
        status.urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
        status.activeSensorDescription = UserDefaults.standard.activeSensorDescription
        status.preferSensorCountdown = UserDefaults.standard.preferSensorCountdown
        status.isMaster = UserDefaults.standard.isMaster
        status.followerDataSourceTypeRawValue = UserDefaults.standard.followerDataSourceType.rawValue
        status.followerBackgroundKeepAliveTypeRawValue = UserDefaults.standard.followerBackgroundKeepAliveType.rawValue
        status.keepAliveIsDisabled = !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled

        if let sensorStartDate = UserDefaults.standard.activeSensorStartDate {
            let minutes = Calendar.current.dateComponents([.minute], from: sensorStartDate, to: .now).minute ?? 0
            status.sensorAgeInMinutes = Double(minutes)
        } else {
            status.sensorAgeInMinutes = 0
        }

        status.sensorMaxAgeInMinutes = (UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0) * 24 * 60

        // let's set the state values if we're using a heartbeat
        if let timeStampOfLastHeartBeat = UserDefaults.standard.timeStampOfLastHeartBeat?.timeIntervalSince1970, let secondsUntilHeartBeatDisconnectWarning = UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning {
            status.secondsUntilHeartBeatDisconnectWarning = Int(secondsUntilHeartBeatDisconnectWarning)
            status.timeStampOfLastHeartBeat = timeStampOfLastHeartBeat
        }

        // let's set the follower server connection values if we're using follower mode
        if let timeStampOfLastFollowerConnection = UserDefaults.standard.timeStampOfLastFollowerConnection?.timeIntervalSince1970 {
            status.secondsUntilFollowerDisconnectWarning = UserDefaults.standard.followerDataSourceType.secondsUntilFollowerDisconnectWarning
            status.timeStampOfLastFollowerConnection = timeStampOfLastFollowerConnection
        }

        // add AID/loop status data
        if !UserDefaults.standard.nightscoutEnabled || UserDefaults.standard.nightscoutUrl == nil || UserDefaults.standard.nightscoutFollowType == .none {
            status.deviceStatusAvailable = false
        } else if UserDefaults.standard.nightscoutEnabled, UserDefaults.standard.nightscoutUrl != nil, nightscoutSyncManager.deviceStatus.createdAt != .distantPast {
            status.deviceStatusAvailable = true
            status.deviceStatusCreatedAt = nightscoutSyncManager.deviceStatus.createdAt.timeIntervalSince1970
            status.deviceStatusLastLoopDate = nightscoutSyncManager.deviceStatus.lastLoopDate.timeIntervalSince1970
            status.deviceStatusIOB = nightscoutSyncManager.deviceStatus.iob
            status.deviceStatusCOB = nightscoutSyncManager.deviceStatus.cob
        }

        return status
    }

    private func payload(updateTypes: Set<WatchUpdateType>) -> [String: Any]? {
        var payload: [String: Any] = [:]

        if updateTypes.contains(.status), let statusDictionary = status.asDictionary {
            payload["status"] = statusDictionary
        }

        if updateTypes.contains(.bgReadings), let bgReadingsDictionary = bgReadings.asDictionary {
            payload["bgReadings"] = bgReadingsDictionary
        }

        return payload.isEmpty ? nil : payload
    }

    private func sendUpdateToWatch(updateTypes: Set<WatchUpdateType>, forceComplicationUpdate: Bool) {
        // Pairing and installation state are only valid after WatchConnectivity has activated
        guard session.activationState == .activated else {
            let activationStateString = "\(session.activationState)"
            trace("watch session activationState = %{public}@. Reactivating", log: log, category: ConstantsLog.categoryWatchManager, type: .debug, activationStateString)
            activateSessionIfNeeded()
            return
        }

        guard session.isPaired else {
            trace("no Watch is paired", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
            return
        }

        guard session.isWatchAppInstalled else {
            trace("watch app is not installed", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
            return
        }

        // if the WCSession is reachable it means that Watch app is in the foreground so send the watch update as a message
        // if it's not reachable, then it means it's in the background so send the update as a userInfo
        // if more than x minutes have passed since the last complication update, call transferCurrentComplicationUserInfo to force an update
        // if not, then just send it as a normal priority transferUserInfo (but limit the sending to once every 5 minutes!) which will be queued and sent as soon as the watch app is reachable again (this will help get the app showing data quicker)
        if let userInfo = payload(updateTypes: updateTypes) {
            if session.isReachable {
                session.sendMessage(userInfo, replyHandler: nil, errorHandler: { [weak self] error in
                    guard let self = self else { return }
                    trace("error sending watch update, error = %{public}@", log: self.log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
                })
            } else {
                if (lastForcedComplicationUpdateTimeStamp < .now.addingTimeInterval(-Double(UserDefaults.standard.forceComplicationUpdateInMinutes * 60)) && session.isComplicationEnabled) || forceComplicationUpdate {
                    let updateType: String = forceComplicationUpdate ? "forcing" : "sending"

                    trace("%{public}@ background complication update every %{public}@ minutes", log: log, category: ConstantsLog.categoryWatchManager, type: .info, updateType, UserDefaults.standard.forceComplicationUpdateInMinutes.description)

                    session.transferCurrentComplicationUserInfo(userInfo)
                    lastForcedComplicationUpdateTimeStamp = .now
                } else {
                    trace("sending background watch update", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)

                    session.transferUserInfo(userInfo)
                }
            }
        }
    }

    // MARK: - Public functions

    func updateWatchApp(forceComplicationUpdate: Bool) {
        processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: forceComplicationUpdate)
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
        activateSessionIfNeeded()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        completeSessionActivationRequest()

        if let error {
            trace("watch session activation failed, error = %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
            return
        }

        guard activationState == .activated else { return }

        // send the update that was deferred while the session was activating
        DispatchQueue.main.async { [weak self] in
            self?.processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
        }
    }

    // process any received messages from the watch app
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // check which type of update the Watch is requesting and call the correct sending function as needed
        if let requestWatchUpdate = message["requestWatchUpdate"] as? String {
            switch requestWatchUpdate {
            case "status":
                DispatchQueue.main.async {
                    self.processWatchUpdate(updateTypes: [.status], forceComplicationUpdate: false)
                }
            case "bgReadings":
                DispatchQueue.main.async {
                    self.processWatchUpdate(updateTypes: [.bgReadings], forceComplicationUpdate: false)
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
                self.processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
            }
        }
    }
}
