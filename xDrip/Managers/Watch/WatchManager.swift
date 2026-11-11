//
//  WatchManager.swift
//  xdrip
//
//  Created by Paul Plant on 9/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Combine
import CoreData
import Foundation
import OSLog
import WatchConnectivity
import WidgetKit

// WatchConnectivity delegate callbacks can trigger async AGP generation
// mutable watch payloads are still committed back on the main queue
final class WatchManager: NSObject, ObservableObject, @unchecked Sendable {
    /// Returns only identities confirmed in the phone's persistent glucose store.
    var importDirectWatchReadings: (([DirectWatchReading]) -> [String])?
    private var directWatchObservers: [NSObjectProtocol] = []
    private var directWatchConfigurationSendScheduled = false
    private var directWatchConfigurationHasPublished = false

    // MARK: - private properties

    /// a watch connectivity session instance
    private let session: WCSession

    // Only the configuration sender's serial queue accesses this transfer. Replace obsolete
    // queued setup snapshots, while leaving reading acknowledgements and log requests alone.
    private var configurationTransfer: WCSessionUserInfoTransfer?
    private lazy var configurationSender = DirectWatchConfigurationSender { [weak self] payload, changed in
        guard let self, self.session.activationState == .activated else { return false }
        if changed {
            self.configurationTransfer?.cancel()
            self.configurationTransfer = self.session.transferUserInfo(payload)
        }
        if self.session.isReachable {
            self.session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        return true
    }

    /// prevents duplicate activate calls while WatchConnectivity is already processing one
    private let sessionActivationLock = NSLock()
    private var sessionActivationRequested = false

    /// a BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor

    /// a SensorsAccessor instance
    private var sensorsAccessor: SensorsAccessor

    /// a coreDataManager instance (must be passed from RVC in the initializer)
    private var coreDataManager: CoreDataManager

    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager

    /// Statistics manager used to build compact AGP backgrounds for the Watch chart
    private var statisticsManager: StatisticsManager

    /// hold the current watch status model
    private var status = WatchStatus()

    /// hold the current watch BG readings model
    private var bgReadings = WatchBgReadings()

    /// hold the current AGP chart background model
    private var agp = WatchAGP()

    /// keep track of when we last forced a complication update from within the code
    private var lastForcedComplicationUpdateTimeStamp: Date = .distantPast

    /// Sends CareLink connection and pump-status transitions without waiting for the next glucose reading.
    private var careLinkStatusObserver: AnyCancellable?

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)

