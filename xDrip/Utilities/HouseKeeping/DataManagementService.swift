//
//  DataManagementService.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

// MARK: - Clean Data Models

/// The amount and date range of one historical Core Data entity.
struct CleanDataCategoryInventory: Sendable {
    let count: Int
    let firstDate: Date?
    let lastDate: Date?
}

/// A read-only summary of the historical data held in Core Data.
struct CleanDataInventory: Sendable {
    let bgReadings: CleanDataCategoryInventory
    let treatments: CleanDataCategoryInventory
    let calibrations: CleanDataCategoryInventory
    let devices: Int
    let sensors: Int
    let storeSizeInBytes: Int64
}

enum CleanDataRangeMode: String, CaseIterable, Identifiable, Sendable {
    case keepRecent
    case custom
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .keepRecent: Texts_SettingsView.cleanDataKeepRecent
        case .custom: Texts_SettingsView.cleanDataDateRange
        case .all: Texts_SettingsView.cleanDataDeleteAll
        }
    }
}

/// The data categories explicitly selected by the user.
struct CleanDataSelection: Sendable {
    let includesBgReadings: Bool
    let includesTreatments: Bool

    var hasSelection: Bool {
        includesBgReadings || includesTreatments
    }
}

/// An immutable, counted deletion plan shown to the user before confirmation.
struct CleanDataDeletionPlan: Sendable {
    let selection: CleanDataSelection
    let rangeMode: CleanDataRangeMode
    let fromDate: Date?
    let throughDate: Date
    let bgReadingCount: Int
    let treatmentCount: Int
    let calibrationCount: Int
    let createdAt: Date

    var totalSelectedRecordCount: Int {
        bgReadingCount + treatmentCount + calibrationCount
    }
}

/// The actual records removed after the confirmed deletion has completed.
struct CleanDataDeletionResult: Sendable {
    let bgReadingCount: Int
    let treatmentCount: Int
    let calibrationCount: Int
    let completedAt: Date
    let storeSizeBeforeInBytes: Int64
    let storeSizeAfterInBytes: Int64
    let oldestRemainingBgReadingDate: Date?
    let oldestRemainingTreatmentDate: Date?
}

enum CleanDataError: LocalizedError {
    case invalidDateRange
    case noDataSelected
    case noMatchingData
    case storedDataChanged
    case unableToDeleteData

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            Texts_SettingsView.cleanDataInvalidDateRangeError
        case .noDataSelected:
            Texts_SettingsView.cleanDataNoSelectionError
        case .noMatchingData:
            Texts_SettingsView.cleanDataNoMatchingDataError
        case .storedDataChanged:
            Texts_SettingsView.cleanDataChangedError
        case .unableToDeleteData:
            Texts_SettingsView.cleanDataDeleteFailedError
        }
    }
}

// MARK: - Clean Data Service

/// Counts and permanently removes selected historical data without changing settings or active device state.
final class DataManagementService: @unchecked Sendable {
    private let coreDataManager: CoreDataManager
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    // MARK: - Inventory and Preview

    /// Returns the current on-disk Core Data size for compact read-only summaries.
    func currentStoreSizeInBytes() -> Int64 {
        let context = coreDataManager.privateManagedObjectContext
        var storeSizeInBytes = Int64(0)
        context.performAndWait {
            storeSizeInBytes = self.storeSizeInBytes(on: context)
        }
        return storeSizeInBytes
    }

    func inventory() async throws -> CleanDataInventory {
        let startedAt = Date()
        try savePendingChanges()
        let context = coreDataManager.privateManagedObjectContext
        let inventory = try await context.perform {
            let bgReadings = try self.bgReadingInventory(on: context)
            let treatments = try self.treatmentInventory(on: context)
            let calibrations = try self.calibrationInventory(on: context)
            return CleanDataInventory(
                bgReadings: bgReadings,
                treatments: treatments,
                calibrations: calibrations,
                devices: try context.count(for: BLEPeripheral.fetchRequest()),
                sensors: try context.count(for: Sensor.fetchRequest()),
                storeSizeInBytes: self.storeSizeInBytes(on: context)
            )
        }
        trace(
            "in cleanDataInventory, completed. duration = %{public}@ ms, store bytes = %{public}@, BG readings = %{public}@, treatments = %{public}@, calibrations = %{public}@, devices = %{public}@, sensors = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            elapsedMilliseconds(since: startedAt),
            inventory.storeSizeInBytes.description,
            inventory.bgReadings.count.description,
            inventory.treatments.count.description,
            inventory.calibrations.count.description,
            inventory.devices.description,
            inventory.sensors.description
        )
        return inventory
    }

