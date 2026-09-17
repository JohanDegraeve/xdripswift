//
//  CareLinkTherapyImporter.swift
//  xdripswift
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import os

protocol CareLinkTherapyImporting: AnyObject {
    func importPumpStatuses(
        _ pump: CareLinkPumpSnapshot,
        treatments: [CareLinkTherapyRecord],
        metadata: CareLinkMetadata,
        checkedAt: Date
    ) async -> Int
    func importTreatments(_ records: [CareLinkTherapyRecord]) async -> Int
}

/// Persists native CareLink treatments in the app's existing treatment store.
///
/// Imported records deliberately retain an empty Nightscout identifier and `uploaded == false`.
/// This allows the normal Nightscout manager to export them without creating a second upload path.
final class CareLinkTherapyImporter: CareLinkTherapyImporting {
    private let coreDataManager: CoreDataManager
    private var timestampRepairCompleted: Bool
    private var patientAliases: [String: String]
    private let isAppActive: @MainActor () -> Bool
    private let deviceStatusAccessor: NightscoutDeviceStatusAccessor
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)

    init(coreDataManager: CoreDataManager,
         isAppActive: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active }) {
        self.coreDataManager = coreDataManager
        self.isAppActive = isAppActive
        // Imports are serialized by CareLinkFollowManager. Cache durable migration and alias state.
        self.timestampRepairCompleted = UserDefaults.standard.bool(
            forKey: UserDefaults.Key.careLinkTimestampRepairCompleted.rawValue)
        self.patientAliases = UserDefaults.standard.dictionary(
            forKey: UserDefaults.Key.careLinkPatientAliases.rawValue) as? [String: String] ?? [:]
        self.deviceStatusAccessor = NightscoutDeviceStatusAccessor(coreDataManager: coreDataManager)
    }

    /// Stores the complete current pump snapshot and every proven automatic-basal history point.
    ///
    /// Every current snapshot retains its reservoir, battery and active insulin at the returned
    /// device timestamp. Additional older basal markers do not contain those telemetry fields, so
    /// only those reconstructed rows leave them empty.
    func importPumpStatuses(
        _ pump: CareLinkPumpSnapshot,
        treatments: [CareLinkTherapyRecord],
        metadata: CareLinkMetadata,
        checkedAt: Date
    ) async -> Int {
        let currentStatus = pump.homeDeviceStatus(metadata: metadata, checkedAt: checkedAt)
        let currentDate = currentStatus?.createdAt
        var statuses = treatments.compactMap {
            $0.historicalPumpDeviceStatus(metadata: metadata, checkedAt: checkedAt)
        }
        if let currentDate {
            statuses.removeAll { abs($0.createdAt.timeIntervalSince(currentDate)) < 1 }
        }
        if let currentStatus {
            statuses.append(currentStatus)
        }

        let insertedCount = await deviceStatusAccessor.upsert(statuses)
        if insertedCount > 0 {
            trace(
                "CareLink imported %{public}d device-status records",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .info,
                insertedCount
            )
        }
        return insertedCount
    }

    /// Adds records not already represented by the same stable CareLink marker identity.
    /// The legacy content fingerprint also protects users who imported treatments before the
    /// dedicated source field was added to the Core Data model.
    func importTreatments(_ records: [CareLinkTherapyRecord]) async -> Int {
        guard !records.isEmpty else { return 0 }
        guard await repairTimestampDuplicatesIfNeeded(records) else { return 0 }
        await migrateLegacyAutomaticBasals()
        let context = coreDataManager.privateChildManagedObjectContext()
        let earliest = records.map(\.date).min() ?? .now
        let latest = records.map(\.date).max() ?? .now
        let knownAliases = patientAliases
        let requestedSourceIdentifiers = records.map { CareLinkPatientIdentity.normalized($0, aliases: knownAliases).sourceIdentifier }

        do {
            let result = try await context.perform {
                let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "careLinkSourceIdentifier IN %@", requestedSourceIdentifiers),
                    NSPredicate(
                        format: "date >= %@ AND date <= %@ AND enteredBy == %@",
                        earliest.addingTimeInterval(-5) as NSDate,
                        latest.addingTimeInterval(5) as NSDate,
                        Self.enteredBy
                    )
                ])
                request.includesPropertyValues = true
                // Repair tombstones must not compete with their retained, corrected event.
                let fetched = try context.fetch(request).filter { !$0.treatmentdeleted }
                let stored = fetched.map(Self.record)
                // This is only the incoming history window, not another full-store migration.
                // A changed namespace is expected; corroborate and remember its relationship.
                let aliases = CareLinkPatientIdentity.aliases(stored: stored, incoming: records, known: knownAliases)
                let identityPlan = CareLinkPatientIdentity.reconcile(stored: stored, incoming: records, aliases: aliases)
                for index in identityPlan.removed {
                    fetched[index].treatmentdeleted = true
                    fetched[index].uploaded = false
                }
                for (index, record) in identityPlan.replacements {
                    Self.apply(record, to: fetched[index])
                    fetched[index].careLinkSourceIdentifier = record.sourceIdentifier
                }
                let existing = fetched.filter { !$0.treatmentdeleted }
                let records = records.map { CareLinkPatientIdentity.normalized($0, aliases: aliases) }
                var entriesBySourceIdentifier = [String: TreatmentEntry]()
                existing.forEach { entry in
                    if let identifier = entry.careLinkSourceIdentifier {
                        entriesBySourceIdentifier[identifier] = entry
                    }
                }
                var legacyEntriesByFingerprint = Dictionary(
                    grouping: existing.filter { $0.careLinkSourceIdentifier == nil },
                    by: Self.fingerprint
                )
                var automaticBasalEntriesByEvent = Dictionary(
                    grouping: existing.filter { $0.treatmentType == .AutomaticBasal },
                    by: Self.basalEventKey
                )
                var added = 0
                for record in records {
                    if let existingEntry = entriesBySourceIdentifier[record.sourceIdentifier] {
                        Self.apply(record, to: existingEntry)
                        if record.type == .AutomaticBasal {
                            let eventKey = Self.basalEventKey(record)
                            automaticBasalEntriesByEvent[eventKey]?
                                .filter { $0 != existingEntry }
                                .forEach(context.delete)
                            automaticBasalEntriesByEvent[eventKey] = [existingEntry]
                        }
                        continue
                    }
                    if record.type == .AutomaticBasal,
                       var matchingEntries = automaticBasalEntriesByEvent[Self.basalEventKey(record)],
                       let existingEntry = matchingEntries.popLast() {
                        Self.apply(record, to: existingEntry)
                        existingEntry.careLinkSourceIdentifier = record.sourceIdentifier
                        matchingEntries.forEach(context.delete)
                        automaticBasalEntriesByEvent[Self.basalEventKey(record)] = [existingEntry]
                        entriesBySourceIdentifier[record.sourceIdentifier] = existingEntry
                        continue
                    }
                    let fingerprint = Self.fingerprint(record)
                    if let legacyEntry = legacyEntriesByFingerprint[fingerprint]?.popLast() {
                        Self.apply(record, to: legacyEntry)
                        legacyEntry.careLinkSourceIdentifier = record.sourceIdentifier
                        entriesBySourceIdentifier[record.sourceIdentifier] = legacyEntry
                        continue
                    }
                    let treatment = TreatmentEntry(
                        date: record.date,
                        value: record.value,
                        valueSecondary: record.durationMinutes,
                        treatmentType: record.type,
                        nightscoutEventType: record.nightscoutEventType,
                        enteredBy: Self.enteredBy,
                        notes: record.notes,
                        nsManagedObjectContext: context
                    )
                    treatment.treatmentdeleted = false
                    treatment.careLinkSourceIdentifier = record.sourceIdentifier
                    entriesBySourceIdentifier[record.sourceIdentifier] = treatment
                    added += 1
                }
                let hadChanges = context.hasChanges
                if hadChanges { try context.save() }
                return (added: added, hadChanges: hadChanges, aliases: aliases)
            }
            if result.hadChanges || result.aliases != patientAliases {
                let saved = await MainActor.run {
                    guard coreDataManager.saveChangesSynchronously() else { return false }
                    UserDefaults.standard.set(result.aliases, forKey: UserDefaults.Key.careLinkPatientAliases.rawValue)
                    UserDefaults.standard.nightscoutTreatmentsUpdateCounter += 1
                    if UserDefaults.standard.dataFlowPolicy.exportsTreatmentsToNightscout {
                        UserDefaults.standard.nightscoutSyncRequired = true
                    }
                    return true
                }
                guard saved else { return 0 }
                if result.aliases != patientAliases {
                    trace("CareLink reconciled patient namespaces; %{public}d aliases retained", log: log,
                          category: ConstantsLog.categoryCareLinkFollowManager, type: .info, result.aliases.count)
                }
                patientAliases = result.aliases
            }
            if result.added > 0 {
                trace("CareLink imported %{public}d therapy records", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, result.added)
            }
            return result.added
        } catch {
            trace("CareLink therapy import failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            return 0
        }
    }

    /// Run once for the store, immediately before the first corrected therapy import. Deleted
    /// copies retain their IDs so the existing Nightscout sync can remove uploaded duplicates.
    private func repairTimestampDuplicatesIfNeeded(_ records: [CareLinkTherapyRecord]) async -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.isMaster, defaults.followerDataSourceType == .careLink else { return true }
        let marker = UserDefaults.Key.careLinkTimestampRepairCompleted.rawValue
        guard !timestampRepairCompleted else { return true }
        let knownAliases = patientAliases
        // Do not import corrected identities beside unrepaired rows while backgrounded.
        // Glucose import is independent; therapy resumes on the next foreground poll.
        guard await isAppActive() else { return false }
        let context = coreDataManager.privateChildManagedObjectContext()
        do {
            let result = try await context.perform {
                let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
                request.predicate = NSPredicate(format: "enteredBy == %@ AND (treatmentdeleted == NO OR treatmentdeleted == nil)", Self.enteredBy)
                // IDs can rotate. Repair all CareLink history, including namespaces no longer fetched.
                let entries = try context.fetch(request).filter { $0.careLinkSourceIdentifier != nil }
                    .sorted { $0.objectID.uriRepresentation().absoluteString < $1.objectID.uriRepresentation().absoluteString }
                let stored = entries.map { entry in
                    CareLinkTherapyRecord(sourceIdentifier: entry.careLinkSourceIdentifier!, date: entry.date,
                        type: entry.treatmentType, value: entry.value, durationMinutes: entry.valueSecondary,
                        nightscoutEventType: entry.nightscoutEventType ?? "", notes: entry.notes)
                }
                let plan = CareLinkTimestampRepair.plan(stored: stored, incoming: records, knownAliases: knownAliases)
                for index in plan.removed {
                    entries[index].treatmentdeleted = true
                    entries[index].uploaded = false
                }
                for (index, record) in plan.replacements {
                    Self.apply(record, to: entries[index])
                    entries[index].careLinkSourceIdentifier = record.sourceIdentifier
                }
                if context.hasChanges { try context.save() }
                return (removed: plan.removed.count, adopted: plan.replacements.count, aliases: plan.patientAliases)
            }
            return await MainActor.run {
                let defaults = UserDefaults.standard
                // The ordinary save is asynchronous; never mark the migration complete until
                // the parent contexts have successfully committed to the persistent store.
                guard coreDataManager.saveChangesSynchronously() else { return false }
                patientAliases = result.aliases
                defaults.set(patientAliases, forKey: UserDefaults.Key.careLinkPatientAliases.rawValue)
                timestampRepairCompleted = true
                defaults.set(true, forKey: marker)
                if result.removed > 0 || result.adopted > 0 {
                    defaults.nightscoutTreatmentsUpdateCounter += 1
                    if defaults.dataFlowPolicy.exportsTreatmentsToNightscout {
                        defaults.nightscoutSyncRequired = true
                    }
                }
                trace("CareLink timestamp repair removed %{public}d duplicate treatments, reconciled %{public}d event identities, retained %{public}d patient aliases", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, result.removed, result.adopted, result.aliases.count)
                return true
            }
        } catch {
            trace("CareLink timestamp repair failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            return false
        }
    }

    /// A readable source label is kept separate from the Nightscout identifier.
    private static let enteredBy = "CareLink"

    /// Converts the earlier CareLink U/hr representation into native delivered insulin amounts.
    /// The query itself is the migration marker, so this remains safe to run before every import.
    private func migrateLegacyAutomaticBasals() async {
        let context = coreDataManager.privateChildManagedObjectContext()

        do {
            let migrated = try await context.perform {
                let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "treatmentType == %@", NSNumber(value: TreatmentType.Basal.rawValue)),
                    NSPredicate(format: "enteredBy == %@", Self.enteredBy),
                    NSPredicate(format: "value >= 0 AND valueSecondary > 0")
                ])
                request.includesPropertyValues = true

                let treatments = try context.fetch(request)
                for treatment in treatments {
                    treatment.value = treatment.value * treatment.valueSecondary / 60
                    treatment.treatmentType = .AutomaticBasal
                }
                if context.hasChanges { try context.save() }
                return treatments.count
            }

            guard migrated > 0 else { return }
            await MainActor.run {
                coreDataManager.saveChanges()
                UserDefaults.standard.nightscoutTreatmentsUpdateCounter += 1
            }
            trace("CareLink migrated %{public}d automatic basal treatments to native doses", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, migrated)
        } catch {
            trace("CareLink automatic basal migration failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
        }
    }

    /// Uses whole-second time because CareLink may alternate between ISO seconds and epoch millis.
    private static func fingerprint(_ record: CareLinkTherapyRecord) -> String {
        fingerprint(date: record.date, type: record.type, value: record.value, duration: record.durationMinutes)
    }

    private static func fingerprint(_ treatment: TreatmentEntry) -> String {
        fingerprint(date: treatment.date, type: treatment.treatmentType, value: treatment.value, duration: treatment.valueSecondary)
    }

    private static func fingerprint(date: Date, type: TreatmentType, value: Double, duration: Double) -> String {
        let timestamp = Int64(date.timeIntervalSince1970.rounded())
        return [String(timestamp), String(type.rawValue), value.description, duration.description].joined(separator: "|")
    }

    private static func basalEventKey(_ record: CareLinkTherapyRecord) -> String {
        (CareLinkPatientIdentity.patient(record.sourceIdentifier) ?? "") + "|" + basalEventKey(date: record.date)
    }

    private static func basalEventKey(_ treatment: TreatmentEntry) -> String {
        (CareLinkPatientIdentity.patient(treatment.careLinkSourceIdentifier ?? "") ?? "") + "|" + basalEventKey(date: treatment.date)
    }

    private static func basalEventKey(date: Date) -> String {
        "\(Int64(date.timeIntervalSince1970.rounded()))|automatic-basal"
    }

    private static func record(_ entry: TreatmentEntry) -> CareLinkTherapyRecord {
        CareLinkTherapyRecord(sourceIdentifier: entry.careLinkSourceIdentifier ?? "", date: entry.date,
            type: entry.treatmentType, value: entry.value, durationMinutes: entry.valueSecondary,
            nightscoutEventType: entry.nightscoutEventType ?? "", notes: entry.notes)
    }

    private static func apply(_ record: CareLinkTherapyRecord, to treatment: TreatmentEntry) {
        let changed = treatment.date != record.date
            || treatment.value != record.value
            || treatment.valueSecondary != record.durationMinutes
            || treatment.treatmentType != record.type
            || treatment.nightscoutEventType != record.nightscoutEventType
            || treatment.notes != record.notes

        treatment.date = record.date
        treatment.value = record.value
        treatment.valueSecondary = record.durationMinutes
        treatment.treatmentType = record.type
        treatment.nightscoutEventType = record.nightscoutEventType
        treatment.enteredBy = enteredBy
        treatment.notes = record.notes
        treatment.treatmentdeleted = false
        if changed {
            treatment.uploaded = false
        }
    }
}