    // MARK: - intializer

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager, session: WCSession = .default) {
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        self.nightscoutSyncManager = nightscoutSyncManager
        self.statisticsManager = StatisticsManager(coreDataManager: coreDataManager)

        self.session = session

        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            activateSessionIfNeeded()
        }

        // add observer to sync to the watch once the device status was updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue, options: .new, context: nil)

        careLinkStatusObserver = CareLinkAccountState.shared.$snapshot
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard UserDefaults.standard.followerDataSourceType == .careLink else { return }
                self?.processWatchUpdate(updateTypes: [.status], forceComplicationUpdate: false)
            }

        // Alarm edits must reach an offline-capable Watch without waiting for a new reading.
        // Inspect saved objects on their context's queue, then build the value snapshot on main.
        directWatchObservers.append(NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { [weak self] notification in
            let keys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey]
            let objects = keys.flatMap { notification.userInfo?[$0] as? Set<NSManagedObject> ?? [] }
            guard objects.contains(where: { $0 is AlertEntry }) else { return }
            DispatchQueue.main.async { self?.sendDirectWatchConfiguration() }
        })
        processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
        directWatchObservers.append(NotificationCenter.default.addObserver(forName: DirectWatchSettings.changed, object: nil, queue: .main) { [weak self] _ in self?.sendDirectWatchConfiguration() })
        directWatchObservers.append(NotificationCenter.default.addObserver(forName: DirectWatchSettings.requestLogs, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.session.activationState == .activated else {
                DirectWatchSettings.recordLogRequest(queued: false)
                return
            }
            let request = DirectWatchCompatibility.outgoing(["directWatchRequestLogs": true])
            if self.session.isReachable {
                self.session.sendMessage(request, replyHandler: nil, errorHandler: { _ in self.session.transferUserInfo(request) })
            } else { self.session.transferUserInfo(request) }
            DirectWatchSettings.recordLogRequest(queued: true)
        })
    }

    private func sendDirectWatchConfiguration() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.sendDirectWatchConfiguration() }
            return
        }
        guard !directWatchConfigurationSendScheduled else { return }
        directWatchConfigurationSendScheduled = true
        // Sensor reconciliation can stop and recreate the internal sensor synchronously.
        // Publish its settled state on the next main-queue turn, not the intermediate nil.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.directWatchConfigurationSendScheduled = false
            self.publishDirectWatchConfiguration()
        }
    }

    private func publishDirectWatchConfiguration() {
        guard session.activationState == .activated else { return }
        if !directWatchConfigurationHasPublished {
            // Invalidate snapshots still queued from the previous phone process, including
            // suspension messages emitted by older builds during sensor reconciliation.
            DirectWatchSettings.advanceRevision()
            directWatchConfigurationHasPublished = true
        }
        var configuration = DirectWatchSettings.configuration
        var unavailableReason: String?
        let activeSensorStart = sensorsAccessor.fetchActiveSensor()?.startDate
        if var current = configuration {
            let selected = BLEPeripheralAccessor(coreDataManager: coreDataManager).getBLEPeripherals().first { $0.shouldconnect && $0.transmitterId == current.transmitterID }
            let g6 = selected?.dexcomG5
            let g7 = selected?.dexcomG7
            // Suspend collection without deleting the user's setup or testing controls.
            if !UserDefaults.standard.isMaster { unavailableReason = TextsDirectWatch.masterRequired }
            else if current.transmitterFamily == .g6 && g6 == nil { unavailableReason = TextsDirectWatch.g6Mismatch }
            else if current.transmitterFamily == .g7 && g7 == nil { unavailableReason = TextsDirectWatch.g7Mismatch }
            else if current.transmitterFamily == .g7 && g7?.useOtherApp == true { unavailableReason = TextsDirectWatch.primaryRequired }
            else if current.transmitterFamily == .g6 && selected?.webOOPEnabled != true { unavailableReason = TextsDirectWatch.nativeG6Required }
            else if current.transmitterFamily == .g7 && (g7?.sensorCode?.count != 4 || g7?.sensorCode?.allSatisfy(\.isNumber) != true) { unavailableReason = TextsDirectWatch.pairingCodeRequired }
            else if (g6?.effectiveDexcomG6BluetoothSlot().rawValue ?? g7?.effectiveDexcomG7BluetoothSlot().rawValue) == current.slot { unavailableReason = TextsDirectWatch.slotsConflict }
            else if current.slot == 3 && current.transmitterFamily == .g6 && g6?.isAnubis != true { unavailableReason = TextsDirectWatch.anubisRequired }
            else if activeSensorStart == nil { unavailableReason = TextsDirectWatch.noActiveSensor }
            current.sensorStartDate = activeSensorStart ?? current.sensorStartDate
            if current.transmitterFamily == .g7 { current.pairingCode = g7?.sensorCode }
            current.isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            current.low = UserDefaults.standard.lowMarkValue
            current.high = UserDefaults.standard.highMarkValue
            let entries = AlertEntriesAccessor(coreDataManager: coreDataManager)
            let types = AlertTypesAccessor(coreDataManager: coreDataManager)
            func schedule(_ kind: AlertKind) -> [DirectWatchAlertEntry] {
                entries.getAllEntries(forAlertKind: kind, alertTypesAccessor: types).map {
                    DirectWatchAlertEntry(startMinute: Int($0.start), threshold: Double($0.value))
                }
            }
            current.urgentLowSchedule = schedule(.verylow)
            current.lowSchedule = schedule(.low)
            if unavailableReason == nil && current != configuration {
                DirectWatchSettings.save(current)
                return
            }
            configuration = unavailableReason == nil ? current : nil
        }
        if UserDefaults.standard.string(forKey: DirectWatchSettings.unavailableReasonKey) != unavailableReason {
            trace("Direct to Watch availability: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, unavailableReason ?? "ready")
            // Availability transitions must also be ordered, so a delayed suspension cannot
            // override a newer ready configuration received through another WCSession channel.
            DirectWatchSettings.advanceRevision()
        }
        UserDefaults.standard.set(unavailableReason, forKey: DirectWatchSettings.unavailableReasonKey)
        var payload: [String: Any] = ["directWatchEnabled": configuration != nil,
                                      "directWatchConfigured": DirectWatchSettings.configuration != nil,
                                      "directWatchRevision": UserDefaults.standard.double(forKey: DirectWatchSettings.revisionKey),
                                      "directWatchPhonePaused": DirectWatchSettings.configuration.map { DirectWatchSettings.phoneIsPaused($0.transmitterID) } ?? false]
        payload.merge(DirectWatchSettings.collectionControl?.payload ?? [:], uniquingKeysWith: { _, new in new })
        if let unavailableReason { payload["directWatchUnavailableReason"] = unavailableReason }
        if let configuration, let data = try? JSONEncoder().encode(configuration) { payload["directWatchConfiguration"] = data }
        payload = DirectWatchCompatibility.outgoing(payload)
        // Device crash reports show updateApplicationContext blocking inside WCSession's
        // synchronous applicationContext getter until iOS kills the main thread. Use the
        // existing queued-message receiver instead, with revisions still ordering snapshots.
        // Build the payload on main, where its Core Data inputs belong, then send only values.
        configurationSender.enqueue(payload)
    }

    private func receiveDirectWatchPayload(_ payload: [String: Any], reply: (([String: Any]) -> Void)? = nil) {
        let payload = DirectWatchCompatibility.normalized(payload)
        DispatchQueue.main.async {
            if let control = DirectWatchCollectionControl.decode(payload) {
                DirectWatchSettings.receiveCollectionControl(control)
            }
            if let event = DirectWatchConnectionEvent.decode(payload) { DirectWatchSettings.recordConnection(event) }
            if let status = payload["directWatchStatus"] as? String {
                UserDefaults.standard.set(String(status.prefix(500)), forKey: DirectWatchSettings.lastStatusKey)
                UserDefaults.standard.set(Date(), forKey: DirectWatchSettings.lastStatusDateKey)
                DirectWatchSettings.recordContact()
            }
            guard let data = payload["directWatchReadings"] as? Data, data.count <= 100_000,
                  let readings = try? JSONDecoder().decode([DirectWatchReading].self, from: data), readings.count <= ConstantsDirectWatch.maximumSyncBatchReadings else {
                reply?(DirectWatchCompatibility.outgoing(DirectWatchSettings.collectionControl?.payload ?? [:]))
                return
            }
            let acknowledged = self.importDirectWatchReadings?(readings) ?? []
            if let latest = readings.filter({ acknowledged.contains($0.id) }).map(\.measuredAt).max() {
                DirectWatchSettings.recordContact(latestReadingAt: latest)
            }
            let response = DirectWatchCompatibility.outgoing(["directWatchAcknowledged": acknowledged].merging(DirectWatchSettings.collectionControl?.payload ?? [:], uniquingKeysWith: { _, new in new }))
            if let reply { reply(response) }
            else if !acknowledged.isEmpty { self.session.transferUserInfo(response) }
            trace("Direct to Watch batch received: %{public}@ readings, %{public}@ acknowledged", log: self.log, category: ConstantsLog.categoryWatchManager, type: .info, readings.count.description, acknowledged.count.description)
            self.processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
        }
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
        case agp
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

    private func processWatchUpdate(updateTypes: Set<WatchUpdateType>, forceComplicationUpdate: Bool, therapyMetrics: TherapyMetricsSnapshot? = nil) {
        // KVO and WatchConnectivity may enter on a background queue. Status providers
        // and UI-owned state are read on main without blocking the notifying writer.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.processWatchUpdate(updateTypes: updateTypes, forceComplicationUpdate: forceComplicationUpdate, therapyMetrics: therapyMetrics)
            }
            return
        }
        if updateTypes.contains(.status) {
            status = currentStatus(therapyMetrics: therapyMetrics)
        }

        if updateTypes.contains(.bgReadings) {
            bgReadings = currentBgReadings()
        }

        sendDirectWatchConfiguration()
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

    private func currentStatus(therapyMetrics: TherapyMetricsSnapshot? = nil) -> WatchStatus {
        var status = WatchStatus()

        status.generatedAt = Date().timeIntervalSince1970
        status.isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        status.urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
        status.lowLimitInMgDl = UserDefaults.standard.lowMarkValue
        status.highLimitInMgDl = UserDefaults.standard.highMarkValue
        status.urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
        status.activeSensorDescription = UserDefaults.standard.activeSensorDescription
        if UserDefaults.standard.isMaster {
            // Use the selected transmitter, not an inactive Anubis saved in the device list.
            coreDataManager.mainManagedObjectContext.performAndWait {
                let peripheral = BLEPeripheralAccessor(coreDataManager: coreDataManager)
                    .getBLEPeripherals()
                    .first(where: { $0.shouldconnect && $0.dexcomG5 != nil })
                if peripheral?.dexcomG5?.isAnubis == true {
                    status.activeSensorDescription = DexcomProductNameResolver.anubisTitle
                }
            }
        }
        if UserDefaults.standard.isMaster {
            let peripheral = BLEPeripheralAccessor(coreDataManager: coreDataManager)
                .getBLEPeripherals()
                .first { $0.shouldconnect && ($0.dexcomG5 != nil || $0.dexcomG7 != nil) }
            if let peripheral {
                status.phoneBLECollectionPaused = DirectWatchSettings.phoneIsPaused(peripheral.transmitterId ?? "")

            }
        }
        status.preferSensorCountdown = UserDefaults.standard.preferSensorCountdown
        status.isMaster = UserDefaults.standard.isMaster
        status.followerDataSourceTypeRawValue = UserDefaults.standard.followerDataSourceType.rawValue
        status.followerBackgroundKeepAliveTypeRawValue = UserDefaults.standard.followerBackgroundKeepAliveType.rawValue
        status.followerConnectionStatusRawValue = UserDefaults.standard.followerDataSourceType == .careLink
            ? CareLinkAccountState.shared.snapshot.status.rawValue
            : nil
        status.keepAliveIsDisabled = !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled

        if let sensorStartDate = UserDefaults.standard.activeSensorStartDate {
            let minutes = Calendar.current.dateComponents([.minute], from: sensorStartDate, to: .now).minute ?? 0
            status.sensorAgeInMinutes = Double(minutes)
        } else {
            status.sensorAgeInMinutes = 0
        }

        status.sensorMaxAgeInMinutes = (UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0) * 24 * 60

        if status.isMaster,
           UserDefaults.standard.showSensorNoise,
           let activeSensor = sensorsAccessor.fetchActiveSensor(),
           activeSensor.noiseAlgorithmVersion == ConstantsSensorNoise.algorithmVersion,
           let latestReadingAt = activeSensor.noiseLatestReadingAt {
            let readingAge = Date().timeIntervalSince(latestReadingAt)

            if readingAge >= -TimeInterval(minutes: 5),
               readingAge <= ConstantsSensorNoise.rootWarningFreshness {
                let rawSensorNoiseState = SensorNoiseState(rawValue: activeSensor.noiseStateRaw) ?? .collecting
                status.sensorNoiseStateRawValue = Int(
                    ConstantsSensorNoise.displayState(
                        rawState: rawSensorNoiseState,
                        shortTermNoise: activeSensor.shortTermNoise?.doubleValue,
                        longTermNoise: activeSensor.longTermNoise?.doubleValue,
                        sensitivity: UserDefaults.standard.sensorNoiseSensitivity
                    ).rawValue
                )
            }
        }

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

        // CareLink has no Nightscout device-status record, so both sources are normalized before
        // crossing the Watch boundary rather than making the Watch understand either protocol.
        if UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink {
            status.aidStatus = CareLinkAccountState.shared.snapshot.aidStatus
        } else if !UserDefaults.standard.dataFlowPolicy.showsAIDData {
            status.aidStatus = nil
        } else if UserDefaults.standard.nightscoutEnabled, UserDefaults.standard.nightscoutUrl != nil, nightscoutSyncManager.deviceStatus.createdAt != .distantPast {
            status.aidStatus = nightscoutSyncManager.deviceStatus.aidStatus
        } else {
            status.aidStatus = nil
        }

        status.therapyMetrics = therapyMetrics ?? TherapyMetricsManager.shared.snapshot()
        return status
    }

    private func currentAGP(requestID: Double, visibleStartDate: Date, visibleEndDate: Date) async -> WatchAGP {
        guard visibleStartDate < visibleEndDate else {
            return WatchAGP(generatedAt: Date().timeIntervalSince1970, requestID: requestID, visibleStartDateAsDouble: visibleStartDate.timeIntervalSince1970, visibleEndDateAsDouble: visibleEndDate.timeIntervalSince1970)
        }

        // use the same AGP calculation as the iOS landscape comparison chart
        // for the Watch app, keep the baseline focused on recent days and only send the compact
        // minute-of-day profile. The Watch maps that profile onto its current chart window locally.
        let baseline = await statisticsManager.landscapeBaseline(referenceDate: visibleEndDate, daysBack: ConstantsGlucoseChartSwiftUI.agpDaysBackWatchApp)
        let agpPoints = GlucoseReportAGPDisplayPoints.smoothedDisplayPoints(from: baseline.agpPoints)

        return WatchAGP(
            generatedAt: Date().timeIntervalSince1970,
            requestID: requestID,
            visibleStartDateAsDouble: visibleStartDate.timeIntervalSince1970,
            visibleEndDateAsDouble: visibleEndDate.timeIntervalSince1970,
            dayCount: baseline.dayCount,
            minuteOfDayValues: agpPoints.map(\.minuteOfDay),
            p5Values: agpPoints.map(\.p5MgDl),
            p25Values: agpPoints.map(\.p25MgDl),
            medianValues: agpPoints.map(\.medianMgDl),
            p75Values: agpPoints.map(\.p75MgDl),
            p95Values: agpPoints.map(\.p95MgDl)
        )
    }

    private func payload(updateTypes: Set<WatchUpdateType>) -> [String: Any]? {
        var payload: [String: Any] = [:]

        if updateTypes.contains(.status), let statusDictionary = status.asDictionary {
            payload["status"] = statusDictionary
        }

        if updateTypes.contains(.bgReadings), let bgReadingsDictionary = bgReadings.asDictionary {
            payload["bgReadings"] = bgReadingsDictionary
        }

        if updateTypes.contains(.agp), let agpDictionary = agp.asDictionary {
            payload["agp"] = agpDictionary
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
                trace("sending foreground watch update", log: log, category: ConstantsLog.categoryWatchManager, type: .debug)
                session.sendMessage(userInfo, replyHandler: nil, errorHandler: { [weak self] error in
                    guard let self = self else { return }
                    trace("error sending watch update, error = %{public}@", log: self.log, category: ConstantsLog.categoryWatchManager, type: .error, troubleshooting: .detailed(.integration(name: .watch, activity: .failed)), error.localizedDescription)
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

    func updateTherapyMetrics(_ snapshot: TherapyMetricsSnapshot) {
        processWatchUpdate(updateTypes: [.status], forceComplicationUpdate: false, therapyMetrics: snapshot)
    }

    func updateWatchApp(forceComplicationUpdate: Bool) {
        processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: forceComplicationUpdate)
    }

    deinit {
        directWatchObservers.forEach { NotificationCenter.default.removeObserver($0) }
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue)
    }
}

// MARK: - conform to WCSessionDelegate protocol

extension WatchManager: WCSessionDelegate {
    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_: WCSession) {
        session.delegate = self
        activateSessionIfNeeded()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        completeSessionActivationRequest()
        sendDirectWatchConfiguration()

        if let error {
            trace("watch session activation failed, error = %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, troubleshooting: .detailed(.integration(name: .watch, activity: .failed)), error.localizedDescription)
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
        receiveDirectWatchPayload(message)
        sendDirectWatchConfiguration()
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
            case "agp":
                // the Watch sends the current visible range so iOS can calculate the AGP baseline
                // with the same reference date. The reply is still a compact minute-of-day profile.
                let requestID = message["requestID"] as? Double ?? 0
                let visibleStartDate = Date(timeIntervalSince1970: message["visibleStartDate"] as? Double ?? Date().addingTimeInterval(-12 * 60 * 60).timeIntervalSince1970)
                let visibleEndDate = Date(timeIntervalSince1970: message["visibleEndDate"] as? Double ?? Date().timeIntervalSince1970)

                Task { [weak self] in
                    guard let self else { return }

                    let agp = await self.currentAGP(requestID: requestID, visibleStartDate: visibleStartDate, visibleEndDate: visibleEndDate)

                    DispatchQueue.main.async {
                        self.agp = agp
                        self.sendUpdateToWatch(updateTypes: [.agp], forceComplicationUpdate: false)
                    }
                }
            default:
                break
            }
        }
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receiveDirectWatchPayload(userInfo)
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let message = DirectWatchCompatibility.normalized(message)
        if let probe = message["directWatchLinkProbe"] as? Double {
            DispatchQueue.main.async {
                if let control = DirectWatchCollectionControl.decode(message) {
                    DirectWatchSettings.receiveCollectionControl(control)
                }
                if let event = DirectWatchConnectionEvent.decode(message) { DirectWatchSettings.recordConnection(event) }
                DirectWatchSettings.recordContact()
                let response: [String: Any] = ["directWatchLinkProbe": probe]
                    .merging(DirectWatchSettings.collectionControl?.payload ?? [:], uniquingKeysWith: { _, new in new })
                replyHandler(DirectWatchCompatibility.outgoing(response))
            }
            return
        }
        receiveDirectWatchPayload(message, reply: replyHandler)
    }

    func session(_: WCSession, didReceive file: WCSessionFile) {
        guard DirectWatchCompatibility.normalized(file.metadata ?? [:])["directWatchLog"] as? Bool == true else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.fileURL.path)
            guard let size = (attributes[.size] as? NSNumber)?.intValue, size > 0, size <= 2_000_000 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try Data(contentsOf: file.fileURL).write(to: DirectWatchSettings.receivedLogURL, options: .atomic)
            // WCSession owns this temporary URL only during the callback. Save it before
            // publishing receipt on the main queue so the share action can use it immediately.
            DispatchQueue.main.async { DirectWatchSettings.recordLogsReceived() }
        } catch {
            DispatchQueue.main.async { DirectWatchSettings.recordLogRequest(queued: false) }
            trace("Direct to Watch log import failed: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
        }
    }

    func session(_: WCSession, didReceiveMessageData _: Data) {}

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            DispatchQueue.main.async {
                self.processWatchUpdate(updateTypes: [.status, .bgReadings], forceComplicationUpdate: false)
            }
        }
    }
}

