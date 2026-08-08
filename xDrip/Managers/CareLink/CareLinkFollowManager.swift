//
//  CareLinkFollowManager.swift
//  xdripswift
//
//  Created by Paul Plant on 2/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import Foundation
import os

/// Bridges CareLink's asynchronous cloud API into the app's established follower pipeline.
///
/// `RootApplicationCoordinator` retains one instance for the application lifetime. The manager
/// mirrors the other follower managers: KVO controls activation, `download()` is the heartbeat
/// entry point, and readings leave through a weak `FollowerDelegate`.
///
/// Account sessions, linked-patient handling, regional routing and CareLink data endpoint
/// workflows were based upon the concepts implemented in these open-source community projects:
/// - xDrip+ CareLink follower:
///   https://github.com/NightscoutFoundation/xDrip/tree/master/app/src/main/java/com/eveningoutpost/dexdrip/cgm/carelinkfollow
/// - CareLinkJavaClient:
///   https://github.com/benceszasz/CareLinkJavaClient
/// - xDripCareLinkFollower:
///   https://github.com/benceszasz/xDripCareLinkFollower
/// - carelink-python-client:
///   https://github.com/ondrej1024/carelink-python-client
/// - carelink-bridge:
///   https://github.com/domien-f/carelink-bridge
///
/// This implementation is written in Swift for xdripswift by porting over the general protocol
/// workflows and payload behavior established by those projects.
final class CareLinkFollowManager: NSObject, CareLinkControlling {
    // MARK: - Dependencies and lifecycle state

    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private weak var followerDelegate: FollowerDelegate?
    private let client: CareLinkClient
    private let state: CareLinkAccountState
    private let therapyImporter: CareLinkTherapyImporter
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)
    private let keyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    /// Used only outside heartbeat mode. Heartbeat cadence belongs to the root coordinator.
    private var timer: Timer?
    /// A single in-flight poll prevents timer, foreground and heartbeat callbacks from overlapping.
    private var pollTask: Task<Void, Never>?
    private var pollIdentifier: UUID?
    /// Prevents frequent coordinator and keep-alive ticks from bypassing the 60-second service cadence.
    private var lastPollStartedAt = Date.distantPast
    /// Retains one explicit Refresh request when a scheduled poll is already in progress.
    private var refreshRequestedWhilePolling = false
    private var authController: CareLinkWebLoginViewController?
    /// Invalidates callbacks from a cancelled or superseded browser login.
    private var loginIdentifier: UUID?
    private var failureCount = 0
    private var audioPlayer: AVAudioPlayer?
    private var playSoundTimer: RepeatingTimer?
    private let backgroundKey = "CareLinkFollowManager-Background"
    private let foregroundKey = "CareLinkFollowManager-Foreground"

    /// Creates the long-lived manager and immediately evaluates the current follower selection.
    init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate, client: CareLinkClient = CareLinkClient(), state: CareLinkAccountState = .shared) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.client = client
        self.state = state
        self.therapyImporter = CareLinkTherapyImporter(coreDataManager: coreDataManager)
        super.init()
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
        }
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkSelectedPatientID.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkUsername.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkPassword.rawValue, options: .new, context: nil)
        Task { @MainActor in state.controller = self }
        verifyAndStartOrStop()
    }

    // MARK: - Existing follower integration

    /// Creates the same Core Data entity used by other followers so alerts, post-processing,
    /// Watch, HealthKit, Live Activities, Calendar, Bluetooth and Nightscout remain downstream.
    func createBgReading(followGlucoseData: FollowerBgReading) -> BgReading {
        let reading = BgReading(timeStamp: followGlucoseData.timeStamp, sensor: nil, calibration: nil, rawData: followGlucoseData.sgv, deviceName: ConstantsHomeView.applicationName + " (CareLink)", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        reading.calculatedValue = followGlucoseData.sgv
        let previous = bgReadingsAccessor.getLatestBgReadings(limit: 3, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true)
        if previous.count >= 2 {
            let slope = previous[0].calculateSlope(lastBgReading: previous[1])
            reading.calculatedValueSlope = slope.0
            reading.hideSlope = slope.1
        } else {
            reading.calculatedValueSlope = 0
            reading.hideSlope = true
        }
        return reading
    }

    /// CareLink runs only in follower mode and only while selected as the follower source.
    static func shouldActivate(isMaster: Bool, dataSource: FollowerDataSourceType) -> Bool {
        !isMaster && dataSource == .careLink
    }

    @MainActor
    /// Delivers the complete newest-first batch through the established coordinator flow.
    static func deliver(_ readings: [FollowerBgReading], to delegate: FollowerDelegate?) {
        guard !readings.isEmpty else { return }
        var copy = readings
        delegate?.followerInfoReceived(followGlucoseDataArray: &copy)
    }

    /// Entry point shared by immediate startup, the 60-second timer, app lifecycle callbacks and
    /// the coordinator heartbeat. Calls are coalesced while a poll is already running.
    @objc func download() {
        dispatchPollRequest(force: false)
    }

    /// Runs an immediate lifecycle or user-requested refresh without waiting for regular cadence.
    func refreshNow() {
        dispatchPollRequest(force: true)
    }

    private func dispatchPollRequest(force: Bool) {
        if Thread.isMainThread {
            requestPoll(force: force)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestPoll(force: force)
        }
    }

    private func requestPoll(force: Bool) {
        guard isActive else { return }
        if pollTask != nil {
            if force { refreshRequestedWhilePolling = true }
            return
        }
        guard force || Date().timeIntervalSince(lastPollStartedAt) >= CareLinkPollingPolicy.interval else { return }
        lastPollStartedAt = Date()
        let identifier = UUID()
        pollIdentifier = identifier
        pollTask = Task { [weak self] in
            await self?.performPoll()
            await self?.finishPoll(identifier: identifier)
        }
    }

    /// Clears only the poll that owns the matching identifier, avoiding a stale task racing a new one.
    @MainActor
    private func finishPoll(identifier: UUID) {
        guard pollIdentifier == identifier else { return }
        pollTask = nil
        pollIdentifier = nil
        if refreshRequestedWhilePolling {
            refreshRequestedWhilePolling = false
            requestPoll(force: true)
        }
    }

    // MARK: - Settings actions

    /// Starts Medtronic's personal web login after both account fields have been configured.
    func logIn() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard CareLinkLoginCredentials.stored() != nil else {
                updateStateOnMain {
                    $0.status = .loginRequired
                    $0.detail = Texts_SettingsView.careLinkCredentialsRequired
                }
                return
            }
            let identifier = prepareLogin()
            await beginLogin(identifier: identifier)
        }
    }

    /// Requests a fresh account and data transaction without changing the retained web session.
    /// If a timer poll is active, exactly one follow-up transaction runs as soon as it finishes.
    func refresh() {
        Task { @MainActor [weak self] in
            guard let self, isActive else { return }
            timer?.invalidate()
            timer = nil
            updateStateOnMain {
                $0.status = .connecting
                $0.detail = Texts_SettingsView.careLinkRefreshing
            }
            if pollTask != nil {
                refreshRequestedWhilePolling = true
            } else {
                requestPoll(force: true)
            }
        }
    }

    /// Stops work, best-effort closes the web session and clears selection while retaining region.
    func logOut() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            cancelLogin()
            stopPolling()
            disableSuspensionPrevention()
            UserDefaults.standard.careLinkSelectedPatientID = nil
            updateStateOnMain { snapshot in
                let region = snapshot.region
                snapshot = CareLinkStatusSnapshot(status: .loginRequired, region: region)
            }
            await client.revokeAndClear()
        }
    }

    /// Moves to the other Medtronic environment. Web sessions are region-bound and cannot be reused.
    func changeRegion() {
        setRegion(region == .unitedStates ? .outsideUnitedStates : .unitedStates)
    }

    /// Clears the region-bound session and waits for the user to start login in the new environment.
    func setRegion(_ selectedRegion: CareLinkRegion) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard selectedRegion != region else { return }
            cancelLogin()
            stopPolling()
            UserDefaults.standard.careLinkRegion = selectedRegion.rawValue
            UserDefaults.standard.careLinkSelectedPatientID = nil
            updateStateOnMain { snapshot in
                snapshot = CareLinkStatusSnapshot(status: .loginRequired, region: selectedRegion)
            }
            await client.revokeAndClear()
        }
    }

    /// Retains the selection hook used by Settings and polls the selected patient.
    func selectPatient(_ id: String) {
        UserDefaults.standard.careLinkSelectedPatientID = id
        refreshNow()
    }

    /// Computes activation from current settings rather than maintaining a second source of truth.
    private var isActive: Bool {
        Self.shouldActivate(isMaster: UserDefaults.standard.isMaster, dataSource: UserDefaults.standard.followerDataSourceType)
    }

    /// Uses device region only for the initial default. The user's persisted selection is authoritative.
    private var region: CareLinkRegion {
        if let value = UserDefaults.standard.careLinkRegion, let region = CareLinkRegion(rawValue: value) { return region }
        let inferred = CareLinkRegion.inferred
        UserDefaults.standard.careLinkRegion = inferred.rawValue
        return inferred
    }

    // MARK: - Browser authentication

    /// Cancels any earlier web login before allocating an identity for the new login.
    @MainActor
    private func prepareLogin() -> UUID {
        let identifier = UUID()
        loginIdentifier = identifier
        authController?.cancel()
        authController = nil
        return identifier
    }

    /// Invalidates an active login so its eventual cancellation callback cannot change new UI state.
    @MainActor
    private func cancelLogin() {
        loginIdentifier = nil
        authController?.cancel()
        authController = nil
    }

    /// Loads CareLink login, pre-fills the configured account and installs the returned cookies.
    @MainActor
    private func beginLogin(identifier: UUID) async {
        guard isActive, loginIdentifier == identifier else { return }
        guard let credentials = CareLinkLoginCredentials.stored() else {
            loginIdentifier = nil
            updateStateOnMain {
                $0.status = .loginRequired
                $0.detail = Texts_SettingsView.careLinkCredentialsRequired
            }
            return
        }
        let loginRegion = region
        updateStateOnMain {
            $0.status = .connecting
            $0.detail = nil
        }
        do {
            let loginURL = await client.loginURL(region: loginRegion)
            let cookies = try await authenticate(url: loginURL, credentials: credentials, identifier: identifier)
            guard loginIdentifier == identifier, region == loginRegion else { return }
            _ = try await client.installWebSession(cookies: cookies, region: loginRegion, countryCode: CareLinkClient.resolvedCountryCode(region: loginRegion, accountCountry: nil))
            guard loginIdentifier == identifier, region == loginRegion else { return }
            loginIdentifier = nil
            updateStateOnMain { $0.lastTokenRefreshAt = Date() }
            configureSuspensionPrevention()
            refreshNow()
        } catch CareLinkError.cancelled {
            guard loginIdentifier == identifier else { return }
            loginIdentifier = nil
            updateStateOnMain {
                $0.status = .loginRequired
                $0.detail = CareLinkError.cancelled.localizedDescription
            }
        } catch {
            guard loginIdentifier == identifier else { return }
            loginIdentifier = nil
            updateStateOnMain {
                $0.status = .error
                $0.detail = error.localizedDescription
            }
        }
    }

    /// Presents a temporary Medtronic-owned page and returns only its completed session cookies.
    /// CAPTCHA and MFA remain Medtronic content. Only empty account fields are pre-filled.
    @MainActor
    private func authenticate(url: URL, credentials: CareLinkLoginCredentials, identifier: UUID) async throws -> [HTTPCookie] {
        guard let presenter = CareLinkWebLoginViewController.topViewController() else { throw CareLinkError.invalidConfiguration }
        let controller = CareLinkWebLoginViewController(loginURL: url, credentials: credentials)
        authController = controller
        defer { if loginIdentifier == identifier { authController = nil } }
        return try await controller.present(from: presenter)
    }

    // MARK: - Polling and account selection

    /// Performs one complete account → patient → route → parse → delegate transaction.
    private func performPoll() async {
        let currentRegion = region
        trace("CareLink poll started, region=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, currentRegion.rawValue)
        #if DEBUG
        do {
            // The explicit localhost launch hook drives the production manager pipeline without
            // adding a simulator credential or authentication bypass to release builds.
            try await client.installDebugSimulatorSessionIfRequested(region: currentRegion)
        } catch let error as CareLinkError {
            await handle(error)
            return
        } catch {
            await updateState {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = false
            }
            return
        }
        #endif
        if let authenticatedRegion = await client.authenticatedRegion(), authenticatedRegion != currentRegion {
            await handle(.regionMismatch(selected: currentRegion, authenticated: authenticatedRegion))
            return
        }
        await updateState {
            $0.status = .connecting
            $0.lastCheckAt = Date()
            $0.region = currentRegion
        }
        do {
            let account = try await client.userAndPatients(region: currentRegion)
            let tokenRefreshAt = await client.tokenRefreshDate()
            let previousSelection = UserDefaults.standard.careLinkSelectedPatientID
            let selectedID = CareLinkPatientSelection.resolve(patients: account.patients, savedID: previousSelection)
            // Clear a stale saved identifier instead of silently redirecting it.
            if previousSelection != nil, selectedID == nil {
                UserDefaults.standard.careLinkSelectedPatientID = nil
            }
            if selectedID != previousSelection {
                UserDefaults.standard.careLinkSelectedPatientID = selectedID
            }
            await updateState { snapshot in
                snapshot.patients = account.patients
                snapshot.selectedPatientID = selectedID
                snapshot.metadata.accountName = account.metadata.accountName
                snapshot.metadata.role = account.metadata.role
                snapshot.metadata.countryCode = account.metadata.countryCode
                snapshot.lastTokenRefreshAt = tokenRefreshAt
                snapshot.serviceReachable = true
            }
            // Patient accounts must resolve to themselves. Care Partner accounts may validly have
            // no links yet, in which case authentication is retained for automatic recovery.
            guard !account.patients.isEmpty else {
                failureCount = 0
                if CareLinkAccountRole.isCarePartner(account.metadata.role) {
                    await updateState {
                        $0.status = .noData
                        $0.detail = Texts_SettingsView.careLinkNoLinkedPatients
                    }
                } else {
                    await updateState {
                        $0.status = .error
                        $0.detail = CareLinkError.patientIdentityMissing.localizedDescription
                    }
                }
                schedule(after: CareLinkPollingPolicy.interval)
                return
            }
            guard let selectedID, let patient = account.patients.first(where: { $0.id == selectedID || $0.username == selectedID }) else {
                failureCount = 0
                await updateState {
                    $0.status = .selectPatient
                    $0.detail = CareLinkError.patientSelectionRequired.localizedDescription
                }
                schedule(after: CareLinkPollingPolicy.interval)
                return
            }
            let response = try await client.fetchPatientData(region: currentRegion, patient: patient, username: account.metadata.accountName, accountRole: account.metadata.role, countryCode: account.metadata.countryCode, linkedPatientCount: account.patients.count)
            let refreshedAt = await client.tokenRefreshDate()
            var parsed = try CareLinkGlucoseParser.readings(from: response.0)
            let therapy = try CareLinkTherapyParser.payload(from: response.0, patientID: patient.id)
            let importsTherapy = UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink
            let importedCount = importsTherapy ? await therapyImporter.importTreatments(therapy.treatments) : 0
            parsed.metadata.accountName = account.metadata.accountName
            parsed.metadata.role = account.metadata.role
            parsed.metadata.countryCode = account.metadata.countryCode
            parsed.metadata.patientName = patient.displayName
            parsed.metadata.route = response.1
            let importedPumpStatusCount: Int
            if importsTherapy {
                importedPumpStatusCount = await therapyImporter.importPumpStatuses(
                    therapy.pump,
                    treatments: therapy.treatments,
                    metadata: parsed.metadata,
                    checkedAt: Date()
                )
            } else {
                importedPumpStatusCount = 0
            }
            let latest = parsed.readings.first?.timeStamp
            let hasGlucose = !parsed.readings.isEmpty
            let checkedAt = Date()
            let connectionStatus = CareLinkStatePolicy.status(
                hasGlucose: hasGlucose,
                lastReadingAt: latest,
                pump: therapy.pump,
                now: checkedAt
            )
            failureCount = 0
            UserDefaults.standard.timeStampOfLastFollowerConnection = checkedAt
            await updateState { snapshot in
                snapshot.status = connectionStatus
                snapshot.metadata = parsed.metadata
                snapshot.lastReadingAt = latest
                snapshot.lastTokenRefreshAt = refreshedAt
                snapshot.serviceReachable = true
                snapshot.detail = CareLinkStatePolicy.detail(hasGlucose: hasGlucose, pump: therapy.pump)
                snapshot.pump = therapy.pump
                snapshot.importedTreatmentCount = importedCount
                snapshot.lastTherapyImportAt = importsTherapy ? Date() : nil
                snapshot.importedPumpStatusCount = importedPumpStatusCount
                if importedPumpStatusCount > 0 {
                    snapshot.lastPumpHistoryImportAt = Date()
                }
            }
            // Core Data and all downstream behavior remain owned by the existing follower delegate.
            trace(
                "CareLink poll succeeded, route=%{public}@ readings=%{public}d therapy=%{public}d imported=%{public}d pump=%{public}@ status=%{public}@ communicating=%{public}@ inRange=%{public}@",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .info,
                response.1.rawValue,
                parsed.readings.count,
                therapy.treatments.count,
                importedCount,
                therapy.pump.observedAt == nil ? "absent" : "present",
                connectionStatus.rawValue,
                therapy.pump.isCommunicating.map { String(describing: $0) } ?? "unknown",
                therapy.pump.isInRange.map { String(describing: $0) } ?? "unknown"
            )
            if !parsed.readings.isEmpty {
                let readings = parsed.readings
                await MainActor.run { [weak self] in Self.deliver(readings, to: self?.followerDelegate) }
            }
            schedule(after: CareLinkPollingPolicy.interval)
        } catch let error as CareLinkError {
            guard isActive, !Task.isCancelled else { return }
            trace("CareLink poll failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            await handle(error)
        } catch {
            guard isActive, !Task.isCancelled else { return }
            trace("CareLink poll failed with unexpected error: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            failureCount += 1
            await updateState {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = false
            }
            schedule(after: backoff)
        }
    }

    /// Separates service reachability, reconnect requirements, rate limits and transient backoff.
    private func handle(_ error: CareLinkError) async {
        switch error {
        case let .rateLimited(until):
            await updateState {
                $0.status = .rateLimited
                $0.rateLimitedUntil = until
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
            }
            schedule(after: max(1, until.timeIntervalSinceNow))
        case .reconnectRequired, .regionMismatch, .notAuthenticated:
            await updateState {
                $0.status = .loginRequired
                $0.detail = error.localizedDescription
            }
        case .accountRejected:
            await updateState {
                $0.status = .loginRequired
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
            }
        case .noGlucoseData:
            // Empty data is a healthy authenticated response, not a transient server failure.
            // Keep polling normally so readings appear automatically if the account gains data.
            failureCount = 0
            await updateState {
                $0.status = .noData
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
                $0.lastReadingAt = nil
            }
            schedule(after: CareLinkPollingPolicy.interval)
        case let .unsupportedRole(metadata):
            await updateState {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.metadata.accountName = metadata.accountName
                $0.metadata.role = metadata.role
                $0.serviceReachable = true
            }
        default:
            failureCount += 1
            await updateState {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = error != .offline
            }
            schedule(after: backoff)
        }
    }

    /// Current bounded delay for transient network/server failures.
    private var backoff: TimeInterval { CareLinkPollingPolicy.backoff(failureCount: failureCount) }

    /// Schedules one poll unless coordinator heartbeat mode owns cadence.
    private func schedule(after interval: TimeInterval) {
        Task { @MainActor [weak self] in
            guard let self, self.isActive, UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
            self.timer?.invalidate()
            let timer = Timer(timeInterval: interval, target: self, selector: #selector(self.download), userInfo: nil, repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    /// Cancels both scheduled and active work so logout/source switching cannot receive a late poll.
    @MainActor
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        pollTask?.cancel()
        pollTask = nil
        pollIdentifier = nil
        lastPollStartedAt = .distantPast
        refreshRequestedWhilePolling = false
    }

    // MARK: - Activation and background keep-alive

    /// Reacts to follower/master/settings changes without destroying a retained CareLink login.
    private func verifyAndStartOrStop() {
        if isActive {
            timer?.invalidate()
            timer = nil
            configureSuspensionPrevention()
            download()
        } else {
            timer?.invalidate()
            pollTask?.cancel()
            pollTask = nil
            pollIdentifier = nil
            lastPollStartedAt = .distantPast
            disableSuspensionPrevention()
            ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: foregroundKey)
        }
    }

    /// Reuses the app's established silent-audio keep-alive behavior for normal/aggressive modes.
    private func configureSuspensionPrevention() {
        disableSuspensionPrevention()
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: foregroundKey) { [weak self] in
            self?.playSoundTimer?.suspend()
        }
        guard UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive else { return }
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal ? ConstantsSuspensionPrevention.intervalNormal : ConstantsSuspensionPrevention.intervalAggressive
        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(interval)) { [weak self] in
            guard let self else { return }
            if self.audioPlayer?.isPlaying == false { self.audioPlayer?.play() }
            self.download()
        }
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(key: backgroundKey) { [weak self] in
            self?.playSoundTimer?.resume()
            self?.audioPlayer?.play()
            self?.download()
        }
    }

    /// Suspends local audio work and removes both application lifecycle callbacks.
    private func disableSuspensionPrevention() {
        playSoundTimer?.suspend()
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: backgroundKey)
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: foregroundKey)
    }

    /// Applies synchronous state mutations from code already executing on the main actor.
    @MainActor
    private func updateStateOnMain(_ transform: @escaping (inout CareLinkStatusSnapshot) -> Void) { state.update(transform) }
    /// Marshals background polling updates onto the UI's main-thread observable object.
    private func updateState(_ transform: @escaping (inout CareLinkStatusSnapshot) -> Void) async { await MainActor.run { self.state.update(transform) } }

    // MARK: - KVO

    /// Debounces related UserDefaults notifications before re-evaluating manager activation.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath, let key = UserDefaults.Key(rawValue: keyPath) else { return }
        switch key {
        case .careLinkUsername, .careLinkPassword:
            logOut()
        case .isMaster, .followerDataSourceType, .followerBackgroundKeepAliveType, .careLinkSelectedPatientID:
            guard keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) else { return }
            verifyAndStartOrStop()
        default: break
        }
    }

    /// Removes KVO, timers and lifecycle closures owned by this manager.
    deinit {
        for key in [UserDefaults.Key.isMaster, .followerDataSourceType, .followerBackgroundKeepAliveType, .careLinkSelectedPatientID, .careLinkUsername, .careLinkPassword] {
            UserDefaults.standard.removeObserver(self, forKeyPath: key.rawValue)
        }
        timer?.invalidate()
        pollTask?.cancel()
        let loginController = authController
        Task { @MainActor in loginController?.cancel() }
        disableSuspensionPrevention()
    }

}