extension CareLinkTherapyRecord {
    /// Builds a sparse historical pump status only from an automatic-basal marker.
    /// `lastLoopDate` carries proven SmartGuard activity into the existing status model. It does
    /// not represent a synthetic loop cycle or a Nightscout result.
    func historicalPumpDeviceStatus(metadata: CareLinkMetadata, checkedAt: Date) -> NightscoutDeviceStatus? {
        guard type == .AutomaticBasal,
              sourceIdentifier.contains("|AUTO_BASAL_DELIVERY|"),
              value.isFinite,
              value >= 0,
              durationMinutes.isFinite,
              durationMinutes > 0
        else {
            return nil
        }

        var status = NightscoutDeviceStatus()
        status.id = "carelink-\(Int(date.timeIntervalSince1970 * 1000))"
        status.createdAt = date
        status.updatedDate = checkedAt
        status.lastCheckedDate = checkedAt
        status.lastLoopDate = date
        status.timestamp = date
        status.device = "carelink://pump-history"
        status.rate = AutomaticBasalTreatmentMath.rate(amount: value, durationSeconds: durationMinutes * 60)
        status.duration = Int(durationMinutes.rounded())
        status.pumpStatus = "Automatic Basal"
        status.pumpStatusTimestamp = date
        status.pumpManufacturer = "Medtronic"
        status.pumpModel = metadata.deviceModel
        return status
    }
}

