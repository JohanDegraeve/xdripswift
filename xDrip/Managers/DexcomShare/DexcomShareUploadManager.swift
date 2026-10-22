import Combine
import Foundation
import os

/// Upload diagnostics belong to this manager, not the Dexcom Share follower session.
/// They deliberately start unchecked each launch; the persisted upload cursor is a reading date.
final class DexcomShareUploadState: ObservableObject {
    @Published var isChecking = false
    @Published var lastConnection: Date?
    @Published var lastUpload: Date?
    @Published var authenticationError: String?
    @Published var uploadError: String?

    func reset() {
        isChecking = false
        lastConnection = nil
        lastUpload = nil
        authenticationError = nil
        uploadError = nil
    }
}

struct DexcomShareUploadBatch {
    let readings: [[String: Any]]
    let latestReading: Date
}

/// Owns automatic uploading and the read-only account check used by Settings.
/// Main-actor ownership keeps Core Data access, session changes and UI diagnostics serialized.
@MainActor final class DexcomShareUploadManager: NSObject {
    // MARK: - Properties

    /// Connection and upload activity for Settings; no account identifiers are exposed.
    let state: DexcomShareUploadState
    private let defaults: UserDefaults
    private let session: URLSession
    private let messageHandler: ((String, String) -> Void)?
    private let activityHandler: (TroubleshootingLogEntry) -> Void
    private let makeBatch: (Date, Date?) -> DexcomShareUploadBatch?
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDexcomShareUploadManager)
    private var sessionId: String?
    /// Shared by automatic uploads and manual checks so only one login is in flight.
    private var loginTask: Task<String, Error>?
    private var loginTaskID: UUID?
    private var uploadTask: Task<Void, Never>?
    /// Invalidates responses started before the account, mode or enable setting changed.
    private var generation = UUID()
    private var configuration: Configuration
    private let observedKeys: [UserDefaults.Key] = [
        .dexcomShareAccountName, .dexcomSharePassword, .useUSDexcomShareurl,
        .uploadReadingstoDexcomShare, .dexcomShareUploadSerialNumber,
        .dexcomShareUploadUseSchedule, .dexcomShareUploadSchedule, .isMaster
    ]

    private struct Configuration: Equatable {
        let username: String?
        let password: String?
        let serialNumber: String?
        let useUS: Bool
        let enabled: Bool
        let master: Bool

        init(_ defaults: UserDefaults) {
            username = defaults.dexcomShareAccountName
            password = defaults.dexcomSharePassword
            serialNumber = defaults.dexcomShareUploadSerialNumber
            useUS = defaults.useUSDexcomShareurl
            enabled = defaults.uploadReadingstoDexcomShare
            master = defaults.isMaster
        }

        var canAuthenticate: Bool {
            enabled && master && username?.isEmpty == false && password?.isEmpty == false
        }

        var baseURL: URL {
            URL(string: useUS ? ConstantsDexcomShare.usBaseShareUrl : ConstantsDexcomShare.globalBaseShareUrl)!
        }
    }

    // MARK: - Initializers

    convenience init(bgReadingsAccessor: BgReadingsAccessor, state: DexcomShareUploadState? = nil, messageHandler: ((String, String) -> Void)?) {
        self.init(state: state, messageHandler: messageHandler) { fromDate, lastConnectionChange in
            let readings = bgReadingsAccessor.getLatestBgReadings(
                limit: nil, fromDate: fromDate, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false
            ).filter(
                minimumTimeBetweenTwoReadingsInMinutes: ConstantsDexcomShare.minimiumTimeBetweenTwoReadingsInMinutes,
                lastConnectionStatusChangeTimeStamp: lastConnectionChange,
                timeStampLastProcessedBgReading: fromDate
            )
            guard let latest = readings.first else { return nil }
            return DexcomShareUploadBatch(
                readings: readings.map { $0.dictionaryRepresentationForDexcomShareUpload },
                latestReading: latest.timeStamp
            )
        }
    }

    /// Inject networking and value snapshots for focused tests without accessing real accounts or Core Data.
    init(
        defaults: UserDefaults = .standard,
        session: URLSession = .shared,
        state: DexcomShareUploadState? = nil,
        messageHandler: ((String, String) -> Void)? = nil,
        activityHandler: @escaping (TroubleshootingLogEntry) -> Void = { TroubleshootingLogStore.shared.record($0) },
        makeBatch: @escaping (Date, Date?) -> DexcomShareUploadBatch?
    ) {
        self.defaults = defaults
        self.session = session
        self.state = state ?? DexcomShareUploadState()
        self.messageHandler = messageHandler
        self.makeBatch = makeBatch
        self.activityHandler = activityHandler
        configuration = Configuration(defaults)
        super.init()
        for key in observedKeys {
            defaults.addObserver(self, forKeyPath: key.rawValue, options: .new, context: nil)
        }
    }

    deinit {
        for key in observedKeys { defaults.removeObserver(self, forKeyPath: key.rawValue) }
        loginTask?.cancel()
        uploadTask?.cancel()
    }

    // MARK: - Settings and account checks

    nonisolated override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let changed = self.reconcileConfiguration()
            // Account verification is independent of serial-number readiness and the upload schedule.
            // Coalesced KVO callbacks must not trigger a second login after the first check finishes.
            if changed && self.configuration.canAuthenticate { await self.checkAccount(force: false) }
            // Settings still automatically trigger uploading; schedule edits never bypass the schedule.
            self.uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: Date())
        }
    }

    /// Verifies credentials only. It never posts glucose or starts remote monitoring.
    func testConnection() async {
        reconcileConfiguration()
        guard configuration.canAuthenticate else { return }
        await checkAccount(force: true)
    }

    private func checkAccount(force: Bool) async {
        let currentGeneration = generation
        do {
            _ = try await authenticate(configuration, generation: currentGeneration, force: force)
        } catch {
            recordAuthenticationError(error, generation: currentGeneration)
        }
    }

    func uploadLatestBgReadings(lastConnectionStatusChangeTimeStamp: Date?) {
        reconcileConfiguration()
        guard uploadTask == nil, canUpload else { return }
        let currentGeneration = generation
        uploadTask = Task { [weak self] in
            guard let self else { return }
            await self.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
            if self.generation == currentGeneration { self.uploadTask = nil }
        }
    }

    private var canUpload: Bool {
        configuration.canAuthenticate && configuration.serialNumber?.isEmpty == false && scheduleIsOn
    }

    private var scheduleIsOn: Bool {
        !defaults.dexcomShareUploadUseSchedule || defaults.dexcomShareUploadSchedule?.indicatesOn(forWhen: Date()) != false
    }

    @discardableResult private func reconcileConfiguration() -> Bool {
        let updated = Configuration(defaults)
        guard configuration != updated else { return false }
        if configuration.enabled != updated.enabled {
            activityHandler(.standard(.configuration(.dexcomShareUploadChanged(enabled: updated.enabled))))
        }
        configuration = updated
        generation = UUID()
        sessionId = nil
        loginTask?.cancel()
        loginTask = nil
        loginTaskID = nil
        uploadTask?.cancel()
        uploadTask = nil
        state.reset()
        return true
    }

    /// Compare the actual settings as well as the generation: KVO delivery can be queued behind a response.
    private func requireCurrent(_ config: Configuration, generation: UUID) throws {
        guard self.generation == generation, Configuration(defaults) == config, !Task.isCancelled else {
            throw CancellationError()
        }
    }

    private func authenticate(_ config: Configuration, generation: UUID, force: Bool = false) async throws -> String {
        try requireCurrent(config, generation: generation)
        if let loginTask { return try await loginTask.value }
        if !force, let sessionId { return sessionId }
        let taskID = UUID()
        state.isChecking = true
        let task = Task { () throws -> String in
            let accountData = try await self.request(
                config, path: ConstantsDexcomShare.dexcomShareFollowAuthPath,
                body: ["accountName": config.username!, "password": config.password!, "applicationId": ConstantsDexcomShare.applicationId],
                generation: generation, authentication: true
            )
            let accountID = try self.decodeIdentifier(accountData)
            let loginData = try await self.request(
                config, path: ConstantsDexcomShare.dexcomShareFollowLoginPath,
                body: ["accountId": accountID, "password": config.password!, "applicationId": ConstantsDexcomShare.applicationId],
                generation: generation, authentication: true
            )
            return try self.decodeIdentifier(loginData)
        }
        loginTask = task
        loginTaskID = taskID
        defer {
            if loginTaskID == taskID {
                loginTask = nil
                loginTaskID = nil
                state.isChecking = false
            }
        }
        let result = try await task.value
        try requireCurrent(config, generation: generation)
        sessionId = result
        // A valid account does not resolve a previous upload or receiver error.
        state.authenticationError = nil
        state.lastConnection = Date()
        activityHandler(.detailed(.integration(name: .dexcomShareUploadAccount, activity: .succeeded(itemCount: nil))))
        trace("Dexcom Share upload account verified", log: log, category: ConstantsLog.categoryDexcomShareUploadManager, type: .info)
        return result
    }

    // MARK: - Uploading

    /// Preserves the existing reading cursor and filtering. Acceptance time is tracked separately for the UI.
    func uploadIfNeeded(lastConnectionStatusChangeTimeStamp: Date?) async {
        reconcileConfiguration()
        guard canUpload else { return }
        let config = configuration
        let currentGeneration = generation
        do {
            var token: String
            do {
                token = try await authenticate(config, generation: currentGeneration)
            } catch {
                recordAuthenticationError(error, generation: currentGeneration)
                return
            }
            try requireCurrent(config, generation: currentGeneration)
            guard canUpload else { return }
            // A cursor from months ago must not turn the intended eight-hour upload into tens of
            // thousands of readings (HTTP 413). Keep the stored cursor until an upload is accepted.
            let earliest = Date(timeIntervalSinceNow: -8 * 60 * 60)
            let fromDate = max(defaults.timeStampLatestDexcomShareUploadedBgReading ?? earliest, earliest)
            guard let batch = makeBatch(fromDate, lastConnectionStatusChangeTimeStamp), !batch.readings.isEmpty else { return }
            let body: [String: Any] = ["Egvs": batch.readings, "SN": config.serialNumber!, "TA": -5]
            let uploadStartedAt = Date()
            var retriedSession = false
            var restartedMonitoring = false
            while true {
                try requireCurrent(config, generation: currentGeneration)
                guard scheduleIsOn else { return }
                do {
                    _ = try await request(
                        config, path: ConstantsDexcomShare.dexcomShareUploadPostReceiverEgvRecordsPath,
                        body: body, query: [.init(name: "sessionId", value: token)], generation: currentGeneration
                    )
                    break
                } catch let error as ShareError {
                    if error.code == "DuplicateEgvPosted" { break }
                    if ["SessionNotValid", "SessionIdNotFound"].contains(error.code), !retriedSession {
                        retriedSession = true
                        trace("Dexcom Share upload retry: renewing expired session", log: log,
                              category: ConstantsLog.categoryDexcomShareUploadManager, type: .debug)
                        sessionId = nil
                        do {
                            token = try await authenticate(config, generation: currentGeneration, force: true)
                        } catch {
                            recordAuthenticationError(error, generation: currentGeneration)
                            return
                        }
                    } else if error.code == "MonitoringSessionNotActive", !restartedMonitoring {
                        restartedMonitoring = true
                        trace("Dexcom Share upload recovery: starting monitoring session", log: log,
                              category: ConstantsLog.categoryDexcomShareUploadManager, type: .debug)
                        _ = try await request(
                            config, path: ConstantsDexcomShare.dexcomShareUploadStartRemoteMonitoringSessionPath,
                            query: [.init(name: "sessionId", value: token), .init(name: "serialNumber", value: config.serialNumber!)],
                            generation: currentGeneration
                        )
                    } else {
                        throw error
                    }
                }
            }
            try requireCurrent(config, generation: currentGeneration)
            defaults.timeStampLatestDexcomShareUploadedBgReading = batch.latestReading
            state.lastConnection = Date()
            state.lastUpload = state.lastConnection
            state.uploadError = nil
            activityHandler(.detailed(.integration(name: .dexcomShareUpload, activity: .succeeded(itemCount: batch.readings.count))))
            trace("Dexcom Share upload accepted: readings=%{public}@ newest=%{public}@ elapsedMs=%{public}@", log: log,
                  category: ConstantsLog.categoryDexcomShareUploadManager, type: .info,
                  batch.readings.count.description, batch.latestReading.ISO8601Format(),
                  Int(Date().timeIntervalSince(uploadStartedAt) * 1_000).description)
        } catch {
            guard isCurrent(currentGeneration), !(error is CancellationError) else { return }
            state.uploadError = errorMessage(error)
            activityHandler(.standard(.integration(name: .dexcomShareUpload, activity: .failed)))
            trace("Dexcom Share upload failed: %{public}@", log: log,
                  category: ConstantsLog.categoryDexcomShareUploadManager, type: .error, Self.diagnosticCode(for: error))
            if let error = error as? ShareError,
               ["MonitoredReceiverSerialNumberDoesNotMatch", "MonitoredReceiverNotAssigned"].contains(error.code) {
                messageHandler?(Texts_DexcomShareTestResult.uploadErrorWarning, errorMessage(error))
            }
        }
    }

    private func isCurrent(_ generation: UUID) -> Bool {
        self.generation == generation && Configuration(defaults) == configuration
    }

    private func recordAuthenticationError(_ error: Error, generation: UUID) {
        guard isCurrent(generation), !(error is CancellationError) else { return }
        state.authenticationError = errorMessage(error)
        activityHandler(.standard(.integration(name: .dexcomShareUploadAccount, activity: .failed)))
        trace("Dexcom Share upload account verification failed: %{public}@", log: log,
              category: ConstantsLog.categoryDexcomShareUploadManager, type: .error, Self.diagnosticCode(for: error))
        sessionId = nil
    }

    // MARK: - Requests and errors

    private struct ShareError: Error {
        let code: String
        var httpStatus: Int? = nil
    }

    /// Only known codes are safe to put in developer traces. Error descriptions, userInfo,
    /// unknown domains and server-provided text can contain request URLs or account/session details.
    static func diagnosticCode(for error: Error) -> String {
        if let error = error as? ShareError {
            let status = error.httpStatus.map { "HTTP \($0)" }
            switch error.code.lowercased() {
            case "duplicateegvposted", "sessionnotvalid", "sessionidnotfound", "monitoringsessionnotactive",
                 "monitoredreceiverserialnumberdoesnotmatch", "monitoredreceivernotassigned",
                 "sso_authenticateaccountnotfound", "sso_authenticatepasswordinvalid",
                 "sso_authenticatemaxattemptsexceeed", "sso_authenticatemaxattemptsexceeded",
                 "invalidloginresponse", "invalidresponse":
                return [status, error.code].compactMap { $0 }.joined(separator: " ")
            default:
                return status ?? "Unrecognized Dexcom error"
            }
        }
        let error = error as NSError
        let domain = [NSURLErrorDomain, NSCocoaErrorDomain, NSPOSIXErrorDomain].contains(error.domain) ? error.domain : "NSError"
        return "\(domain) code=\(error.code)"
    }

    private func decodeIdentifier(_ data: Data) throws -> String {
        guard let value = try? JSONDecoder().decode(String.self, from: data),
              UUID(uuidString: value) != nil, value != ConstantsDexcomShare.failedSessionId else {
            throw ShareError(code: "InvalidLoginResponse")
        }
        return value
    }

    private func request(
        _ config: Configuration, path: String, body: [String: Any]? = nil,
        query: [URLQueryItem] = [], generation: UUID, authentication: Bool = false
    ) async throws -> Data {
        try requireCurrent(config, generation: generation)
        var components = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            authentication ? "Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0" : "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = try body.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        trace("Dexcom Share request started: %{public}@", log: log,
              category: ConstantsLog.categoryDexcomShareUploadManager, type: .debug, path)
        let requestStartedAt = Date()
        do {
            let (data, response) = try await session.data(for: request)
            try requireCurrent(config, generation: generation)
            guard let response = response as? HTTPURLResponse else { throw ShareError(code: "InvalidResponse") }
            // An empty body is only successful with a successful HTTP status. Never advance the cursor on HTTP errors.
            guard (200...299).contains(response.statusCode) else {
                let code = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                throw ShareError(code: code?["Code"] as? String ?? "HTTP \(response.statusCode)", httpStatus: response.statusCode)
            }
            return data
        } catch {
            // Settings changes deliberately cancel obsolete requests; those are not service failures.
            if isCurrent(generation), !(error is CancellationError) {
                trace("Dexcom Share request failed: %{public}@ %{public}@ elapsedMs=%{public}@", log: log,
                      category: ConstantsLog.categoryDexcomShareUploadManager, type: .error,
                      path, Self.diagnosticCode(for: error), Int(Date().timeIntervalSince(requestStartedAt) * 1_000).description)
            }
            throw error
        }
    }

    private func errorMessage(_ error: Error) -> String {
        guard let error = error as? ShareError else {
            // Use the localized message for Settings; developer traces only use diagnosticCode.
            return (error as NSError).localizedDescription
        }
        switch error.code.lowercased() {
        case "sso_authenticateaccountnotfound", "sso_authenticatepasswordinvalid":
            return Texts_Common.invalidAccountOrPassword
        case "sso_authenticatemaxattemptsexceeed", "sso_authenticatemaxattemptsexceeded":
            return Texts_DexcomShareTestResult.authenticateMaxAttemptsExceeded
        case "monitoredreceiverserialnumberdoesnotmatch":
            return Texts_DexcomShareTestResult.monitoredReceiverSNDoesNotMatch
        case "monitoredreceivernotassigned":
            return Texts_SettingsView.shareUploadReceiverNotAssigned
        case "http 413":
            return Texts_SettingsView.shareUploadTooLarge
        default:
            return Texts_SettingsView.followerConnectionFailed
        }
    }
}
