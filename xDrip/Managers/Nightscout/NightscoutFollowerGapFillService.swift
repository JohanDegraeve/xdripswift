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

/// Performs a bounded, incremental audit for missing Nightscout follower readings.
///
/// Live follower downloads remain responsible for current data. This helper only identifies
/// significant leading or internal gaps after a successful startup/foreground download and asks
/// the established historical importer to merge-fill those exact ranges.
final class NightscoutFollowerGapFillService: @unchecked Sendable {
    static let initialAuditDuration: TimeInterval = 72 * 60 * 60
    static let auditOverlap: TimeInterval = 30 * 60
    static let minimumGapDuration: TimeInterval = 15 * 60

    struct AuditWindow: Equatable {
        let interval: DateInterval
        let isInitial: Bool
    }

    private let bgReadingsAccessor: BgReadingsAccessor
    private let importService: NightscoutImportService
    private let defaults: UserDefaults
    private let onReadingsAdded: (Date) -> Void
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutFollowManager)

    /// All state transitions are made on the main queue. The identifier prevents a cancelled
    /// operation from publishing after a newer lifecycle generation has started.
    private var gapFillTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init(
        coreDataManager: CoreDataManager,
        defaults: UserDefaults = .standard,
        onReadingsAdded: @escaping (Date) -> Void
    ) {
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.importService = NightscoutImportService(coreDataManager: coreDataManager)
        self.defaults = defaults
        self.onReadingsAdded = onReadingsAdded
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

        let window = Self.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: defaults.nightscoutFollowerGapFillLastAuditEndDate,
            storedSite: defaults.nightscoutFollowerGapFillSite,
            currentSite: site
        )
        let timestamps = bgReadingsAccessor.getReadingTimestamps(
            fromDate: window.interval.start,
            toDate: window.interval.end,
            forSensor: nil
        )
        let intervals = Self.gapFillIntervals(timestamps: timestamps, in: window.interval)

        trace(
            "in Nightscout follower gap fill, starting %{public}@ audit. start = %{public}@, end = %{public}@, local readings = %{public}@, gaps = %{public}@",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info,
            window.isInitial ? "initial" : "incremental",
            window.interval.start.toStringForTrace(timeStyle: .long, dateStyle: .long),
            window.interval.end.toStringForTrace(timeStyle: .long, dateStyle: .long),
            timestamps.count.description,
            intervals.count.description
        )

        guard !intervals.isEmpty else {
            saveCheckpoint(endingAt: auditEnd, site: site)
            trace(
                "in Nightscout follower gap fill, completed with no gaps greater than 15 minutes; audit checkpoint advanced",
                log: log,
                category: ConstantsLog.categoryNightscoutFollowManager,
                type: .info
            )
            return
        }

        let runID = UUID()
        activeRunID = runID
        let importService = importService
        gapFillTask = Task { [weak self] in
            do {
                let result = try await importService.mergeBgReadings(in: intervals)
                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    self?.finish(
                        runID: runID,
                        auditEnd: auditEnd,
                        site: site,
                        intervals: intervals,
                        result: result
                    )
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    self?.finishCancellation(runID: runID)
                }
            } catch {
                let nsError = error as NSError
                await MainActor.run { [weak self] in
                    self?.finishFailure(runID: runID, errorType: String(describing: Swift.type(of: error)), errorCode: nsError.code)
                }
            }
        }
    }

    /// Cancels active range work. The previous successful checkpoint is deliberately retained.
    func cancel() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.cancel()
            }
            return
        }
        guard activeRunID != nil else { return }
        activeRunID = nil
        gapFillTask?.cancel()
        gapFillTask = nil
        trace(
            "in Nightscout follower gap fill, cancelled; audit checkpoint not advanced",
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
            return AuditWindow(
                interval: DateInterval(start: earliestAllowedStart, end: auditEnd),
                isInitial: true
            )
        }

        return AuditWindow(
            interval: DateInterval(
                start: max(earliestAllowedStart, lastSuccessfulEnd.addingTimeInterval(-auditOverlap)),
                end: auditEnd
            ),
            isInitial: false
        )
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

        for (older, newer) in zip(sortedTimestamps, sortedTimestamps.dropFirst()) where newer.timeIntervalSince(older) > gapThreshold {
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

    private func finish(
        runID: UUID,
        auditEnd: Date,
        site: String,
        intervals: [DateInterval],
        result: NightscoutBgRangeMergeResult
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        gapFillTask = nil

        guard isNightscoutFollowerActive,
              UIApplication.shared.applicationState != .background,
              normalizedConfiguredSite() == site
        else {
            trace(
                "in Nightscout follower gap fill, lifecycle changed before completion; audit checkpoint not advanced",
                log: log,
                category: ConstantsLog.categoryNightscoutFollowManager,
                type: .info
            )
            return
        }

        saveCheckpoint(endingAt: auditEnd, site: site)
        trace(
            "in Nightscout follower gap fill, completed. ranges = %{public}@, downloaded = %{public}@, added = %{public}@, skipped = %{public}@, invalid = %{public}@; audit checkpoint advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info,
            intervals.count.description,
            result.documentsDownloaded.description,
            result.readingsAdded.description,
            result.readingsSkipped.description,
            result.documentsInvalid.description
        )

        if result.readingsAdded > 0, let earliestStart = intervals.first?.start {
            onReadingsAdded(earliestStart)
        }
    }

    private func finishCancellation(runID: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        gapFillTask = nil
        trace(
            "in Nightscout follower gap fill, cancelled; audit checkpoint not advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .info
        )
    }

    private func finishFailure(runID: UUID, errorType: String, errorCode: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard activeRunID == runID else { return }
        activeRunID = nil
        gapFillTask = nil
        trace(
            "in Nightscout follower gap fill, failed. error type = %{public}@, code = %{public}@; audit checkpoint not advanced",
            log: log,
            category: ConstantsLog.categoryNightscoutFollowManager,
            type: .error,
            errorType,
            errorCode.description
        )
    }

    private func saveCheckpoint(endingAt auditEnd: Date, site: String) {
        defaults.nightscoutFollowerGapFillSite = site
        defaults.nightscoutFollowerGapFillLastAuditEndDate = auditEnd
    }
}