extension CareLinkPumpSnapshot {
    /// Adapts CareLink pump values for the existing compact Home pump calculations.
    /// The CareLink device identity is retained and newer telemetry is never copied into history.
    func homeDeviceStatus(metadata: CareLinkMetadata, checkedAt: Date?) -> NightscoutDeviceStatus? {
        guard isReported, observedAt != nil || lastDataUpdateAt != nil else { return nil }
        var status = NightscoutDeviceStatus()
        let effectiveDate = observedAt ?? lastDataUpdateAt ?? .now
        status.updatedDate = checkedAt ?? .now
        status.lastCheckedDate = checkedAt ?? .now
        status.createdAt = effectiveDate
        status.id = "carelink-\(Int(effectiveDate.timeIntervalSince1970 * 1000))"
        status.timestamp = effectiveDate
        status.device = "carelink://pump"
        status.iob = activeInsulin
        status.rate = currentBasalRate
        status.pumpBatteryPercent = batteryPercent
        status.pumpClock = observedAt
        status.pumpIsSuspended = isSuspended
        status.pumpStatus = pumpStatusTitle
        status.pumpStatusTimestamp = effectiveDate
        status.pumpManufacturer = "Medtronic"
        status.pumpModel = metadata.deviceModel
        status.pumpReservoir = reservoirUnits
        if reportsActiveSmartGuard && isCommunicating != false && isInRange != false {
            status.lastLoopDate = effectiveDate
        }
        return status
    }
}