/// Keep framework calls off main and retain at most the latest waiting configuration.
/// The lock protects the handoff only. A slow framework call never holds it, so UI and
/// Bluetooth callers can continue replacing the pending snapshot without waiting.
final class DirectWatchConfigurationSender {
    private let queue = DispatchQueue(label: "DirectWatchConfigurationSender", qos: .utility)
    private let lock = NSLock()
    private var pending: [String: Any]?
    private var sending = false
    private var lastSent: [String: Any]?
    private let send: ([String: Any], Bool) -> Bool

    /// The changed flag requests replacement of the queued configuration. Return false
    /// when the session is inactive, so the next activation can retry the same snapshot.
    init(send: @escaping ([String: Any], Bool) -> Bool) { self.send = send }

    func enqueue(_ payload: [String: Any]) {
        lock.lock()
        pending = payload
        let shouldStart = !sending
        sending = true
        lock.unlock()
        if shouldStart { queue.async { self.drain() } }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let payload = pending else {
                sending = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()
            // Refresh requests may resend an unchanged live message, but must not keep
            // cancelling and recreating an identical background configuration transfer.
            let changed = lastSent.map { !NSDictionary(dictionary: $0).isEqual(to: payload) } ?? true
            // Activation can disappear between main's snapshot and this queue's send.
            // Do not suppress the background retry when activation completes again.
            if send(payload, changed) { lastSent = payload }
        }
    }
}
