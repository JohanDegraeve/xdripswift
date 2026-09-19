import CoreData
import Foundation
import os
import WatchConnectivity

/// The host injects its existing database and WCSession. All scheduling and registry access
/// run on main; Core Data work uses the context queues. Imports never grant BLE authority.
final class Libre2PhoneHistorySync {
    private let log = Logger(subsystem: "xDrip", category: "Libre2PhoneHistorySync")
    static let didImport = Notification.Name("Libre2PhoneHistoryDidImport")

    private let coreDataManager: CoreDataManager
    private let session: WCSession
    private var registry: Libre2HistoryRegistry?
    private var pending: [(Libre2HistoryBatch, (([String: Any]) -> Void)?)] = []
    private var pendingLatest: (Libre2HistoryBatch, (([String: Any]) -> Void)?)?
    private var isImporting = false
    private var importingBatch: Libre2HistoryBatch?
    private var importResponses: [(batch: Libre2HistoryBatch, reply: (([String: Any]) -> Void)?, isLatest: Bool)] = []
    private var historyUpdate = Libre2PhoneHistoryUpdate()
    private let beforeStoreSave: (@Sendable () throws -> Void)?

    private struct ImportResult {
        var inserted = 0
        var changedSensorIDs: Set<String> = []
    }

    init(coreDataManager: CoreDataManager, session: WCSession, registry: Libre2HistoryRegistry? = nil,
         beforeStoreSave: (@Sendable () throws -> Void)? = nil) {
        self.coreDataManager = coreDataManager
        self.session = session
        self.registry = registry
        self.beforeStoreSave = beforeStoreSave
    }

