//
//  NightscoutImportService.swift
//  xdrip
//
//  Created by Paul Plant on 14/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

// MARK: - Import Options and Results

/// The user-selectable amount of Nightscout history to merge into local storage.
///
/// Encoding remains a single integer for checkpoint compatibility.
struct NightscoutImportPeriod: Codable, Hashable, Identifiable, Sendable {
    static let sevenDays = NightscoutImportPeriod(rawValue: 7)
    static let thirtyDays = NightscoutImportPeriod(rawValue: 30)
    static let ninetyDays = NightscoutImportPeriod(rawValue: 90)
    static let oneHundredEightyDays = NightscoutImportPeriod(rawValue: 180)
    static let oneYear = NightscoutImportPeriod(rawValue: 365)

    private static let standardPeriods = ConstantsHousekeeping.retentionPeriodsInDays.map {
        NightscoutImportPeriod(rawValue: $0)
    }

    let rawValue: Int

    var id: Int { rawValue }

    var title: String {
        Texts_SettingsView.cleanDataDays(rawValue)
    }

    var isSupported: Bool {
        ConstantsHousekeeping.retentionPeriodsInDays.contains(rawValue)
    }

    /// Returns the shared fixed choices up to and including the configured retention period.
    static func available(retentionDays: Int) -> [NightscoutImportPeriod] {
        standardPeriods.filter { $0.rawValue <= retentionDays }
    }

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The immutable choices captured when an import starts.
struct NightscoutImportOptions: Codable, Sendable {
    let period: NightscoutImportPeriod
    let includesBgReadings: Bool
    let includesTreatments: Bool
    let includesDeviceStatus: Bool

    var hasSelection: Bool {
        includesBgReadings || includesTreatments || includesDeviceStatus
    }

    private enum CodingKeys: String, CodingKey {
        case period
        case includesBgReadings
        case includesTreatments
        case includesDeviceStatus
    }

    init(
        period: NightscoutImportPeriod,
        includesBgReadings: Bool,
        includesTreatments: Bool,
        includesDeviceStatus: Bool
    ) {
        self.period = period
        self.includesBgReadings = includesBgReadings
        self.includesTreatments = includesTreatments
        self.includesDeviceStatus = includesDeviceStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(NightscoutImportPeriod.self, forKey: .period)
        includesBgReadings = try container.decode(Bool.self, forKey: .includesBgReadings)
        includesTreatments = try container.decode(Bool.self, forKey: .includesTreatments)
        includesDeviceStatus = try container.decodeIfPresent(Bool.self, forKey: .includesDeviceStatus) ?? false
    }
}

/// Counters are persisted with the checkpoint so a resumed import reports the full operation.
struct NightscoutImportCounts: Codable, Sendable {
    var bgDocumentsDownloaded = 0
    var bgReadingsAdded = 0
    var bgReadingsSkipped = 0
    var bgDocumentsInvalid = 0
    var treatmentDocumentsDownloaded = 0
    var treatmentsAdded = 0
    var treatmentsSkipped = 0
    var treatmentDocumentsUnsupported = 0
    var deviceStatusDocumentsDownloaded = 0
    var deviceStatusAdded = 0
    var deviceStatusSkipped = 0
    var deviceStatusDocumentsInvalid = 0

    private enum CodingKeys: String, CodingKey {
        case bgDocumentsDownloaded
        case bgReadingsAdded
        case bgReadingsSkipped
        case bgDocumentsInvalid
        case treatmentDocumentsDownloaded
        case treatmentsAdded
        case treatmentsSkipped
        case treatmentDocumentsUnsupported
        case deviceStatusDocumentsDownloaded
        case deviceStatusAdded
        case deviceStatusSkipped
        case deviceStatusDocumentsInvalid
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bgDocumentsDownloaded = try container.decodeIfPresent(Int.self, forKey: .bgDocumentsDownloaded) ?? 0
        bgReadingsAdded = try container.decodeIfPresent(Int.self, forKey: .bgReadingsAdded) ?? 0
        bgReadingsSkipped = try container.decodeIfPresent(Int.self, forKey: .bgReadingsSkipped) ?? 0
        bgDocumentsInvalid = try container.decodeIfPresent(Int.self, forKey: .bgDocumentsInvalid) ?? 0
        treatmentDocumentsDownloaded = try container.decodeIfPresent(Int.self, forKey: .treatmentDocumentsDownloaded) ?? 0
        treatmentsAdded = try container.decodeIfPresent(Int.self, forKey: .treatmentsAdded) ?? 0
        treatmentsSkipped = try container.decodeIfPresent(Int.self, forKey: .treatmentsSkipped) ?? 0
        treatmentDocumentsUnsupported = try container.decodeIfPresent(Int.self, forKey: .treatmentDocumentsUnsupported) ?? 0
        deviceStatusDocumentsDownloaded = try container.decodeIfPresent(Int.self, forKey: .deviceStatusDocumentsDownloaded) ?? 0
        deviceStatusAdded = try container.decodeIfPresent(Int.self, forKey: .deviceStatusAdded) ?? 0
        deviceStatusSkipped = try container.decodeIfPresent(Int.self, forKey: .deviceStatusSkipped) ?? 0
        deviceStatusDocumentsInvalid = try container.decodeIfPresent(Int.self, forKey: .deviceStatusDocumentsInvalid) ?? 0
    }
}

/// Final, user-facing summary returned only after every selected phase has completed.
struct NightscoutImportResult: Sendable {
    let requestedFrom: Date
    let requestedTo: Date
    let completedAt: Date
    let siteDisplayName: String
    let counts: NightscoutImportCounts
}

/// Summary from a focused BG-only range merge used by automatic follower gap filling.
struct NightscoutBgRangeMergeResult: Sendable {
    var documentsDownloaded = 0
    var documentsInvalid = 0
    var readingsAdded = 0
    var readingsSkipped = 0
}

/// Summary from a focused treatment range merge used by automatic follower recovery.
struct NightscoutTreatmentRangeMergeResult: Sendable {
    var documentsDownloaded = 0
    var documentsUnsupported = 0
    var treatmentsAdded = 0
    var treatmentsSkipped = 0
}

/// Summary from a focused device-status range merge used by automatic follower recovery.
struct NightscoutDeviceStatusRangeMergeResult: Sendable {
    var documentsDownloaded = 0
    var documentsInvalid = 0
    var statusesAdded = 0
    var statusesSkipped = 0
}

/// Summary from the profile-history merge used by automatic follower recovery.
struct NightscoutProfileRangeMergeResult: Sendable {
    var documentsDownloaded = 0
    var documentsInvalid = 0
    var profilesAdded = 0
    var profilesSkipped = 0
}

/// A lightweight update sent to the main-actor view model during network and Core Data work.
struct NightscoutImportProgress: Sendable {
    let completedUnits: Int
    let totalUnits: Int
    let chunkNumber: Int
    let totalChunks: Int
    let counts: NightscoutImportCounts

    var fractionCompleted: Double {
        guard totalUnits > 0 else { return 0 }
        return min(max(Double(completedUnits) / Double(totalUnits), 0), 1)
    }
}

// MARK: - Checkpointing

/// Identifies which resource should run next inside the current outer date chunk.
private enum NightscoutImportCheckpointPhase: String, Codable, Sendable {
    case bgReadings
    case treatments
    case deviceStatus
}

/// Everything required to safely continue after navigation, suspension, termination or a failure.
struct NightscoutImportCheckpoint: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let siteURL: String
    let requestedFrom: Date
    let requestedTo: Date
    let options: NightscoutImportOptions
    var nextChunkIndex: Int
    fileprivate var nextPhase: NightscoutImportCheckpointPhase
    var counts: NightscoutImportCounts

