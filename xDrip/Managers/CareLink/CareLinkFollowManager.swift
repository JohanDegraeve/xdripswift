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

/// Authentication readiness is deliberately separate from follower selection. In particular, a
/// Keychain item left by an earlier installation is not usable without a configured account.
enum CareLinkLifecycleState: Equatable {
    case inactive
    case awaitingCredentials
    case awaitingLogin
    case invalidatingSession
    case authenticating
    case authenticated
}

enum CareLinkLifecyclePolicy {
    static func state(isSelected: Bool, hasCredentials: Bool, hasSession: Bool) -> CareLinkLifecycleState {
        guard isSelected else { return .inactive }
        guard hasCredentials else { return .awaitingCredentials }
        return hasSession ? .authenticated : .awaitingLogin
    }

    static func permitsPolling(_ state: CareLinkLifecycleState) -> Bool {
        state == .authenticated
    }
}

/// Bridges CareLink's asynchronous cloud API into the app's established follower pipeline.
///
/// `RootApplicationCoordinator` retains one instance for the application lifetime. The manager
/// mirrors the other follower managers: KVO controls activation, `download()` is the polling
/// entry point, and glucose readings leave through a weak `FollowerDelegate`.
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
    /// Invalidates the one-shot download timer used outside heartbeat mode.
    private var invalidateDownloadTimer: (() -> Void)?
    /// A single in-flight poll prevents timer, foreground and heartbeat callbacks from overlapping.
    private var pollTask: Task<Void, Never>?
    private var pollIdentifier: UUID?
    /// Prevents frequent coordinator callbacks from bypassing the Nightscout-matched cadence.
    private var lastPollStartedAt = Date.distantPast
    /// Retains one explicit Refresh request when a scheduled poll is already in progress.
    private var refreshRequestedWhilePolling = false
    private var authController: CareLinkWebLoginViewController?
    /// Invalidates callbacks from a cancelled or superseded browser login.
    private var loginIdentifier: UUID?
    /// Invalidates reconciliation, authentication and poll callbacks from older configurations.
    private var lifecycleGeneration = 0
    private var lifecycleState: CareLinkLifecycleState = .inactive
    private var invalidationTask: Task<Void, Never>?
    private var invalidationIdentifier: UUID?
    private var failureCount = 0
    private var audioPlayer: AVAudioPlayer?
    private var playSoundTimer: RepeatingTimer?
    private let applicationManagerKeyResumePlaySoundTimer = "CareLinkFollowerManager-ResumePlaySoundTimer"
    private let applicationManagerKeySuspendPlaySoundTimer = "CareLinkFollowerManager-SuspendPlaySoundTimer"

    /// Creates the long-lived manager and immediately evaluates the current follower selection.
    init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate, client: CareLinkClient = CareLinkClient(), state: CareLinkAccountState = .shared) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.client = client
        self.state = state
        self.therapyImporter = CareLinkTherapyImporter(coreDataManager: coreDataManager)
        if let url = Bundle.main.url(forResource: ConstantsSuspensionPrevention.soundFileName, withExtension: "") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
            } catch let error {
                trace(
                    "in init, exception while trying to create audioplayer, error = %{public}@",
                    log: self.log,
                    category: ConstantsLog.categoryCareLinkFollowManager,
                    type: .error,
                    error.localizedDescription
                )
            }
        }
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkSelectedPatientID.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkUsername.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkPassword.rawValue, options: .new, context: nil)
        Task { @MainActor [weak self] in
            guard let self else { return }
            state.controller = self
            reconcileLifecycle()
        }
    }

    // MARK: - Existing follower integration

    /// Creates the same Core Data entity used by other followers. Glucose persistence and all
    /// glucose-specific downstream work remain owned by `RootApplicationCoordinator`.
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

    /// Entry point shared by immediate startup, the one-shot timer and the coordinator heartbeat.
    /// Calls are coalesced while a poll is already running.
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
        guard CareLinkLifecyclePolicy.permitsPolling(lifecycleState),
              isActive,
              CareLinkLoginCredentials.stored() != nil else { return }
        if pollTask != nil {
            if force { refreshRequestedWhilePolling = true }
            return
        }
        guard force || Date().timeIntervalSince(lastPollStartedAt) >= CareLinkPollingPolicy.interval else { return }
        lastPollStartedAt = Date()
        let identifier = UUID()
        let generation = lifecycleGeneration
        pollIdentifier = identifier
        pollTask = Task { [weak self] in
            await self?.performPoll(generation: generation)
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
            if let invalidationTask { await invalidationTask.value }
            guard isActive, let credentials = CareLinkLoginCredentials.stored() else {
                lifecycleState = isActive ? .awaitingCredentials : .inactive
                updateStateOnMain {
                    $0.status = .loginRequired
                    $0.detail = Texts_SettingsView.careLinkCredentialsRequired
                }
                return
            }
            guard !(await client.hasToken()) else {
                reconcileLifecycle()
                return
            }
            lifecycleGeneration += 1
            let generation = lifecycleGeneration
            lifecycleState = .authenticating
            let identifier = prepareLogin()
            await beginLogin(identifier: identifier, generation: generation, credentials: credentials)
        }
    }

    /// Requests a fresh account and data transaction without changing the retained web session.
    /// If a timer poll is active, exactly one follow-up transaction runs as soon as it finishes.
    func refresh() {
        Task { @MainActor [weak self] in
            guard let self,
                  CareLinkLifecyclePolicy.permitsPolling(lifecycleState),
                  isActive else { return }
            cancelScheduledDownload()
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
            await invalidateSession(revokeRemotely: true)
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
            UserDefaults.standard.careLinkRegion = selectedRegion.rawValue
            await invalidateSession(revokeRemotely: true)
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
    private func beginLogin(identifier: UUID, generation: Int, credentials: CareLinkLoginCredentials) async {
        guard isActive,
              lifecycleGeneration == generation,
              lifecycleState == .authenticating,
              loginIdentifier == identifier,
              CareLinkLoginCredentials.stored() == credentials else { return }
        guard CareLinkLoginCredentials.stored() != nil else {
            loginIdentifier = nil
            lifecycleState = .awaitingCredentials
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
            guard lifecycleGeneration == generation,
                  lifecycleState == .authenticating,
                  loginIdentifier == identifier,
                  region == loginRegion,
                  CareLinkLoginCredentials.stored() == credentials else { return }
            _ = try await client.installWebSession(cookies: cookies, region: loginRegion, countryCode: CareLinkClient.resolvedCountryCode(region: loginRegion, accountCountry: nil))
            guard lifecycleGeneration == generation,
                  lifecycleState == .authenticating,
                  loginIdentifier == identifier,
                  region == loginRegion,
                  CareLinkLoginCredentials.stored() == credentials else {
                await client.clearLocalSession()
                return
            }
            loginIdentifier = nil
            lifecycleState = .authenticated
            updateStateOnMain { $0.lastTokenRefreshAt = Date() }
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                enableSuspensionPrevention()
            } else {
                disableSuspensionPrevention()
            }
            refreshNow()
        } catch CareLinkError.cancelled {
            guard loginIdentifier == identifier else { return }
            loginIdentifier = nil
            lifecycleState = .awaitingLogin
            updateStateOnMain {
                $0.status = .loginRequired
                $0.detail = CareLinkError.cancelled.localizedDescription
            }
        } catch {
            guard loginIdentifier == identifier else { return }
            loginIdentifier = nil
            lifecycleState = .awaitingLogin
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
    private func performPoll(generation: Int) async {
        guard await pollIsCurrent(generation) else { return }
        let currentRegion = region
        trace("CareLink poll started, region=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, currentRegion.rawValue)
        #if DEBUG
        do {
            // The explicit localhost launch hook drives the production manager pipeline without
            // adding a simulator credential or authentication bypass to release builds.
            try await client.installDebugSimulatorSessionIfRequested(region: currentRegion)
        } catch let error as CareLinkError {
            await handle(error, generation: generation)
            return
        } catch {
            guard await pollIsCurrent(generation) else { return }
            await updateState(generation: generation) {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = false
            }
            return
        }
        #endif
        guard await pollIsCurrent(generation) else { return }
        if let authenticatedRegion = await client.authenticatedRegion(), authenticatedRegion != currentRegion {
            await handle(.regionMismatch(selected: currentRegion, authenticated: authenticatedRegion), generation: generation)
            return
        }
        guard await pollIsCurrent(generation) else { return }
        await updateState(generation: generation) {
            $0.status = .connecting
            $0.lastCheckAt = Date()
            $0.region = currentRegion
        }
        do {
            let account = try await client.userAndPatients(region: currentRegion)
            guard await pollIsCurrent(generation) else { return }
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
            await updateState(generation: generation) { snapshot in
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
                    await updateState(generation: generation) {
                        $0.status = .noData
                        $0.detail = Texts_SettingsView.careLinkNoLinkedPatients
                    }
                } else {
                    await updateState(generation: generation) {
                        $0.status = .error
                        $0.detail = CareLinkError.patientIdentityMissing.localizedDescription
                    }
                }
                await scheduleNewDownload(generation: generation)
                return
            }
            guard let selectedID, let patient = account.patients.first(where: { $0.id == selectedID || $0.username == selectedID }) else {
                failureCount = 0
                await updateState(generation: generation) {
                    $0.status = .selectPatient
                    $0.detail = CareLinkError.patientSelectionRequired.localizedDescription
                }
                await scheduleNewDownload(generation: generation)
                return
            }
            let response = try await client.fetchPatientData(region: currentRegion, patient: patient, username: account.metadata.accountName, accountRole: account.metadata.role, countryCode: account.metadata.countryCode, linkedPatientCount: account.patients.count)
            guard await pollIsCurrent(generation) else { return }
            let refreshedAt = await client.tokenRefreshDate()
            var parsed = try CareLinkGlucoseParser.readings(from: response.0)
            let therapy = try CareLinkTherapyParser.payload(from: response.0, patientID: patient.id)
            let importsTherapy = UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink
            let importedCount = importsTherapy ? await therapyImporter.importTreatments(therapy.treatments) : 0
            guard await pollIsCurrent(generation) else { return }
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
            guard await pollIsCurrent(generation) else { return }
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
            await updateState(generation: generation) { snapshot in
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
            // Glucose persistence and downstream behavior remain owned by the follower delegate.
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
                await MainActor.run { [weak self] in
                    guard let self, self.pollIsCurrentOnMain(generation) else { return }
                    Self.deliver(readings, to: self.followerDelegate)
                }
            }
            await scheduleNewDownload(generation: generation)
        } catch let error as CareLinkError {
            guard isActive, !Task.isCancelled else { return }
            trace("CareLink poll failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            await handle(error, generation: generation)
        } catch {
            guard !Task.isCancelled, await pollIsCurrent(generation) else { return }
            trace("CareLink poll failed with unexpected error: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            failureCount += 1
            await updateState(generation: generation) {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = false
            }
            await scheduleRetry(after: backoff, generation: generation)
        }
    }

    /// Separates service reachability, reconnect requirements, rate limits and transient backoff.
    private func handle(_ error: CareLinkError, generation: Int) async {
        guard await pollIsCurrent(generation) else { return }
        switch error {
        case let .rateLimited(until):
            await updateState(generation: generation) {
                $0.status = .rateLimited
                $0.rateLimitedUntil = until
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
            }
            await scheduleRetry(after: max(1, until.timeIntervalSinceNow), generation: generation)
        case .reconnectRequired, .regionMismatch, .notAuthenticated:
            await transitionToAwaitingLogin(generation: generation)
            await updateState(generation: generation) {
                $0.status = .loginRequired
                $0.detail = error.localizedDescription
            }
        case .accountRejected:
            await transitionToAwaitingLogin(generation: generation)
            await updateState(generation: generation) {
                $0.status = .loginRequired
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
            }
        case .noGlucoseData:
            // Empty data is a healthy authenticated response, not a transient server failure.
            // Keep polling normally so readings appear automatically if the account gains data.
            failureCount = 0
            await updateState(generation: generation) {
                $0.status = .noData
                $0.detail = error.localizedDescription
                $0.serviceReachable = true
                $0.lastReadingAt = nil
            }
            await scheduleNewDownload(generation: generation)
        case let .unsupportedRole(metadata):
            await updateState(generation: generation) {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.metadata.accountName = metadata.accountName
                $0.metadata.role = metadata.role
                $0.serviceReachable = true
            }
        default:
            failureCount += 1
            await updateState(generation: generation) {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = error != .offline
            }
            await scheduleRetry(after: backoff, generation: generation)
        }
    }

    /// Current bounded delay for transient network/server failures.
    private var backoff: TimeInterval { CareLinkPollingPolicy.backoff(failureCount: failureCount) }

    /// Schedules the next download using the Nightscout follower's one-shot timer workflow.
    @MainActor
    private func scheduleNewDownload(generation: Int) {
        guard pollIsCurrentOnMain(generation) else { return }
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        cancelScheduledDownload()
        trace("in scheduleNewDownload", log: self.log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info)
        let downloadTimer = Timer.scheduledTimer(
            timeInterval: CareLinkPollingPolicy.interval,
            target: self,
            selector: #selector(self.download),
            userInfo: nil,
            repeats: false
        )
        invalidateDownloadTimer = {
            downloadTimer.invalidate()
        }
    }

    /// Retains CareLink's service-specific delay for errors and rate limits.
    @MainActor
    private func scheduleRetry(after interval: TimeInterval, generation: Int) {
        guard pollIsCurrentOnMain(generation),
              UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else { return }
        cancelScheduledDownload()
        let downloadTimer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(self.download),
            userInfo: nil,
            repeats: false
        )
        invalidateDownloadTimer = {
            downloadTimer.invalidate()
        }
    }

    @MainActor
    private func cancelScheduledDownload() {
        invalidateDownloadTimer?()
        invalidateDownloadTimer = nil
    }

    /// Cancels both scheduled and active work so logout/source switching cannot receive a late poll.
    @MainActor
    private func stopPolling() {
        cancelScheduledDownload()
        pollTask?.cancel()
        pollTask = nil
        pollIdentifier = nil
        lastPollStartedAt = .distantPast
        refreshRequestedWhilePolling = false
    }

    // MARK: - Activation and background keep-alive

    /// Reconciles follower selection, configured account details and secure-session availability.
    @MainActor
    private func reconcileLifecycle() {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        // Reconciliation is idempotent. Tear down the prior generation before enabling a new one.
        stopPolling()
        disableSuspensionPrevention()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let selected = isActive
            let hasCredentials = CareLinkLoginCredentials.stored() != nil

            if !hasCredentials {
                cancelLogin()
                stopPolling()
                disableSuspensionPrevention()
                lifecycleState = selected ? .awaitingCredentials : .inactive
                if selected, UserDefaults.standard.careLinkSelectedPatientID != nil {
                    UserDefaults.standard.careLinkSelectedPatientID = nil
                }
                await client.clearLocalSession()
                guard lifecycleGeneration == generation else { return }
                if selected {
                    publishLoginRequired(detail: Texts_SettingsView.careLinkCredentialsRequired)
                }
                return
            }

            if !selected {
                cancelLogin()
                stopPolling()
                disableSuspensionPrevention()
                lifecycleState = .inactive
                return
            }

            if let invalidationTask { await invalidationTask.value }
            guard lifecycleGeneration == generation, isActive, CareLinkLoginCredentials.stored() != nil else { return }
            let hasSession = await client.hasToken()
            guard lifecycleGeneration == generation else { return }
            lifecycleState = CareLinkLifecyclePolicy.state(isSelected: true, hasCredentials: true, hasSession: hasSession)
            if lifecycleState == .authenticated {
                if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                    enableSuspensionPrevention()
                } else {
                    disableSuspensionPrevention()
                }
                download()
            } else {
                stopPolling()
                disableSuspensionPrevention()
                publishLoginRequired(detail: nil)
            }
        }
    }

    /// Immediately blocks all work, then clears locally and optionally revokes the captured session.
    @MainActor
    private func invalidateSession(revokeRemotely: Bool) async {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        cancelLogin()
        stopPolling()
        disableSuspensionPrevention()
        lifecycleState = .invalidatingSession
        if UserDefaults.standard.careLinkSelectedPatientID != nil {
            UserDefaults.standard.careLinkSelectedPatientID = nil
        }
        publishLoginRequired(detail: CareLinkLoginCredentials.stored() == nil ? Texts_SettingsView.careLinkCredentialsRequired : nil)

        let task: Task<Void, Never>
        let identifier: UUID
        if let invalidationTask {
            task = invalidationTask
            identifier = invalidationIdentifier ?? UUID()
        } else {
            identifier = UUID()
            task = Task { [client] in
                if revokeRemotely { await client.revokeAndClear() }
                else { await client.clearLocalSession() }
            }
            invalidationTask = task
            invalidationIdentifier = identifier
        }
        await task.value
        if invalidationIdentifier == identifier {
            invalidationTask = nil
            invalidationIdentifier = nil
        }
        guard lifecycleGeneration == generation else { return }
        reconcileLifecycle()
    }

    @MainActor
    private func publishLoginRequired(detail: String?) {
        updateStateOnMain { snapshot in
            let region = self.region
            snapshot = CareLinkStatusSnapshot(status: .loginRequired, region: region)
            snapshot.detail = detail
        }
    }

    @MainActor
    private func pollIsCurrentOnMain(_ generation: Int) -> Bool {
        lifecycleGeneration == generation
            && lifecycleState == .authenticated
            && isActive
            && CareLinkLoginCredentials.stored() != nil
    }

    private func pollIsCurrent(_ generation: Int) async -> Bool {
        await MainActor.run { self.pollIsCurrentOnMain(generation) }
    }

    private func transitionToAwaitingLogin(generation: Int) async {
        let shouldClear = await MainActor.run {
            guard self.lifecycleGeneration == generation else { return false }
            self.lifecycleState = .awaitingLogin
            self.stopPolling()
            self.disableSuspensionPrevention()
            return true
        }
        guard shouldClear else { return }
        await client.clearLocalSession()
    }

    /// Suspends local audio work and removes both application lifecycle callbacks.
    private func disableSuspensionPrevention() {
        if let playSoundTimer = playSoundTimer {
            playSoundTimer.suspend()
        }
        ApplicationManager.shared.removeClosureToRunWhenAppDidEnterBackground(key: applicationManagerKeyResumePlaySoundTimer)
        ApplicationManager.shared.removeClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeySuspendPlaySoundTimer)
    }

    /// Launches the same silent-audio timer used by the Nightscout follower.
    private func enableSuspensionPrevention() {
        if !UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
            trace(
                "not enabling suspension prevention as keep-alive type is: %{public}@",
                log: self.log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .debug,
                UserDefaults.standard.followerBackgroundKeepAliveType.description
            )
            return
        }
        let interval = UserDefaults.standard.followerBackgroundKeepAliveType == .normal
            ? ConstantsSuspensionPrevention.intervalNormal
            : ConstantsSuspensionPrevention.intervalAggressive
        // This timer maintains audio only. Polling is scheduled independently after each request.
        playSoundTimer = RepeatingTimer(timeInterval: TimeInterval(Double(interval))) { [weak self] in
            guard let self = self else { return }
            trace(
                "in eventhandler checking if audioplayer exists",
                log: self.log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .info
            )
            if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                trace(
                    "playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@",
                    log: self.log,
                    category: ConstantsLog.categoryCareLinkFollowManager,
                    type: .info,
                    interval.description,
                    UserDefaults.standard.followerDataSourceType.description,
                    UserDefaults.standard.followerBackgroundKeepAliveType.description
                )
                audioPlayer.play()
            }
        }
        ApplicationManager.shared.addClosureToRunWhenAppDidEnterBackground(
            key: applicationManagerKeyResumePlaySoundTimer
        ) { [weak self] in
            guard let self = self else { return }
            // Match Nightscout by starting audio here without forcing a network request.
            if UserDefaults.standard.followerBackgroundKeepAliveType.shouldKeepAlive {
                if let playSoundTimer = self.playSoundTimer {
                    playSoundTimer.resume()
                }
                if let audioPlayer = self.audioPlayer, !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
            }
        }
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(
            key: applicationManagerKeySuspendPlaySoundTimer
        ) { [weak self] in
            guard let self = self else { return }
            if let playSoundTimer = self.playSoundTimer {
                playSoundTimer.suspend()
            }
        }
    }

    /// Applies synchronous state mutations from code already executing on the main actor.
    @MainActor
    private func updateStateOnMain(_ transform: @escaping (inout CareLinkStatusSnapshot) -> Void) { state.update(transform) }
    /// Marshals background polling updates onto the UI's main-thread observable object.
    private func updateState(generation: Int, _ transform: @escaping (inout CareLinkStatusSnapshot) -> Void) async {
        await MainActor.run {
            guard self.lifecycleGeneration == generation else { return }
            self.state.update(transform)
        }
    }

    // MARK: - KVO

    /// Debounces related UserDefaults notifications before re-evaluating manager activation.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath, let key = UserDefaults.Key(rawValue: keyPath) else { return }
        switch key {
        case .careLinkUsername, .careLinkPassword:
            Task { @MainActor [weak self] in
                await self?.invalidateSession(revokeRemotely: true)
            }
        case .isMaster, .followerDataSourceType, .followerBackgroundKeepAliveType:
            guard keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) else { return }
            Task { @MainActor [weak self] in self?.reconcileLifecycle() }
        case .careLinkSelectedPatientID:
            refreshNow()
        default: break
        }
    }

    /// Removes KVO, timers and lifecycle closures owned by this manager.
    deinit {
        for key in [UserDefaults.Key.isMaster, .followerDataSourceType, .followerBackgroundKeepAliveType, .careLinkSelectedPatientID, .careLinkUsername, .careLinkPassword] {
            UserDefaults.standard.removeObserver(self, forKeyPath: key.rawValue)
        }
        invalidateDownloadTimer?()
        pollTask?.cancel()
        let loginController = authController
        Task { @MainActor in loginController?.cancel() }
        disableSuspensionPrevention()
    }

}
