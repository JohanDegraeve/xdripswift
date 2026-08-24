//
//  NightscoutFollowerGapFillService.swift
//  xdrip
//
//  Created by Paul Plant on 13/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import UIKit

/// One silent refresh notification for views that cache historical treatment or pump data.
extension Notification.Name {
    static let nightscoutFollowerGapFillDidMergeHistory = Notification.Name("nightscoutFollowerGapFillDidMergeHistory")
}

/// Detached summary passed to the application coordinator after historical data was merged.
struct NightscoutFollowerGapFillResult: Sendable {
    var bgReadingsAdded = 0
    var treatmentsAdded = 0
    var deviceStatusesAdded = 0
    var profilesAdded = 0
    var bgProcessingStartDate: Date?
    var earliestChangedDate: Date?

    var totalAdded: Int {
        bgReadingsAdded + treatmentsAdded + deviceStatusesAdded + profilesAdded
    }

    var hasChanges: Bool { totalAdded > 0 }

    mutating func recordChangedWindow(_ interval: DateInterval) {
        earliestChangedDate = min(earliestChangedDate ?? interval.start, interval.start)
    }
}

/// Performs bounded, incremental Nightscout follower history recovery.
///
/// Glucose can be cadence-audited, so only significant leading/internal gaps are requested.
/// Treatments, device status and profiles are sparse streams and are therefore range-swept.
/// The live follower remains responsible for current data and all live-reading side effects.
final class NightscoutFollowerGapFillService: @unchecked Sendable {
    static let initialAuditDuration: TimeInterval = 72 * 60 * 60
    static let auditOverlap: TimeInterval = 30 * 60
    static let minimumGapDuration: TimeInterval = 15 * 60
    static let minimumIncrementalAdvance: TimeInterval = 15 * 60

    enum Resource: String, Codable, CaseIterable, Sendable {
        case bgReadings
        case treatments
        case deviceStatus
        case profiles
    }

    struct AuditWindow: Equatable {
        let interval: DateInterval
        let isInitial: Bool
    }

    struct CoverageState: Codable, Equatable {
        var site: String
        var bgReadingsEnd: Date?
        var treatmentsEnd: Date?
        var deviceStatusEnd: Date?
        var profilesEnd: Date?

        init(
            site: String,
            bgReadingsEnd: Date? = nil,
            treatmentsEnd: Date? = nil,
            deviceStatusEnd: Date? = nil,
            profilesEnd: Date? = nil
        ) {
            self.site = site
            self.bgReadingsEnd = bgReadingsEnd
            self.treatmentsEnd = treatmentsEnd
            self.deviceStatusEnd = deviceStatusEnd
            self.profilesEnd = profilesEnd
        }

        func endDate(for resource: Resource) -> Date? {
            switch resource {
            case .bgReadings: bgReadingsEnd
            case .treatments: treatmentsEnd
            case .deviceStatus: deviceStatusEnd
            case .profiles: profilesEnd
            }
        }

        mutating func setEndDate(_ date: Date, for resource: Resource) {
            switch resource {
            case .bgReadings: bgReadingsEnd = date
            case .treatments: treatmentsEnd = date
            case .deviceStatus: deviceStatusEnd = date
            case .profiles: profilesEnd = date
            }
        }
    }

    struct RecoveryPlan: Equatable {
        let auditEnd: Date
        let site: String
        let windows: [Resource: AuditWindow]

        var isEmpty: Bool { windows.isEmpty }
        var isInitial: Bool { windows.values.contains(where: \.isInitial) }
    }