    var totalChunks: Int {
        // New imports always create one outer chunk per selected day. Deriving this from the
        // validated option avoids allocating ranges merely to render a saved checkpoint summary.
        max(options.period.rawValue, 0)
    }

    var completedChunks: Int {
        min(max(nextChunkIndex, 0), totalChunks)
    }
}

/// Stores a single small checkpoint in UserDefaults; no credentials or downloaded medical data are stored.
final class NightscoutImportCheckpointStore: @unchecked Sendable {
    private static let key = "nightscoutHistoricalImportCheckpointV1"
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> NightscoutImportCheckpoint? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = userDefaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(NightscoutImportCheckpoint.self, from: data)
    }

    func save(_ checkpoint: NightscoutImportCheckpoint) throws {
        let data = try JSONEncoder().encode(checkpoint)
        lock.lock()
        userDefaults.set(data, forKey: Self.key)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        userDefaults.removeObject(forKey: Self.key)
        lock.unlock()
    }
}

// MARK: - Errors

enum NightscoutImportError: LocalizedError {
    case noDataSelected
    case unsupportedPeriod
    case periodExceedsRetention
    case missingURL
    case invalidURL
    case checkpointUnavailable
    case checkpointSiteChanged
    case authenticationFailed
    case endpointNotFound
    case rateLimited
    case serverError(Int)
    case unexpectedStatus(Int)
    case invalidResponse
    case responseLimitExceeded

    var errorDescription: String? {
        switch self {
        case .noDataSelected:
            Texts_SettingsView.nightscoutImportErrorNoSelection
        case .unsupportedPeriod:
            Texts_SettingsView.nightscoutImportErrorUnsupportedPeriod
        case .periodExceedsRetention:
            Texts_SettingsView.nightscoutImportErrorRetention
        case .missingURL:
            Texts_SettingsView.nightscoutImportErrorMissingURL
        case .invalidURL:
            Texts_SettingsView.nightscoutImportErrorInvalidURL
        case .checkpointUnavailable:
            Texts_SettingsView.nightscoutImportErrorCheckpointUnavailable
        case .checkpointSiteChanged:
            Texts_SettingsView.nightscoutImportErrorSiteChanged
        case .authenticationFailed:
            Texts_SettingsView.nightscoutImportErrorAuthentication
        case .endpointNotFound:
            Texts_SettingsView.nightscoutImportErrorEndpoint
        case .rateLimited:
            Texts_SettingsView.nightscoutImportErrorRateLimited
        case let .serverError(status):
            Texts_SettingsView.nightscoutImportErrorServer(status)
        case let .unexpectedStatus(status):
            Texts_SettingsView.nightscoutImportErrorUnexpectedStatus(status)
        case .invalidResponse:
            Texts_SettingsView.nightscoutImportErrorInvalidResponse
        case .responseLimitExceeded:
            Texts_SettingsView.nightscoutImportErrorResponseLimit
        }
    }
}

// MARK: - Nightscout Network Documents

/// Decodes JSON numbers whether a Nightscout version emits them as numbers or numeric strings.
private struct NightscoutFlexibleDouble: Decodable, Sendable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Int64.self) {
            self.value = Double(value)
        } else if let text = try? container.decode(String.self), let value = Double(text) {
            self.value = value
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a numeric value")
        }
    }
}

/// A permissive representation of an SGV document returned by different Nightscout versions/uploaders.
private struct NightscoutEntryDocument: Decodable, Sendable {
    let id: String?
    let identifier: String?
    let date: NightscoutFlexibleDouble?
    let dateString: String?
    let sgv: NightscoutFlexibleDouble?
    let type: String?
    let device: String?
    let direction: String?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case identifier
        case date
        case dateString
        case sgv
        case type
        case device
        case direction
    }

    /// Treats malformed optional fields as missing so one unusual uploader does not reject the whole response.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id)
        identifier = container.decodeLossyString(forKey: .identifier)
        date = container.decodeLossyFlexibleDouble(forKey: .date)
        dateString = container.decodeLossyString(forKey: .dateString)
        sgv = container.decodeLossyFlexibleDouble(forKey: .sgv)
        type = container.decodeLossyString(forKey: .type)
        device = container.decodeLossyString(forKey: .device)
        direction = container.decodeLossyString(forKey: .direction)
    }
}

/// A permissive treatment document. One document may legitimately create multiple local treatments.
private struct NightscoutTreatmentDocument: Decodable, Sendable {
    let id: String?
    let identifier: String?
    let createdAt: String?
    let eventTime: String?
    let mills: NightscoutFlexibleDouble?
    let eventType: String?
    let carbs: NightscoutFlexibleDouble?
    let insulin: NightscoutFlexibleDouble?
    let duration: NightscoutFlexibleDouble?
    let glucose: NightscoutFlexibleDouble?
    let units: String?
    let rate: NightscoutFlexibleDouble?
    let enteredBy: String?
    let notes: String?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case identifier
        case createdAt = "created_at"
        case eventTime
        case mills
        case eventType
        case carbs
        case insulin
        case duration
        case glucose
        case units
        case rate
        case enteredBy
        case notes
    }

    /// Nightscout treatment documents are intentionally loose; validation happens after decoding.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id)
        identifier = container.decodeLossyString(forKey: .identifier)
        createdAt = container.decodeLossyString(forKey: .createdAt)
        eventTime = container.decodeLossyString(forKey: .eventTime)
        mills = container.decodeLossyFlexibleDouble(forKey: .mills)
        eventType = container.decodeLossyString(forKey: .eventType)
        carbs = container.decodeLossyFlexibleDouble(forKey: .carbs)
        insulin = container.decodeLossyFlexibleDouble(forKey: .insulin)
        duration = container.decodeLossyFlexibleDouble(forKey: .duration)
        glucose = container.decodeLossyFlexibleDouble(forKey: .glucose)
        units = container.decodeLossyString(forKey: .units)
        rate = container.decodeLossyFlexibleDouble(forKey: .rate)
        enteredBy = container.decodeLossyString(forKey: .enteredBy)
        notes = container.decodeLossyString(forKey: .notes)
    }
}

/// Nightscout is schemaless, so optional fields must never make the surrounding document undecodable.
private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        try? decodeIfPresent(String.self, forKey: key)
    }

    func decodeLossyFlexibleDouble(forKey key: Key) -> NightscoutFlexibleDouble? {
        try? decodeIfPresent(NightscoutFlexibleDouble.self, forKey: key)
    }
}

/// Queue-safe value used after a remote entry has passed validation.
private struct NightscoutImportedBgReading: Sendable {
    let remoteIdentity: String
    let timeStamp: Date
    let value: Double
    let device: String?
    let direction: String?
}

/// Queue-safe value used after a remote treatment document has been expanded and validated.
private struct NightscoutImportedTreatment: Sendable {
    let id: String
    let date: Date
    let value: Double
    let valueSecondary: Double
    let type: TreatmentType
    let nightscoutEventType: String?
    let enteredBy: String?
    let notes: String?
}

// MARK: - Service

/// Performs a merge-only historical import without sharing managed objects across queues.
final class NightscoutImportService: @unchecked Sendable {
    /// Imported IDs are namespaced so live Nightscout upload can avoid echoing downloaded entries back.
    static let importedBgReadingIDPrefix = "nightscout-import:"

    private static let outerChunkDuration: TimeInterval = 24 * 60 * 60
    private static let minimumSubdivisionDuration: TimeInterval = 5 * 60
    private static let bgResponseLimit = 2_000
    private static let treatmentResponseLimit = 1_000
    private static let deviceStatusResponseLimit = 1_000
    private static let maximumRequestAttempts = 4
    private static let duplicateBgWindow: TimeInterval = 30

