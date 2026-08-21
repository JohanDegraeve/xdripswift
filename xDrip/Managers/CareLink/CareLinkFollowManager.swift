//
//  CareLinkFollowManager.swift
//  xdripswift
//
//  Created by Paul Plant on 2/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import os

/// Authentication readiness is deliberately separate from follower selection.
enum CareLinkLifecycleState: Equatable {
    case inactive
    case awaitingLogin
    case invalidatingSession
    case authenticating
    case authenticated
}

enum CareLinkLifecyclePolicy {
    static func state(isSelected: Bool, hasSession: Bool) -> CareLinkLifecycleState {
        guard isSelected else { return .inactive }
        return hasSession ? .authenticated : .awaitingLogin
    }

    static func permitsPolling(_ state: CareLinkLifecycleState) -> Bool {
        state == .authenticated
    }
}

/// One duplicate-safe unit of deferred CareLink therapy persistence.
///
/// Each CareLink response contains overlapping history. Merging by the source identity retains an
/// intermediate record even if a newer response arrives while the previous import is still active.
struct CareLinkTherapyImportBatch {
    let generation: Int
    private(set) var recordsByIdentifier: [String: CareLinkTherapyRecord]
    private(set) var pump: CareLinkPumpSnapshot
    private(set) var metadata: CareLinkMetadata
    private(set) var checkedAt: Date

    init(generation: Int, treatments: [CareLinkTherapyRecord], pump: CareLinkPumpSnapshot, metadata: CareLinkMetadata, checkedAt: Date) {
        self.generation = generation
        self.recordsByIdentifier = Dictionary(treatments.map { ($0.sourceIdentifier, $0) }, uniquingKeysWith: { _, newest in newest })
        self.pump = pump
        self.metadata = metadata
        self.checkedAt = checkedAt
    }

    var treatments: [CareLinkTherapyRecord] {
        recordsByIdentifier.values.sorted {
            $0.date == $1.date ? $0.sourceIdentifier < $1.sourceIdentifier : $0.date < $1.date
        }
    }

    mutating func merge(_ newer: CareLinkTherapyImportBatch) {
        guard generation == newer.generation else { return }
        newer.recordsByIdentifier.forEach { recordsByIdentifier[$0.key] = $0.value }
        pump = newer.pump
        metadata = newer.metadata
        checkedAt = newer.checkedAt
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
    typealias PollingSchedulerFactory = (TimeInterval, @escaping () -> Void) -> FollowerBackgroundTimer

    // MARK: - Dependencies and lifecycle state

    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private weak var followerDelegate: FollowerDelegate?
    private let client: CareLinkClient
    private let state: CareLinkAccountState
    private let therapyImporter: CareLinkTherapyImporting
    /// The root-owned shared keep-alive engine; CareLink registers only after authentication and
    /// never connects an audio lifecycle event or replay tick to its polling API.
    private let backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging
    /// Allows wiring tests to reconcile authenticated state without starting follower networking.
    private let startsInitialDownload: Bool
    /// Creates CareLink's local deadline scheduler. Injection keeps lifecycle tests deterministic.
    private let pollingSchedulerFactory: PollingSchedulerFactory
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)
    private let keyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    /// One persistent scheduler checks the retained deadline outside heartbeat mode.
    private var pollingScheduler: FollowerBackgroundTimer?
    private var pollingSchedulerIsRunning = false
    /// Shared deadline used by both the local scheduler and heartbeat-triggered download attempts.
    private var nextPollAt: Date?
    /// A single in-flight poll prevents timer, foreground and heartbeat callbacks from overlapping.
    private var pollTask: Task<Void, Never>?
    private var pollIdentifier: UUID?
    /// Prevents lifecycle and coordinator callbacks from starting requests too close together.
    private var lastPollStartedAt = Date.distantPast
    /// Retains one explicit Refresh request when a scheduled poll is already in progress.
    private var refreshRequestedWhilePolling = false
    /// Therapy history is deliberately serialized outside the glucose polling transaction.
    private var therapyImportTask: Task<Void, Never>?
    private var therapyImportIdentifier: UUID?
    private var pendingTherapyImport: CareLinkTherapyImportBatch?
    private var authController: CareLinkWebLoginViewController?
    /// Invalidates callbacks from a cancelled or superseded browser login.
    private var loginIdentifier: UUID?
    /// Invalidates reconciliation, authentication and poll callbacks from older configurations.
    private var lifecycleGeneration = 0
    private var lifecycleState: CareLinkLifecycleState = .inactive
    private var invalidationTask: Task<Void, Never>?
    private var invalidationIdentifier: UUID?
    private var failureCount = 0

