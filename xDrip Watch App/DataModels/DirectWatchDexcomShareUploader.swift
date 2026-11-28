//
//  DirectWatchDexcomShareUploader.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 26/11/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CryptoKit
import Foundation
import Security

#if os(iOS)
@testable import xdrip
#endif

/// Uploads Watch-owned readings to Dexcom Share. Store credentials in Keychain and keep each reading
/// with the account, region and receiver selected at collection time.
@MainActor final class DirectWatchDexcomShareUploader {
    // MARK: - Properties

    private static let configurationKey = DirectWatchUploadSettings.dexcomShareConfigurationKey
    private static let credentialsKey = DirectWatchUploadSettings.dexcomShareCredentialsKey
    private static let keychainService = "xdrip.directWatch.dexcomShare"
    private static let maximumPendingReadings = 2016

    var isReady: Bool { uploadStatus?.isReady == true }
    var pendingCount: Int { uploadStatus?.pending ?? 0 }
    private(set) var isUploading = false
    var onStatusChange: (() -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var collectionAllowsUpload: () -> Bool = { true }

    private struct Payload: Codable, Equatable, Sendable {
        let sampleID: String
        let date: Date
        let value: Int
        let trend: Int
        let direction: String

        var dictionary: [String: Any] {
            let milliseconds = Int64(floor(date.timeIntervalSince1970 * 1_000) / 1_000) * 1_000
            let shareDate = "/Date(\(milliseconds))/"
            return ["Trend": trend, "ST": shareDate, "DT": shareDate,
                    "Value": value, "direction": direction]
        }
    }

    private struct Delivery: Codable, Equatable, Sendable {
        let payload: Payload
        let baseURL: String
        let username: String
        let serialNumber: String
        var awaitingReadingCommit: Bool?
        var failures = 0
        var retryAt: Date?
        var uploadedAt: Date?
        var authenticationBlocked = false
        var error: String?
    }

    private struct Store: Codable, Equatable, Sendable {
        var configuration: DirectWatchDexcomShareConfiguration?
        var credentialSaveFailedForRevision: Double?
        var deliveries: [String: Delivery] = [:]
        var lastError: String?
    }

    private struct Account: Equatable {
        let baseURL: String
        let username: String
    }

    private struct ShareError: Error {
        let code: String
        var status: Int? = nil
    }

    private let storeURL: URL
    private let sendRequest: @MainActor (URLRequest) async throws -> (Data, URLResponse)
    private var store = Store()
    private var storageReadFailed = false
    private var session: (account: Account, id: String)?
    private var retryTask: Task<Void, Never>?
    private var uploadStatus: DirectWatchUploadServiceStatus?

    // MARK: - Initialization

    init(directory: URL? = nil, send: @escaping @MainActor (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }) {
        self.sendRequest = send
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        storeURL = base.appendingPathComponent("DirectWatchDexcomShareOutbox.json")
        do {
            store = try JSONDecoder().decode(Store.self, from: Data(contentsOf: storeURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // First launch has no outbox yet.
        } catch {
            storageReadFailed = true
            store.lastError = "Saved Dexcom Share upload queue could not be read"
        }
        publish()
    }

    // MARK: - Configuration and queue

    private var hasUsableConfiguration: Bool {
        guard let configuration = store.configuration, configuration.enabled,
              configuration.revision != store.credentialSaveFailedForRevision,
              let baseURL = configuration.baseURL, let username = configuration.username,
              let serial = configuration.serialNumber, !serial.isEmpty else { return false }
        return loadCredentials(baseURL: baseURL, username: username) != nil
    }

    var canAcceptNewReading: Bool { pendingCount < Self.maximumPendingReadings }
    var isConfiguredToUpload: Bool { store.configuration?.enabled == true }
    var scheduleIsActive: Bool { store.configuration?.scheduleIsOn(at: .now) ?? false }

    func receiveConfiguration(_ payload: [String: Any]) {
        guard !storageReadFailed,
              let data = payload[Self.configurationKey] as? Data, data.count <= 4096,
              let next = try? JSONDecoder().decode(DirectWatchDexcomShareConfiguration.self, from: data),
              next.version == DirectWatchDexcomShareConfiguration.version,
              next.revision.isFinite, next.revision > 0,
              next.baseURL == nil || Self.normalizedBaseURL(next.baseURL) == next.baseURL else { return }
        if let current = store.configuration, next.revision < current.revision { return }
        let credentials = (payload[Self.credentialsKey] as? Data).flatMap { data -> DirectWatchDexcomShareCredentials? in
            guard data.count <= 4096 else { return nil }
            return try? JSONDecoder().decode(DirectWatchDexcomShareCredentials.self, from: data)
        }
        let previous = store.configuration
        let savedCredentials = next.baseURL.flatMap { baseURL in
            next.username.flatMap { loadCredentials(baseURL: baseURL, username: $0) }
        }
        let credentialsChanged = next.enabled && credentials != savedCredentials
        let hadCredentialSaveFailure = store.credentialSaveFailedForRevision != nil
        guard previous != next || credentialsChanged || hadCredentialSaveFailure else {
            uploadNextReading()
            return
        }

        if next.enabled {
            guard let baseURL = next.baseURL, let username = next.username,
                  let serial = next.serialNumber, !serial.isEmpty,
                  let credentials, credentials.username == username,
                  !credentialsChanged || saveCredentials(credentials, baseURL: baseURL, username: username) else {
                store.configuration = next
                store.credentialSaveFailedForRevision = next.revision
                store.lastError = "Dexcom Share credentials could not be saved"
                diagnose("Configuration not ready: credentials missing or Keychain write failed")
                _ = save()
                publish()
                return
            }
        }
        if hadCredentialSaveFailure { store.lastError = nil }
        store.credentialSaveFailedForRevision = nil
        store.configuration = next
        if credentialsChanged, session?.account.baseURL == next.baseURL, session?.account.username == next.username {
            session = nil
        }
        if next.enabled && (credentialsChanged || hadCredentialSaveFailure || previous?.enabled != true
            || previous?.baseURL != next.baseURL || previous?.username != next.username || previous?.serialNumber != next.serialNumber) {
            // Queued readings retain their original account. Changes can unblock only that account's deliveries.
            for id in store.deliveries.keys where store.deliveries[id]?.baseURL == next.baseURL
                && store.deliveries[id]?.username == next.username {
                store.deliveries[id]?.authenticationBlocked = false
                store.deliveries[id]?.retryAt = nil
            }
        }
        diagnose("Configuration applied: enabled=\(next.enabled), scheduleActive=\(scheduleIsActive), pending=\(pendingCount)")
        _ = save()
        publish()
        uploadNextReading()
    }

    func shouldOwnNewReading(collectedAt: Date, phoneReachable: Bool, phoneSyncDisabled: Bool) -> Bool {
        guard (!phoneReachable || phoneSyncDisabled), let configuration = store.configuration else { return false }
        return DirectWatchUploadRouting.shouldOwnReading(enabled: configuration.enabled,
            configurationReady: hasUsableConfiguration, queueHasCapacity: canAcceptNewReading,
            collectedAt: collectedAt, enabledSince: configuration.enabledSince)
    }

    /// Save the pending upload before the collector marks the reading as Watch-owned.
    /// Wait for the collector to save the reading before sending it.
    @discardableResult func stageReading(_ reading: DirectWatchReading, alongside readings: [DirectWatchReading]) -> Bool {
        guard reading.isUsable, let configuration = store.configuration, configuration.enabled,
              let baseURL = configuration.baseURL, let username = configuration.username,
              let serialNumber = configuration.serialNumber, !serialNumber.isEmpty,
              let credentials = loadCredentials(baseURL: baseURL, username: username),
              let collectedAt = reading.collectedAt, collectedAt >= configuration.enabledSince,
              store.deliveries[reading.id] == nil else { return false }
        guard canAcceptNewReading else {
            store.lastError = "Dexcom Share upload queue is full"
            publish()
            return false
        }
        let previous = readings.first { $0.measuredAt < reading.measuredAt
            && $0.transmitterID == reading.transmitterID
            && $0.sensorStartCounter == reading.sensorStartCounter
            && $0.family == reading.family }
        let slope: Double
        if let previous {
            let minutes = reading.measuredAt.timeIntervalSince(previous.measuredAt) / 60
            slope = minutes > 0 && minutes <= 10 ? (reading.mgDl - previous.mgDl) / minutes : 0
        } else {
            slope = 0
        }
        let trend = Self.trend(for: slope)
        let payload = Payload(sampleID: reading.id, date: reading.measuredAt,
                              value: Int(reading.mgDl.rounded()), trend: trend.ordinal, direction: trend.direction)
        store.deliveries[reading.id] = Delivery(payload: payload, baseURL: baseURL, username: credentials.username,
            serialNumber: serialNumber, awaitingReadingCommit: true)
        guard save() else {
            store.deliveries.removeValue(forKey: reading.id)
            publish()
            return false
        }
        return true
    }

    /// If the app stops between the two saves, keep only uploads whose ownership was saved by the collector.
    func reconcileStagedReadings(committedIDs: Set<String>) {
        let staged = store.deliveries.values.filter { $0.awaitingReadingCommit == true }.map(\.payload.sampleID)
        guard !staged.isEmpty else { return }
        for id in staged {
            if committedIDs.contains(id) { store.deliveries[id]?.awaitingReadingCommit = nil }
            else { store.deliveries.removeValue(forKey: id) }
        }
        _ = save()
        publish()
    }

    func readingStatus(for reading: DirectWatchReading) -> DirectWatchServiceReadingStatus {
        guard let delivery = store.deliveries[reading.id] else { return isReady ? .notTracked : .disabled }
        if delivery.uploadedAt != nil { return .uploaded }
        if delivery.authenticationBlocked || delivery.error != nil { return .error }
        return .pending
    }

    var statusPayload: [String: Any] { uploadStatus?.payload ?? [:] }

    func retryPendingUploads() {
        uploadNextReading()
        if !isUploading { scheduleRetry() }
    }

    // MARK: - Delivery

    private func uploadNextReading() {
        guard collectionAllowsUpload(), !isUploading, let configuration = store.configuration, configuration.enabled,
              configuration.revision != store.credentialSaveFailedForRevision,
              configuration.scheduleIsOn(at: .now), let delivery = nextDelivery() else { return }
        guard let credentials = loadCredentials(baseURL: delivery.baseURL, username: delivery.username) else {
            fail(delivery, "Dexcom Share credentials unavailable", authentication: true)
            return
        }
        isUploading = true
        let revision = configuration.revision
        Task { [weak self] in
            await self?.upload(delivery, credentials: credentials, revision: revision)
        }
    }

    private func upload(_ delivery: Delivery, credentials: DirectWatchDexcomShareCredentials, revision: Double) async {
        do {
            var sessionID = try await authenticate(delivery, credentials: credentials, revision: revision)
            var renewedSession = false
            var restartedMonitoring = false
            while true {
                do {
                    try await post(delivery, sessionID: sessionID, revision: revision)
                    break
                } catch let error as ShareError where error.code == "DuplicateEgvPosted" {
                    // Share already has this reading. Clear the queued retry.
                    diagnose("Server reported duplicate: measuredAt=\(delivery.payload.date.ISO8601Format())")
                    break
                } catch let error as ShareError where ["SessionNotValid", "SessionIdNotFound"].contains(error.code) && !renewedSession {
                    renewedSession = true
                    diagnose("Renewing expired Share session")
                    sessionID = try await authenticate(delivery, credentials: credentials, revision: revision, force: true)
                } catch let error as ShareError where error.code == "MonitoringSessionNotActive" && !restartedMonitoring {
                    restartedMonitoring = true
                    diagnose("Restarting remote monitoring")
                    try await startMonitoring(delivery, sessionID: sessionID, revision: revision)
                }
            }
            // Save the accepted result for this reading even if settings changed while the POST was in flight.
            complete(delivery, error: nil, authentication: false)
        } catch {
            if error is CancellationError || store.configuration?.revision != revision {
                isUploading = false
                publish()
                uploadNextReading()
                return
            }
            let authentication = (error as? ShareError).map {
                ["SSO_AuthenticateAccountNotFound", "SSO_AuthenticatePasswordInvalid"].contains($0.code)
            } ?? false
            complete(delivery, error: Self.diagnosticCode(error), authentication: authentication)
        }
    }

    /// Recheck collection, schedule and settings before each request. Any of them can change during login.
    private func requireCurrentConfiguration(_ revision: Double) throws {
        guard collectionAllowsUpload(), let configuration = store.configuration,
              configuration.enabled, configuration.revision == revision,
              revision != store.credentialSaveFailedForRevision, configuration.scheduleIsOn(at: .now) else {
            throw CancellationError()
        }
    }

    private func authenticate(_ delivery: Delivery, credentials: DirectWatchDexcomShareCredentials,
                              revision: Double, force: Bool = false) async throws -> String {
        try requireCurrentConfiguration(revision)
        let account = Account(baseURL: delivery.baseURL, username: delivery.username)
        // The next queued reading may belong to a different account or region.
        if !force, let session, session.account == account { return session.id }
        if force { session = nil }
        let accountData = try await request(delivery, revision: revision, path: ConstantsDexcomShare.dexcomShareFollowAuthPath,
            body: ["accountName": credentials.username, "password": credentials.password,
                   "applicationId": ConstantsDexcomShare.applicationId], authentication: true)
        let accountID = try decodeIdentifier(accountData)
        let loginData = try await request(delivery, revision: revision, path: ConstantsDexcomShare.dexcomShareFollowLoginPath,
            body: ["accountId": accountID, "password": credentials.password,
                   "applicationId": ConstantsDexcomShare.applicationId], authentication: true)
        let newSession = try decodeIdentifier(loginData)
        try requireCurrentConfiguration(revision)
        session = (account, newSession)
        return newSession
    }

    private func startMonitoring(_ delivery: Delivery, sessionID: String, revision: Double) async throws {
        _ = try await request(delivery, revision: revision, path: ConstantsDexcomShare.dexcomShareUploadStartRemoteMonitoringSessionPath,
            query: [URLQueryItem(name: "sessionId", value: sessionID),
                    URLQueryItem(name: "serialNumber", value: delivery.serialNumber)])
    }

    private func post(_ delivery: Delivery, sessionID: String, revision: Double) async throws {
        let body: [String: Any] = ["Egvs": [delivery.payload.dictionary], "SN": delivery.serialNumber, "TA": -5]
        _ = try await request(delivery, revision: revision, path: ConstantsDexcomShare.dexcomShareUploadPostReceiverEgvRecordsPath,
            body: body, query: [URLQueryItem(name: "sessionId", value: sessionID)])
    }

    private func request(_ delivery: Delivery, revision: Double, path: String, body: [String: Any]? = nil,
                         query: [URLQueryItem] = [], authentication: Bool = false) async throws -> Data {
        try requireCurrentConfiguration(revision)
        guard let base = URL(string: delivery.baseURL),
              let url = URLComponents(url: base.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false)?.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ShareError(code: "InvalidURL")
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let requestURL = components.url else { throw ShareError(code: "InvalidURL") }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authentication
            ? "Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0"
            : "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try body.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        let measuredAt = delivery.payload.date.ISO8601Format()
        let startedAt = Date()
        diagnose("POST \(path) started: measuredAt=\(measuredAt)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await sendRequest(request)
        } catch {
            diagnose("POST \(path) failed: measuredAt=\(measuredAt), error=\(Self.diagnosticCode(error))")
            throw error
        }
        guard let http = response as? HTTPURLResponse else { throw ShareError(code: "InvalidResponse") }
        diagnose("POST \(path) finished: measuredAt=\(measuredAt), HTTP=\(http.statusCode), elapsedMs=\(Int(Date().timeIntervalSince(startedAt) * 1_000))")
        guard (200...299).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw ShareError(code: json?["Code"] as? String ?? "HTTP \(http.statusCode)", status: http.statusCode)
        }
        return data
    }

    private func decodeIdentifier(_ data: Data) throws -> String {
        guard let value = try? JSONDecoder().decode(String.self, from: data),
              UUID(uuidString: value) != nil, value != ConstantsDexcomShare.failedSessionId else {
            throw ShareError(code: "InvalidLoginResponse")
        }
        return value
    }

    private func nextDelivery() -> Delivery? {
        store.deliveries.values.filter {
            $0.awaitingReadingCommit != true && $0.uploadedAt == nil && !$0.authenticationBlocked
                && ($0.retryAt.map { $0 <= .now } ?? true)
        }.min { $0.payload.date < $1.payload.date }
    }

    private func fail(_ delivery: Delivery, _ message: String, authentication: Bool) {
        guard var current = store.deliveries[delivery.payload.sampleID] else { return }
        current.failures += 1
        current.error = message
        current.authenticationBlocked = authentication
        current.retryAt = authentication ? nil : Date().addingTimeInterval(DirectWatchUploadRetry.delay(afterFailures: current.failures))
        store.deliveries[delivery.payload.sampleID] = current
        store.lastError = message
        _ = save()
        let retry = current.retryAt?.ISO8601Format() ?? "blocked pending settings change"
        diagnose("Delivery failed: measuredAt=\(delivery.payload.date.ISO8601Format()), retryAt=\(retry), error=\(message)")
        publish()
    }

    private func complete(_ delivery: Delivery, error: String?, authentication: Bool) {
        isUploading = false
        if let error {
            fail(delivery, error, authentication: authentication)
        } else {
            if var current = store.deliveries[delivery.payload.sampleID] {
                current.uploadedAt = .now
                current.error = nil
                current.authenticationBlocked = false
                current.retryAt = nil
                store.deliveries[delivery.payload.sampleID] = current
                store.lastError = nil
                trimDeliveredHistory()
                _ = save()
            }
            diagnose("Delivery accepted: measuredAt=\(delivery.payload.date.ISO8601Format())")
        }
        publish()
        uploadNextReading()
    }

    // MARK: - Status and retries

    private func publish() {
        let ready = hasUsableConfiguration
        let pending = store.deliveries.values.filter { $0.awaitingReadingCommit != true && $0.uploadedAt == nil }.count
        let failed = store.lastError != nil || store.deliveries.values.contains { $0.uploadedAt == nil && $0.error != nil }
        uploadStatus = DirectWatchUploadServiceStatus(service: .dexcomShare, isReady: ready,
            pending: pending, hasError: failed, lastUpload: store.deliveries.values.compactMap(\.uploadedAt).max())
        scheduleRetry()
        onStatusChange?()
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = nil
        guard collectionAllowsUpload(), !isUploading, let configuration = store.configuration, configuration.enabled,
              configuration.revision != store.credentialSaveFailedForRevision,
              let next = store.deliveries.values.filter({ $0.awaitingReadingCommit != true && $0.uploadedAt == nil && !$0.authenticationBlocked })
                .min(by: { ($0.retryAt ?? .distantPast) < ($1.retryAt ?? .distantPast) }) else { return }
        let retryDelay = max(1, (next.retryAt ?? .now).timeIntervalSinceNow)
        let delay = configuration.scheduleIsOn(at: .now) ? min(retryDelay, DirectWatchUploadRetry.maximumDelay)
            : DirectWatchUploadRetry.scheduleCheckInterval
        retryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
            guard let self else { return }
            self.uploadNextReading()
            if !self.isUploading { self.scheduleRetry() }
        }
    }

    // MARK: - Storage

    @discardableResult private func save() -> Bool {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(store).write(to: storeURL, options: .atomic)
            return true
        } catch {
            store.lastError = "Dexcom Share upload state could not be saved"
            diagnose("Upload state could not be saved: errorCode=\((error as NSError).code)")
            return false
        }
    }

