//
//  CareLinkTherapyImporter.swift
//  xdripswift
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

/// Persists normalized CareLink treatments in the app's existing treatment store.
///
/// Imported records deliberately retain an empty Nightscout identifier and `uploaded == false`.
/// This allows the normal Nightscout manager to export them without creating a second upload path.
final class CareLinkTherapyImporter {
    private let coreDataManager: CoreDataManager
    private let deviceStatusAccessor: NightscoutDeviceStatusAccessor
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
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
        let context = coreDataManager.privateChildManagedObjectContext()
        let earliest = records.map(\.date).min() ?? .now
        let latest = records.map(\.date).max() ?? .now
        let requestedSourceIdentifiers = records.map(\.sourceIdentifier)

        do {
            let added = try await context.perform {
                let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "careLinkSourceIdentifier IN %@", requestedSourceIdentifiers),
                    NSPredicate(
                        format: "date >= %@ AND date <= %@ AND enteredBy == %@",
                        earliest.addingTimeInterval(-1) as NSDate,
                        latest.addingTimeInterval(1) as NSDate,
                        Self.enteredBy
                    )
                ])
                request.includesPropertyValues = true
                let existing = try context.fetch(request)
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
                var basalEntriesByEvent = Dictionary(
                    grouping: existing.filter { $0.treatmentType == .Basal },
                    by: Self.basalEventKey
                )
                var added = 0
                for record in records {
                    if let existingEntry = entriesBySourceIdentifier[record.sourceIdentifier] {
                        Self.apply(record, to: existingEntry)
                        if record.type == .Basal {
                            let eventKey = Self.basalEventKey(record)
                            basalEntriesByEvent[eventKey]?
                                .filter { $0 != existingEntry }
                                .forEach(context.delete)
                            basalEntriesByEvent[eventKey] = [existingEntry]
                        }
                        continue
                    }
                    if record.type == .Basal,
                       var matchingEntries = basalEntriesByEvent[Self.basalEventKey(record)],
                       let existingEntry = matchingEntries.popLast() {
                        Self.apply(record, to: existingEntry)
                        existingEntry.careLinkSourceIdentifier = record.sourceIdentifier
                        matchingEntries.forEach(context.delete)
                        basalEntriesByEvent[Self.basalEventKey(record)] = [existingEntry]
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
                if context.hasChanges { try context.save() }
                return added
            }
            guard added > 0 else { return added }
            await MainActor.run {
                coreDataManager.saveChanges()
                if UserDefaults.standard.dataFlowPolicy.exportsTreatmentsToNightscout {
                    UserDefaults.standard.nightscoutSyncRequired = true
                }
            }
            trace("CareLink imported %{public}d therapy records", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, added)
            return added
        } catch {
            trace("CareLink therapy import failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, error.localizedDescription)
            return 0
        }
    }

    /// A readable source label is kept separate from the Nightscout identifier.
    private static let enteredBy = "CareLink"

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
        basalEventKey(date: record.date, type: record.type)
    }

    private static func basalEventKey(_ treatment: TreatmentEntry) -> String {
        basalEventKey(date: treatment.date, type: treatment.treatmentType)
    }

    private static func basalEventKey(date: Date, type: TreatmentType) -> String {
        "\(Int64(date.timeIntervalSince1970.rounded()))|\(type.rawValue)"
    }

    private static func apply(_ record: CareLinkTherapyRecord, to treatment: TreatmentEntry) {
        treatment.date = record.date
        treatment.value = record.value
        treatment.valueSecondary = record.durationMinutes
        treatment.treatmentType = record.type
        treatment.nightscoutEventType = record.nightscoutEventType
        treatment.enteredBy = enteredBy
        treatment.notes = record.notes
        treatment.treatmentdeleted = false
    }
}

extension CareLinkTherapyRecord {
    /// Builds a sparse historical pump status only from an automatic-basal marker.
    /// `lastLoopDate` carries proven SmartGuard activity into the existing status model. It does
    /// not represent a synthetic loop cycle or a Nightscout result.
    func historicalPumpDeviceStatus(metadata: CareLinkMetadata, checkedAt: Date) -> NightscoutDeviceStatus? {
        guard type == .Basal,
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
        status.rate = value
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
        guard observedAt != nil || lastDataUpdateAt != nil else { return nil }
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