/// Repairs corroborated duplicate import streams, including rotated patient namespaces.
/// A close pair alone is not evidence of duplicate delivery.
enum CareLinkTimestampRepair {
    struct Plan {
        var patientAliases = [String: String]()
        var removed = Set<Int>()
        var replacements = [Int: CareLinkTherapyRecord]()
    }

    private struct Key: Hashable {
        let patient: String
        let family: String
        let amount: Double
        let notes: String?
        let eventType: String
    }

    private struct Shift: Hashable {
        let patient: String
        let day: Int
        let seconds: Int
    }

    static func plan(stored: [CareLinkTherapyRecord], incoming: [CareLinkTherapyRecord],
                     knownAliases: [String: String] = [:]) -> Plan {
        let aliases = CareLinkPatientIdentity.aliases(stored: stored, incoming: incoming, known: knownAliases)
        let identityPlan = CareLinkPatientIdentity.reconcile(stored: stored, incoming: incoming, aliases: aliases)
        let indices = stored.indices.filter { !identityPlan.removed.contains($0) }
        let normalized = indices.map { identityPlan.replacements[$0] ?? stored[$0] }
        let timestampPlan = planForCanonicalPatients(stored: normalized,
            incoming: incoming.map { CareLinkPatientIdentity.normalized($0, aliases: aliases) })
        var plan = identityPlan
        plan.patientAliases = aliases
        for index in timestampPlan.removed {
            plan.removed.insert(indices[index])
            plan.replacements.removeValue(forKey: indices[index])
        }
        for (index, record) in timestampPlan.replacements { plan.replacements[indices[index]] = record }
        return plan
    }

