//
//  NightscoutDeviceStatusAccessor.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

/// A managed-object-free copy of a stored Nightscout status.
///
/// Accessors return snapshots so chart rendering and report calculation can safely move the
/// values between the Core Data queues, background operation queues and SwiftUI's main thread.
struct NightscoutDeviceStatusSnapshot: Sendable {
    let id: String
    let createdAt: Date
    let updatedDate: Date
    let lastCheckedDate: Date
    let lastLoopDate: Date
    let timestamp: Date?
    let device: String?
    let appVersion: String?
    let activeProfile: String?
    let iob: Double?
    let cob: Double?
    let eventualBG: Double?
    let currentTarget: Double?
    let isf: Double?
    let insulinReq: Double?
    let bolusVolume: Double?
    let rate: Double?
    let duration: Int?
    let reason: String?
    let sensitivityRatio: Double?
    let tdd: Double?
    let error: String?
    let overrideActive: Bool?
    let overrideName: String?
    let overrideMinValue: Double?
    let overrideMaxValue: Double?
    let overrideMultiplier: Double?
    let pumpBatteryPercent: Int?
    let pumpReservoir: Double?
    let pumpIsBolusing: Bool?
    let pumpIsSuspended: Bool?
    let pumpStatus: String?
    let pumpStatusTimestamp: Date?
    let pumpManufacturer: String?
    let pumpModel: String?
    let uploaderBatteryPercent: Int?
    let uploaderIsCharging: Bool?
}

