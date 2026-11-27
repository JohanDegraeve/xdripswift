//
//  DirectWatchNightscoutUploader.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 14/11/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CryptoKit
import Foundation
import Security

#if os(iOS)
@testable import xdrip
#endif

/// Uploads Watch-owned readings to Nightscout. The Watch keeps the queue and retries locally.
/// The iPhone gets the ownership flag with each reading and a summary in the normal Watch status message.
@MainActor final class DirectWatchNightscoutUploader {
    // MARK: - Properties

    private static let configurationKey = DirectWatchUploadSettings.nightscoutConfigurationKey
    private static let credentialsKey = DirectWatchUploadSettings.nightscoutCredentialsKey
    private static let keychainService = "xdrip.directWatch.nightscout"
    private static let maxPendingReadings = 2016
    private static let maxRetainedDeliveredReadings = 2016
    private static let retryDelays: [TimeInterval] = [30, 60, 120, 300, 900]

    var isReady: Bool { uploadStatus?.isReady == true }
    var pendingCount: Int { uploadStatus?.pending ?? 0 }
    var onStatusChange: (() -> Void)?
    private var uploadStatus: DirectWatchUploadServiceStatus?
    var onDiagnostic: ((String) -> Void)?
    var collectionAllowsUpload: () -> Bool = { true }
    var isConfiguredToUpload: Bool { store.configuration?.enabled == true }
    var scheduleIsActive: Bool { store.configuration?.scheduleIsOn(at: .now) ?? false }
    private var hasUsableConfiguration: Bool {
        guard let configuration = store.configuration, configuration.enabled,
              configuration.revision != store.credentialSaveFailedForRevision,
              let destination = configuration.destination,
              loadCredentials(destination: destination) != nil else { return false }
        return true
    }
    var canAcceptNewReading: Bool { pendingCount < Self.maxPendingReadings }

    func shouldOwnNewReading(collectedAt: Date, phoneReachable: Bool, phoneSyncDisabled: Bool) -> Bool {
        guard (!phoneReachable || phoneSyncDisabled), let configuration = store.configuration else { return false }
        return DirectWatchUploadRouting.shouldOwnReading(enabled: configuration.enabled,
            configurationReady: hasUsableConfiguration, queueHasCapacity: canAcceptNewReading,
            collectedAt: collectedAt, enabledSince: configuration.enabledSince)
    }

    private struct Payload: Codable, Equatable, Sendable {
        let sampleID: String
        let date: Date
        let value: Int
        let direction: String
        let device: String