    private let coreDataManager: CoreDataManager
    private let checkpointStore: NightscoutImportCheckpointStore
    private let session: URLSession
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    init(
        coreDataManager: CoreDataManager,
        checkpointStore: NightscoutImportCheckpointStore = NightscoutImportCheckpointStore(),
        session: URLSession? = nil
    ) {
        self.coreDataManager = coreDataManager
        self.checkpointStore = checkpointStore
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 45
            configuration.timeoutIntervalForResource = 90
            configuration.waitsForConnectivity = true
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    var savedCheckpoint: NightscoutImportCheckpoint? {
        checkpointStore.load()
    }

    func discardCheckpoint() {
        trace(
            "in Nightscout historical import, user requested that the saved import checkpoint be discarded",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        checkpointStore.clear()
    }

    static func isImportedBgReadingID(_ id: String) -> Bool {
        id.hasPrefix(importedBgReadingIDPrefix)
    }

    /// Downloads and merge-fills only the supplied BG intervals.
    ///
    /// This deliberately bypasses the user-driven historical import checkpoint while reusing
    /// its authenticated requests, validation, response subdivision and duplicate-safe merge.
    func mergeBgReadings(in intervals: [DateInterval]) async throws -> NightscoutBgRangeMergeResult {
        let validIntervals = intervals
            .filter { $0.start < $0.end }
            .sorted { $0.start < $1.start }
        guard !validIntervals.isEmpty else { return NightscoutBgRangeMergeResult() }

        let configuration = try currentConfiguration()
        try await persistManagedObjectContexts()
        var result = NightscoutBgRangeMergeResult()

        for interval in validIntervals {
            try Task.checkCancellation()
            let documents = try await downloadEntries(in: interval, configuration: configuration)
            let prepared = prepareBgReadings(documents, in: interval)
            let applied = try await applyBgReadings(prepared.records, in: interval)
            result.documentsDownloaded += documents.count
            result.documentsInvalid += prepared.invalidCount
            result.readingsAdded += applied.added
            result.readingsSkipped += applied.skipped
        }

        return result
    }

    /// Downloads and merge-fills treatments across one bounded follower recovery window.
    /// This does not read or mutate the manual historical-import checkpoint.
    func mergeTreatments(in interval: DateInterval) async throws -> NightscoutTreatmentRangeMergeResult {
        guard interval.start < interval.end else { return NightscoutTreatmentRangeMergeResult() }

        let configuration = try currentConfiguration()
        try await persistManagedObjectContexts()
        var result = NightscoutTreatmentRangeMergeResult()

        for chunk in Self.makeChunks(from: interval.start, to: interval.end) {
            try Task.checkCancellation()
            let documents = try await downloadTreatments(in: chunk, configuration: configuration)
            let prepared = prepareTreatments(documents, in: chunk)
            let applied = try await applyFollowerTreatments(prepared.records, in: chunk)
            result.documentsDownloaded += documents.count
            result.documentsUnsupported += prepared.unsupportedCount
            result.treatmentsAdded += applied.added
            result.treatmentsSkipped += applied.skipped
        }

        return result
    }

    /// Downloads and merge-fills every device-status document in a bounded follower window.
    /// The live sync remains responsible for publishing the composed current status.
    func mergeDeviceStatus(in interval: DateInterval) async throws -> NightscoutDeviceStatusRangeMergeResult {
        guard interval.start < interval.end else { return NightscoutDeviceStatusRangeMergeResult() }

        let configuration = try currentConfiguration()
        try await persistManagedObjectContexts()
        var result = NightscoutDeviceStatusRangeMergeResult()

        for chunk in Self.makeChunks(from: interval.start, to: interval.end) {
            try Task.checkCancellation()
            let documents = try await downloadDeviceStatus(in: chunk, configuration: configuration)
            let prepared = prepareDeviceStatus(documents, in: chunk)
            let accessor = NightscoutDeviceStatusAccessor(coreDataManager: coreDataManager)
            let applied = try await accessor.insertMissing(prepared.records)
            try await persistManagedObjectContexts()
            result.documentsDownloaded += documents.count
            result.documentsInvalid += prepared.invalidCount
            result.statusesAdded += applied.added
            result.statusesSkipped += applied.skipped
        }

        return result
    }

    /// Imports profile changes inside the follower window plus the newest pre-window baseline.
    /// Nightscout profile collections are normally small, so one collection request avoids
    /// endpoint-specific range-query assumptions across Nightscout versions.
    func mergeProfiles(in interval: DateInterval) async throws -> NightscoutProfileRangeMergeResult {
        guard interval.start < interval.end else { return NightscoutProfileRangeMergeResult() }

        let configuration = try currentConfiguration()
        try await persistManagedObjectContexts()
        let documents = try await downloadProfiles(configuration: configuration)
        let prepared = prepareProfiles(documents, in: interval)
        let accessor = NightscoutProfileAccessor(coreDataManager: coreDataManager)
        let applied = try await accessor.insertMissing(prepared.profiles)
        try await persistManagedObjectContexts()

        return NightscoutProfileRangeMergeResult(
            documentsDownloaded: documents.count,
            documentsInvalid: prepared.invalidCount,
            profilesAdded: applied.added,
            profilesSkipped: applied.skipped
        )
    }

    /// Creates exact 24-hour outer chunks. Inner safety subdivision happens only when a response is full.
    static func makeChunks(from start: Date, to end: Date) -> [DateInterval] {
        guard start < end else { return [] }
        var chunks = [DateInterval]()
        var chunkStart = start
        while chunkStart < end {
            let chunkEnd = min(chunkStart.addingTimeInterval(outerChunkDuration), end)
            chunks.append(DateInterval(start: chunkStart, end: chunkEnd))
            chunkStart = chunkEnd
        }
        return chunks
    }

    /// Starts a new operation and writes its checkpoint before the first network request.
    func start(
        options: NightscoutImportOptions,
        now: Date = Date(),
        progress: @escaping @Sendable (NightscoutImportProgress) -> Void
    ) async throws -> NightscoutImportResult {
        trace(
            "in Nightscout historical import, user requested a new import. days = %{public}@, BG = %{public}@, treatments = %{public}@, device status = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            options.period.rawValue.description,
            options.includesBgReadings.description,
            options.includesTreatments.description,
            options.includesDeviceStatus.description
        )
        do {
            guard options.hasSelection else { throw NightscoutImportError.noDataSelected }
            guard options.period.isSupported else { throw NightscoutImportError.unsupportedPeriod }
            guard options.period.rawValue <= UserDefaults.standard.retentionPeriodInDays else {
                throw NightscoutImportError.periodExceedsRetention
            }
            let configuration = try currentConfiguration()
            let requestedFrom = now.addingTimeInterval(-TimeInterval(options.period.rawValue) * Self.outerChunkDuration)
            guard let initialPhase = selectedPhases(for: options).first else {
                throw NightscoutImportError.noDataSelected
            }
            let checkpoint = NightscoutImportCheckpoint(
                id: UUID(),
                createdAt: now,
                siteURL: configuration.normalizedSiteURL,
                requestedFrom: requestedFrom,
                requestedTo: now,
                options: options,
                nextChunkIndex: 0,
                nextPhase: initialPhase,
                counts: NightscoutImportCounts()
            )
            try checkpointStore.save(checkpoint)
            return try await execute(checkpoint: checkpoint, configuration: configuration, progress: progress)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            traceFailure(intent: "new import", error: error)
            throw error
        }
    }

    /// Resumes only when the configured site still matches the site captured at start time.
    func resume(
        progress: @escaping @Sendable (NightscoutImportProgress) -> Void
    ) async throws -> NightscoutImportResult {
        trace(
            "in Nightscout historical import, user requested that a saved import be resumed",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        do {
            guard let checkpoint = checkpointStore.load() else {
                throw NightscoutImportError.checkpointUnavailable
            }
            try validate(checkpoint: checkpoint)
            trace(
                "in Nightscout historical import, resume settings. days = %{public}@, next batch = %{public}@/%{public}@, phase = %{public}@, BG = %{public}@, treatments = %{public}@, device status = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .info,
                checkpoint.options.period.rawValue.description,
                min(checkpoint.nextChunkIndex + 1, checkpoint.totalChunks).description,
                checkpoint.totalChunks.description,
                checkpoint.nextPhase.rawValue,
                checkpoint.options.includesBgReadings.description,
                checkpoint.options.includesTreatments.description,
                checkpoint.options.includesDeviceStatus.description
            )
            let configuration = try currentConfiguration()
            guard configuration.normalizedSiteURL == checkpoint.siteURL else {
                throw NightscoutImportError.checkpointSiteChanged
            }
            return try await execute(checkpoint: checkpoint, configuration: configuration, progress: progress)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            traceFailure(intent: "resume import", error: error)
            throw error
        }
    }

    // MARK: Import Execution

    /// Rejects damaged, legacy or policy-incompatible checkpoints before they can allocate chunks.
    private func validate(checkpoint: NightscoutImportCheckpoint) throws {
        let phases = selectedPhases(for: checkpoint.options)
        guard checkpoint.options.hasSelection,
              phases.contains(checkpoint.nextPhase),
              checkpoint.options.period.isSupported,
              checkpoint.options.period.rawValue <= UserDefaults.standard.retentionPeriodInDays,
              checkpoint.requestedFrom < checkpoint.requestedTo,
              checkpoint.nextChunkIndex >= 0,
              checkpoint.nextChunkIndex <= checkpoint.options.period.rawValue
        else {
            if !checkpoint.options.period.isSupported {
                throw NightscoutImportError.unsupportedPeriod
            }
            if checkpoint.options.period.rawValue > UserDefaults.standard.retentionPeriodInDays {
                throw NightscoutImportError.periodExceedsRetention
            }
            throw NightscoutImportError.checkpointUnavailable
        }

        let expectedDuration = TimeInterval(checkpoint.options.period.rawValue) * Self.outerChunkDuration
        guard abs(checkpoint.requestedTo.timeIntervalSince(checkpoint.requestedFrom) - expectedDuration) < 1 else {
            throw NightscoutImportError.checkpointUnavailable
        }
    }

    private func execute(
        checkpoint initialCheckpoint: NightscoutImportCheckpoint,
        configuration: NightscoutImportConfiguration,
        progress: @escaping @Sendable (NightscoutImportProgress) -> Void
    ) async throws -> NightscoutImportResult {
        let startedAt = Date()
        var checkpoint = initialCheckpoint
        let chunks = Self.makeChunks(from: checkpoint.requestedFrom, to: checkpoint.requestedTo)
        guard checkpoint.nextChunkIndex <= chunks.count else {
            checkpointStore.clear()
            throw NightscoutImportError.checkpointUnavailable
        }
        let phases = selectedPhases(for: checkpoint.options)
        guard !phases.isEmpty else {
            checkpointStore.clear()
            throw NightscoutImportError.noDataSelected
        }

        // Make pending local work durable before child contexts begin their merge/deduplication passes.
        try await persistManagedObjectContexts()
        trace(
            "in Nightscout historical import, starting or resuming. days = %{public}@, chunk = %{public}@/%{public}@, BG = %{public}@, treatments = %{public}@, device status = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            // Historical imports are user-requested maintenance rather than live glucose status.
            // Their supporting classification documents that distinction, but all retained entries
            // are now visible because the Activity Log no longer has a detail filter.
            troubleshooting: .detailed(.integration(name: .nightscoutImport, activity: .started)),
            checkpoint.options.period.rawValue.description,
            min(checkpoint.nextChunkIndex + 1, chunks.count).description,
            chunks.count.description,
            checkpoint.options.includesBgReadings.description,
            checkpoint.options.includesTreatments.description,
            checkpoint.options.includesDeviceStatus.description
        )

        while checkpoint.nextChunkIndex < chunks.count {
            try Task.checkCancellation()
            let interval = chunks[checkpoint.nextChunkIndex]

            reportProgress(checkpoint: checkpoint, chunks: chunks, phases: phases, progress: progress)
            switch checkpoint.nextPhase {
            case .bgReadings:
                let documents = try await downloadEntries(in: interval, configuration: configuration)
                let prepared = prepareBgReadings(documents, in: interval)
                let applied = try await applyBgReadings(prepared.records, in: interval)
                checkpoint.counts.bgDocumentsDownloaded += documents.count
                checkpoint.counts.bgDocumentsInvalid += prepared.invalidCount
                checkpoint.counts.bgReadingsAdded += applied.added
                checkpoint.counts.bgReadingsSkipped += applied.skipped
            case .treatments:
                let documents = try await downloadTreatments(in: interval, configuration: configuration)
                let prepared = prepareTreatments(documents, in: interval)
                let applied = try await applyTreatments(prepared.records, in: interval)
                checkpoint.counts.treatmentDocumentsDownloaded += documents.count
                checkpoint.counts.treatmentDocumentsUnsupported += prepared.unsupportedCount
                checkpoint.counts.treatmentsAdded += applied.added
                checkpoint.counts.treatmentsSkipped += applied.skipped
            case .deviceStatus:
                let documents = try await downloadDeviceStatus(in: interval, configuration: configuration)
                let prepared = prepareDeviceStatus(documents, in: interval)
                let applied = try await applyDeviceStatus(prepared.records, in: interval)
                checkpoint.counts.deviceStatusDocumentsDownloaded += documents.count
                checkpoint.counts.deviceStatusDocumentsInvalid += prepared.invalidCount
                checkpoint.counts.deviceStatusAdded += applied.added
                checkpoint.counts.deviceStatusSkipped += applied.skipped
            }
            advance(&checkpoint, phases: phases)
            try checkpointStore.save(checkpoint)
            reportProgress(checkpoint: checkpoint, chunks: chunks, phases: phases, progress: progress)
        }

        checkpointStore.clear()
        let result = NightscoutImportResult(
            requestedFrom: checkpoint.requestedFrom,
            requestedTo: checkpoint.requestedTo,
            completedAt: Date(),
            siteDisplayName: configuration.displayName,
            counts: checkpoint.counts
        )
        trace(
            "in Nightscout historical import, completed. duration = %{public}@ ms, BG downloaded = %{public}@, BG added = %{public}@, BG skipped = %{public}@, BG invalid = %{public}@, treatment documents downloaded = %{public}@, treatments added = %{public}@, treatments skipped = %{public}@, treatment documents unsupported = %{public}@, device status documents downloaded = %{public}@, device status added = %{public}@, device status skipped = %{public}@, device status invalid = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            troubleshooting: .detailed(.integration(
                name: .nightscoutImport,
                activity: .succeeded(itemCount: result.counts.bgReadingsAdded + result.counts.treatmentsAdded + result.counts.deviceStatusAdded)
            )),
            Int(Date().timeIntervalSince(startedAt) * 1_000).description,
            result.counts.bgDocumentsDownloaded.description,
            result.counts.bgReadingsAdded.description,
            result.counts.bgReadingsSkipped.description,
            result.counts.bgDocumentsInvalid.description,
            result.counts.treatmentDocumentsDownloaded.description,
            result.counts.treatmentsAdded.description,
            result.counts.treatmentsSkipped.description,
            result.counts.treatmentDocumentsUnsupported.description,
            result.counts.deviceStatusDocumentsDownloaded.description,
            result.counts.deviceStatusAdded.description,
            result.counts.deviceStatusSkipped.description,
            result.counts.deviceStatusDocumentsInvalid.description
        )
        return result
    }

    /// Records terminal failures without including URLs, credentials, query payloads or medical data.
    private func traceFailure(intent: String, error: Error) {
        let nsError = error as NSError
        let safeDescription = (error as? NightscoutImportError)?.localizedDescription
            ?? "\(nsError.domain) code \(nsError.code)"
        trace(
            "in Nightscout historical import, %{public}@ failed. error type = %{public}@, description = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .error,
            troubleshooting: .detailed(.integration(name: .nightscoutImport, activity: .failed)),
            intent,
            String(describing: Swift.type(of: error)),
            safeDescription
        )
    }

    private func reportProgress(
        checkpoint: NightscoutImportCheckpoint,
        chunks: [DateInterval],
        phases: [NightscoutImportCheckpointPhase],
        progress: @escaping @Sendable (NightscoutImportProgress) -> Void
    ) {
        let resourcesPerChunk = phases.count
        let completedInCurrentChunk = checkpoint.nextChunkIndex >= chunks.count
            ? 0
            : phases.firstIndex(of: checkpoint.nextPhase) ?? 0
        let completedUnits = min(
            checkpoint.nextChunkIndex * resourcesPerChunk + completedInCurrentChunk,
            chunks.count * resourcesPerChunk
        )
        progress(NightscoutImportProgress(
            completedUnits: completedUnits,
            totalUnits: chunks.count * resourcesPerChunk,
            chunkNumber: min(checkpoint.nextChunkIndex + 1, chunks.count),
            totalChunks: chunks.count,
            counts: checkpoint.counts
        ))
    }

    private func selectedPhases(for options: NightscoutImportOptions) -> [NightscoutImportCheckpointPhase] {
        var phases = [NightscoutImportCheckpointPhase]()
        if options.includesBgReadings { phases.append(.bgReadings) }
        if options.includesTreatments { phases.append(.treatments) }
        if options.includesDeviceStatus { phases.append(.deviceStatus) }
        return phases
    }

    private func advance(_ checkpoint: inout NightscoutImportCheckpoint, phases: [NightscoutImportCheckpointPhase]) {
        guard let currentIndex = phases.firstIndex(of: checkpoint.nextPhase),
              currentIndex + 1 < phases.count
        else {
            checkpoint.nextChunkIndex += 1
            checkpoint.nextPhase = phases[0]
            return
        }

        checkpoint.nextPhase = phases[currentIndex + 1]
    }

    // MARK: Network Configuration and Requests

    private struct NightscoutImportConfiguration: Sendable {
        let baseURL: URL
        let normalizedSiteURL: String
        let displayName: String
        let apiSecretHash: String?
        let token: String?
    }

    private func currentConfiguration() throws -> NightscoutImportConfiguration {
        guard let configuredURL = UserDefaults.standard.nightscoutUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !configuredURL.isEmpty
        else {
            throw NightscoutImportError.missingURL
        }
        guard var components = URLComponents(string: configuredURL),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil
        else {
            throw NightscoutImportError.invalidURL
        }
        components.fragment = nil
        // A Nightscout site setting is a base URL. Authentication comes from the dedicated secret
        // and token settings, so query items must not enter requests or the persisted checkpoint.
        components.query = nil
        components.user = nil
        components.password = nil
        let port = UserDefaults.standard.nightscoutPort
        if port != 0 {
            guard (1...65_535).contains(port) else { throw NightscoutImportError.invalidURL }
            components.port = port
        }
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let baseURL = components.url else { throw NightscoutImportError.invalidURL }
        guard let normalized = Self.normalizedSiteIdentity(from: components) else {
            throw NightscoutImportError.invalidURL
        }
        return NightscoutImportConfiguration(
            baseURL: baseURL,
            normalizedSiteURL: normalized,
            displayName: components.host ?? normalized,
            apiSecretHash: UserDefaults.standard.nightscoutAPIKey?.sha1(),
            token: UserDefaults.standard.nightscoutToken?.trimmingCharacters(in: .whitespacesAndNewlines).toNilIfLength0()
        )
    }

    /// Builds the non-secret site identity stored in checkpoints and used for resume validation.
    static func normalizedSiteIdentity(from configuredComponents: URLComponents) -> String? {
        var components = configuredComponents
        guard let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil,
              components.port.map({ (1...65_535).contains($0) }) ?? true
        else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url?.absoluteString
    }

    private func downloadEntries(
        in interval: DateInterval,
        configuration: NightscoutImportConfiguration
    ) async throws -> [NightscoutEntryDocument] {
        try await downloadCollection(
            path: "/api/v1/entries/sgv.json",
            interval: interval,
            responseLimit: Self.bgResponseLimit,
            configuration: configuration,
            rangeQuery: { interval in
                [
                    URLQueryItem(name: "find[date][$gte]", value: String(Int64(interval.start.timeIntervalSince1970 * 1_000))),
                    URLQueryItem(name: "find[date][$lt]", value: String(Int64(interval.end.timeIntervalSince1970 * 1_000))),
                ]
            },
            type: NightscoutEntryDocument.self
        )
    }

    private func downloadTreatments(
        in interval: DateInterval,
        configuration: NightscoutImportConfiguration
    ) async throws -> [NightscoutTreatmentDocument] {
        try await downloadCollection(
            path: "/api/v1/treatments.json",
            interval: interval,
            responseLimit: Self.treatmentResponseLimit,
            configuration: configuration,
            rangeQuery: { interval in
                [
                    URLQueryItem(name: "find[created_at][$gte]", value: Self.iso8601String(from: interval.start)),
                    URLQueryItem(name: "find[created_at][$lt]", value: Self.iso8601String(from: interval.end))
                ]
            },
            type: NightscoutTreatmentDocument.self
        )
    }

    private func downloadDeviceStatus(
        in interval: DateInterval,
        configuration: NightscoutImportConfiguration
    ) async throws -> [NightscoutDeviceStatusResponse] {
        try await downloadCollection(
            path: "/api/v1/devicestatus.json",
            interval: interval,
            responseLimit: Self.deviceStatusResponseLimit,
            configuration: configuration,
            rangeQuery: { interval in
                [
                    URLQueryItem(name: "find[created_at][$gte]", value: Self.iso8601String(from: interval.start)),
                    URLQueryItem(name: "find[created_at][$lt]", value: Self.iso8601String(from: interval.end))
                ]
            },
            type: NightscoutDeviceStatusResponse.self
        )
    }

    private func downloadProfiles(
        configuration: NightscoutImportConfiguration
    ) async throws -> [NightscoutProfileResponse] {
        let data = try await request(
            path: "/api/v1/profile",
            queryItems: [],
            configuration: configuration
        )
        do {
            return try JSONDecoder().decode([NightscoutProfileResponse].self, from: data)
        } catch {
            trace(
                "in Nightscout historical import, JSON decoding failed for profile history. error type = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .error,
                String(describing: Swift.type(of: error))
            )
            throw NightscoutImportError.invalidResponse
        }
    }

    /// A full response is treated as possibly truncated and split by time until both halves are below the cap.
    private func downloadCollection<Document: Decodable>(
        path: String,
        interval: DateInterval,
        responseLimit: Int,
        configuration: NightscoutImportConfiguration,
        rangeQuery: @escaping @Sendable (DateInterval) -> [URLQueryItem],
        type: Document.Type
    ) async throws -> [Document] {
        try Task.checkCancellation()
        var queryItems = rangeQuery(interval)
        queryItems.append(URLQueryItem(name: "count", value: responseLimit.description))
        let data = try await request(
            path: path,
            queryItems: queryItems,
            configuration: configuration
        )
        let documents: [Document]
        do {
            documents = try JSONDecoder().decode([Document].self, from: data)
        } catch {
            trace(
                "in Nightscout historical import, JSON decoding failed for %{public}@. error type = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .error,
                path,
                String(describing: Swift.type(of: error))
            )
            throw NightscoutImportError.invalidResponse
        }

        guard documents.count >= responseLimit else { return documents }
        guard interval.duration > Self.minimumSubdivisionDuration else {
            throw NightscoutImportError.responseLimitExceeded
        }

        // Half-open ranges guarantee that a boundary timestamp belongs to exactly one child request.
        let midpoint = interval.start.addingTimeInterval(interval.duration / 2)
        let earlier = try await downloadCollection(
            path: path,
            interval: DateInterval(start: interval.start, end: midpoint),
            responseLimit: responseLimit,
            configuration: configuration,
            rangeQuery: rangeQuery,
            type: type
        )
        let later = try await downloadCollection(
            path: path,
            interval: DateInterval(start: midpoint, end: interval.end),
            responseLimit: responseLimit,
            configuration: configuration,
            rangeQuery: rangeQuery,
            type: type
        )
        return earlier + later
    }

    private func request(
        path: String,
        queryItems: [URLQueryItem],
        configuration: NightscoutImportConfiguration
    ) async throws -> Data {
        var lastError: Error?
        for attempt in 1...Self.maximumRequestAttempts {
            try Task.checkCancellation()
            do {
                let request = try makeRequest(path: path, queryItems: queryItems, configuration: configuration)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NightscoutImportError.invalidResponse
                }
                switch httpResponse.statusCode {
                case 200...299:
                    markNightscoutConnectionSucceeded()
                    return data
                case 401, 403:
                    throw NightscoutImportError.authenticationFailed
                case 404:
                    throw NightscoutImportError.endpointNotFound
                case 429:
                    if attempt == Self.maximumRequestAttempts { throw NightscoutImportError.rateLimited }
                    let delay = retryDelay(attempt: attempt, response: httpResponse)
                    try await sleepForRetry(delay)
                case 500...599:
                    if attempt == Self.maximumRequestAttempts {
                        throw NightscoutImportError.serverError(httpResponse.statusCode)
                    }
                    let delay = retryDelay(attempt: attempt, response: httpResponse)
                    try await sleepForRetry(delay)
                default:
                    throw NightscoutImportError.unexpectedStatus(httpResponse.statusCode)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as NightscoutImportError {
                switch error {
                case .rateLimited, .serverError:
                    lastError = error
                default:
                    throw error
                }
            } catch let error as URLError where isTransient(error) {
                lastError = error
                if attempt < Self.maximumRequestAttempts {
                    try await sleepForRetry(pow(2, Double(attempt - 1)))
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? NightscoutImportError.invalidResponse
    }

    /// Keep the shared Nightscout connection indicator current when the import
    /// service gets a valid response from the configured server.
    private func markNightscoutConnectionSucceeded() {
        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem],
        configuration: NightscoutImportConfiguration
    ) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw NightscoutImportError.invalidURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + path
        var allQueryItems = (components.queryItems ?? []).filter { $0.name.lowercased() != "token" }
        allQueryItems.append(contentsOf: queryItems)
        if let token = configuration.token {
            allQueryItems.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = allQueryItems
        guard let url = components.url else { throw NightscoutImportError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiSecretHash = configuration.apiSecretHash {
            request.setValue(apiSecretHash, forHTTPHeaderField: "api-secret")
        }
        return request
    }

    private func retryDelay(attempt: Int, response: HTTPURLResponse) -> TimeInterval {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter) {
            return min(max(seconds, 0.5), 30)
        }
        return pow(2, Double(attempt - 1))
    }

    private func sleepForRetry(_ delay: TimeInterval) async throws {
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .networkConnectionLost, .notConnectedToInternet, .resourceUnavailable:
            true
        default:
            false
        }
    }

    // MARK: Document Validation and Expansion

    private func prepareBgReadings(
        _ documents: [NightscoutEntryDocument],
        in interval: DateInterval
    ) -> (records: [NightscoutImportedBgReading], invalidCount: Int) {
        var records = [NightscoutImportedBgReading]()
        var invalidCount = 0
        var identities = Set<String>()
        for document in documents {
            guard document.type == nil || document.type?.lowercased() == "sgv",
                  let sgv = document.sgv?.value,
                  sgv.isFinite,
                  sgv > 0,
                  sgv <= 1_000,
                  let timeStamp = Self.documentDate(milliseconds: document.date?.value, iso8601: document.dateString),
                  interval.containsHalfOpen(timeStamp)
            else {
                invalidCount += 1
                continue
            }
            let identity = document.id ?? document.identifier
                ?? "\(Int64(timeStamp.timeIntervalSince1970 * 1_000)):\(sgv.bitPattern)"
            guard identities.insert(identity).inserted else {
                invalidCount += 1
                continue
            }
            records.append(NightscoutImportedBgReading(
                remoteIdentity: identity,
                timeStamp: timeStamp,
                value: sgv,
                device: document.device?.toNilIfLength0(),
                direction: document.direction
            ))
        }
        return (records.sorted { $0.timeStamp < $1.timeStamp }, invalidCount)
    }

    private func prepareTreatments(
        _ documents: [NightscoutTreatmentDocument],
        in interval: DateInterval
    ) -> (records: [NightscoutImportedTreatment], unsupportedCount: Int) {
        var records = [NightscoutImportedTreatment]()
        var unsupportedCount = 0
        for document in documents {
            let createdAt = Self.documentDate(
                milliseconds: document.mills?.value,
                iso8601: document.createdAt ?? document.eventTime
            )
            guard let createdAt,
                  interval.containsHalfOpen(createdAt),
                  let remoteID = document.id ?? document.identifier
            else {
                unsupportedCount += 1
                continue
            }
            let expanded = expandTreatment(document, remoteID: remoteID, createdAt: createdAt)
            if expanded.isEmpty {
                unsupportedCount += 1
            } else {
                records.append(contentsOf: expanded)
            }
        }
        return (records.sorted { $0.date < $1.date }, unsupportedCount)
    }

    private func prepareDeviceStatus(
        _ documents: [NightscoutDeviceStatusResponse],
        in interval: DateInterval
    ) -> (records: [NightscoutDeviceStatus], invalidCount: Int) {
        var records = [NightscoutDeviceStatus]()
        var invalidCount = 0
        var identities = Set<String>()

        for document in documents {
            var status = NightscoutDeviceStatus(from: document)
            guard status.createdAt > .distantPast,
                  interval.containsHalfOpen(status.createdAt)
            else {
                invalidCount += 1
                continue
            }

            let identity = status.id.isEmpty
                ? "createdAt-\(Int(status.createdAt.timeIntervalSince1970 * 1_000))"
                : status.id
            guard identities.insert(identity).inserted else {
                invalidCount += 1
                continue
            }

            status.id = identity
            status.lastCheckedDate = status.createdAt
            status.updatedDate = status.createdAt
            records.append(status)
        }

        return (records.sorted { $0.createdAt < $1.createdAt }, invalidCount)
    }

    private func prepareProfiles(
        _ documents: [NightscoutProfileResponse],
        in interval: DateInterval
    ) -> (profiles: [NightscoutProfile], invalidCount: Int) {
        var validProfiles = [NightscoutProfile]()
        var invalidCount = 0
        var identities = Set<String>()

        for document in documents {
            let profile = NightscoutProfile(from: document)
            guard profile.startDate > .distantPast,
                  profile.startDate.timeIntervalSinceReferenceDate.isFinite,
                  profile.startDate < interval.end
            else {
                invalidCount += 1
                continue
            }
            let identity = profile.id.isEmpty
                ? "startDate-\(Int64(profile.startDate.timeIntervalSince1970 * 1_000))"
                : profile.id
            guard identities.insert(identity).inserted else {
                invalidCount += 1
                continue
            }
            validProfiles.append(profile)
        }

        return (Self.profilesForFollowerRecovery(validProfiles, in: interval), invalidCount)
    }

    /// Selects the active pre-window profile plus every profile change inside the half-open range.
    static func profilesForFollowerRecovery(
        _ profiles: [NightscoutProfile],
        in interval: DateInterval
    ) -> [NightscoutProfile] {
        let ordered = profiles
            .filter { $0.startDate > .distantPast && $0.startDate < interval.end }
            .sorted { $0.startDate < $1.startDate }
        let baseline = ordered.last { $0.startDate < interval.start }
        let inWindow = ordered.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
        return (baseline.map { [$0] } ?? []) + inWindow
    }

    private func expandTreatment(
        _ document: NightscoutTreatmentDocument,
        remoteID: String,
        createdAt: Date
    ) -> [NightscoutImportedTreatment] {
        var records = [NightscoutImportedTreatment]()
        let eventType = document.eventType

        func append(type: TreatmentType, value: Double, secondary: Double = 0, notes: String? = nil) {
            guard value.isFinite, secondary.isFinite else { return }
            records.append(NightscoutImportedTreatment(
                id: remoteID + type.idExtension(),
                date: createdAt,
                value: value,
                valueSecondary: secondary,
                type: type,
                nightscoutEventType: eventType,
                enteredBy: document.enteredBy,
                notes: notes
            ))
        }

        if let carbs = document.carbs?.value, carbs >= 0 { append(type: .Carbs, value: carbs) }
        if let insulin = document.insulin?.value, insulin >= 0 { append(type: .Insulin, value: insulin) }
        if eventType?.caseInsensitiveCompare("Exercise") == .orderedSame,
           let duration = document.duration?.value,
           duration >= 0 {
            append(type: .Exercise, value: duration)
        }
        if let glucose = document.glucose?.value, glucose > 0 {
            let units = document.units?.lowercased() ?? ConstantsNightscout.mgDlNightscoutUnitString
            let value = units.contains("mmol") ? glucose.mmolToMgdl() : glucose
            append(type: .BgCheck, value: value)
        }
        if let rate = document.rate?.value,
           let duration = document.duration?.value,
           duration >= 0 {
            append(type: .Basal, value: rate, secondary: duration)
        }

        switch eventType?.lowercased() {
        case "site change": append(type: .SiteChange, value: 0)
        case "sensor start", "sensor change": append(type: .SensorStart, value: 0)
        case "pump battery change": append(type: .PumpBatteryChange, value: 0)
        case ConstantsNightscout.noteEventType.lowercased():
            if let notes = document.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                append(type: .Note, value: 0, notes: notes)
            }
        default: break
        }
        return records
    }

    // MARK: Core Data Merge

    private func applyBgReadings(
        _ records: [NightscoutImportedBgReading],
        in interval: DateInterval
    ) async throws -> (added: Int, skipped: Int) {
        guard !records.isEmpty else { return (0, 0) }
        let context = coreDataManager.privateChildManagedObjectContext()
        let result = try await context.perform {
            let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            request.predicate = NSPredicate(
                format: "timeStamp >= %@ AND timeStamp < %@",
                interval.start.addingTimeInterval(-Self.duplicateBgWindow) as NSDate,
                interval.end.addingTimeInterval(Self.duplicateBgWindow) as NSDate
            )
            request.includesPropertyValues = true
            let existing = try context.fetch(request)
            var existingIDs = Set(existing.map(\.id))
            var existingTimeStamps = existing.map(\.timeStamp).sorted()
            var added = 0
            var skipped = 0

            for record in records {
                try Task.checkCancellation()
                let localID = Self.importedBgReadingIDPrefix + record.remoteIdentity
                let overlaps = existingTimeStamps.contains {
                    abs($0.timeIntervalSince(record.timeStamp)) <= Self.duplicateBgWindow
                }
                guard !existingIDs.contains(localID), !overlaps else {
                    skipped += 1
                    continue
                }

                let reading = BgReading(
                    timeStamp: record.timeStamp,
                    sensor: nil,
                    calibration: nil,
                    rawData: record.value,
                    deviceName: record.device ?? "Nightscout",
                    nsManagedObjectContext: context
                )
                reading.id = localID
                reading.calculatedValue = record.value
                let slope = Self.slope(forNightscoutDirection: record.direction)
                reading.calculatedValueSlope = slope.value
                reading.hideSlope = slope.hidden
                reading.isSuppressedByFiveMinuteCadence = false
                existingIDs.insert(localID)
                existingTimeStamps.append(record.timeStamp)
                added += 1
            }
            try context.save()
            return (added, skipped)
        }
        try await persistManagedObjectContexts()
        return result
    }

    private func applyTreatments(
        _ records: [NightscoutImportedTreatment],
        in interval: DateInterval
    ) async throws -> (added: Int, skipped: Int) {
        guard !records.isEmpty else { return (0, 0) }
        let context = coreDataManager.privateChildManagedObjectContext()
        let result = try await context.perform {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                interval.start as NSDate,
                interval.end as NSDate
            )
            request.includesPropertyValues = true
            let existing = try context.fetch(request)
            var existingIDs = Set(existing.map(\.id).filter { !$0.isEmpty })
            var fingerprints = Set(existing.map(Self.treatmentFingerprint))
            var added = 0
            var skipped = 0

            for record in records {
                try Task.checkCancellation()
                let fingerprint = Self.treatmentFingerprint(record)
                guard !existingIDs.contains(record.id), !fingerprints.contains(fingerprint) else {
                    skipped += 1
                    continue
                }
                let treatment = TreatmentEntry(
                    id: record.id,
                    date: record.date,
                    value: record.value,
                    valueSecondary: record.valueSecondary,
                    treatmentType: record.type,
                    uploaded: true,
                    nightscoutEventType: record.nightscoutEventType,
                    enteredBy: record.enteredBy,
                    notes: record.notes,
                    nsManagedObjectContext: context
                )
                treatment.treatmentdeleted = false
                existingIDs.insert(record.id)
                fingerprints.insert(fingerprint)
                added += 1
            }
            try context.save()
            return (added, skipped)
        }
        try await persistManagedObjectContexts()
        return result
    }

    /// Follower recovery shares the main context used by live treatment sync. Serializing the
    /// duplicate check and insertion on that context prevents startup recovery and the initial
    /// live download from inserting the same Nightscout treatment concurrently.
    private func applyFollowerTreatments(
        _ records: [NightscoutImportedTreatment],
        in interval: DateInterval
    ) async throws -> (added: Int, skipped: Int) {
        guard !records.isEmpty else { return (0, 0) }
        let context = coreDataManager.mainManagedObjectContext
        let result = try await context.perform {
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                interval.start as NSDate,
                interval.end as NSDate
            )
            request.includesPropertyValues = true
            let existing = try context.fetch(request)
            var existingIDs = Set(existing.map(\.id).filter { !$0.isEmpty })
            var fingerprints = Set(existing.map(Self.treatmentFingerprint))
            var added = 0
            var skipped = 0

            for record in records {
                try Task.checkCancellation()
                let fingerprint = Self.treatmentFingerprint(record)
                guard !existingIDs.contains(record.id), !fingerprints.contains(fingerprint) else {
                    skipped += 1
                    continue
                }
                let treatment = TreatmentEntry(
                    id: record.id,
                    date: record.date,
                    value: record.value,
                    valueSecondary: record.valueSecondary,
                    treatmentType: record.type,
                    uploaded: true,
                    nightscoutEventType: record.nightscoutEventType,
                    enteredBy: record.enteredBy,
                    notes: record.notes,
                    nsManagedObjectContext: context
                )
                treatment.treatmentdeleted = false
                existingIDs.insert(record.id)
                fingerprints.insert(fingerprint)
                added += 1
            }
            try context.save()
            return (added, skipped)
        }
        try await persistManagedObjectContexts()
        return result
    }