    /// Creates the long-lived manager and immediately evaluates the current follower selection.
    init(
        coreDataManager: CoreDataManager,
        followerDelegate: FollowerDelegate,
        backgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging,
        client: CareLinkClient = CareLinkClient(),
        state: CareLinkAccountState = .shared,
        therapyImporter: CareLinkTherapyImporting? = nil,
        startsInitialDownload: Bool = true,
        pollingSchedulerFactory: @escaping PollingSchedulerFactory = { interval, eventHandler in
            RepeatingTimer(timeInterval: interval, eventHandler: eventHandler)
        }
    ) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.followerDelegate = followerDelegate
        self.client = client
        self.state = state
        self.therapyImporter = therapyImporter ?? CareLinkTherapyImporter(coreDataManager: coreDataManager)
        self.backgroundKeepAliveManager = backgroundKeepAliveManager
        self.startsInitialDownload = startsInitialDownload
        self.pollingSchedulerFactory = pollingSchedulerFactory
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerDataSourceType.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.careLinkSelectedPatientID.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue, options: .new, context: nil)
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

    /// Entry point shared by immediate startup, the deadline scheduler and coordinator heartbeat.
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
              isActive else { return }
        if pollTask != nil {
            if force { refreshRequestedWhilePolling = true }
            return
        }
        let now = Date()
        guard force || (
            now.timeIntervalSince(lastPollStartedAt) >= ConstantsCareLink.minimumPollingInterval
                && (nextPollAt.map { now >= $0 } ?? true)
        ) else { return }
        lastPollStartedAt = now
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

    /// Starts Medtronic's CarePartner OAuth login; stored fields are optional page prefill only.
    func logIn() {
        trace(
            "user requested CareLink login",
            log: log,
            category: ConstantsLog.categoryCareLinkFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .careLink, activity: .loginStarted))
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let invalidationTask { await invalidationTask.value }
            guard isActive else { return }
            do {
                let hasSession = try await client.hasToken()
                guard !hasSession else {
                    reconcileLifecycle()
                    return
                }
            } catch {
                lifecycleState = .inactive
                updateStateOnMain {
                    $0.status = .error
                    $0.detail = error.localizedDescription
                }
                return
            }
            lifecycleGeneration += 1
            let generation = lifecycleGeneration
            lifecycleState = .authenticating
            let identifier = prepareLogin()
            await beginLogin(identifier: identifier, generation: generation)
        }
    }

    /// Requests a fresh account and data transaction without changing the retained OAuth session.
    /// If a poll is active, exactly one follow-up transaction runs as soon as it finishes.
    func refresh() {
        Task { @MainActor [weak self] in
            guard let self,
                  CareLinkLifecyclePolicy.permitsPolling(lifecycleState),
                  isActive else { return }
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

    /// Stops work, best-effort revokes OAuth and clears selection while retaining region.
    func logOut() {
        trace(
            "CareLink logged out",
            log: log,
            category: ConstantsLog.categoryCareLinkFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .careLink, activity: .loggedOut))
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            await invalidateSession(revokeRemotely: true)
        }
    }

    /// Moves to the other Medtronic environment. OAuth sessions are region-bound and cannot be reused.
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

    /// Loads CarePartner login and exchanges its protected callback for rotating credentials.
    @MainActor
    private func beginLogin(identifier: UUID, generation: Int) async {
        guard isActive,
              lifecycleGeneration == generation,
              lifecycleState == .authenticating,
              loginIdentifier == identifier else { return }
        let loginRegion = region
        updateStateOnMain {
            $0.status = .connecting
            $0.detail = nil
        }
        do {
            let transaction = try await client.authorizationTransaction(region: loginRegion)
            let callback = try await authenticate(transaction: transaction, identifier: identifier)
            guard lifecycleGeneration == generation,
                  lifecycleState == .authenticating,
                  loginIdentifier == identifier,
                  region == loginRegion else { return }
            _ = try await client.installOAuthSession(callbackURL: callback, transaction: transaction, region: loginRegion)
            guard lifecycleGeneration == generation,
                  lifecycleState == .authenticating,
                  loginIdentifier == identifier,
                  region == loginRegion else {
                await client.clearLocalSession()
                return
            }
            loginIdentifier = nil
            lifecycleState = .authenticated
            trace(
                "CareLink login succeeded",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .info,
                troubleshooting: .standard(.follower(source: .careLink, activity: .loginSucceeded))
            )
            updateStateOnMain { $0.lastTokenRefreshAt = Date() }
            backgroundKeepAliveManager.start(for: .careLink)
            if startsInitialDownload {
                refreshNow()
            }
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
            trace(
                "CareLink login failed: %{public}@",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .error,
                troubleshooting: .standard(.follower(source: .careLink, activity: .loginFailed)),
                error.localizedDescription
            )
            updateStateOnMain {
                $0.status = .error
                $0.detail = error.localizedDescription
            }
        }
    }

    /// CAPTCHA and MFA remain Medtronic content. Stored fields only prefill empty form controls.
    @MainActor
    private func authenticate(transaction: CareLinkAuthorizationTransaction, identifier: UUID) async throws -> URL {
        guard let presenter = CareLinkWebLoginViewController.topViewController() else { throw CareLinkError.invalidConfiguration }
        let controller = CareLinkWebLoginViewController(transaction: transaction, prefill: .stored())
        authController = controller
        defer { if loginIdentifier == identifier { authController = nil } }
        return try await controller.present(from: presenter)
    }

    // MARK: - Polling and account selection

    /// Performs one complete account → patient → route → parse → delegate transaction.
    private func performPoll(generation: Int) async {
        guard await pollIsCurrent(generation) else { return }
        let currentRegion = region
        trace("CareLink poll started, region=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, troubleshooting: .detailed(.follower(source: .careLink, activity: .downloadStarted)), currentRegion.rawValue)
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
                await scheduleNewDownload(latestReadingAt: nil, lastDataUpdateAt: nil, generation: generation)
                return
            }
            guard let selectedID, let patient = account.patients.first(where: { $0.id == selectedID || $0.username == selectedID }) else {
                failureCount = 0
                await updateState(generation: generation) {
                    $0.status = .selectPatient
                    $0.detail = CareLinkError.patientSelectionRequired.localizedDescription
                }
                await scheduleNewDownload(latestReadingAt: nil, lastDataUpdateAt: nil, generation: generation)
                return
            }
            let response = try await client.fetchPatientData(region: currentRegion, patient: patient, username: account.metadata.accountName, accountRole: account.metadata.role, countryCode: account.metadata.countryCode, linkedPatientCount: account.patients.count)
            guard await pollIsCurrent(generation) else { return }
            let refreshedAt = await client.tokenRefreshDate()
            var parsed = try CareLinkGlucoseParser.readings(from: response.0)
            let therapy = try CareLinkTherapyParser.payload(from: response.0, patientID: patient.id)
            parsed.metadata.accountName = account.metadata.accountName
            parsed.metadata.role = account.metadata.role
            parsed.metadata.countryCode = account.metadata.countryCode
            parsed.metadata.patientName = patient.displayName
            parsed.metadata.route = response.1
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
            await publishSuccessfulPoll(
                readings: parsed.readings,
                metadata: parsed.metadata,
                therapy: therapy,
                route: response.1,
                connectionStatus: connectionStatus,
                refreshedAt: refreshedAt,
                checkedAt: checkedAt,
                generation: generation
            )
        } catch let error as CareLinkError {
            guard isActive, !Task.isCancelled else { return }
            trace("CareLink poll failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, troubleshooting: .standard(.follower(source: .careLink, activity: .downloadFailed)), error.localizedDescription)
            await handle(error, generation: generation)
        } catch {
            guard !Task.isCancelled, await pollIsCurrent(generation) else { return }
            trace("CareLink poll failed with unexpected error: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, troubleshooting: .standard(.follower(source: .careLink, activity: .downloadFailed)), error.localizedDescription)
            failureCount += 1
            await updateState(generation: generation) {
                $0.status = .error
                $0.detail = error.localizedDescription
                $0.serviceReachable = false
            }
            await scheduleRetry(after: backoff, generation: generation)
        }
    }

    /// Completes the glucose transaction before starting persistence that is not required to show
    /// the current reading or calculate the next request. Physical-device logs on 18 August 2026
    /// showed valid CareLink responses waiting inside therapy import for up to 38 minutes; because
    /// that work still owned `pollTask`, heartbeat wakeups could not start the next due request.
    @MainActor
    private func publishSuccessfulPoll(
        readings: [FollowerBgReading],
        metadata: CareLinkMetadata,
        therapy: CareLinkTherapyPayload,
        route: CareLinkDataRoute,
        connectionStatus: CareLinkConnectionStatus,
        refreshedAt: Date?,
        checkedAt: Date,
        generation: Int
    ) {
        guard pollIsCurrentOnMain(generation) else { return }
        let hasGlucose = !readings.isEmpty
        let latest = readings.first?.timeStamp
        let importsTherapy = UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink
        UserDefaults.standard.timeStampOfLastFollowerConnection = checkedAt
        state.update { snapshot in
            snapshot.status = connectionStatus
            snapshot.metadata = metadata
            snapshot.lastReadingAt = latest
            snapshot.lastTokenRefreshAt = refreshedAt
            snapshot.serviceReachable = true
            snapshot.detail = CareLinkStatePolicy.detail(hasGlucose: hasGlucose, pump: therapy.pump)
            snapshot.pump = therapy.pump
        }

        // Glucose persistence and all established downstream behavior remain owned by the follower delegate.
        if !readings.isEmpty {
            Self.deliver(readings, to: followerDelegate)
        }
        trace(
            "CareLink poll succeeded, route=%{public}@ readings=%{public}d therapy=%{public}d pump=%{public}@ status=%{public}@ communicating=%{public}@ inRange=%{public}@",
            log: log,
            category: ConstantsLog.categoryCareLinkFollowManager,
            type: .info,
            troubleshooting: .standard(.follower(source: .careLink, activity: .downloadSucceeded(readingCount: readings.count))),
            route.rawValue,
            readings.count,
            therapy.treatments.count,
            therapy.pump.observedAt == nil ? "absent" : "present",
            connectionStatus.rawValue,
            therapy.pump.isCommunicating.map { String(describing: $0) } ?? "unknown",
            therapy.pump.isInRange.map { String(describing: $0) } ?? "unknown"
        )
        scheduleNewDownload(
            latestReadingAt: latest,
            lastDataUpdateAt: therapy.pump.lastDataUpdateAt,
            generation: generation
        )
        if importsTherapy {
            enqueueTherapyImport(
                CareLinkTherapyImportBatch(
                    generation: generation,
                    treatments: therapy.treatments,
                    pump: therapy.pump,
                    metadata: metadata,
                    checkedAt: checkedAt
                )
            )
        }
    }

    /// Coalesces overlapping response history while one Core Data transaction remains suspended.
    /// Stable CareLink identifiers preserve every unique treatment and keep imports single-filed.
    @MainActor
    private func enqueueTherapyImport(_ batch: CareLinkTherapyImportBatch) {
        if pendingTherapyImport?.generation == batch.generation {
            pendingTherapyImport?.merge(batch)
        } else {
            pendingTherapyImport = batch
        }
        startTherapyImportIfNeeded()
    }

    @MainActor
    private func startTherapyImportIfNeeded() {
        guard therapyImportTask == nil, pendingTherapyImport != nil else { return }
        let identifier = UUID()
        therapyImportIdentifier = identifier
        therapyImportTask = Task { [weak self] in
            await self?.drainTherapyImports(identifier: identifier)
        }
    }

    private func drainTherapyImports(identifier: UUID) async {
        while !Task.isCancelled, let batch = await takePendingTherapyImport(identifier: identifier) {
            guard await permitsTherapyImport(generation: batch.generation) else { continue }
            let treatments = batch.treatments
            let importedCount = await therapyImporter.importTreatments(treatments)
            guard !Task.isCancelled else { break }
            guard await permitsTherapyImport(generation: batch.generation) else { continue }
            let importedPumpStatusCount = await therapyImporter.importPumpStatuses(
                batch.pump,
                treatments: treatments,
                metadata: batch.metadata,
                checkedAt: batch.checkedAt
            )
            await publishTherapyImportResult(
                importedCount: importedCount,
                importedPumpStatusCount: importedPumpStatusCount,
                generation: batch.generation
            )
        }
        await finishTherapyImports(identifier: identifier)
    }

    @MainActor
    private func takePendingTherapyImport(identifier: UUID) -> CareLinkTherapyImportBatch? {
        guard therapyImportIdentifier == identifier else { return nil }
        defer { pendingTherapyImport = nil }
        return pendingTherapyImport
    }

    @MainActor
    private func permitsTherapyImport(generation: Int) -> Bool {
        pollIsCurrentOnMain(generation) && UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink
    }

    @MainActor
    private func publishTherapyImportResult(importedCount: Int, importedPumpStatusCount: Int, generation: Int) {
        guard permitsTherapyImport(generation: generation) else { return }
        state.update { snapshot in
            snapshot.importedTreatmentCount = importedCount
            snapshot.lastTherapyImportAt = Date()
            snapshot.importedPumpStatusCount = importedPumpStatusCount
            if importedPumpStatusCount > 0 {
                snapshot.lastPumpHistoryImportAt = Date()
            }
        }
    }

    @MainActor
    private func finishTherapyImports(identifier: UUID) {
        guard therapyImportIdentifier == identifier else { return }
        therapyImportTask = nil
        therapyImportIdentifier = nil
        startTherapyImportIfNeeded()
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
        case .reconnectRequired:
            trace(
                "CareLink OAuth refresh token was rejected",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .error,
                troubleshooting: .standard(.follower(source: .careLink, activity: .sessionExpired))
            )
            await transitionToAwaitingLogin(generation: generation)
            await updateState(generation: generation) {
                $0.status = .loginRequired
                $0.detail = error.localizedDescription
            }
        case .regionMismatch, .notAuthenticated:
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
            await scheduleNewDownload(latestReadingAt: nil, lastDataUpdateAt: nil, generation: generation)
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

    /// Updates the retained deadline from CareLink's latest known data timestamps.
    ///
    /// The first timestamp-aligned implementation recreated a one-shot `Timer` after every poll.
    /// Live background testing on 16 August 2026 showed one such timer disappear while unrelated
    /// app work continued. Keeping one scheduler alive means an early, delayed or missed check does
    /// not discard the only future opportunity; the next check still observes the same deadline.
    @MainActor
    private func scheduleNewDownload(latestReadingAt: Date?, lastDataUpdateAt: Date?, generation: Int) {
        guard pollIsCurrentOnMain(generation) else { return }
        let now = Date()
        let nextPollAt = CareLinkPollingPolicy.nextPollDate(
            latestReadingAt: latestReadingAt,
            lastDataUpdateAt: lastDataUpdateAt,
            now: now
        )
        self.nextPollAt = nextPollAt
        startPollingSchedulerIfNeeded()
        trace(
            "CareLink next polling deadline in %{public}@ seconds",
            log: log,
            category: ConstantsLog.categoryCareLinkFollowManager,
            type: .info,
            troubleshooting: .detailed(.follower(source: .careLink, activity: .retryScheduled)),
            Int(max(0, nextPollAt.timeIntervalSince(now))).description
        )
    }

    /// Starts one persistent local scheduler; its checks never imply a CareLink request.
    ///
    /// `requestPoll` remains the sole network gate and compares `nextPollAt` before doing work. The
    /// scheduler therefore checks locally every 20 seconds while normal CareLink traffic remains
    /// aligned to the expected five-minute data updates. Heartbeat mode supplies its own wakeups.
    @MainActor
    private func startPollingSchedulerIfNeeded() {
        guard CareLinkLifecyclePolicy.permitsPolling(lifecycleState), isActive else {
            stopPollingScheduler()
            return
        }
        guard UserDefaults.standard.followerBackgroundKeepAliveType != .heartbeat else {
            stopPollingScheduler()
            return
        }
        if pollingScheduler == nil {
            pollingScheduler = pollingSchedulerFactory(ConstantsCareLink.schedulerCheckInterval) { [weak self] in
                self?.download()
            }
        }
        guard !pollingSchedulerIsRunning else { return }
        pollingSchedulerIsRunning = true
        pollingScheduler?.resume()
    }

    /// Retains CareLink's service-specific delay for errors and rate limits.
    @MainActor
    private func scheduleRetry(after interval: TimeInterval, generation: Int) {
        guard pollIsCurrentOnMain(generation) else { return }
        let nextPollAt = Date().addingTimeInterval(max(ConstantsCareLink.minimumPollingInterval, interval))
        self.nextPollAt = nextPollAt
        startPollingSchedulerIfNeeded()
    }

    @MainActor
    private func stopPollingScheduler() {
        guard pollingSchedulerIsRunning else { return }
        pollingScheduler?.suspend()
        pollingSchedulerIsRunning = false
    }

    /// Cancels both scheduled and active work so logout/source switching cannot receive a late poll.
    @MainActor
    private func stopPolling() {
        stopPollingScheduler()
        pollingScheduler = nil
        pollTask?.cancel()
        pollTask = nil
        pollIdentifier = nil
        nextPollAt = nil
        lastPollStartedAt = .distantPast
        refreshRequestedWhilePolling = false
        // An active Core Data operation remains serialized until it returns, but no queued work or
        // result from the superseded lifecycle may be published afterward.
        pendingTherapyImport = nil
    }

    // MARK: - Activation and background keep-alive

    /// Reconciles follower selection and secure OAuth-session availability.
    @MainActor
    private func reconcileLifecycle() {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        // Reconciliation is idempotent. Tear down the prior generation before enabling a new one.
        stopPolling()
        backgroundKeepAliveManager.stop(for: .careLink)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let selected = isActive

            if !selected {
                cancelLogin()
                stopPolling()
                backgroundKeepAliveManager.stop(for: .careLink)
                lifecycleState = .inactive
                return
            }

            updateStateOnMain {
                $0.status = .connecting
                $0.detail = nil
                $0.region = self.region
            }
            if let invalidationTask { await invalidationTask.value }
            guard lifecycleGeneration == generation, isActive else { return }
            let hasSession: Bool
            do {
                hasSession = try await client.hasToken()
            } catch {
                guard lifecycleGeneration == generation else { return }
                lifecycleState = .inactive
                updateStateOnMain {
                    $0.status = .error
                    $0.detail = error.localizedDescription
                }
                return
            }
            guard lifecycleGeneration == generation else { return }
            lifecycleState = CareLinkLifecyclePolicy.state(isSelected: true, hasSession: hasSession)
            if lifecycleState == .authenticated {
                backgroundKeepAliveManager.start(for: .careLink)
                startPollingSchedulerIfNeeded()
                if startsInitialDownload {
                    download()
                }
            } else {
                stopPolling()
                backgroundKeepAliveManager.stop(for: .careLink)
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
        backgroundKeepAliveManager.stop(for: .careLink)
        lifecycleState = .invalidatingSession
        if UserDefaults.standard.careLinkSelectedPatientID != nil {
            UserDefaults.standard.careLinkSelectedPatientID = nil
        }
        publishLoginRequired(detail: nil)

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
    }

    private func pollIsCurrent(_ generation: Int) async -> Bool {
        await MainActor.run { self.pollIsCurrentOnMain(generation) }
    }

    private func transitionToAwaitingLogin(generation: Int) async {
        let shouldClear = await MainActor.run {
            guard self.lifecycleGeneration == generation else { return false }
            self.lifecycleState = .awaitingLogin
            self.stopPolling()
            self.backgroundKeepAliveManager.stop(for: .careLink)
            return true
        }
        guard shouldClear else { return }
        await client.clearLocalSession()
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
        case .isMaster, .followerDataSourceType:
            guard keyValueObserverTimeKeeper.verifyKey(forKey: keyPath, withMinimumDelayMilliSeconds: 200) else { return }
            Task { @MainActor [weak self] in self?.reconcileLifecycle() }
        case .careLinkSelectedPatientID:
            refreshNow()
        case .followerBackgroundKeepAliveType:
            Task { @MainActor [weak self] in
                guard let self else { return }
                if UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                    stopPollingScheduler()
                } else {
                    startPollingSchedulerIfNeeded()
                }
            }
        default: break
        }
    }

    /// Removes KVO, timers and lifecycle closures owned by this manager.
    deinit {
        for key in [UserDefaults.Key.isMaster, .followerDataSourceType, .careLinkSelectedPatientID, .followerBackgroundKeepAliveType] {
            UserDefaults.standard.removeObserver(self, forKeyPath: key.rawValue)
        }
        if pollingSchedulerIsRunning {
            pollingScheduler?.suspend()
        }
        pollTask?.cancel()
        therapyImportTask?.cancel()
        let loginController = authController
        Task { @MainActor in loginController?.cancel() }
        backgroundKeepAliveManager.stop(for: .careLink)
    }

}