    private static func planForCanonicalPatients(stored: [CareLinkTherapyRecord], incoming: [CareLinkTherapyRecord]) -> Plan {
        func key(_ record: CareLinkTherapyRecord) -> Key? {
            let parts = record.sourceIdentifier.split(separator: "|", maxSplits: 2).map(String.init)
            guard parts.count == 3, record.value.isFinite, record.value >= 0 else { return nil }
            let family: String
            switch record.type {
            case .Insulin: family = "INSULIN"
            case .Carbs: family = "MEAL"
            case .AutomaticBasal: family = "AUTO_BASAL_DELIVERY"
            default: return nil
            }
            guard parts[1] == family else { return nil }
            var fallback = [String(Int64(record.date.timeIntervalSince1970.rounded())), record.value.description]
            if record.type != .AutomaticBasal { fallback.append(record.durationMinutes.description) }
            guard parts[2] == fallback.joined(separator: ":") else { return nil }
            return Key(patient: parts[0], family: family, amount: record.value,
                       notes: record.notes, eventType: record.nightscoutEventType)
        }

        let grouped = Dictionary(grouping: stored.indices.filter { key(stored[$0]) != nil }, by: { key(stored[$0])! })
        var clusters = [(key: Key, indices: [Int])]()
        for (key, indices) in grouped {
            let sorted = indices.sorted {
                if stored[$0].date == stored[$1].date { return $0 < $1 }
                return stored[$0].date < stored[$1].date
            }
            var chain = [Int]()
            func finishChain() {
                guard let first = chain.first, let last = chain.last else { return }
                // Do not bridge a chain of near neighbours into a larger deletion window.
                if stored[last].date.timeIntervalSince(stored[first].date) <= 5 {
                    clusters.append((key, chain))
                }
                chain.removeAll()
            }
            for index in sorted {
                if let last = chain.last, stored[index].date.timeIntervalSince(stored[last].date) > 5 {
                    finishChain()
                }
                chain.append(index)
            }
            finishChain()
        }

        // Three independent events on the same UTC day must exhibit the same second shift.
        // Requiring a minute of spread prevents a single burst of treatments corroborating itself.
        var evidence = [Shift: [Date]]()
        for cluster in clusters where cluster.indices.count > 1 {
            let latest = stored[cluster.indices.last!].date
            let offsets = Set(cluster.indices.dropLast().map { Int(latest.timeIntervalSince(stored[$0].date).rounded()) })
            for offset in offsets where offset > 0 {
                let shift = Shift(patient: cluster.key.patient,
                                  day: Int(latest.timeIntervalSince1970 / 86400), seconds: offset)
                evidence[shift, default: []].append(latest)
            }
        }
        let confirmed = Set(evidence.compactMap { shift, dates -> Shift? in
            guard Set(dates).count >= 3, let first = dates.min(), let last = dates.max(),
                  last.timeIntervalSince(first) >= 60 else { return nil }
            return shift
        })
        let incomingByKey = Dictionary(grouping: incoming.filter { key($0) != nil }, by: { key($0)! })
        var plan = Plan()
        for cluster in clusters {
            let survivor = cluster.indices.last!
            let latest = stored[survivor].date
            let matches = (incomingByKey[cluster.key] ?? []).filter { record in
                cluster.indices.contains { abs(stored[$0].date.timeIntervalSince(record.date)) <= 5 }
            }
            // A unique fresh event supplies the stable time, including for a single old copy.
            // Multiple nearby fresh events are ambiguous, even if a historical shift is known.
            guard matches.count <= 1 else { continue }
            if let record = matches.first {
                let matchingClusters = clusters.filter { other in
                    other.key == cluster.key && other.indices.contains {
                        abs(stored[$0].date.timeIntervalSince(record.date)) <= 5
                    }
                }
                guard matchingClusters.count == 1 else { continue }
            }
            for index in cluster.indices.dropLast() {
                let offset = Int(latest.timeIntervalSince(stored[index].date).rounded())
                let shift = Shift(patient: cluster.key.patient,
                                  day: Int(latest.timeIntervalSince1970 / 86400), seconds: offset)
                if offset == 0 || confirmed.contains(shift) {
                    plan.removed.insert(index)
                }
            }
            if let record = matches.first,
               cluster.indices.dropLast().allSatisfy({ plan.removed.contains($0) }) {
                plan.replacements[survivor] = record
            }
        }
        repairShiftedSequences(stored: stored, incoming: incoming, plan: &plan)
        return plan
    }