    func deletionPlan(
        selection: CleanDataSelection,
        rangeMode: CleanDataRangeMode,
        fromDate: Date?,
        throughDate: Date
    ) async throws -> CleanDataDeletionPlan {
        guard selection.hasSelection else { throw CleanDataError.noDataSelected }
        if let fromDate, fromDate > throughDate { throw CleanDataError.invalidDateRange }

        try savePendingChanges()
        let context = coreDataManager.privateManagedObjectContext
        let counts = try await context.perform {
            let bgReadingCount = selection.includesBgReadings
                ? try context.count(for: self.bgReadingFetchRequest(fromDate: fromDate, throughDate: throughDate))
                : 0
            let treatmentCount = selection.includesTreatments
                ? try context.count(for: self.treatmentFetchRequest(
                    fromDate: fromDate,
                    throughDate: throughDate,
                    includesUndatedTreatments: rangeMode == .all
                ))
                : 0
            let calibrationCount = selection.includesBgReadings
                ? try context.count(for: self.calibrationFetchRequest(
                    fromDate: fromDate,
                    throughDate: throughDate,
                    afterDeletingSelectedBgReadings: true
                ))
                : 0
            return (bgReadingCount, treatmentCount, calibrationCount)
        }
        guard counts.0 + counts.1 + counts.2 > 0 else { throw CleanDataError.noMatchingData }

        let plan = CleanDataDeletionPlan(
            selection: selection,
            rangeMode: rangeMode,
            fromDate: fromDate,
            throughDate: throughDate,
            bgReadingCount: counts.0,
            treatmentCount: counts.1,
            calibrationCount: counts.2,
            createdAt: Date()
        )
        trace(
            "in cleanDataDeletionPlan, preview created. mode = %{public}@, from = %{public}@, through = %{public}@, BG readings = %{public}@, treatments = %{public}@, unused calibrations = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            rangeMode.rawValue,
            fromDate?.description(with: .current) ?? "earliest stored data",
            throughDate.description(with: .current),
            plan.bgReadingCount.description,
            plan.treatmentCount.description,
            plan.calibrationCount.description
        )
        return plan
    }

    // MARK: - Confirmed Deletion