        var dictionary: [String: Any] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let stamp = formatter.string(from: date)
            return ["_id": DirectWatchNightscoutUploader.stableNightscoutID(sampleID), "date": Int64((date.timeIntervalSince1970 * 1000).rounded()),
                    "dateString": stamp, "sysTime": stamp, "type": "sgv", "sgv": value,
                    "direction": direction, "device": device]
        }
    }

    private struct Delivery: Codable, Equatable, Sendable {
        let payload: Payload
        let destination: String
        var awaitingReadingCommit: Bool?
        var attempted: Bool?
        var failures = 0
        var retryAt: Date?
        var uploadedAt: Date?
        var authenticationBlocked = false
        var error: String?
    }

    private struct Store: Codable, Equatable, Sendable {
        var configuration: DirectWatchNightscoutConfiguration?
        var credentialSaveFailedForRevision: Double? = nil
        var deliveries: [String: Delivery] = [:]
        var lastError: String?
    }
    private enum ReadBackResult: Equatable { case found, absent, uncertain }

    private let storeURL: URL
    private let sendRequest: @MainActor (URLRequest) async throws -> (Data, URLResponse)
    private var store = Store()
    private var storageReadFailed = false
    private(set) var isUploading = false
    private var retryTask: Task<Void, Never>?

    // MARK: - Initialization

    init(directory: URL? = nil, send: @escaping @MainActor (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }) {
        self.sendRequest = send
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        storeURL = base.appendingPathComponent("DirectWatchNightscoutOutbox.json")
        do {
            store = try JSONDecoder().decode(Store.self, from: Data(contentsOf: storeURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // First launch has no outbox yet.
        } catch {
            storageReadFailed = true
            store.lastError = "Saved Nightscout upload queue could not be read"
        }
        publish()
    }

    // MARK: - Configuration and queue

    /// Store credentials in Keychain by destination so retries can use the server chosen at collection time.
    func receiveConfiguration(_ payload: [String: Any]) {
        guard !storageReadFailed, let data = payload[Self.configurationKey] as? Data, data.count <= 4096,
              let next = try? JSONDecoder().decode(DirectWatchNightscoutConfiguration.self, from: data),
              next.version == DirectWatchNightscoutConfiguration.version,
              next.revision.isFinite, next.revision > 0,
              next.destination == nil || DirectWatchNightscoutConfiguration.normalizedDestination(next.destination) == next.destination else { return }
        if let current = store.configuration, next.revision < current.revision { return }

        let credentials = (payload[Self.credentialsKey] as? Data).flatMap { data -> DirectWatchNightscoutCredentials? in
            guard data.count <= 4096 else { return nil }
            return try? JSONDecoder().decode(DirectWatchNightscoutCredentials.self, from: data)
        }
        let previous = store.configuration
        let credentialsChanged = next.enabled && next.destination.flatMap { loadCredentials(destination: $0) } != credentials
        let hadCredentialSaveFailure = store.credentialSaveFailedForRevision != nil
        guard previous != next || credentialsChanged || hadCredentialSaveFailure else {
            uploadNextReading()
            return
        }
        if next.enabled {
            guard let destination = next.destination, let credentials,
                  !credentialsChanged || saveCredentials(credentials, destination: destination) else {
                store.credentialSaveFailedForRevision = next.revision
                store.configuration = next
                store.lastError = "Nightscout credentials could not be saved"
                diagnose("Configuration not ready: credentials missing or Keychain write failed")
                save()
                publish()
                return
            }
        }
        if hadCredentialSaveFailure { store.lastError = nil }
        store.credentialSaveFailedForRevision = nil
        store.configuration = next
        diagnose("Configuration applied: enabled=\(next.enabled), scheduleActive=\(scheduleIsActive), pending=\(pendingCount)")
        if credentialsChanged || hadCredentialSaveFailure || previous?.enabled != next.enabled || previous?.destination != next.destination {
            for id in store.deliveries.keys where store.deliveries[id]?.destination == next.destination {
                store.deliveries[id]?.authenticationBlocked = false
                store.deliveries[id]?.retryAt = nil
            }
        }
        _ = save()
        publish()
        uploadNextReading()
    }

    /// Save the pending upload before the collector marks the reading as Watch-owned.
    /// Wait for the collector to save the reading before sending it.
    func stageReading(_ reading: DirectWatchReading, alongside readings: [DirectWatchReading]) -> Bool {
        guard reading.isUsable, let configuration = store.configuration, configuration.enabled,
              let destination = configuration.destination, store.deliveries[reading.id] == nil else { return false }
        guard canAcceptNewReading else {
            store.lastError = "Nightscout upload queue is full"
            publish()
            return false
        }
        let previous = readings.first { $0.measuredAt < reading.measuredAt
            && $0.transmitterID == reading.transmitterID
            && $0.sensorStartCounter == reading.sensorStartCounter
            && $0.family == reading.family }
        let minutes = previous.map { reading.measuredAt.timeIntervalSince($0.measuredAt) / 60 }
        let direction = Self.direction(current: reading.mgDl, previous: previous?.mgDl, minutes: minutes)
        let payload = Payload(sampleID: reading.id, date: reading.measuredAt, value: Int(reading.mgDl.rounded()),
                              direction: direction, device: "xDrip Direct to Watch")
        store.deliveries[reading.id] = Delivery(payload: payload, destination: destination, awaitingReadingCommit: true, attempted: false)
        guard save() else {
            store.deliveries.removeValue(forKey: reading.id)
            diagnose("Queue save failed: measuredAt=\(reading.measuredAt.ISO8601Format())")
            publish()
            return false
        }
        return true
    }

    /// If the app stops between the two saves, keep only uploads whose ownership was saved by the collector.
    func reconcileStagedReadings(committedIDs: Set<String>) {
        let stagedIDs = store.deliveries.values.filter { $0.awaitingReadingCommit == true }.map(\.payload.sampleID)
        guard !stagedIDs.isEmpty else { return }
        for id in stagedIDs {
            if committedIDs.contains(id) {
                store.deliveries[id]?.awaitingReadingCommit = nil
            } else {
                store.deliveries.removeValue(forKey: id)
            }
        }
        save()
        publish()
    }

    func retryPendingUploads() {
        uploadNextReading()
        if !isUploading { scheduleRetry() }
    }

    func readingStatus(for reading: DirectWatchReading) -> DirectWatchServiceReadingStatus {
        guard let delivery = store.deliveries[reading.id] else { return isReady ? .notTracked : .disabled }
        if delivery.uploadedAt != nil { return .uploaded }
        if delivery.authenticationBlocked || delivery.error != nil { return .error }
        return .pending
    }

    var statusPayload: [String: Any] { uploadStatus?.payload ?? [:] }

    // MARK: - Delivery

    private func uploadNextReading() {
        guard collectionAllowsUpload(), !isUploading, let configuration = store.configuration, configuration.enabled,
              configuration.scheduleIsOn(at: .now), let delivery = nextDelivery(at: .now) else { return }
        guard (delivery.destination != configuration.destination || configuration.revision != store.credentialSaveFailedForRevision),
              let credentials = loadCredentials(destination: delivery.destination) else {
            diagnose("Upload skipped: Watch credentials unavailable")
            setFailure(for: delivery.payload.sampleID, message: "Nightscout credentials unavailable", authentication: true)
            publish()
            return
        }
        guard let request = Self.request(destination: delivery.destination, credentials: credentials, method: "POST") else {
            diagnose("Upload skipped: Nightscout URL invalid")
            setFailure(for: delivery.payload.sampleID, message: "Nightscout URL is invalid", authentication: true)
            publish()
            return
        }

        isUploading = true
        var post = request
        post.httpBody = try? JSONSerialization.data(withJSONObject: [delivery.payload.dictionary])
        guard let body = post.httpBody, body.count < 48_000 else {
            isUploading = false
            diagnose("Upload skipped: invalid or oversized entry payload")
            setFailure(for: delivery.payload.sampleID, message: "Nightscout entry is too large", authentication: true)
            publish()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            guard self.collectionAllowsUpload() else {
                self.isUploading = false
                self.publish()
                return
            }
            // A timeout or restart can hide a successful POST. Check for the entry before retrying.
            if delivery.attempted != false {
                switch await self.readBack(delivery, credentials: credentials) {
                case .found:
                    self.complete(delivery, accepted: true, failure: "", authenticationFailure: false)
                    return
                case .uncertain:
                    self.complete(delivery, accepted: false,
                        failure: "Could not verify whether Nightscout accepted this reading", authenticationFailure: false)
                    return
                case .absent: break
                }
            }
            // Settings can change while the readback is in flight.
            guard self.collectionAllowsUpload(), let configuration = self.store.configuration, configuration.enabled,
                  configuration.scheduleIsOn(at: .now),
                  self.loadCredentials(destination: delivery.destination) == credentials else {
                self.isUploading = false
                self.publish()
                return
            }
            // Save the attempt before posting so a restart still triggers verification.
            self.store.deliveries[delivery.payload.sampleID]?.attempted = true
            guard self.save() else {
                self.complete(delivery, accepted: false, failure: "Nightscout upload state could not be saved", authenticationFailure: false)
                return
            }
            self.diagnose("POST started: measuredAt=\(delivery.payload.date.ISO8601Format())")
            await self.perform(delivery: delivery, request: post, credentials: credentials)
        }
    }

    private func perform(delivery: Delivery, request: URLRequest,
                         credentials: DirectWatchNightscoutCredentials) async {
        var accepted = false
        var authenticationFailure = false
        var failure = "Nightscout did not confirm this reading"
        do {
            let (data, response) = try await sendRequest(request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if [401, 403].contains(http.statusCode) {
                authenticationFailure = true
                failure = "Nightscout rejected the credentials"
            } else if (200..<300).contains(http.statusCode) {
                let entries = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
                accepted = Self.contains(delivery.payload, in: entries)
                if !accepted { accepted = await readBack(delivery, credentials: credentials) == .found }
            } else {
                failure = "Nightscout returned HTTP \(http.statusCode)"
                accepted = await readBack(delivery, credentials: credentials) == .found
            }
            diagnose("POST finished: measuredAt=\(delivery.payload.date.ISO8601Format()), HTTP=\(http.statusCode), accepted=\(accepted)")
        } catch {
            let transportError = "Network error \((error as NSError).code)"
            failure = transportError
            let readBackResult = await readBack(delivery, credentials: credentials)
            accepted = readBackResult == .found
            diagnose("POST result uncertain: measuredAt=\(delivery.payload.date.ISO8601Format()), readBack=\(readBackResult), error=\(transportError), accepted=\(accepted)")
        }

        complete(delivery, accepted: accepted, failure: failure,
                 authenticationFailure: authenticationFailure && loadCredentials(destination: delivery.destination) == credentials)
    }

    private func complete(_ delivery: Delivery, accepted: Bool, failure: String, authenticationFailure: Bool) {
        isUploading = false
        if accepted {
            if var current = store.deliveries[delivery.payload.sampleID], current.destination == delivery.destination {
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
        } else {
            setFailure(for: delivery.payload.sampleID, message: failure, authentication: authenticationFailure)
            let retry = store.deliveries[delivery.payload.sampleID]?.retryAt?.ISO8601Format() ?? "blocked pending settings change"
            diagnose("Delivery failed: measuredAt=\(delivery.payload.date.ISO8601Format()), retryAt=\(retry), error=\(failure)")
        }
        publish()
        uploadNextReading()
    }

    private func nextDelivery(at date: Date) -> Delivery? {
        store.deliveries.values.filter {
            $0.awaitingReadingCommit != true && $0.uploadedAt == nil && !$0.authenticationBlocked && ($0.retryAt.map { $0 <= date } ?? true)
        }.min { $0.payload.date < $1.payload.date }
    }

    private func readBack(_ delivery: Delivery, credentials: DirectWatchNightscoutCredentials) async -> ReadBackResult {
        var result = ReadBackResult.uncertain
        defer { diagnose("GET verification: measuredAt=\(delivery.payload.date.ISO8601Format()), result=\(result)") }
        guard var request = Self.request(destination: delivery.destination, credentials: credentials, method: "GET"),
              let base = request.url,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return .uncertain }
        let millis = Int64((delivery.payload.date.timeIntervalSince1970 * 1000).rounded())
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "find[date][$gte]", value: String(millis - 1500)),
            URLQueryItem(name: "find[date][$lte]", value: String(millis + 1500)),
            URLQueryItem(name: "count", value: "100")]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        request.url = components.url
        do {
            let (data, response) = try await sendRequest(request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return .uncertain }
            result = Self.contains(delivery.payload, in: entries) ? .found : .absent
            return result
        } catch { return .uncertain }
    }

    private static func contains(_ payload: Payload, in entries: [[String: Any]]) -> Bool {
        entries.contains { entry in
            guard let date = entry["date"] as? NSNumber, let value = entry["sgv"] as? NSNumber else { return false }
            if entry["_id"] as? String == stableNightscoutID(payload.sampleID) {
                return entry["type"] as? String == "sgv" && value.intValue == payload.value
                    && abs(date.doubleValue - payload.date.timeIntervalSince1970 * 1000) <= 1
            }
            return abs(date.doubleValue - payload.date.timeIntervalSince1970 * 1000) <= 1
                && value.intValue == payload.value && entry["type"] as? String == "sgv"
                && entry["direction"] as? String == payload.direction
                && entry["device"] as? String == payload.device
        }
    }

    private static func request(destination: String, credentials: DirectWatchNightscoutCredentials,
                                method: String) -> URLRequest? {
        guard let base = URL(string: destination),
              var components = URLComponents(url: base.appendingPathComponent("api/v1/entries"), resolvingAgainstBaseURL: false) else { return nil }
        if let token = credentials.token, !token.isEmpty { components.queryItems = [URLQueryItem(name: "token", value: token)] }
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.allowsCellularAccess = true
        }
        if let secret = credentials.secretHash, !secret.isEmpty { request.setValue(secret, forHTTPHeaderField: "api-secret") }
        return request
    }

    private func setFailure(for sampleID: String, message: String, authentication: Bool) {
        guard var delivery = store.deliveries[sampleID] else { return }
        let delays = Self.retryDelays
        delivery.failures = min(max(0, delivery.failures), delays.count - 1) + 1
        delivery.authenticationBlocked = authentication
        delivery.error = String(message.prefix(240))
        delivery.retryAt = authentication ? nil : .now.addingTimeInterval(delays[min(delivery.failures - 1, delays.count - 1)])
        store.deliveries[sampleID] = delivery
        store.lastError = delivery.error
        _ = save()
    }

    // MARK: - Status and retries

    private func publish() {
        let ready = hasUsableConfiguration
        let pending = store.deliveries.values.filter { $0.awaitingReadingCommit != true && $0.uploadedAt == nil }.count
        let destination = store.configuration?.destination
        let failed = store.lastError != nil || store.deliveries.values.contains { $0.uploadedAt == nil && $0.error != nil }
        let latestForDestination = store.deliveries.values.lazy
            .filter { $0.destination == destination }.compactMap(\.uploadedAt).max()
        uploadStatus = DirectWatchUploadServiceStatus(service: .nightscout, isReady: ready,
            pending: pending, hasError: failed, lastUpload: latestForDestination)
        scheduleRetry()
        onStatusChange?()
    }

    private func diagnose(_ message: String) { onDiagnostic?("Nightscout: \(message)") }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = nil
        guard collectionAllowsUpload(), !isUploading, let configuration = store.configuration, configuration.enabled,
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
            store.lastError = "Nightscout upload state could not be saved"
            diagnose("Upload state could not be saved: errorCode=\((error as NSError).code)")
            return false
        }
    }

    private func trimDeliveredHistory() {
        let successful = store.deliveries.filter { $0.value.uploadedAt != nil }
            .sorted { ($0.value.uploadedAt ?? .distantPast) > ($1.value.uploadedAt ?? .distantPast) }
        for (id, _) in successful.dropFirst(Self.maxRetainedDeliveredReadings) { store.deliveries.removeValue(forKey: id) }
    }

    // MARK: - Keychain

    private func saveCredentials(_ credentials: DirectWatchNightscoutCredentials, destination: String) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Self.keychainService,
                                    kSecAttrAccount as String: destination]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func loadCredentials(destination: String) -> DirectWatchNightscoutCredentials? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Self.keychainService,
                                    kSecAttrAccount as String: destination,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(DirectWatchNightscoutCredentials.self, from: data)
    }

    // MARK: - Payload

    private static func direction(current: Double, previous: Double?, minutes: Double?) -> String {
        guard let previous, let minutes, minutes > 0, minutes <= 10 else { return "NOT COMPUTABLE" }
        switch (current - previous) / minutes {
        case ...(-3.5): return "DoubleDown"
        case ...(-2): return "SingleDown"
        case ...(-1): return "FortyFiveDown"
        case ...1: return "Flat"
        case ...2: return "FortyFiveUp"
        case ...3.5: return "SingleUp"
        default: return "DoubleUp"
        }
    }

    nonisolated private static func stableNightscoutID(_ sampleID: String) -> String {
        SHA256.hash(data: Data(sampleID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