    /// Match duplicated import streams, not arbitrary equal doses an hour apart. Numeric
    /// marker IDs do not establish the correct clock: stored copies with numeric IDs can
    /// themselves be shifted relative to the current display-time history.
    private static func repairShiftedSequences(stored: [CareLinkTherapyRecord], incoming: [CareLinkTherapyRecord], plan: inout Plan) {
        struct Event: Hashable {
            let patient: String
            let family: String
            let value: Double
            let duration: Double
            let notes: String?
            let eventType: String
        }
        struct Offset: Hashable {
            let patient: String
            let seconds: Int
        }
        func key(_ record: CareLinkTherapyRecord) -> Event? {
            let parts = record.sourceIdentifier.split(separator: "|", maxSplits: 2)
            guard parts.count == 3, record.value.isFinite, record.value >= 0 else { return nil }
            let family: String
            switch record.type {
            case .Insulin: family = "INSULIN"
            case .Carbs: family = "MEAL"
            case .AutomaticBasal: family = "AUTO_BASAL_DELIVERY"
            default: return nil
            }
            guard parts[1] == Substring(family) else { return nil }
            // Basal duration is inferred from the NEXT marker and changes on later fetches.
            return Event(patient: String(parts[0]), family: family, value: record.value,
                         duration: record.type == .AutomaticBasal ? 0 : record.durationMinutes,
                         notes: record.notes, eventType: record.nightscoutEventType)
        }
        func fallback(_ record: CareLinkTherapyRecord) -> Bool {
            var suffix = [String(Int64(record.date.timeIntervalSince1970.rounded())), record.value.description]
            if record.type != .AutomaticBasal { suffix.append(record.durationMinutes.description) }
            return record.sourceIdentifier.split(separator: "|", maxSplits: 2).last.map(String.init) == suffix.joined(separator: ":")
        }
        func numeric(_ record: CareLinkTherapyRecord) -> Bool {
            record.sourceIdentifier.split(separator: "|", maxSplits: 2).last.flatMap { Int64($0) } != nil
        }
        let freshByKey = Dictionary(grouping: incoming.filter { key($0) != nil }, by: { key($0)! })
        let storedByKey = Dictionary(grouping: stored.indices.filter { key(stored[$0]) != nil }, by: { key(stored[$0])! })
        // A unique current event also resolves small residual clusters (including numeric IDs)
        // which could not corroborate a shift by themselves. Never merge two current events.
        for (event, indices) in storedByKey {
            let fresh = freshByKey[event] ?? []
            for record in fresh {
                let matches = indices.filter { abs(stored[$0].date.timeIntervalSince(record.date)) <= 5 }
                guard let survivor = matches.min(by: {
                    abs(stored[$0].date.timeIntervalSince(record.date)) < abs(stored[$1].date.timeIntervalSince(record.date))
                }), fresh.filter({ other in matches.contains { abs(stored[$0].date.timeIntervalSince(other.date)) <= 5 } }).count == 1 else { continue }
                for index in matches where index != survivor {
                    plan.removed.insert(index)
                    plan.replacements.removeValue(forKey: index)
                }
                plan.removed.remove(survivor)
                plan.replacements[survivor] = record
            }
        }
        // First collapse short-shift fallback copies. Otherwise one numeric record can appear
        // to match two different fallback events, concealing the larger duplicated stream.
        for numericStream in [false, true] {
            let records = stored.indices.map { plan.replacements[$0] ?? stored[$0] }
            let indices = records.indices.filter { !plan.removed.contains($0) && key(records[$0]) != nil }
            let groups = Dictionary(grouping: indices, by: { key(records[$0])! })
            var evidence = [Offset: Set<Int>]()
            for (event, group) in groups where event.family == "INSULIN" {
                let sources = group.filter { numericStream ? numeric(records[$0]) : fallback(records[$0]) }
                let targets = group.filter { fallback(records[$0]) }
                for source in sources {
                    for target in targets {
                        let seconds = Int(records[source].date.timeIntervalSince(records[target].date).rounded())
                        guard numericStream ? (abs(seconds) > 5 && abs(seconds) <= 3660) : (seconds > 5 && seconds <= 60) else { continue }
                        evidence[Offset(patient: event.patient, seconds: seconds), default: []].insert(source)
                    }
                }
            }
            let offsets = evidence.keys.filter { offset in
                Set(evidence[offset]!.map { records[$0].value }).count >= 3
            }.sorted { $0.patient == $1.patient ? $0.seconds < $1.seconds : $0.patient < $1.patient }
            for offset in offsets {
                var pairs = [(source: Int, target: Int)]()
                for (event, group) in groups where event.patient == offset.patient {
                    let sources = group.filter {
                        !plan.removed.contains($0) && (numericStream
                            ? (numeric(records[$0]) || (event.family == "MEAL" && fallback(records[$0])))
                            : fallback(records[$0]))
                    }
                    let targets = group.filter { !plan.removed.contains($0) && fallback(records[$0]) }
                    let bySecond = Dictionary(grouping: targets, by: { Int(records[$0].date.timeIntervalSince1970.rounded()) })
                    for source in sources {
                        let date = records[source].date.addingTimeInterval(-Double(offset.seconds))
                        let second = Int(date.timeIntervalSince1970.rounded())
                        let matches = (-2...2).flatMap { bySecond[second + $0] ?? [] }.filter {
                            abs(records[$0].date.timeIntervalSince(date)) <= 2
                        }
                        guard matches.count == 1 else { continue }
                        if numericStream {
                            // Competing corroborated offsets must agree on the same event.
                            // Otherwise repeated doses could make the chosen clock arbitrary.
                            let alternatives = group.filter { target in
                                fallback(records[target]) && offsets.contains { other in
                                    other.patient == event.patient && abs(records[source].date.timeIntervalSince(records[target].date) - Double(other.seconds)) <= 2
                                }
                            }
                            guard alternatives.count == 1 else { continue }
                        }
                        pairs.append((source, matches[0]))
                    }
                }
                if numericStream {
                    // Meal markers may omit the numeric ID carried by their bolus. Include
                    // them only when both meal times coincide with a proven bolus pair.
                    let bolusPairs = pairs.filter { records[$0.source].type == .Insulin }
                    pairs.removeAll { pair in
                        records[pair.source].type == .Carbs && !bolusPairs.contains {
                            abs(records[$0.source].date.timeIntervalSince(records[pair.source].date)) <= 5
                                && abs(records[$0.target].date.timeIntervalSince(records[pair.target].date)) <= 5
                        }
                    }
                }
                // One-to-one correspondence is essential when amounts repeat naturally.
                let targetCounts = Dictionary(grouping: pairs, by: { $0.target })
                pairs.removeAll { targetCounts[$0.target]!.count != 1 }
                pairs.sort { records[$0.source].date < records[$1.source].date }
                var run = [(source: Int, target: Int)]()
                func finishRun() {
                    defer { run.removeAll() }
                    let bolus = run.filter { records[$0.source].type == .Insulin }
                    let basal = run.filter { records[$0.source].type == .AutomaticBasal }
                    guard Set(bolus.map { records[$0.source].value }).count >= 3,
                          basal.count >= 12, Set(basal.map { records[$0.source].value }).count >= 3,
                          let first = bolus.first, let last = bolus.last,
                          records[last.source].date.timeIntervalSince(records[first.source].date) >= 900 else { return }
                    for pair in run {
                        guard !plan.removed.contains(pair.source), !plan.removed.contains(pair.target) else { continue }
                        let fresh = (freshByKey[key(records[pair.source])!] ?? []).filter { record in
                            abs(records[pair.source].date.timeIntervalSince(record.date)) <= 5
                                || abs(records[pair.target].date.timeIntervalSince(record.date)) <= 5
                        }
                        guard fresh.count <= 1 else { continue }
                        let keepSource = fresh.first.map { abs(records[pair.source].date.timeIntervalSince($0.date)) <= 5 } ?? false
                        let survivor = keepSource ? pair.source : pair.target
                        let duplicate = keepSource ? pair.target : pair.source
                        plan.removed.insert(duplicate)
                        plan.replacements.removeValue(forKey: duplicate)
                        if let fresh = fresh.first { plan.replacements[survivor] = fresh }
                    }
                }
                for pair in pairs {
                    // Numeric-ID history is sparse: an overlapping 48-hour response can
                    // contain only a few IDs between much denser fallback imports. Do not
                    // demand a bolus on every basal-only stretch of that same shifted stream.
                    if let first = run.first, let last = run.last,
                       records[pair.source].date.timeIntervalSince(records[last.source].date) > (numericStream ? 172800 : 7200)
                        || (!numericStream && records[pair.source].date.timeIntervalSince(records[first.source].date) > 86400) { finishRun() }
                    run.append(pair)
                }
                finishRun()
            }
        }
    }
}

