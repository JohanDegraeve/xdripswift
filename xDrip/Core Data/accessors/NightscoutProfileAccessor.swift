//
//  NightscoutProfileAccessor.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

enum NightscoutProfileScheduleKind: Int16, CaseIterable, Sendable {
    case basal = 0
    case carbRatio = 1
    case sensitivity = 2
    case targetLow = 3
    case targetHigh = 4
}

/// A managed-object-free profile and its normalized schedule rows.
///
/// Keeping schedules inside the value snapshot lets report code use profile history without
/// retaining managed objects after the private Core Data context has finished its fetch.
struct NightscoutProfileSnapshot: Sendable {
    let id: String
    let startDate: Date
    let createdAt: Date
    let updatedDate: Date
    let lastCheckedDate: Date
    let profileName: String?
    let enteredBy: String?
    let timezone: String?
    let dia: Double?
    let isMgDl: Bool?
    let basal: [NightscoutProfile.TimeValue]
    let carbRatio: [NightscoutProfile.TimeValue]
    let sensitivity: [NightscoutProfile.TimeValue]
    let targetLow: [NightscoutProfile.TimeValue]
    let targetHigh: [NightscoutProfile.TimeValue]
}

/// Owns persistence and date-range retrieval for normalized Nightscout profiles.
final class NightscoutProfileAccessor {
    private let coreDataManager: CoreDataManager
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutSyncManager)

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    /// Updates the matching profile, or creates it when it has not been stored before.
    ///
    /// Re-importing a profile replaces its schedule rows as one operation. This avoids mixing an
    /// old schedule with a revised Nightscout profile that happens to use the same identifier.
    ///
    /// Live profiles are stored directly on the private context because they are never edited by the UI.
    @discardableResult
    func upsert(_ profile: NightscoutProfile) async -> Bool {
        guard profile.startDate > .distantPast || !profile.id.isEmpty else { return false }

        let context = coreDataManager.privateManagedObjectContext
        let log = log
        return await context.perform {
            let entry = Self.existingEntry(for: profile, on: context) ?? NightscoutProfileEntry(context: context)
            Self.apply(profile, to: entry, on: context)
            do {
                if context.hasChanges {
                    try context.save()
                }
                return true
            } catch {
                context.rollback()
                trace("in NightscoutProfileAccessor.upsert, error = %{public}@", log: log, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
                return false
            }
        }
    }

    /// Inserts missing historical profiles without rewriting profiles already stored locally.
    ///
    /// The automatic follower recovery is merge-only. A profile is considered known by its
    /// Nightscout identifier, or by its start date when the identifier is absent.
    func insertMissing(_ profiles: [NightscoutProfile]) async throws -> (added: Int, skipped: Int) {
        guard !profiles.isEmpty else { return (0, 0) }

        let context = coreDataManager.privateManagedObjectContext
        return try await context.perform {
            let request: NSFetchRequest<NightscoutProfileEntry> = NightscoutProfileEntry.fetchRequest()
            request.includesPropertyValues = true
            let existing = try context.fetch(request)
            var existingIDs = Set(existing.map(\.id).filter { !$0.isEmpty })
            var existingStartMilliseconds = Set(existing.map { Int64($0.startDate.timeIntervalSince1970 * 1_000) })
            var added = 0
            var skipped = 0

            for profile in profiles {
                try Task.checkCancellation()
                let startMilliseconds = Int64(profile.startDate.timeIntervalSince1970 * 1_000)
                let matchesID = !profile.id.isEmpty && existingIDs.contains(profile.id)
                guard !matchesID, !existingStartMilliseconds.contains(startMilliseconds) else {
                    skipped += 1
                    continue
                }

                let entry = NightscoutProfileEntry(context: context)
                Self.apply(profile, to: entry, on: context)
                existingIDs.insert(entry.id)
                existingStartMilliseconds.insert(startMilliseconds)
                added += 1
            }

            if context.hasChanges {
                try context.save()
            }
            return (added, skipped)
        }
    }

    /// Returns the newest detached profile, including every normalized schedule.
    func latest() -> NightscoutProfileSnapshot? {
        let context = coreDataManager.privateManagedObjectContext
        var snapshot: NightscoutProfileSnapshot?
        context.performAndWait {
            let request: NSFetchRequest<NightscoutProfileEntry> = NightscoutProfileEntry.fetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NightscoutProfileEntry.startDate), ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["schedules"]
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true
            snapshot = try? context.fetch(request).first.map(Self.snapshot(from:))
        }
        return snapshot
    }

    /// Fetches detached profile snapshots in chronological order.
    ///
    /// Passing a `nil` start date is intentional for reports: the newest profile before the
    /// reporting period is the baseline that remains active until another profile starts.
    func fetch(fromDate: Date?, toDate: Date?) -> [NightscoutProfileSnapshot] {
        let context = coreDataManager.privateManagedObjectContext
        var snapshots: [NightscoutProfileSnapshot] = []
        context.performAndWait {
            let request: NSFetchRequest<NightscoutProfileEntry> = NightscoutProfileEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NightscoutProfileEntry.startDate), ascending: true)]
            request.relationshipKeyPathsForPrefetching = ["schedules"]
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            var predicates = [NSPredicate]()
            if let fromDate {
                predicates.append(NSPredicate(format: "startDate >= %@", fromDate as NSDate))
            }
            if let toDate {
                predicates.append(NSPredicate(format: "startDate <= %@", toDate as NSDate))
            }
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            do {
                snapshots = try context.fetch(request).map(Self.snapshot(from:))
            } catch {
                trace("in NightscoutProfileAccessor.fetch, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
        return snapshots
    }

    /// Removes superseded profile history while preserving the active pre-boundary baseline.
    @discardableResult
    func deleteOlderThan(_ date: Date) -> Int {
        let context = coreDataManager.privateManagedObjectContext
        var deletedCount = 0
        context.performAndWait {
            let request: NSFetchRequest<NightscoutProfileEntry> = NightscoutProfileEntry.fetchRequest()
            request.predicate = NSPredicate(format: "startDate < %@", date as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NightscoutProfileEntry.startDate), ascending: false)]
            do {
                // Keep the newest profile before the retention boundary. It is the
                // baseline schedule that remains active until the next profile change.
                let profiles = Array(try context.fetch(request).dropFirst())
                profiles.forEach { context.delete($0) }
                deletedCount = profiles.count
                let objectIDs = profiles.map(\.objectID)
                if context.hasChanges {
                    try context.save()
                }
                if !objectIDs.isEmpty {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                        into: [context, self.coreDataManager.mainManagedObjectContext]
                    )
                }
            } catch {
                trace("in NightscoutProfileAccessor.deleteOlderThan, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
        return deletedCount
    }

    private static func existingEntry(for profile: NightscoutProfile, on context: NSManagedObjectContext) -> NightscoutProfileEntry? {
        let request: NSFetchRequest<NightscoutProfileEntry> = NightscoutProfileEntry.fetchRequest()
        request.fetchLimit = 1
        if !profile.id.isEmpty {
            request.predicate = NSPredicate(format: "id == %@", profile.id)
        } else {
            request.predicate = NSPredicate(format: "startDate == %@", profile.startDate as NSDate)
        }
        return try? context.fetch(request).first
    }

    private static func apply(_ profile: NightscoutProfile, to entry: NightscoutProfileEntry, on context: NSManagedObjectContext) {
        entry.id = profile.id.isEmpty ? "startDate-\(Int(profile.startDate.timeIntervalSince1970 * 1000))" : profile.id
        entry.startDate = profile.startDate
        entry.createdAt = profile.createdAt
        entry.updatedDate = profile.updatedDate
        entry.lastCheckedDate = profile.lastCheckedDate
        entry.profileName = profile.profileName
        entry.enteredBy = profile.enteredBy
        entry.timezone = profile.timezone
        entry.dia = profile.dia.nsNumber
        entry.isMgDl = profile.isMgDl.nsNumber

        if let schedules = entry.schedules as? Set<NightscoutProfileScheduleEntry> {
            schedules.forEach { context.delete($0) }
        }

        addSchedules(profile.basal, kind: .basal, profileEntry: entry, on: context)
        addSchedules(profile.carbratio, kind: .carbRatio, profileEntry: entry, on: context)
        addSchedules(profile.sensitivity, kind: .sensitivity, profileEntry: entry, on: context)
        addSchedules(profile.targetLow, kind: .targetLow, profileEntry: entry, on: context)
        addSchedules(profile.targetHigh, kind: .targetHigh, profileEntry: entry, on: context)
    }

    private static func addSchedules(_ schedules: [NightscoutProfile.TimeValue]?, kind: NightscoutProfileScheduleKind, profileEntry: NightscoutProfileEntry, on context: NSManagedObjectContext) {
        schedules?.forEach { timeValue in
            let entry = NightscoutProfileScheduleEntry(context: context)
            entry.kind = kind.rawValue
            entry.timeAsSecondsFromMidnight = Int32(timeValue.timeAsSecondsFromMidnight)
            entry.value = timeValue.value
            entry.profile = profileEntry
        }
    }

    private static func snapshot(from entry: NightscoutProfileEntry) -> NightscoutProfileSnapshot {
        let schedules = (entry.schedules as? Set<NightscoutProfileScheduleEntry>) ?? []

        func values(for kind: NightscoutProfileScheduleKind) -> [NightscoutProfile.TimeValue] {
            schedules
                .filter { $0.kind == kind.rawValue }
                .sorted { $0.timeAsSecondsFromMidnight < $1.timeAsSecondsFromMidnight }
                .map { NightscoutProfile.TimeValue(timeAsSecondsFromMidnight: Int($0.timeAsSecondsFromMidnight), value: $0.value) }
        }

        return NightscoutProfileSnapshot(
            id: entry.id,
            startDate: entry.startDate,
            createdAt: entry.createdAt,
            updatedDate: entry.updatedDate,
            lastCheckedDate: entry.lastCheckedDate,
            profileName: entry.profileName,
            enteredBy: entry.enteredBy,
            timezone: entry.timezone,
            dia: entry.dia?.doubleValue,
            isMgDl: entry.isMgDl?.boolValue,
            basal: values(for: .basal),
            carbRatio: values(for: .carbRatio),
            sensitivity: values(for: .sensitivity),
            targetLow: values(for: .targetLow),
            targetHigh: values(for: .targetHigh)
        )
    }
}

private extension Optional where Wrapped == Double {
    var nsNumber: NSNumber? {
        map { NSNumber(value: $0) }
    }
}

private extension Optional where Wrapped == Bool {
    var nsNumber: NSNumber? {
        map { NSNumber(value: $0) }
    }
}