    func delete(plan: CleanDataDeletionPlan) async throws -> CleanDataDeletionResult {
        let startedAt = Date()
        try savePendingChanges()

        let context = coreDataManager.privateManagedObjectContext
        let execution = try await context.perform {
            let storeSizeBeforeInBytes = self.storeSizeInBytes(on: context)
            var deletedObjectIDURLs = [URL]()

            let currentBgReadingCount = plan.selection.includesBgReadings
                ? try context.count(for: self.bgReadingFetchRequest(fromDate: plan.fromDate, throughDate: plan.throughDate))
                : 0
            let currentTreatmentCount = plan.selection.includesTreatments
                ? try context.count(for: self.treatmentFetchRequest(
                    fromDate: plan.fromDate,
                    throughDate: plan.throughDate,
                    includesUndatedTreatments: plan.rangeMode == .all
                ))
                : 0
            let currentCalibrationCount = plan.selection.includesBgReadings
                ? try context.count(for: self.calibrationFetchRequest(
                    fromDate: plan.fromDate,
                    throughDate: plan.throughDate,
                    afterDeletingSelectedBgReadings: true
                ))
                : 0
            guard currentBgReadingCount == plan.bgReadingCount,
                  currentTreatmentCount == plan.treatmentCount,
                  currentCalibrationCount == plan.calibrationCount
            else {
                throw CleanDataError.storedDataChanged
            }

            let bgReadingCount: Int
            if plan.selection.includesBgReadings {
                let result = try self.executeBatchDelete(
                    fetchRequest: self.bgReadingFetchRequest(fromDate: plan.fromDate, throughDate: plan.throughDate),
                    on: context
                )
                bgReadingCount = result.count
                deletedObjectIDURLs.append(contentsOf: result.objectIDURLs)
            } else {
                bgReadingCount = 0
            }

            let treatmentCount: Int
            if plan.selection.includesTreatments {
                let result = try self.executeBatchDelete(
                    fetchRequest: self.treatmentFetchRequest(
                        fromDate: plan.fromDate,
                        throughDate: plan.throughDate,
                        includesUndatedTreatments: plan.rangeMode == .all
                    ),
                    on: context
                )
                treatmentCount = result.count
                deletedObjectIDURLs.append(contentsOf: result.objectIDURLs)
            } else {
                treatmentCount = 0
            }

            let calibrationCount: Int
            if plan.selection.includesBgReadings {
                let result = try self.executeBatchDelete(
                    fetchRequest: self.calibrationFetchRequest(
                        fromDate: plan.fromDate,
                        throughDate: plan.throughDate,
                        afterDeletingSelectedBgReadings: false
                    ),
                    on: context
                )
                calibrationCount = result.count
                deletedObjectIDURLs.append(contentsOf: result.objectIDURLs)
            } else {
                calibrationCount = 0
            }

            let remainingBgReadings = try self.bgReadingInventory(on: context)
            let remainingTreatments = try self.treatmentInventory(on: context)
            return (
                bgReadingCount,
                treatmentCount,
                calibrationCount,
                deletedObjectIDURLs,
                storeSizeBeforeInBytes,
                self.storeSizeInBytes(on: context),
                remainingBgReadings.firstDate,
                remainingTreatments.firstDate
            )
        }

        mergeDeletedObjects(with: execution.3)
        let result = CleanDataDeletionResult(
            bgReadingCount: execution.0,
            treatmentCount: execution.1,
            calibrationCount: execution.2,
            completedAt: Date(),
            storeSizeBeforeInBytes: execution.4,
            storeSizeAfterInBytes: execution.5,
            oldestRemainingBgReadingDate: execution.6,
            oldestRemainingTreatmentDate: execution.7
        )
        trace(
            "in cleanDataDelete, completed. duration = %{public}@ ms, BG readings = %{public}@, treatments = %{public}@, unused calibrations = %{public}@, store bytes before = %{public}@, store bytes after = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            elapsedMilliseconds(since: startedAt),
            result.bgReadingCount.description,
            result.treatmentCount.description,
            result.calibrationCount.description,
            result.storeSizeBeforeInBytes.description,
            result.storeSizeAfterInBytes.description
        )
        return result
    }

    // MARK: - Fetch Requests

    private func bgReadingFetchRequest(fromDate: Date?, throughDate: Date) -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BgReading")
        request.predicate = datePredicate(key: #keyPath(BgReading.timeStamp), fromDate: fromDate, throughDate: throughDate)
        return request
    }

    private func treatmentFetchRequest(
        fromDate: Date?,
        throughDate: Date,
        includesUndatedTreatments: Bool
    ) -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TreatmentEntry")
        let datedPredicate = datePredicate(key: #keyPath(TreatmentEntry.date), fromDate: fromDate, throughDate: throughDate)
        request.predicate = includesUndatedTreatments
            ? NSCompoundPredicate(orPredicateWithSubpredicates: [NSPredicate(format: "date == nil"), datedPredicate])
            : datedPredicate
        return request
    }