/// CareLink's patient ID is a response namespace, not an immutable treatment identity.
/// Link namespaces only with a varied, time-aligned sequence, then persist that relationship.
enum CareLinkPatientIdentity {
    static func patient(_ identifier: String) -> String? {
        let parts = identifier.split(separator: "|", maxSplits: 2)
        return parts.count == 3 ? String(parts[0]) : nil
    }

    private static func root(_ patient: String, aliases: [String: String]) -> String {
        var result = patient
        var visited = Set<String>()
        while let next = aliases[result], next != result, visited.insert(result).inserted { result = next }
        return result
    }

    static func normalized(_ record: CareLinkTherapyRecord, aliases: [String: String]) -> CareLinkTherapyRecord {
        guard let patient = patient(record.sourceIdentifier) else { return record }
        let canonical = root(patient, aliases: aliases)
        guard patient != canonical else { return record }
        return CareLinkTherapyRecord(sourceIdentifier: canonical + record.sourceIdentifier.dropFirst(patient.count),
            date: record.date, type: record.type, value: record.value, durationMinutes: record.durationMinutes,
            nightscoutEventType: record.nightscoutEventType, notes: record.notes)
    }

    private static func sameEvent(_ a: CareLinkTherapyRecord, _ b: CareLinkTherapyRecord) -> Bool {
        a.type == b.type && a.value == b.value && a.notes == b.notes
            && a.nightscoutEventType == b.nightscoutEventType
            && (a.type == .AutomaticBasal || a.durationMinutes == b.durationMinutes)
            && abs(a.date.timeIntervalSince(b.date)) <= 5
    }

