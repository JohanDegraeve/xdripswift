//
//  TherapyMetricsManager.swift
//  xdrip
//
//  Created by Paul Plant on 12/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

extension DataFlowPolicy {
    var externalIOBSource: TherapyMetricSource? {
        importsTherapyFromCareLink ? .careLink : importsStatusFromNightscout ? .nightscout : nil
    }
    var externalCOBSource: TherapyMetricSource? { importsStatusFromNightscout ? .nightscout : nil }
}

struct TherapyTreatment: Sendable {
    let date: Date
    let amount: Double
    let isIOB: Bool
}

/// Core Data is read only on its owning queue. Caches contain detached value types.
/// Reads happen outside the cache lock so a Core Data save notification cannot deadlock a fetch.
final class TherapyMetricsManager {
    static let shared = TherapyMetricsManager()
    static let changed = Notification.Name("TherapyMetricsChanged")
    // Configured during app setup. Snapshot/status providers are read by main-thread consumers.
    // Worker queues use only Core Data queue operations and immutable calculation inputs.
    private var coreDataManager: CoreDataManager?
    private var externalStatus: (() -> AIDStatus?)?
    private let lock = NSLock()
    private var revision = 0
    private var treatmentCache: [String: [TherapyTreatment]] = [:]
    private var treatmentRevision = 0
    private var pendingReads = Set<String>()
    private var failedReads: [String: Date] = [:]
    private let inputQueue = DispatchQueue(label: "therapy.inputs", qos: .utility)
    private let chartQueue = DispatchQueue(label: "therapy.chart", qos: .utility)
    private var externalHistory = TherapyStatusHistoryCache()
    private var chartCache: [String: TherapyChartSeries] = [:]
    private var preferenceSignature = ""
    private var observers: [NSObjectProtocol] = []

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func configure(coreDataManager: CoreDataManager, externalStatus: @escaping () -> AIDStatus?) {
        self.coreDataManager = coreDataManager
        self.externalStatus = externalStatus
        guard observers.isEmpty else { invalidate(); return }
        for name in [Notification.Name.NSManagedObjectContextDidSave, .NSManagedObjectContextObjectsDidChange, NSNotification.Name.NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                if name == .NSManagedObjectContextObjectsDidChange {
                    guard notification.object as? NSManagedObjectContext === self?.coreDataManager?.privateManagedObjectContext,
                          notification.userInfo?[NSInvalidatedAllObjectsKey] != nil else { return }
                }
                var treatmentsChanged = true
                if name == .NSManagedObjectContextDidSave {
                    guard notification.object as? NSManagedObjectContext === self?.coreDataManager?.privateManagedObjectContext else { return }
                    let keys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey]
                    let objects = keys.flatMap { notification.userInfo?[$0] as? Set<NSManagedObject> ?? [] }
                    treatmentsChanged = objects.contains { $0 is TreatmentEntry }
                    guard treatmentsChanged || objects.contains(where: { $0 is NightscoutDeviceStatusEntry }) else { return }
                }
                self?.invalidate(treatmentsChanged: treatmentsChanged)
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            // Do not make background defaults writers wait for the main queue.
            DispatchQueue.main.async { [weak self] in
                // Cache keys include only the relevant preferences. Unrelated defaults do not flush inputs.
                guard let self else { return }
                let signature = "\(UserDefaults.standard.dataFlowPolicy)-\(TherapyModelSettings(defaults: .standard))"
                    + "-\(UserDefaults.standard.showIOBCOB)"
                guard signature != self.preferenceSignature else { return }
                self.preferenceSignature = signature
                NotificationCenter.default.post(name: Self.changed, object: self)
            }
        })
    }

    func invalidate(treatmentsChanged: Bool = true) {
        lock.lock()
        revision &+= 1
        if treatmentsChanged {
            treatmentRevision &+= 1
            treatmentCache.removeAll()
            failedReads.removeAll()
        }
        chartCache.removeAll()
        lock.unlock()
        DispatchQueue.main.async { NotificationCenter.default.post(name: Self.changed, object: self) }
    }

    private func key(policy: DataFlowPolicy, settings: TherapyModelSettings) -> String {
        lock.lock(); let version = revision; lock.unlock()
        return "\(version)-\(UserDefaults.standard.nightscoutTreatmentsUpdateCounter)-\(policy.therapyDataSource.rawValue)-\(policy.nightscoutFollowType.rawValue)-\(settings)"
    }

    func snapshot(at date: Date = .now, external: AIDStatus? = nil, historical: Bool = false) -> TherapyMetricsSnapshot {
        let policy = UserDefaults.standard.dataFlowPolicy
        let settings = TherapyModelSettings(defaults: .standard)
        let status = historical ? external : externalStatus?() ?? external
        let needsInputs = policy.externalIOBSource == nil || policy.externalCOBSource == nil
        let currentDate = Date()
        let window = TherapyModelSettings.visibilityInterval
        let entries = needsInputs ? treatments(from: date.addingTimeInterval(-window),
            to: min(currentDate, date.addingTimeInterval(window)), policy: policy, settings: settings) : []
        let recentEntries = needsInputs && historical ? treatments(from: currentDate.addingTimeInterval(-window),
            to: currentDate, policy: policy, settings: settings) : []
        return Self.resolve(at: date, external: status, policy: policy, settings: settings, entries: entries,
            currentDate: currentDate, recentEntries: recentEntries)
    }

    static func resolve(at date: Date, external status: AIDStatus?, policy: DataFlowPolicy, settings: TherapyModelSettings, entries: [TherapyTreatment]?, currentDate: Date? = nil, recentEntries: [TherapyTreatment]? = []) -> TherapyMetricsSnapshot {
        var result = TherapyMetricsSnapshot.external(status, at: date)
        // Ownership is configured capability, even when a poll has returned no status at all.
        if let source = policy.externalIOBSource {
            result.iob.source = source
            if status == nil { result.iob.reason = .missingExternalData }
        }
        if let source = policy.externalCOBSource {
            result.cob.source = source
            if status == nil { result.cob.reason = .missingExternalData }
        }
        if policy.externalIOBSource == nil {
            result.iob = Self.localMetric(entries: entries, isIOB: true, date: date, settings: settings, currentDate: currentDate, recentEntries: recentEntries)
        }
        if policy.externalCOBSource == nil {
            result.cob = Self.localMetric(entries: entries, isIOB: false, date: date, settings: settings, currentDate: currentDate, recentEntries: recentEntries)
        }
        return result
    }

    static func localMetric(entries: [TherapyTreatment]?, isIOB: Bool, date: Date, settings: TherapyModelSettings,
                            currentDate: Date? = nil, recentEntries: [TherapyTreatment]? = []) -> TherapyMetricState {
        let currentDate = currentDate ?? date
        let window = TherapyModelSettings.visibilityInterval
        var state = TherapyMetricState(source: .local, referenceDate: date, reason: .noTreatments)
        guard isIOB ? settings.validInsulin : settings.validCarbs else { state.reason = .invalidSettings; return state }
        guard let entries, let recentEntries else { state.reason = .readFailed; return state }
        // One pass avoids allocating several filtered treatment arrays for every chart sample.
        // Either treatment type enables both metrics, but only matching past entries add amount.
        var deadline: Date?
        var amount = 0.0
        func includeVisibility(_ entry: TherapyTreatment, nearby: Bool) {
            if nearby, abs(entry.date.timeIntervalSince(date)) < window {
                deadline = max(deadline ?? .distantPast, entry.date.addingTimeInterval(window))
            }
            if entry.date > currentDate.addingTimeInterval(-window) {
                let recentDeadline = date.addingTimeInterval(entry.date.addingTimeInterval(window).timeIntervalSince(currentDate))
                deadline = max(deadline ?? .distantPast, recentDeadline)
            }
        }
        for entry in entries where entry.amount.isFinite && entry.amount > 0 && entry.date <= currentDate {
            includeVisibility(entry, nearby: true)
            guard entry.isIOB == isIOB, entry.date <= date, entry.date > date.addingTimeInterval(-window) else { continue }
            let minutes = date.timeIntervalSince(entry.date) / 60
            amount += isIOB
                ? TherapyCalculations.insulinRemaining(units: entry.amount, minutes: minutes, duration: settings.insulinDuration, peak: settings.insulinPeak)
                : TherapyCalculations.carbsRemaining(grams: entry.amount, minutes: minutes, duration: settings.carbDuration)
        }
        for entry in recentEntries where entry.amount.isFinite && entry.amount > 0 && entry.date <= currentDate {
            includeVisibility(entry, nearby: false)
        }
        guard let deadline else { return state }
        state.amount = amount.isFinite ? amount : nil
        state.visibilityDeadline = deadline
        state.expiresAt = min(date.addingTimeInterval(TherapyModelSettings.freshnessInterval), deadline)
        state.reason = state.amount?.isFinite == true ? nil : .invalidSettings
        return state
    }

    func treatments(from start: Date, to end: Date, policy: DataFlowPolicy, settings: TherapyModelSettings) -> [TherapyTreatment]? {
        guard let coreDataManager else { return nil }
        // Hour buckets let 15-second refreshes reuse the same input snapshot, including future entries.
        let from = Date(timeIntervalSince1970: floor(start.timeIntervalSince1970 / 3600) * 3600)
        let to = Date(timeIntervalSince1970: (floor(end.timeIntervalSince1970 / 3600) + 1) * 3600)
        lock.lock()
        let generation = treatmentRevision
        let cacheKey = "\(generation)-\(policy.therapyDataSource.rawValue)-\(policy.nightscoutFollowType.rawValue)-\(from)-\(to)"
        let cached = treatmentCache[cacheKey]
        let recentlyFailed = failedReads[cacheKey].map { Date().timeIntervalSince($0) < 60 } ?? false
        if let cached { lock.unlock(); return cached }
        if recentlyFailed { lock.unlock(); return nil }
        if Thread.isMainThread {
            let shouldFetch = pendingReads.count < 8 && pendingReads.insert(cacheKey).inserted
            lock.unlock()
            if shouldFetch {
                inputQueue.async { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    let stillNeeded = generation == self.treatmentRevision
                    self.lock.unlock()
                    if stillNeeded { _ = self.treatments(from: start, to: end, policy: policy, settings: settings) }
                    self.lock.lock()
                    self.pendingReads.remove(cacheKey)
                    let current = generation == self.treatmentRevision
                    self.lock.unlock()
                    if current {
                        DispatchQueue.main.async { NotificationCenter.default.post(name: Self.changed, object: self) }
                    }
                }
            }
            // A missing/failed read is unavailable, never a confident zero. Publication
            // is refreshed when the immutable input snapshot arrives.
            return nil
        }
        lock.unlock()
        // Only worker queues wait for Core Data. Failed/pending saves cannot leak
        // optimistic amounts into the display.
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coreDataManager.privateManagedObjectContext.persistentStoreCoordinator
        var result: [TherapyTreatment]?
        context.performAndWait {
            let request = TreatmentEntry.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND (treatmentdeleted == NO OR treatmentdeleted == nil) AND treatmentType IN %@", from as NSDate, to as NSDate, [TreatmentType.Insulin.rawValue, TreatmentType.Carbs.rawValue])
            do {
                result = try context.fetch(request).filter { entry in
                    let careLink = entry.careLinkSourceIdentifier != nil || (entry.nightscoutEventType != nil && entry.enteredBy == "CareLink")
                    if careLink { return policy.importsTherapyFromCareLink }
                    // Local bolus/carb entries keep a nil remote event type through upload and
                    // reconciliation. enteredBy is editable text, not reliable source identity.
                    let local = entry.id.isEmpty || entry.nightscoutEventType == nil
                    return local || policy.importsTreatmentsFromNightscout
                }.map { TherapyTreatment(date: $0.date, amount: $0.value, isIOB: $0.treatmentType == .Insulin) }
            } catch { result = nil }
        }
        lock.lock()
        defer { lock.unlock() }
        guard generation == treatmentRevision else { return nil }
        if treatmentCache.count > 6 { treatmentCache.removeAll() }
        if failedReads.count > 6 { failedReads.removeAll() }
        treatmentCache[cacheKey] = result
        if result == nil { failedReads[cacheKey] = Date() }
        return result
    }

    func chart(from start: Date, to end: Date) async -> TherapyChartSeries {
        let cancellation = TherapyChartCancellation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                chartQueue.async(execute: DispatchWorkItem {
                    continuation.resume(returning: self.buildChart(from: start, to: end, isCancelled: { cancellation.isCancelled }))
                })
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private func buildChart(from start: Date, to end: Date, isCancelled: () -> Bool) -> TherapyChartSeries {
        // Serial GCD work does not block Swift concurrency's cooperative executor.
        // Superseded requests leave the queue without fetching or calculating.
        guard !isCancelled() else { return TherapyChartSeries() }
        guard let coreDataManager else { return TherapyChartSeries() }
        let end = min(end, Date())
        guard start < end else { return TherapyChartSeries() }
        let policy = UserDefaults.standard.dataFlowPolicy
        let settings = TherapyModelSettings(defaults: .standard)
        let cacheKey = "\(key(policy: policy, settings: settings))-\(start.timeIntervalSince1970)-\(floor(end.timeIntervalSince1970 / 300))-\(floor(Date().timeIntervalSince1970 / 60))"
        lock.lock(); let cached = chartCache[cacheKey]; let generation = revision; lock.unlock()
        if let cached { return cached }
        let currentDate = Date()
        let window = TherapyModelSettings.visibilityInterval
        let needsLocalInputs = policy.externalIOBSource == nil || policy.externalCOBSource == nil
        let entries = needsLocalInputs ? treatments(from: start.addingTimeInterval(-window), to: min(currentDate, end.addingTimeInterval(window)), policy: policy, settings: settings) : []
        let recentEntries = needsLocalInputs ? treatments(from: currentDate.addingTimeInterval(-window), to: currentDate, policy: policy, settings: settings) : []
        let statuses = policy.aidAnalyticsSource.map { source in
            externalHistory.load(key: "\(generation)-\(policy.therapyDataSource.rawValue)-\(policy.nightscoutFollowType.rawValue)",
                from: start.addingTimeInterval(-TherapyModelSettings.externalChartJoinInterval), to: end) { from, to in
                NightscoutDeviceStatusAccessor(coreDataManager: coreDataManager).fetch(fromDate: from, toDate: to)
                    .filter { source.ownsDeviceStatus(with: $0.device) }
            }
        } ?? []
        guard !isCancelled() else { return TherapyChartSeries() }
        let result = Self.chartSeries(entries: entries, statuses: statuses, policy: policy, settings: settings, start: start, end: end, currentDate: currentDate, recentEntries: recentEntries, isCancelled: isCancelled)
        guard !isCancelled() else { return TherapyChartSeries() }
        lock.lock(); defer { lock.unlock() }
        guard generation == revision else { return TherapyChartSeries() }
        if chartCache.count > 6 { chartCache.removeAll() }
        chartCache[cacheKey] = result
        return result
    }
    static func chartSeries(entries: [TherapyTreatment]?, statuses: [NightscoutDeviceStatusSnapshot], policy: DataFlowPolicy, settings: TherapyModelSettings, start: Date, end: Date, currentDate: Date? = nil, recentEntries: [TherapyTreatment]? = [], isCancelled: () -> Bool = { false }) -> TherapyChartSeries {
        func series(isIOB: Bool) -> [TherapyChartPoint] {
            guard !isCancelled() else { return [] }
            if (isIOB ? policy.externalIOBSource : policy.externalCOBSource) != nil {
                return externalChartPoints(statuses: statuses, isIOB: isIOB, start: start, end: end, isCancelled: isCancelled)
            }
            guard let entries else { return [] }
            var dates = Set([start, end])
            var t = ceil(start.timeIntervalSince1970 / 300) * 300
            while t < end.timeIntervalSince1970 { dates.insert(Date(timeIntervalSince1970: t)); t += 300 }
            for entry in entries {
                guard !isCancelled() else { return [] }
                for offset in [-TherapyModelSettings.visibilityInterval, 0.0, entry.isIOB ? settings.insulinDuration * 60 : (settings.carbDuration + TherapyModelSettings.carbDelay) * 60, TherapyModelSettings.visibilityInterval] {
                    let boundary = entry.date.addingTimeInterval(offset)
                    for date in [boundary.addingTimeInterval(-0.001), boundary, boundary.addingTimeInterval(0.001)] where date >= start && date <= end { dates.insert(date) }
                }
            }
            var segment = 0, points: [TherapyChartPoint] = []
            for date in dates.sorted() {
                guard !isCancelled() else { return [] }
                let state = Self.localMetric(entries: entries, isIOB: isIOB, date: date, settings: settings, currentDate: currentDate ?? end, recentEntries: recentEntries)
                guard let amount = state.value(at: date) else { segment += 1; continue }
                // Keep the treatment's before/after values at exactly the same time.
                // This draws a vertical jump without anticipating the dose or breaking the line.
                let added = entries.filter {
                    $0.isIOB == isIOB && $0.date == date && $0.amount.isFinite && $0.amount > 0
                }.reduce(0) { $0 + $1.amount }
                let before = max(0, amount - added)
                if added > 0, before != amount {
                    points.append(TherapyChartPoint(date: date, amount: before, segment: segment))
                }
                points.append(TherapyChartPoint(date: date, amount: amount, segment: segment))
            }
            return points
        }
        return TherapyChartSeries(iob: series(isIOB: true), cob: series(isIOB: false))
    }

    /// Status rows may contain only pump/uploader changes. An absent metric does not
    /// invalidate a nearby AID reading. Continuity depends on time between valid readings.
    static func externalChartPoints(statuses: [NightscoutDeviceStatusSnapshot], isIOB: Bool, start: Date, end: Date, isCancelled: () -> Bool = { false }) -> [TherapyChartPoint] {
        guard !isCancelled() else { return [] }
        let freshness = TherapyModelSettings.freshnessInterval
        var values: [Date: Double] = [:]
        for status in statuses.sorted(by: {
            if $0.updatedDate != $1.updatedDate { return $0.updatedDate < $1.updatedDate }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }) {
            guard !isCancelled() else { return [] }
            guard status.createdAt <= end,
                  let amount = isIOB ? status.iob : status.cob, amount.isFinite else { continue }
            // AID systems can upload the same calculation several times with new createdAt
            // values. Plot one point at calculation time, not a staircase of upload times.
            let date: Date
            if let calculatedAt = status.timestamp, calculatedAt > .distantPast,
               calculatedAt <= status.createdAt.addingTimeInterval(60) {
                guard status.createdAt.timeIntervalSince(calculatedAt) < freshness else { continue }
                date = calculatedAt
            } else {
                date = status.createdAt
            }
            guard date <= end else { continue }
            // Keep the latest stored revision of a calculation, independently per metric.
            values[date] = amount
        }
        let dates = values.keys.sorted()
        var points: [TherapyChartPoint] = [], segment = 0
        func append(_ date: Date, _ amount: Double) {
            guard date >= start && date <= end else { return }
            points.append(TherapyChartPoint(date: date, amount: amount, segment: segment))
        }
        for (index, date) in dates.enumerated() {
            guard !isCancelled() else { return [] }
            guard let amount = values[date] else { continue }
            let next = index + 1 < dates.count ? dates[index + 1] : nil
            let joinsNext = next.map { $0.timeIntervalSince(date) < TherapyModelSettings.externalChartJoinInterval } ?? false
            if date < start, (joinsNext || start < date.addingTimeInterval(freshness)), (next.map { $0 > start } ?? true) {
                let boundaryAmount: Double
                if joinsNext, let next, let nextAmount = values[next] {
                    boundaryAmount = amount + (nextAmount - amount) * start.timeIntervalSince(date) / next.timeIntervalSince(date)
                } else {
                    boundaryAmount = amount
                }
                append(start, boundaryAmount)
            }
            append(date, amount)
            if !joinsNext {
                // A fresh isolated reading still has a visible segment. Stop before expiry.
                // Never connect across a genuine outage or extend a frozen value indefinitely.
                let freshEnd = min(end, date.addingTimeInterval(freshness - 0.001))
                if freshEnd > max(date, start) { append(freshEnd, amount) }
                segment += 1
            }
        }
        return points
    }

}