    private func trimDeliveredHistory() {
        let sent = store.deliveries.filter { $0.value.uploadedAt != nil }
            .sorted { ($0.value.uploadedAt ?? .distantPast) > ($1.value.uploadedAt ?? .distantPast) }
        for (id, _) in sent.dropFirst(Self.maximumPendingReadings) { store.deliveries.removeValue(forKey: id) }
    }

    // MARK: - Keychain

    private func saveCredentials(_ credentials: DirectWatchDexcomShareCredentials, baseURL: String, username: String) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        let account = Self.keychainAccount(baseURL: baseURL, username: username)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Self.keychainService,
                                    kSecAttrAccount as String: account]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func loadCredentials(baseURL: String, username: String) -> DirectWatchDexcomShareCredentials? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Self.keychainService,
                                    kSecAttrAccount as String: Self.keychainAccount(baseURL: baseURL, username: username),
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(DirectWatchDexcomShareCredentials.self, from: data)
    }

    private static func keychainAccount(baseURL: String, username: String) -> String {
        SHA256.hash(data: Data("\(baseURL)|\(username)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedBaseURL(_ value: String?) -> String? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Payload and diagnostics

    private static func trend(for slope: Double) -> (ordinal: Int, direction: String) {
        switch slope {
        case ...(-3.5): return (7, "DoubleDown")
        case ...(-2): return (6, "SingleDown")
        case ...(-1): return (5, "FortyFiveDown")
        case ...1: return (4, "Flat")
        case ...2: return (3, "FortyFiveUp")
        case ...3.5: return (2, "SingleUp")
        default: return (1, "DoubleUp")
        }
    }

    private static func diagnosticCode(_ error: Error) -> String {
        if let error = error as? ShareError {
            let known = ["DuplicateEgvPosted", "SessionNotValid", "SessionIdNotFound", "MonitoringSessionNotActive",
                         "MonitoredReceiverSerialNumberDoesNotMatch", "MonitoredReceiverNotAssigned",
                         "SSO_AuthenticateAccountNotFound", "SSO_AuthenticatePasswordInvalid"]
            return known.contains(error.code) ? (error.status.map { "HTTP \($0) " } ?? "") + error.code
                : error.status.map { "HTTP \($0)" } ?? "Unrecognized Dexcom error"
        }
        let error = error as NSError
        return "\(error.domain == NSURLErrorDomain ? "Network" : "NSError") code=\(error.code)"
    }

    private func diagnose(_ message: String) { onDiagnostic?(message) }
}