    static func aliases(stored: [CareLinkTherapyRecord], incoming: [CareLinkTherapyRecord],
                        known: [String: String]) -> [String: String] {
        var aliases = known
        let records = stored + incoming
        let groups = Dictionary(grouping: records.filter { patient($0.sourceIdentifier) != nil },
                                by: { patient($0.sourceIdentifier)! })
        // Prefer established stored history over the latest response's namespace.
        let firstStored = Dictionary(grouping: stored.filter { patient($0.sourceIdentifier) != nil },
                                     by: { patient($0.sourceIdentifier)! }).mapValues { $0.map(\.date).min()! }
        let patients = groups.keys.sorted {
            let a = firstStored[$0] ?? .distantFuture, b = firstStored[$1] ?? .distantFuture
            return a == b ? $0 < $1 : a < b
        }
        for (position, older) in patients.enumerated() {
            for newer in patients.dropFirst(position + 1) {
                guard root(older, aliases: aliases) != root(newer, aliases: aliases) else { continue }
                // Count distinct delivery times, never repeated copies of one marker.
                let matches = groups[older]!.filter { a in groups[newer]!.contains { sameEvent(a, $0) } }
                func corroborated(_ type: TreatmentType, count: Int, span: TimeInterval) -> Bool {
                    let events = matches.filter { $0.type == type }
                    let times = events.map(\.date).sorted()
                    var distinct = [Date]()
                    for time in times where distinct.last.map({ time.timeIntervalSince($0) > 10 }) ?? true {
                        distinct.append(time)
                    }
                    guard distinct.count >= count, Set(events.map(\.value)).count >= 3,
                          let first = distinct.first, let last = distinct.last else { return false }
                    return last.timeIntervalSince(first) >= span
                }
                if corroborated(.Insulin, count: 3, span: 900)
                    || corroborated(.AutomaticBasal, count: 12, span: 3600) {
                    aliases[root(newer, aliases: aliases)] = root(older, aliases: aliases)
                }
            }
        }
        for key in Array(aliases.keys) { aliases[key] = root(key, aliases: aliases) }
        return aliases
    }

    /// Reconcile only proven cross-namespace copies. Same-namespace event IDs remain distinct.
    static func reconcile(stored: [CareLinkTherapyRecord], incoming: [CareLinkTherapyRecord],
                          aliases: [String: String]) -> CareLinkTimestampRepair.Plan {
        var plan = CareLinkTimestampRepair.Plan()
        guard !aliases.isEmpty else { return plan }
        let canonical = stored.map { normalized($0, aliases: aliases) }
        for index in stored.indices {
            if canonical[index].sourceIdentifier != stored[index].sourceIdentifier {
                plan.replacements[index] = canonical[index]
            }
        }
        guard !plan.replacements.isEmpty || incoming.contains(where: {
            normalized($0, aliases: aliases).sourceIdentifier != $0.sourceIdentifier
        }) else { return plan }
        for index in stored.indices where !plan.removed.contains(index) {
            guard let namespace = patient(stored[index].sourceIdentifier) else { continue }
            let duplicates = stored.indices.filter { other in
                other > index && !plan.removed.contains(other)
                    && patient(stored[other].sourceIdentifier) != namespace
                    && patient(canonical[other].sourceIdentifier) == patient(canonical[index].sourceIdentifier)
                    && sameEvent(stored[index], stored[other])
            }
            // Multiple distinct events in either namespace are ambiguous: leave them intact.
            for other in duplicates {
                let peers = stored.indices.filter {
                    patient(stored[$0].sourceIdentifier) == namespace && sameEvent(stored[$0], stored[other])
                }
                let otherPeers = duplicates.filter {
                    patient(stored[$0].sourceIdentifier) == patient(stored[other].sourceIdentifier)
                }
                guard peers.count == 1, otherPeers.count == 1 else { continue }
                plan.removed.insert(other)
                plan.replacements.removeValue(forKey: other)
            }
            let matches = incoming.filter {
                patient($0.sourceIdentifier) != namespace
                    && patient(normalized($0, aliases: aliases).sourceIdentifier) == patient(canonical[index].sourceIdentifier)
                    && sameEvent(stored[index], $0)
            }
            if matches.count == 1 {
                // Adopt the current marker identity so ordinary import updates the retained row.
                let peers = stored.indices.filter {
                    !plan.removed.contains($0) && sameEvent(stored[$0], matches[0])
                        && patient(canonical[$0].sourceIdentifier) == patient(canonical[index].sourceIdentifier)
                }
                if peers.count == 1 { plan.replacements[index] = normalized(matches[0], aliases: aliases) }
            }
        }
        return plan
    }
}