    /// Register before PREPARE is sent. Saving the sensor itself precedes writing the mapping,
    /// so an app restart cannot leave Watch readings pointing at an unsaved phone sensor.
    func register(_ watchSession: Libre2WatchSession, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            do {
                try await register(watchSession)
                completion(.success(()))
            } catch { completion(.failure(error)) }
        }
    }

    @discardableResult
    func receive(_ dictionary: [String: Any], reply: (([String: Any]) -> Void)? = nil) -> Bool {
        guard dictionary[Libre2HistoryBatch.key] != nil else { return false }
        do {
            let batch = try Libre2HistoryBatch.decode(dictionary)
            // Context, live latest and history often arrive together. Share the in-flight
            // save only for identical contents; every history batch still gets its own reply.
            if importingBatch?.readings == batch.readings {
                importResponses.append((batch, reply, dictionary[Libre2HistoryBatch.latestKey] as? Bool == true))
                return true
            }
            if dictionary[Libre2HistoryBatch.latestKey] as? Bool == true {
                // Coalesce live messages while an import is running. Supersession is not
                // a save acknowledgement; all measurements remain in Watch history.
                if let waiting = pendingLatest, waiting.0.readings[0].date >= batch.readings[0].date {
                    reply?(["superseded": true])
                    return true
                }
                if let waiting = pendingLatest {
                    waiting.1?(["superseded": true])
                }
                pendingLatest = (batch, reply)
            } else {
                pending.append((batch, reply))
            }
            importNext()
        } catch {
            report(error)
            reply?(["error": error.localizedDescription])
        }
        return true
    }

    private func importNext() {
        guard !isImporting, pendingLatest != nil || !pending.isEmpty else { return }
        isImporting = true
        // Finish the current save, then prefer the freshest live value to waiting history.
        let isLatest = pendingLatest != nil
        let (batch, reply) = pendingLatest ?? pending.removeFirst()
        pendingLatest = nil
        importingBatch = batch
        importResponses = [(batch, reply, isLatest)]
        Task { @MainActor in
            defer {
                isImporting = false
                importNext()
            }
            do {
                let result = try await importReadings(batch)
                finishImport { try Libre2HistoryAcknowledgement(batch: $0).dictionary }
                if result.inserted > 0 {
                    record("Saved \(result.inserted) Direct Watch readings on iPhone.")
                }
                // Also publish after a duplicate: an earlier attempt may have failed at the
                // final store save. Only a new, current value may refresh phone alerts.
                let currentDate = historyUpdate.consume(currentReadingDate(in: batch),
                    maximumAge: ConstantsFollower.maximumBgReadingAgeForAlertsInSeconds)
                var info: [String: Any] = currentDate.map {
                    [Libre2PhoneHistoryUpdate.currentReadingDateKey: $0]
                } ?? [:]
                info[Libre2PhoneHistoryUpdate.changedSensorIDsKey] = Array(result.changedSensorIDs)
                NotificationCenter.default.post(name: Self.didImport, object: self, userInfo: info)
            } catch let rejection as Libre2HistoryRejection {
                finishImport {
                    try Libre2HistoryRejection(batchID: $0.id, readingIDs: rejection.readingIDs).dictionary
                }
                record(
                    "History sync: \(rejection.readingIDs.count) unmatched readings remain on Watch; other readings can continue uploading.")
            } catch {
                report(error)
                finishImport { _ in throw error }
                // No success acknowledgement. The Watch retains and retries the batch.
            }
        }
    }

    private func finishImport(_ response: (Libre2HistoryBatch) throws -> [String: Any]) {
        let responses = importResponses
        importResponses = []
        importingBatch = nil
        for delivery in responses {
            do {
                let dictionary = try response(delivery.batch)
                if !delivery.isLatest || delivery.reply != nil { respond(dictionary, reply: delivery.reply) }
            } catch {
                delivery.reply?(["error": error.localizedDescription])
            }
        }
    }

    private func respond(_ dictionary: [String: Any], reply: (([String: Any]) -> Void)?) {
        if let reply {
            reply(dictionary)
        } else if session.activationState == .activated {
            session.transferUserInfo(dictionary)
        }
    }

    @MainActor
    private func register(_ watchSession: Libre2WatchSession) async throws {
        let registry = try sensorRegistry()
        if let saved = registry.entries.first(where: { $0.sessionID == watchSession.id }) {
            guard saved.sensorUID == watchSession.sensorUID else {
                throw Libre2HistoryError.unknownSensor
            }
            return
        }
        guard UserDefaults.standard.libreSensorUID == watchSession.sensorUID,
            let sensor = SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor(),
            sensor.startDate <= Date()
        else { throw Libre2HistoryError.unknownSensor }
        let sensorID = sensor.id
        try await saveToPersistentStore()
        try registry.register(watchSession, sensorID: sensorID)
    }

    @MainActor
    private func importReadings(_ batch: Libre2HistoryBatch) async throws -> ImportResult {
        let registry = try sensorRegistry()
        let sensorIDs: [String?] = try batch.readings.map { reading in
            do { return try registry.sensorID(for: reading) }
            catch Libre2HistoryError.unknownSensor { return nil }
        }
        let context = coreDataManager.privateChildManagedObjectContext()
        let result = try await context.perform {
            // Resolve the entire batch before inserting any rows.
            var sensors: [String: Sensor] = [:]
            for id in Set(sensorIDs.compactMap { $0 }) {
                let request = Sensor.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id)
                request.fetchLimit = 1
                sensors[id] = try context.fetch(request).first
            }
            let unresolvedIDs = zip(batch.readings, sensorIDs).compactMap { sample, sensorID in
                sensorID.flatMap { sensors[$0] } == nil ? sample.id : nil
            }
            guard unresolvedIDs.isEmpty else {
                throw Libre2HistoryRejection(batchID: batch.id, readingIDs: unresolvedIDs)
            }
            var result = ImportResult()
            for (sample, sensorID) in zip(batch.readings, sensorIDs) {
                guard let sensorID else { continue } // All mappings were resolved above.
                let request = BgReading.fetchRequest()
                // Deterministic IDs cover repeated/cross-handoff Watch samples. At a switch
                // boundary prefer an existing phone reading within half a minute.
                request.predicate = NSPredicate(
                    format: "id == %@ OR (sensor.id == %@ AND timeStamp > %@ AND timeStamp < %@ AND calculatedValue > 0 AND NOT (id BEGINSWITH 'direct-libre-watch:'))",
                    sample.id, sensorID, sample.date.addingTimeInterval(-30) as NSDate,
                    sample.date.addingTimeInterval(30) as NSDate)
                request.fetchLimit = 1
                guard try context.fetch(request).isEmpty else { continue }
                let reading = BgReading(timeStamp: sample.date, sensor: sensors[sensorID], calibration: nil,
                    rawData: sample.glucose, deviceName: "Libre 2 Watch", nsManagedObjectContext: context)
                reading.id = sample.id
                reading.calculatedValue = sample.glucose
                reading.ageAdjustedRawValue = sample.glucose
                reading.hideSlope = true
                let receivedAt = Date()
                if receivedAt.timeIntervalSince(sample.date) > ConstantsBloodGlucose.minimumSecondsToConsiderAsBackfillDelay {
                    reading.backfilledAt = receivedAt
                }
                result.inserted += 1
                result.changedSensorIDs.insert(sensorID)
            }
            if let start = batch.readings.map(\.date).min(), let end = batch.readings.map(\.date).max() {
                result.changedSensorIDs.formUnion(try Libre2PhoneReadingProcessing.updateSlopes(
                    sensorIDs: Set(sensorIDs.compactMap { $0 }), from: start, to: end, context: context))
            }
            if context.hasChanges { try context.save() }
            return result
        }
        // Saving the child/main contexts alone is not durable. Always attempt the final save,
        // even for a duplicate batch after an earlier disk-save failure.
        try await saveToPersistentStore()
        return result
    }

    /// AlertManager reads the newest stored value, so only announce that same reading,
    /// belonging to both this batch and the currently active phone sensor.
    @MainActor
    private func currentReadingDate(in batch: Libre2HistoryBatch) -> Date? {
        guard UserDefaults.standard.isMaster,
            let activeSensor = SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor(),
            let latest = BgReadingsAccessor(coreDataManager: coreDataManager).getLatestBgReadings(
                limit: 1, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).first,
            latest.sensor?.id == activeSensor.id,
            batch.readings.contains(where: { $0.id == latest.id })
        else { return nil }
        return latest.timeStamp
    }

    private func saveToPersistentStore() async throws {
        let main = coreDataManager.mainManagedObjectContext
        try await main.perform { if main.hasChanges { try main.save() } }
        let store = coreDataManager.privateManagedObjectContext
        let beforeStoreSave = self.beforeStoreSave
        try await store.perform {
            try beforeStoreSave?()
            if store.hasChanges { try store.save() }
        }
    }

    private func sensorRegistry() throws -> Libre2HistoryRegistry {
        if let registry { return registry }
        let loaded = try Libre2HistoryRegistry()
        registry = loaded
        return loaded
    }

    private func record(_ message: String) { log.info("\(message, privacy: .public)") }

    private func report(_ error: Error) {
        record("History sync: \(error.localizedDescription)")
    }
}