    private func applyDeviceStatus(
        _ records: [NightscoutDeviceStatus],
        in interval: DateInterval
    ) async throws -> (added: Int, skipped: Int) {
        guard !records.isEmpty else { return (0, 0) }
        let context = coreDataManager.privateChildManagedObjectContext()
        let result = try await context.perform {
            let request: NSFetchRequest<NightscoutDeviceStatusEntry> = NightscoutDeviceStatusEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "createdAt >= %@ AND createdAt < %@",
                interval.start as NSDate,
                interval.end as NSDate
            )
            request.includesPropertyValues = true
            let existing = try context.fetch(request)
            var existingIDs = Set(existing.map(\.id).filter { !$0.isEmpty })
            var existingCreatedAtMilliseconds = Set(existing.map { Int64($0.createdAt.timeIntervalSince1970 * 1_000) })
            var added = 0
            var skipped = 0

            for status in records {
                try Task.checkCancellation()
                let createdAtMilliseconds = Int64(status.createdAt.timeIntervalSince1970 * 1_000)
                guard !existingIDs.contains(status.id),
                      !existingCreatedAtMilliseconds.contains(createdAtMilliseconds)
                else {
                    skipped += 1
                    continue
                }

                let entry = NightscoutDeviceStatusEntry(context: context)
                Self.apply(status, to: entry)
                existingIDs.insert(entry.id)
                existingCreatedAtMilliseconds.insert(createdAtMilliseconds)
                added += 1
            }
            try context.save()
            return (added, skipped)
        }
        try await persistManagedObjectContexts()
        return result
    }

    /// Saves child changes through both parents before advancing the durable import checkpoint.
    private func persistManagedObjectContexts() async throws {
        let mainContext = coreDataManager.mainManagedObjectContext
        try await mainContext.perform {
            if mainContext.hasChanges {
                try mainContext.save()
            }
        }

        let storeContext = coreDataManager.privateManagedObjectContext
        try await storeContext.perform {
            if storeContext.hasChanges {
                try storeContext.save()
            }
        }
    }

    private static func treatmentFingerprint(_ treatment: TreatmentEntry) -> String {
        treatmentFingerprint(
            date: treatment.date,
            type: treatment.treatmentType,
            value: treatment.value,
            secondary: treatment.valueSecondary,
            notes: treatment.notes
        )
    }

    private static func treatmentFingerprint(_ treatment: NightscoutImportedTreatment) -> String {
        treatmentFingerprint(
            date: treatment.date,
            type: treatment.type,
            value: treatment.value,
            secondary: treatment.valueSecondary,
            notes: treatment.notes
        )
    }

    private static func treatmentFingerprint(
        date: Date,
        type: TreatmentType,
        value: Double,
        secondary: Double,
        notes: String?
    ) -> String {
        "\(Int64(date.timeIntervalSince1970 * 1_000))|\(type.rawValue)|\(value.bitPattern)|\(secondary.bitPattern)|\(notes ?? "")"
    }

    private static func apply(_ status: NightscoutDeviceStatus, to entry: NightscoutDeviceStatusEntry) {
        entry.id = status.id.isEmpty ? "createdAt-\(Int(status.createdAt.timeIntervalSince1970 * 1_000))" : status.id
        entry.createdAt = status.createdAt
        entry.updatedDate = status.updatedDate
        entry.lastCheckedDate = status.lastCheckedDate
        entry.lastLoopDate = status.lastLoopDate
        entry.timestamp = status.timestamp
        entry.device = status.device
        entry.appVersion = status.appVersion
        entry.activeProfile = status.activeProfile
        entry.iob = status.iob.map { NSNumber(value: $0) }
        entry.cob = status.cob.map { NSNumber(value: $0) }
        entry.eventualBG = status.eventualBG.map { NSNumber(value: $0) }
        entry.currentTarget = status.currentTarget.map { NSNumber(value: $0) }
        entry.isf = status.isf.map { NSNumber(value: $0) }
        entry.insulinReq = status.insulinReq.map { NSNumber(value: $0) }
        entry.bolusVolume = status.bolusVolume.map { NSNumber(value: $0) }
        entry.rate = status.rate.map { NSNumber(value: $0) }
        entry.duration = status.duration.map { NSNumber(value: $0) }
        entry.reason = status.reason
        entry.sensitivityRatio = status.sensitivityRatio.map { NSNumber(value: $0) }
        entry.tdd = status.tdd.map { NSNumber(value: $0) }
        entry.error = status.error
        entry.overrideActive = status.overrideActive.map { NSNumber(value: $0) }
        entry.overrideName = status.overrideName
        entry.overrideMinValue = status.overrideMinValue.map { NSNumber(value: $0) }
        entry.overrideMaxValue = status.overrideMaxValue.map { NSNumber(value: $0) }
        entry.overrideMultiplier = status.overrideMultiplier.map { NSNumber(value: $0) }
        entry.pumpBatteryPercent = status.pumpBatteryPercent.map { NSNumber(value: $0) }
        entry.pumpReservoir = status.pumpReservoir.map { NSNumber(value: $0) }
        entry.pumpIsBolusing = status.pumpIsBolusing.map { NSNumber(value: $0) }
        entry.pumpIsSuspended = status.pumpIsSuspended.map { NSNumber(value: $0) }
        entry.pumpStatus = status.pumpStatus
        entry.pumpStatusTimestamp = status.pumpStatusTimestamp
        entry.pumpManufacturer = status.pumpManufacturer
        entry.pumpModel = status.pumpModel
        entry.uploaderBatteryPercent = status.uploaderBatteryPercent.map { NSNumber(value: $0) }
        entry.uploaderIsCharging = status.uploaderIsCharging.map { NSNumber(value: $0) }
    }

    // MARK: Date and Direction Helpers

    private static func documentDate(milliseconds: Double?, iso8601: String?) -> Date? {
        if let milliseconds, milliseconds.isFinite, milliseconds > 0 {
            return Date(timeIntervalSince1970: milliseconds / 1_000)
        }
        guard let iso8601 else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: iso8601)
            ?? ISO8601DateFormatter.withoutFractionalSeconds.date(from: iso8601)
    }

    private static func iso8601String(from date: Date) -> String {
        return ISO8601DateFormatter.withFractionalSeconds.string(from: date)
    }

    private static func slope(forNightscoutDirection direction: String?) -> (value: Double, hidden: Bool) {
        let milligramsPerDeciliterPerMinute: Double
        switch direction?.lowercased() {
        case "doubleup": milligramsPerDeciliterPerMinute = 4
        case "singleup": milligramsPerDeciliterPerMinute = 2.5
        case "fortyfiveup": milligramsPerDeciliterPerMinute = 1.5
        case "flat": milligramsPerDeciliterPerMinute = 0
        case "fortyfivedown": milligramsPerDeciliterPerMinute = -1.5
        case "singledown": milligramsPerDeciliterPerMinute = -2.5
        case "doubledown": milligramsPerDeciliterPerMinute = -4
        default: return (0, true)
        }
        return (milligramsPerDeciliterPerMinute / 60_000, false)
    }
}

private extension DateInterval {
    /// DateInterval.contains includes its end; API range queries deliberately do not.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