/// A bounded, retained history window. Scrolls append/prepend only missing edges.
/// Source changes, data revisions and disjoint jumps reset it. Owned by the serial chart queue.
struct TherapyStatusHistoryCache {
    private var key: String?
    private var range: ClosedRange<Date>?
    private var records: [String: NightscoutDeviceStatusSnapshot] = [:]

    mutating func load(key: String, from start: Date, to end: Date,
                       fetch: (Date, Date) -> [NightscoutDeviceStatusSnapshot]) -> [NightscoutDeviceStatusSnapshot] {
        guard start <= end else { return [] }
        let request = start...end
        if self.key != key || range.map({ !$0.overlaps(request) }) ?? true {
            records.removeAll()
            range = nil
            self.key = key
        }
        var missing: [(Date, Date)] = []
        if let range {
            if start < range.lowerBound { missing.append((start, range.lowerBound)) }
            if end > range.upperBound { missing.append((range.upperBound, end)) }
        } else {
            missing.append((start, end))
        }
        for (from, to) in missing {
            for record in fetch(from, to) { records[record.id] = record }
        }
        let lower = min(range?.lowerBound ?? start, start)
        let upper = max(range?.upperBound ?? end, end)
        let buffer = min(max(end.timeIntervalSince(start) * 0.5, 3600), 24 * 3600)
        let retained = max(lower, start.addingTimeInterval(-buffer))...min(upper, end.addingTimeInterval(buffer))
        records = records.filter { retained.contains($0.value.createdAt) }
        range = retained
        return records.values.filter { request.contains($0.createdAt) }
    }
}

/// Cancellation crosses the task and serial worker queues without retaining a task's closure.
final class TherapyChartCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }
}