    private func calibrationFetchRequest(
        fromDate: Date?,
        throughDate: Date,
        afterDeletingSelectedBgReadings: Bool
    ) -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Calibration")
        var predicates = [datePredicate(key: #keyPath(Calibration.timeStamp), fromDate: fromDate, throughDate: throughDate)]
        if afterDeletingSelectedBgReadings {
            if let fromDate {
                predicates.append(NSPredicate(
                    format: "SUBQUERY(bgreadings, $reading, $reading.timeStamp < %@ OR $reading.timeStamp > %@).@count == 0",
                    fromDate as NSDate,
                    throughDate as NSDate
                ))
            } else {
                predicates.append(NSPredicate(
                    format: "SUBQUERY(bgreadings, $reading, $reading.timeStamp > %@).@count == 0",
                    throughDate as NSDate
                ))
            }
        } else {
            predicates.append(NSPredicate(format: "bgreadings.@count == 0"))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return request
    }

    private func datePredicate(key: String, fromDate: Date?, throughDate: Date) -> NSPredicate {
        if let fromDate {
            return NSPredicate(
                format: "%K >= %@ AND %K <= %@",
                key,
                fromDate as NSDate,
                key,
                throughDate as NSDate
            )
        }
        return NSPredicate(format: "%K <= %@", key, throughDate as NSDate)
    }

    // MARK: - Inventory Helpers

    private func bgReadingInventory(on context: NSManagedObjectContext) throws -> CleanDataCategoryInventory {
        let count = try context.count(for: BgReading.fetchRequest())
        return try CleanDataCategoryInventory(
            count: count,
            firstDate: firstBgReading(on: context, ascending: true)?.timeStamp,
            lastDate: firstBgReading(on: context, ascending: false)?.timeStamp
        )
    }

    private func treatmentInventory(on context: NSManagedObjectContext) throws -> CleanDataCategoryInventory {
        let count = try context.count(for: TreatmentEntry.fetchRequest())
        return try CleanDataCategoryInventory(
            count: count,
            firstDate: firstTreatment(on: context, ascending: true)?.date,
            lastDate: firstTreatment(on: context, ascending: false)?.date
        )
    }

    private func calibrationInventory(on context: NSManagedObjectContext) throws -> CleanDataCategoryInventory {
        let count = try context.count(for: Calibration.fetchRequest())
        return try CleanDataCategoryInventory(
            count: count,
            firstDate: firstCalibration(on: context, ascending: true)?.timeStamp,
            lastDate: firstCalibration(on: context, ascending: false)?.timeStamp
        )
    }

    private func firstBgReading(on context: NSManagedObjectContext, ascending: Bool) throws -> BgReading? {
        let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: ascending)]
        return try context.fetch(request).first
    }

    private func firstTreatment(on context: NSManagedObjectContext, ascending: Bool) throws -> TreatmentEntry? {
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "date != nil")
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: ascending)]
        return try context.fetch(request).first
    }

    private func firstCalibration(on context: NSManagedObjectContext, ascending: Bool) throws -> Calibration? {
        let request: NSFetchRequest<Calibration> = Calibration.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Calibration.timeStamp), ascending: ascending)]
        return try context.fetch(request).first
    }

    // MARK: - Deletion Helpers

    private func executeBatchDelete(
        fetchRequest: NSFetchRequest<NSFetchRequestResult>,
        on context: NSManagedObjectContext
    ) throws -> (count: Int, objectIDURLs: [URL]) {
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeObjectIDs
        guard let result = try context.execute(request) as? NSBatchDeleteResult,
              let objectIDs = result.result as? [NSManagedObjectID]
        else {
            throw CleanDataError.unableToDeleteData
        }
        if !objectIDs.isEmpty {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [context]
            )
        }
        return (objectIDs.count, objectIDs.map { $0.uriRepresentation() })
    }

    private func savePendingChanges() throws {
        var savedError: Error?
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                if coreDataManager.mainManagedObjectContext.hasChanges {
                    try coreDataManager.mainManagedObjectContext.save()
                }
            } catch {
                savedError = error
            }
        }
        if let savedError { throw savedError }

        coreDataManager.privateManagedObjectContext.performAndWait {
            do {
                if coreDataManager.privateManagedObjectContext.hasChanges {
                    try coreDataManager.privateManagedObjectContext.save()
                }
            } catch {
                savedError = error
            }
        }
        if let savedError { throw savedError }
    }

    private func mergeDeletedObjects(with objectIDURLs: [URL]) {
        let coordinator = coreDataManager.privateManagedObjectContext.persistentStoreCoordinator
        let objectIDs = objectIDURLs.compactMap { coordinator?.managedObjectID(forURIRepresentation: $0) }
        guard !objectIDs.isEmpty else { return }
        coreDataManager.mainManagedObjectContext.performAndWait {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [coreDataManager.mainManagedObjectContext]
            )
        }
    }

    private func storeSizeInBytes(on context: NSManagedObjectContext) -> Int64 {
        guard let storeURL = context.persistentStoreCoordinator?.persistentStores.first?.url else { return 0 }
        let fileURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm"),
        ]
        return fileURLs.reduce(into: Int64(0)) { result, url in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let fileSize = attributes[.size] as? NSNumber
            else { return }
            result += fileSize.int64Value
        }
    }

    private func elapsedMilliseconds(since startDate: Date) -> String {
        String(Int(Date().timeIntervalSince(startDate) * 1000))
    }
}