/// Owns persistence and date-range retrieval for normalized Nightscout device-status records.
final class NightscoutDeviceStatusAccessor {
    private let coreDataManager: CoreDataManager
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNightscoutSyncManager)

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    /// Updates the matching Nightscout record, or creates it when it has not been stored before.
    ///
    /// Nightscout identifiers are preferred for identity. Some compatible servers omit them, so
    /// `createdAt` provides a deterministic fallback and keeps repeated imports idempotent.
    func upsert(_ status: NightscoutDeviceStatus) {
        guard status.createdAt > .distantPast || status.lastLoopDate > .distantPast else { return }

        let context = coreDataManager.mainManagedObjectContext
        context.performAndWait {
            let entry = self.existingEntry(for: status, on: context) ?? NightscoutDeviceStatusEntry(context: context)
            self.apply(status, to: entry)
        }
        coreDataManager.saveChanges()
    }

    /// Returns the newest detached status without exposing its managed object or context.
    func latest() -> NightscoutDeviceStatusSnapshot? {
        let context = coreDataManager.privateManagedObjectContext
        var snapshot: NightscoutDeviceStatusSnapshot?
        context.performAndWait {
            let request: NSFetchRequest<NightscoutDeviceStatusEntry> = NightscoutDeviceStatusEntry.fetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [
                NSSortDescriptor(key: #keyPath(NightscoutDeviceStatusEntry.createdAt), ascending: false),
                NSSortDescriptor(key: #keyPath(NightscoutDeviceStatusEntry.lastLoopDate), ascending: false)
            ]
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true
            snapshot = try? context.fetch(request).first.map(Self.snapshot(from:))
        }
        return snapshot
    }

    /// Fetches detached snapshots in chronological order for caches and report calculations.
    func fetch(fromDate: Date?, toDate: Date?) -> [NightscoutDeviceStatusSnapshot] {
        let context = coreDataManager.privateManagedObjectContext
        var snapshots: [NightscoutDeviceStatusSnapshot] = []
        context.performAndWait {
            let request: NSFetchRequest<NightscoutDeviceStatusEntry> = NightscoutDeviceStatusEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NightscoutDeviceStatusEntry.createdAt), ascending: true)]
            request.returnsObjectsAsFaults = false
            request.includesPropertyValues = true

            var predicates = [NSPredicate]()
            if let fromDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", fromDate as NSDate))
            }
            if let toDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", toDate as NSDate))
            }
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            do {
                snapshots = try context.fetch(request).map(Self.snapshot(from:))
            } catch {
                trace("in NightscoutDeviceStatusAccessor.fetch, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
        return snapshots
    }

    /// Removes status history outside the configured retention period.
    @discardableResult
    func deleteOlderThan(_ date: Date) -> Int {
        let context = coreDataManager.privateManagedObjectContext
        var deletedCount = 0
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "NightscoutDeviceStatusEntry")
            request.predicate = NSPredicate(format: "createdAt < %@", date as NSDate)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            do {
                guard let result = try context.execute(deleteRequest) as? NSBatchDeleteResult,
                      let objectIDs = result.result as? [NSManagedObjectID]
                else { return }
                deletedCount = objectIDs.count
                if !objectIDs.isEmpty {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                        into: [context, self.coreDataManager.mainManagedObjectContext]
                    )
                }
            } catch {
                trace("in NightscoutDeviceStatusAccessor.deleteOlderThan, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSyncManager, type: .error, error.localizedDescription)
            }
        }
        return deletedCount
    }

    private func existingEntry(for status: NightscoutDeviceStatus, on context: NSManagedObjectContext) -> NightscoutDeviceStatusEntry? {
        let request: NSFetchRequest<NightscoutDeviceStatusEntry> = NightscoutDeviceStatusEntry.fetchRequest()
        request.fetchLimit = 1
        if !status.id.isEmpty {
            request.predicate = NSPredicate(format: "id == %@", status.id)
        } else {
            request.predicate = NSPredicate(format: "createdAt == %@", status.createdAt as NSDate)
        }
        return try? context.fetch(request).first
    }

    private func apply(_ status: NightscoutDeviceStatus, to entry: NightscoutDeviceStatusEntry) {
        entry.id = status.id.isEmpty ? "createdAt-\(Int(status.createdAt.timeIntervalSince1970 * 1000))" : status.id
        entry.createdAt = status.createdAt
        entry.updatedDate = status.updatedDate
        entry.lastCheckedDate = status.lastCheckedDate
        entry.lastLoopDate = status.lastLoopDate
        entry.timestamp = status.timestamp
        entry.device = status.device
        entry.appVersion = status.appVersion
        entry.activeProfile = status.activeProfile
        entry.iob = status.iob.nsNumber
        entry.cob = status.cob.nsNumber
        entry.eventualBG = status.eventualBG.nsNumber
        entry.currentTarget = status.currentTarget.nsNumber
        entry.isf = status.isf.nsNumber
        entry.insulinReq = status.insulinReq.nsNumber
        entry.bolusVolume = status.bolusVolume.nsNumber
        entry.rate = status.rate.nsNumber
        entry.duration = status.duration.nsNumber
        entry.reason = status.reason
        entry.sensitivityRatio = status.sensitivityRatio.nsNumber
        entry.tdd = status.tdd.nsNumber
        entry.error = status.error
        entry.overrideActive = status.overrideActive.nsNumber
        entry.overrideName = status.overrideName
        entry.overrideMinValue = status.overrideMinValue.nsNumber
        entry.overrideMaxValue = status.overrideMaxValue.nsNumber
        entry.overrideMultiplier = status.overrideMultiplier.nsNumber
        entry.pumpBatteryPercent = status.pumpBatteryPercent.nsNumber
        entry.pumpReservoir = status.pumpReservoir.nsNumber
        entry.pumpIsBolusing = status.pumpIsBolusing.nsNumber
        entry.pumpIsSuspended = status.pumpIsSuspended.nsNumber
        entry.pumpStatus = status.pumpStatus
        entry.pumpStatusTimestamp = status.pumpStatusTimestamp
        entry.pumpManufacturer = status.pumpManufacturer
        entry.pumpModel = status.pumpModel
        entry.uploaderBatteryPercent = status.uploaderBatteryPercent.nsNumber
        entry.uploaderIsCharging = status.uploaderIsCharging.nsNumber
    }

    private static func snapshot(from entry: NightscoutDeviceStatusEntry) -> NightscoutDeviceStatusSnapshot {
        NightscoutDeviceStatusSnapshot(
            id: entry.id,
            createdAt: entry.createdAt,
            updatedDate: entry.updatedDate,
            lastCheckedDate: entry.lastCheckedDate,
            lastLoopDate: entry.lastLoopDate,
            timestamp: entry.timestamp,
            device: entry.device,
            appVersion: entry.appVersion,
            activeProfile: entry.activeProfile,
            iob: entry.iob?.doubleValue,
            cob: entry.cob?.doubleValue,
            eventualBG: entry.eventualBG?.doubleValue,
            currentTarget: entry.currentTarget?.doubleValue,
            isf: entry.isf?.doubleValue,
            insulinReq: entry.insulinReq?.doubleValue,
            bolusVolume: entry.bolusVolume?.doubleValue,
            rate: entry.rate?.doubleValue,
            duration: entry.duration?.intValue,
            reason: entry.reason,
            sensitivityRatio: entry.sensitivityRatio?.doubleValue,
            tdd: entry.tdd?.doubleValue,
            error: entry.error,
            overrideActive: entry.overrideActive?.boolValue,
            overrideName: entry.overrideName,
            overrideMinValue: entry.overrideMinValue?.doubleValue,
            overrideMaxValue: entry.overrideMaxValue?.doubleValue,
            overrideMultiplier: entry.overrideMultiplier?.doubleValue,
            pumpBatteryPercent: entry.pumpBatteryPercent?.intValue,
            pumpReservoir: entry.pumpReservoir?.doubleValue,
            pumpIsBolusing: entry.pumpIsBolusing?.boolValue,
            pumpIsSuspended: entry.pumpIsSuspended?.boolValue,
            pumpStatus: entry.pumpStatus,
            pumpStatusTimestamp: entry.pumpStatusTimestamp,
            pumpManufacturer: entry.pumpManufacturer,
            pumpModel: entry.pumpModel,
            uploaderBatteryPercent: entry.uploaderBatteryPercent?.intValue,
            uploaderIsCharging: entry.uploaderIsCharging?.boolValue
        )
    }
}