    private let bgReadingsAccessor: BgReadingsAccessor
    private let importService: NightscoutImportService
    private let defaults: UserDefaults
    private let onHistoryMerged: (NightscoutFollowerGapFillResult) -> Void
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutFollowManager)

    /// All state transitions are made on the main queue. The identifier prevents a cancelled
    /// operation from publishing after a newer lifecycle generation has started.
    private var gapFillTask: Task<Void, Never>?
    private var activeRunID: UUID?
    private var cancellationRequested = false

    init(
        coreDataManager: CoreDataManager,
        defaults: UserDefaults = .standard,
        onHistoryMerged: @escaping (NightscoutFollowerGapFillResult) -> Void
    ) {
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.importService = NightscoutImportService(coreDataManager: coreDataManager)
        self.defaults = defaults
        self.onHistoryMerged = onHistoryMerged
    }

    /// Starts one audit. Duplicate foreground/startup triggers are intentionally coalesced.
    func run(endingAt auditEnd: Date = Date()) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.run(endingAt: auditEnd)
            }
            return
        }
        guard activeRunID == nil,
              isNightscoutFollowerActive,
              UIApplication.shared.applicationState != .background,
              let site = normalizedConfiguredSite()
        else { return }

        let coverage = loadCoverage(for: site)
        let policy = defaults.dataFlowPolicy
        let plan = Self.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: coverage,
            importsTreatments: policy.importsTreatmentsFromNightscout,
            importsStatus: policy.importsStatusFromNightscout
        )
        guard !plan.isEmpty else { return }

        let bgWindow = plan.windows[.bgReadings]
        let timestamps = bgWindow.map {
            bgReadingsAccessor.getReadingTimestamps(
                fromDate: $0.interval.start,
                toDate: $0.interval.end,
                forSensor: nil
            )
        } ?? []
        let bgIntervals = bgWindow.map {
            Self.gapFillIntervals(timestamps: timestamps, in: $0.interval)
        } ?? []

        trace(
            "in Nightscout follower gap fill, starting %{public}@ recovery. end = %{public}@, resources = %{public}@, local readings = %{public}@, BG gaps = %{public}@",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info,
            troubleshooting: .detailed(.integration(name: .nightscoutBackfill, activity: .started)),
            plan.isInitial ? "initial" : "incremental",
            auditEnd.toStringForTrace(timeStyle: .long, dateStyle: .long),
            Self.resourceDescription(plan.windows).joined(separator: ", "),
            timestamps.count.description,
            bgIntervals.count.description
        )

        let runID = UUID()
        activeRunID = runID
        cancellationRequested = false
        let importService = importService
        gapFillTask = Task { [weak self] in
            var result = NightscoutFollowerGapFillResult()
            var firstFailureType: String?
            var firstFailureCode: Int?
            do {
                if plan.windows[.bgReadings] != nil {
                    do {
                        if !bgIntervals.isEmpty {
                            let merged = try await importService.mergeBgReadings(in: bgIntervals)
                            result.bgReadingsAdded = merged.readingsAdded
                            if merged.readingsAdded > 0, let firstInterval = bgIntervals.first {
                                result.bgProcessingStartDate = firstInterval.start
                                result.recordChangedWindow(firstInterval)
                            }
                            await self?.traceBgCompletion(merged, rangeCount: bgIntervals.count)
                        } else {
                            await self?.traceBgNoGapCompletion()
                        }
                        guard await self?.advanceCoverage(
                            runID: runID,
                            resource: .bgReadings,
                            auditEnd: plan.auditEnd,
                            site: plan.site
                        ) == true else { throw CancellationError() }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let nsError = error as NSError
                        firstFailureType = firstFailureType ?? String(describing: Swift.type(of: error))
                        firstFailureCode = firstFailureCode ?? nsError.code
                        await self?.traceResourceFailure(.bgReadings, error: error)
                    }
                }

                if let window = plan.windows[.treatments] {
                    do {
                        let merged = try await importService.mergeTreatments(in: window.interval)
                        result.treatmentsAdded = merged.treatmentsAdded
                        if merged.treatmentsAdded > 0 { result.recordChangedWindow(window.interval) }
                        await self?.traceTreatmentCompletion(merged)
                        guard await self?.advanceCoverage(
                            runID: runID,
                            resource: .treatments,
                            auditEnd: plan.auditEnd,
                            site: plan.site
                        ) == true else { throw CancellationError() }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let nsError = error as NSError
                        firstFailureType = firstFailureType ?? String(describing: Swift.type(of: error))
                        firstFailureCode = firstFailureCode ?? nsError.code
                        await self?.traceResourceFailure(.treatments, error: error)
                    }
                }

                if let window = plan.windows[.profiles] {
                    do {
                        let merged = try await importService.mergeProfiles(in: window.interval)
                        result.profilesAdded = merged.profilesAdded
                        if merged.profilesAdded > 0 { result.recordChangedWindow(window.interval) }
                        await self?.traceProfileCompletion(merged)
                        guard await self?.advanceCoverage(
                            runID: runID,
                            resource: .profiles,
                            auditEnd: plan.auditEnd,
                            site: plan.site
                        ) == true else { throw CancellationError() }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let nsError = error as NSError
                        firstFailureType = firstFailureType ?? String(describing: Swift.type(of: error))
                        firstFailureCode = firstFailureCode ?? nsError.code
                        await self?.traceResourceFailure(.profiles, error: error)
                    }
                }

                if let window = plan.windows[.deviceStatus] {
                    do {
                        let merged = try await importService.mergeDeviceStatus(in: window.interval)
                        result.deviceStatusesAdded = merged.statusesAdded
                        if merged.statusesAdded > 0 { result.recordChangedWindow(window.interval) }
                        await self?.traceDeviceStatusCompletion(merged)
                        guard await self?.advanceCoverage(
                            runID: runID,
                            resource: .deviceStatus,
                            auditEnd: plan.auditEnd,
                            site: plan.site
                        ) == true else { throw CancellationError() }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let nsError = error as NSError
                        firstFailureType = firstFailureType ?? String(describing: Swift.type(of: error))
                        firstFailureCode = firstFailureCode ?? nsError.code
                        await self?.traceResourceFailure(.deviceStatus, error: error)
                    }
                }

                try Task.checkCancellation()
                let completedResult = result
                if let firstFailureType, let firstFailureCode {
                    await MainActor.run { [weak self] in
                        self?.finishFailure(
                            runID: runID,
                            result: completedResult,
                            errorType: firstFailureType,
                            errorCode: firstFailureCode
                        )
                    }
                } else {
                    await MainActor.run { [weak self] in
                        self?.finish(runID: runID, result: completedResult)
                    }
                }
            } catch is CancellationError {
                let partialResult = result
                await MainActor.run { [weak self] in
                    self?.finishCancellation(runID: runID, result: partialResult)
                }
            } catch {
                let nsError = error as NSError
                let partialResult = result
                await MainActor.run { [weak self] in
                    self?.finishFailure(
                        runID: runID,
                        result: partialResult,
                        errorType: String(describing: Swift.type(of: error)),
                        errorCode: nsError.code
                    )
                }
            }
        }
    }

    /// Cancels active range work. Completed resource checkpoints remain durable; the active
    /// resource is deliberately left at its previous successful endpoint.
    func cancel() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.cancel() }
            return
        }
        guard activeRunID != nil else { return }
        cancellationRequested = true
        gapFillTask?.cancel()
        trace(
            "in Nightscout follower gap fill, cancellation requested; unfinished resource checkpoint will not advance",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info
        )
    }

    static func auditWindow(
        endingAt auditEnd: Date,
        lastSuccessfulEnd: Date?,
        storedSite: String?,
        currentSite: String
    ) -> AuditWindow {
        let earliestAllowedStart = auditEnd.addingTimeInterval(-initialAuditDuration)
        guard storedSite == currentSite,
              let lastSuccessfulEnd,
              lastSuccessfulEnd.timeIntervalSinceReferenceDate.isFinite,
              lastSuccessfulEnd <= auditEnd
        else {
            return AuditWindow(interval: DateInterval(start: earliestAllowedStart, end: auditEnd), isInitial: true)
        }

        return AuditWindow(
            interval: DateInterval(
                start: max(earliestAllowedStart, lastSuccessfulEnd.addingTimeInterval(-auditOverlap)),
                end: auditEnd
            ),
            isInitial: false
        )
    }

    static func migratedCoverage(
        storedCoverage: CoverageState?,
        legacyEnd: Date?,
        legacySite: String?,
        currentSite: String
    ) -> CoverageState {
        if let storedCoverage, storedCoverage.site == currentSite {
            return storedCoverage
        }
        guard storedCoverage == nil, legacySite == currentSite else {
            return CoverageState(site: currentSite)
        }
        // The legacy checkpoint proved glucose coverage only. Sparse streams intentionally start
        // with a full recovery window after this feature upgrade.
        return CoverageState(site: currentSite, bgReadingsEnd: legacyEnd)
    }

    static func recoveryPlan(
        endingAt auditEnd: Date,
        site: String,
        coverage: CoverageState,
        importsTreatments: Bool,
        importsStatus: Bool
    ) -> RecoveryPlan {
        var windows = [Resource: AuditWindow]()
        let resources: [Resource] = [.bgReadings]
            + (importsTreatments ? [.treatments] : [])
            + (importsStatus ? [.profiles, .deviceStatus] : [])

        for resource in resources {
            let checkpoint = coverage.site == site ? coverage.endDate(for: resource) : nil
            let validCheckpoint = checkpoint.flatMap {
                $0.timeIntervalSinceReferenceDate.isFinite && $0 <= auditEnd ? $0 : nil
            }
            if let validCheckpoint,
               auditEnd.timeIntervalSince(validCheckpoint) < minimumIncrementalAdvance {
                continue
            }
            windows[resource] = auditWindow(
                endingAt: auditEnd,
                lastSuccessfulEnd: validCheckpoint,
                storedSite: coverage.site,
                currentSite: site
            )
        }
        return RecoveryPlan(auditEnd: auditEnd, site: site, windows: windows)
    }

    /// Returns half-open leading/internal ranges. The live follower owns the trailing interval.
    static func gapFillIntervals(
        timestamps: [Date],
        in auditInterval: DateInterval,
        gapThreshold: TimeInterval = NightscoutFollowerGapFillService.minimumGapDuration
    ) -> [DateInterval] {
        let sortedTimestamps = timestamps
            .filter { $0 >= auditInterval.start && $0 <= auditInterval.end }
            .sorted()
        guard let first = sortedTimestamps.first else { return [auditInterval] }

        var intervals = [DateInterval]()
        if first.timeIntervalSince(auditInterval.start) > gapThreshold {
            intervals.append(DateInterval(start: auditInterval.start, end: first))
        }
        for (older, newer) in zip(sortedTimestamps, sortedTimestamps.dropFirst())
            where newer.timeIntervalSince(older) > gapThreshold {
            intervals.append(DateInterval(start: older, end: newer))
        }
        return intervals
    }

    private var isNightscoutFollowerActive: Bool {
        defaults.nightscoutEnabled
            && !defaults.isMaster
            && defaults.followerDataSourceType == .nightscout
            && defaults.nightscoutUrl != nil
    }

    private func normalizedConfiguredSite() -> String? {
        guard let configuredURL = defaults.nightscoutUrl,
              var components = URLComponents(string: configuredURL)
        else { return nil }
        let port = defaults.nightscoutPort
        if port != 0 {
            guard (1 ... 65_535).contains(port) else { return nil }
            components.port = port
        }
        return NightscoutImportService.normalizedSiteIdentity(from: components)
    }

    private func loadCoverage(for site: String) -> CoverageState {
        let stored = defaults.nightscoutFollowerGapFillCoverage.flatMap {
            try? JSONDecoder().decode(CoverageState.self, from: $0)
        }
        return Self.migratedCoverage(
            storedCoverage: stored,
            legacyEnd: defaults.nightscoutFollowerGapFillLastAuditEndDate,
            legacySite: defaults.nightscoutFollowerGapFillSite,
            currentSite: site
        )
    }

    private func resourceIsEnabled(_ resource: Resource) -> Bool {
        guard isNightscoutFollowerActive else { return false }
        let policy = defaults.dataFlowPolicy
        switch resource {
        case .bgReadings: return true
        case .treatments: return policy.importsTreatmentsFromNightscout
        case .deviceStatus, .profiles: return policy.importsStatusFromNightscout
        }
    }

    @MainActor
    private func advanceCoverage(runID: UUID, resource: Resource, auditEnd: Date, site: String) -> Bool {
        guard activeRunID == runID,
              !cancellationRequested,
              UIApplication.shared.applicationState != .background,
              normalizedConfiguredSite() == site,
              resourceIsEnabled(resource)
        else { return false }

        var coverage = loadCoverage(for: site)
        coverage.setEndDate(auditEnd, for: resource)
        guard let data = try? JSONEncoder().encode(coverage) else { return false }
        defaults.nightscoutFollowerGapFillCoverage = data
        // Keep the legacy BG properties current for downgrade compatibility.
        if resource == .bgReadings {
            defaults.nightscoutFollowerGapFillSite = site
            defaults.nightscoutFollowerGapFillLastAuditEndDate = auditEnd
        }
        trace(
            "in Nightscout follower gap fill, %{public}@ checkpoint advanced to %{public}@",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info,
            resource.rawValue,
            auditEnd.toStringForTrace(timeStyle: .long, dateStyle: .long)
        )
        return true
    }

    @MainActor
    private func traceBgCompletion(_ result: NightscoutBgRangeMergeResult, rangeCount: Int) {
        trace(
            "in Nightscout follower gap fill, BG completed. ranges = %{public}@, downloaded = %{public}@, added = %{public}@, skipped = %{public}@, invalid = %{public}@",
            log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info,
            rangeCount.description, result.documentsDownloaded.description, result.readingsAdded.description,
            result.readingsSkipped.description, result.documentsInvalid.description
        )
    }

    @MainActor
    private func traceBgNoGapCompletion() {
        trace(
            "in Nightscout follower gap fill, BG completed with no gaps greater than 15 minutes",
            log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info,
            troubleshooting: .detailed(.integration(name: .nightscoutBackfill, activity: .noData))
        )
    }

    @MainActor
    private func traceTreatmentCompletion(_ result: NightscoutTreatmentRangeMergeResult) {
        trace(
            "in Nightscout follower gap fill, treatments completed. downloaded = %{public}@, added = %{public}@, skipped = %{public}@, unsupported = %{public}@",
            log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info,
            result.documentsDownloaded.description, result.treatmentsAdded.description,
            result.treatmentsSkipped.description, result.documentsUnsupported.description
        )
    }

    @MainActor
    private func traceProfileCompletion(_ result: NightscoutProfileRangeMergeResult) {
        trace(
            "in Nightscout follower gap fill, profiles completed. downloaded = %{public}@, added = %{public}@, skipped = %{public}@, invalid = %{public}@",
            log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info,
            result.documentsDownloaded.description, result.profilesAdded.description,
            result.profilesSkipped.description, result.documentsInvalid.description
        )
    }

    @MainActor
    private func traceDeviceStatusCompletion(_ result: NightscoutDeviceStatusRangeMergeResult) {
        trace(
            "in Nightscout follower gap fill, device status completed. downloaded = %{public}@, added = %{public}@, skipped = %{public}@, invalid = %{public}@",
            log: log, category: ConstantsLog.categoryNightscoutFollowManager, type: .info,
            result.documentsDownloaded.description, result.statusesAdded.description,
            result.statusesSkipped.description, result.documentsInvalid.description
        )
    }

    @MainActor
    private func traceResourceFailure(_ resource: Resource, error: Error) {
        let nsError = error as NSError
        trace(
            "in Nightscout follower gap fill, %{public}@ failed. error type = %{public}@, code = %{public}@; checkpoint not advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .error,
            resource.rawValue,
            String(describing: Swift.type(of: error)),
            nsError.code.description
        )
    }

    private func finish(runID: UUID, result: NightscoutFollowerGapFillResult) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        cancellationRequested = false
        gapFillTask = nil
        publishIfNeeded(result)
        trace(
            "in Nightscout follower gap fill, completed. BG added = %{public}@, treatments added = %{public}@, device status added = %{public}@, profiles added = %{public}@",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info,
            troubleshooting: .detailed(.integration(name: .nightscoutBackfill, activity: .succeeded(itemCount: result.totalAdded))),
            result.bgReadingsAdded.description,
            result.treatmentsAdded.description,
            result.deviceStatusesAdded.description,
            result.profilesAdded.description
        )
    }

    private func finishCancellation(runID: UUID, result: NightscoutFollowerGapFillResult) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        cancellationRequested = false
        gapFillTask = nil
        publishIfNeeded(result)
        trace(
            "in Nightscout follower gap fill, cancelled; unfinished resource checkpoint not advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info
        )
    }

    private func finishFailure(
        runID: UUID,
        result: NightscoutFollowerGapFillResult,
        errorType: String,
        errorCode: Int
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        cancellationRequested = false
        gapFillTask = nil
        publishIfNeeded(result)
        trace(
            "in Nightscout follower gap fill, failed. error type = %{public}@, code = %{public}@; unfinished resource checkpoint not advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .error,
            troubleshooting: .detailed(.integration(name: .nightscoutBackfill, activity: .failed)),
            errorType,
            errorCode.description
        )
    }

    private func publishIfNeeded(_ result: NightscoutFollowerGapFillResult) {
        guard result.hasChanges else { return }
        onHistoryMerged(result)
    }

    private static func resourceDescription(_ windows: [Resource: AuditWindow]) -> [String] {
        Resource.allCases.compactMap { resource in
            guard let window = windows[resource] else { return nil }
            return "\(resource.rawValue)[\(window.interval.start.toStringForTrace(timeStyle: .short, dateStyle: .short))...\(window.interval.end.toStringForTrace(timeStyle: .short, dateStyle: .short))]"
        }
    }
}