extension NightscoutDeviceStatusSnapshot {
    func deviceStatus() -> NightscoutDeviceStatus {
        var status = NightscoutDeviceStatus()
        status.id = id
        status.createdAt = createdAt
        status.updatedDate = updatedDate
        status.lastCheckedDate = lastCheckedDate
        status.lastLoopDate = lastLoopDate
        status.timestamp = timestamp
        status.device = device
        status.appVersion = appVersion
        status.activeProfile = activeProfile
        status.iob = iob
        status.cob = cob
        status.eventualBG = eventualBG
        status.currentTarget = currentTarget
        status.isf = isf
        status.insulinReq = insulinReq
        status.bolusVolume = bolusVolume
        status.rate = rate
        status.duration = duration
        status.reason = reason
        status.sensitivityRatio = sensitivityRatio
        status.tdd = tdd
        status.error = error
        status.overrideActive = overrideActive
        status.overrideName = overrideName
        status.overrideMinValue = overrideMinValue
        status.overrideMaxValue = overrideMaxValue
        status.overrideMultiplier = overrideMultiplier
        status.pumpBatteryPercent = pumpBatteryPercent
        status.pumpReservoir = pumpReservoir
        status.pumpIsBolusing = pumpIsBolusing
        status.pumpIsSuspended = pumpIsSuspended
        status.pumpStatus = pumpStatus
        status.pumpStatusTimestamp = pumpStatusTimestamp
        status.pumpManufacturer = pumpManufacturer
        status.pumpModel = pumpModel
        status.uploaderBatteryPercent = uploaderBatteryPercent
        status.uploaderIsCharging = uploaderIsCharging
        return status
    }
}

private extension Optional where Wrapped == Double {
    var nsNumber: NSNumber? {
        map { NSNumber(value: $0) }
    }
}

private extension Optional where Wrapped == Int {
    var nsNumber: NSNumber? {
        map { NSNumber(value: $0) }
    }
}

private extension Optional where Wrapped == Bool {
    var nsNumber: NSNumber? {
        map { NSNumber(value: $0) }
    }
}
