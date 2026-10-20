//
//  DirectWatchBridgeTests.swift
//  xdripTests
//
//  Created by Paul Plant on 12/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import CoreData
#if canImport(xdrip)
@testable import xdrip
#endif

final class DirectWatchBridgeTests: XCTestCase {

    func testWatchAlarmSchedulesRoundTripWithoutBreakingLegacyConfiguration() throws {
        var configuration = configuration()
        configuration.urgentLowSchedule = [DirectWatchAlertEntry(startMinute: 0, threshold: 55)]
        configuration.lowSchedule = [DirectWatchAlertEntry(startMinute: 0, threshold: 70),
                                     DirectWatchAlertEntry(startMinute: 480, threshold: 75)]
        let data = try JSONEncoder().encode(configuration)
        XCTAssertEqual(try JSONDecoder().decode(DirectWatchConfiguration.self, from: data), configuration)
        XCTAssertTrue(configuration.isValid())
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "urgentLowSchedule")
        legacy.removeValue(forKey: "lowSchedule")
        let old = try JSONDecoder().decode(DirectWatchConfiguration.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(old.isValid())
        XCTAssertNil(old.urgentLowSchedule)
        XCTAssertNil(old.lowSchedule)
        configuration.lowSchedule = [DirectWatchAlertEntry(startMinute: 0, threshold: .nan)]
        XCTAssertTrue(configuration.isValid())
        XCTAssertNil(DirectWatchAlertEntry.current(in: configuration.lowSchedule, at: .now))
    }

    func testWatchAlertsIgnoreDisabledFlagsInPreviouslySyncedPhoneSchedules() throws {
        // Older snapshots included phone flags. Decoding must discard them, so a Watch
        // switch can enable an alert even when that time period is disabled on the phone.
        let data = Data(#"[{"startMinute":0,"threshold":60,"enabled":false}]"#.utf8)
        let schedule = try JSONDecoder().decode([DirectWatchAlertEntry].self, from: data)
        let now = Date()
        let entry = DirectWatchAlertEntry.current(in: schedule, at: now)
        XCTAssertEqual(DirectWatchAlertPolicy.glucoseAlert(value: 55, measuredAt: now, now: now,
            urgent: nil, low: entry, urgentEnabled: false, lowEnabled: true,
            lastUrgent: nil, lastLow: nil), .low)
        XCTAssertEqual(DirectWatchAlertPolicy.glucoseAlert(value: 55, measuredAt: now, now: now,
            urgent: entry, low: nil, urgentEnabled: true, lowEnabled: false,
            lastUrgent: nil, lastLow: nil), .urgentLow)
        XCTAssertNil(DirectWatchAlertPolicy.glucoseAlert(value: 55, measuredAt: now, now: now,
            urgent: entry, low: entry, urgentEnabled: false, lowEnabled: false,
            lastUrgent: nil, lastLow: nil))
    }

    func testWatchAlertsRequireOverSixtySecondsWithoutLivePhoneContact() {
        let now = Date(timeIntervalSince1970: 10000)
        XCTAssertFalse(DirectWatchAlertPolicy.mayNotify(collecting: true, lastPhoneContact: now.addingTimeInterval(-60), now: now))
        XCTAssertTrue(DirectWatchAlertPolicy.mayNotify(collecting: true, lastPhoneContact: now.addingTimeInterval(-61), now: now))
        XCTAssertTrue(DirectWatchAlertPolicy.mayNotify(collecting: true, lastPhoneContact: nil, now: now))
        XCTAssertFalse(DirectWatchAlertPolicy.mayNotify(collecting: false, lastPhoneContact: nil, now: now))
        XCTAssertFalse(DirectWatchAlertPolicy.mayNotify(collecting: true, lastPhoneContact: now.addingTimeInterval(60), now: now))
    }

    func testWatchAlarmSchedulesFollowLocalTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7200)!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        let night = DirectWatchAlertEntry(startMinute: 0, threshold: 75)
        let day = DirectWatchAlertEntry(startMinute: 8 * 60, threshold: 65)
        let schedule = [day, night]
        XCTAssertEqual(DirectWatchAlertEntry.current(in: schedule, at: midnight, calendar: calendar), night)
        XCTAssertEqual(DirectWatchAlertEntry.current(in: schedule, at: midnight.addingTimeInterval(8 * 3600), calendar: calendar), day)
        XCTAssertEqual(DirectWatchAlertEntry.current(in: schedule, at: midnight.addingTimeInterval(24 * 3600), calendar: calendar), night)
        XCTAssertNil(DirectWatchAlertEntry.current(in: nil, at: midnight))
        XCTAssertNil(DirectWatchAlertEntry.current(in: [DirectWatchAlertEntry(startMinute: 1500, threshold: 70)], at: midnight))
    }

    func testUrgentLowEscalatesImmediatelyAfterLowWithoutDuplicateLowAlert() {
        let now = Date(timeIntervalSince1970: 10000)
        let urgent = DirectWatchAlertEntry(startMinute: 0, threshold: 55)
        let low = DirectWatchAlertEntry(startMinute: 0, threshold: 70)
        func alert(_ value: Double, urgentEnabled: Bool = true, lowEnabled: Bool = true,
                   lastUrgent: Date? = nil, lastLow: Date? = nil, measuredAt: Date? = nil) -> DirectWatchAlertPolicy.GlucoseAlert? {
            DirectWatchAlertPolicy.glucoseAlert(value: value, measuredAt: measuredAt ?? now, now: now,
                urgent: urgent, low: low, urgentEnabled: urgentEnabled, lowEnabled: lowEnabled,
                lastUrgent: lastUrgent, lastLow: lastLow)
        }
        XCTAssertEqual(alert(65), .low)
        XCTAssertEqual(alert(50, lastLow: now), .urgentLow)
        XCTAssertNil(alert(50, lastUrgent: now))
        XCTAssertNil(alert(65, lastUrgent: now))
        XCTAssertEqual(alert(50, urgentEnabled: false), .low)
        XCTAssertNil(alert(50, urgentEnabled: false, lowEnabled: false))
        XCTAssertNil(alert(200))
        XCTAssertNil(alert(50, measuredAt: now.addingTimeInterval(-8 * 60)))
        XCTAssertNil(alert(50, measuredAt: now.addingTimeInterval(120)))
        XCTAssertEqual(alert(50, lastUrgent: now.addingTimeInterval(-15 * 60)), .urgentLow)
        XCTAssertEqual(DirectWatchAlertPolicy.glucoseAlert(value: 50, measuredAt: now, now: now,
            urgent: DirectWatchAlertEntry(startMinute: 0, threshold: 55), low: nil,
            urgentEnabled: true, lowEnabled: false, lastUrgent: nil, lastLow: nil), .urgentLow)
    }

    func testMissedReadingDeadlineMovesBeyondRecentPhoneContact() {
        let reading = Date(timeIntervalSince1970: 10000)
        XCTAssertEqual(DirectWatchAlertPolicy.missedReadingDeadline(collectedAt: reading, lastPhoneContact: nil), reading.addingTimeInterval(21 * 60))
        let contact = reading.addingTimeInterval(30 * 60)
        XCTAssertEqual(DirectWatchAlertPolicy.missedReadingDeadline(collectedAt: reading, lastPhoneContact: contact), contact.addingTimeInterval(61))
        XCTAssertEqual(DirectWatchAlertPolicy.missedReadingDeadline(collectedAt: reading, lastPhoneContact: reading), reading.addingTimeInterval(21 * 60))
    }
    @MainActor
    func testConfigurationDeliveryNeverBlocksMainAndCoalescesWaitingSnapshots() async {
        let started = expectation(description: "First transfer started")
        let latest = expectation(description: "Latest transfer delivered")
        let duplicate = expectation(description: "Unchanged live refresh delivered")
        let release = DispatchSemaphore(value: 0)
        var call = 0 // Accessed only by the sender's serial queue.
        let sender = DirectWatchConfigurationSender { payload, changed in
            XCTAssertFalse(Thread.isMainThread)
            call += 1
            if call == 1 {
                XCTAssertEqual(payload["revision"] as? Int, 0)
                XCTAssertTrue(changed)
                started.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            } else {
                XCTAssertEqual(payload["revision"] as? Int, 1000)
                if call == 2 {
                    XCTAssertTrue(changed)
                    latest.fulfill()
                } else {
                    XCTAssertEqual(call, 3)
                    XCTAssertFalse(changed)
                    duplicate.fulfill()
                }
            }
            return true
        }
        sender.enqueue(["revision": 0])
        await fulfillment(of: [started], timeout: 5)
        // Simulate a stalled framework call while the main thread keeps receiving changes.
        // Only the newest snapshot should survive, rather than 1000 retained send blocks.
        for revision in 1...1000 { sender.enqueue(["revision": revision]) }
        release.signal()
        await fulfillment(of: [latest], timeout: 5)
        sender.enqueue(["revision": 1000])
        await fulfillment(of: [duplicate], timeout: 5)
    }

    func testConfigurationDeliveryRetriesAfterAnInactiveSession() async {
        let inactive = expectation(description: "Session inactive")
        let retried = expectation(description: "Background retry retained")
        var call = 0 // Accessed only by the sender's serial queue.
        let sender = DirectWatchConfigurationSender { _, changed in
            XCTAssertTrue(changed)
            call += 1
            if call == 1 {
                inactive.fulfill()
                return false
            }
            retried.fulfill()
            return true
        }
        sender.enqueue(["revision": 1])
        await fulfillment(of: [inactive], timeout: 5)
        sender.enqueue(["revision": 1])
        await fulfillment(of: [retried], timeout: 5)
    }

    func testLogRequestsPreservePreviousReceiptUntilANewExportArrives() throws {
        let suite = "DirectWatchLogs.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        DirectWatchSettings.recordLogsReceived(now: start, in: defaults)
        let requestedAt = start.addingTimeInterval(60)
        DirectWatchSettings.recordLogRequest(queued: true, now: requestedAt, in: defaults)
        // Navigating away or relaunching must retain both the earlier receipt and the wait.
        let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(reopened.object(forKey: DirectWatchSettings.logsReceivedDateKey) as? Date, start)
        XCTAssertEqual(reopened.object(forKey: DirectWatchSettings.logsRequestedDateKey) as? Date, requestedAt)
        DirectWatchSettings.recordLogRequest(queued: false, in: reopened)
        XCTAssertTrue(defaults.bool(forKey: DirectWatchSettings.logsFailedKey))
        XCTAssertNil(defaults.object(forKey: DirectWatchSettings.logsRequestedDateKey))
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.logsReceivedDateKey) as? Date, start)
        // An export sent directly from the Watch also clears a failed or pending request.
        let receivedAt = start.addingTimeInterval(120)
        DirectWatchSettings.recordLogsReceived(now: receivedAt, in: defaults)
        XCTAssertFalse(defaults.bool(forKey: DirectWatchSettings.logsFailedKey))
        XCTAssertNil(defaults.object(forKey: DirectWatchSettings.logsRequestedDateKey))
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.logsReceivedDateKey) as? Date, receivedAt)
    }

    func testTelemetryResetDoesNotRemoveConfigurationChoicesOrRevisionClock() throws {
        let suite = "DirectWatchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = [DirectWatchSettings.lastConnectedDateKey, DirectWatchSettings.lastCollectedDateKey,
                         DirectWatchSettings.lastContactDateKey, DirectWatchSettings.lastStatusKey,
                         DirectWatchSettings.lastStatusDateKey, DirectWatchSettings.unavailableReasonKey]
        telemetry.forEach { defaults.set("previous binding", forKey: $0) }
        let configurationData = try JSONEncoder().encode(configuration())
        defaults.set(configurationData, forKey: DirectWatchSettings.configurationKey)
        defaults.set("8ABCDE", forKey: DirectWatchSettings.pausedKey)
        defaults.set(123, forKey: DirectWatchSettings.collectionControlClockKey)
        DirectWatchSettings.clearTelemetry(in: defaults)
        telemetry.forEach { XCTAssertNil(defaults.object(forKey: $0)) }
        XCTAssertEqual(defaults.data(forKey: DirectWatchSettings.configurationKey), configurationData)
        XCTAssertEqual(defaults.string(forKey: DirectWatchSettings.pausedKey), "8ABCDE")
        XCTAssertEqual(defaults.double(forKey: DirectWatchSettings.collectionControlClockKey), 123)
    }

    func testSessionHistoryDoesNotInventResumeGapAfterFirstReadingWasPruned() throws {
        var session = DirectWatchCollectionSession(id: UUID(), connection: configuration().connectionIdentity,
                                                  startedAt: start, isResume: true)
        var first = reading(seconds: 4900)
        first.collectionSessionID = session.id
        first.collectedAt = start.addingTimeInterval(324)
        session.firstReadingID = first.id
        var later = reading(seconds: 5200)
        later.collectionSessionID = session.id
        later.collectedAt = start.addingTimeInterval(650)
        XCTAssertEqual(session.intervalBefore(first, in: [first, later]), 324)
        XCTAssertEqual(session.intervalBefore(later, in: [first, later]), 326)
        XCTAssertNil(session.intervalBefore(later, in: [later]))
        let restored = try JSONDecoder().decode(DirectWatchCollectionSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.firstReadingID, first.id)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        legacy.removeValue(forKey: "firstReadingID")
        let legacySession = try JSONDecoder().decode(DirectWatchCollectionSession.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(legacySession.firstReadingID)
    }

    func testCollectionIntervalsUseResumeAndPreviousAcquisitionWithinTheSameSession() {
        let session = DirectWatchCollectionSession(id: UUID(), connection: configuration().connectionIdentity,
                                                  startedAt: start, isResume: true)
        var first = reading(seconds: 4900)
        first.collectionSessionID = session.id
        first.collectedAt = start.addingTimeInterval(324)
        var next = reading(seconds: 5200)
        next.collectionSessionID = session.id
        next.collectedAt = start.addingTimeInterval(650)
        // Another session cannot become this session's previous reading.
        var other = reading(seconds: 5000)
        other.collectionSessionID = UUID()
        other.collectedAt = start.addingTimeInterval(640)
        XCTAssertEqual(session.intervalBefore(first, in: [first, next, other]), 324)
        XCTAssertEqual(session.intervalBefore(next, in: [first, next, other]), 326)
        XCTAssertNil(session.intervalBefore(other, in: [first, next, other]))
        next.collectionSessionID = nil
        XCTAssertNil(session.intervalBefore(next, in: [first, next, other]))
    }

    func testSecondaryWatchConfirmationPersistsWithoutChangingReadingProvenance() throws {
        let modelDirectory = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v36.mom")))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let phoneReading = BgReading(timeStamp: start, sensor: nil, calibration: nil, rawData: 100,
                                         deviceName: "Anubis G6", nsManagedObjectContext: context)
            phoneReading.calculatedValue = 100
            let confirmation = start.addingTimeInterval(600)
            phoneReading.recordWatchCollection(at: confirmation)
            phoneReading.recordWatchCollection(at: confirmation.addingTimeInterval(60))
            try context.save()
            let objectID = phoneReading.objectID
            context.reset()
            let restored = try XCTUnwrap(context.existingObject(with: objectID) as? BgReading)
            XCTAssertFalse(restored.valueIsFromWatch)
            XCTAssertEqual(restored.watchReceivedAt, confirmation)
            XCTAssertEqual(restored.timeStamp, start)
            XCTAssertEqual(restored.calculatedValue, 100)
            XCTAssertEqual(restored.deviceName, "Anubis G6")
            // A retransmission also preserves the original Watch provenance and receipt time.
            restored.valueIsFromWatch = true
            restored.recordWatchCollection(at: confirmation.addingTimeInterval(120))
            XCTAssertTrue(restored.valueIsFromWatch)
            XCTAssertEqual(restored.watchReceivedAt, confirmation)
        }
    }

    func testWatchFirstCollectionBecomesSharedRegardlessOfAcquisitionDelayAndPersists() throws {
        let modelDirectory = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v36.mom")))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for delta in [0.0, 10, 15, 15.001, 20, 60, 600] {
                let value = BgReading(timeStamp: start, sensor: nil, calibration: nil, rawData: 100,
                                      deviceName: "Anubis G6", nsManagedObjectContext: context)
                value.calculatedValue = 100
                value.valueIsFromWatch = true
                let receipt = start.addingTimeInterval(3600)
                let acquiredAt = receipt.addingTimeInterval(-delta)
                value.watchCollectedAt = acquiredAt
                value.watchReceivedAt = receipt
                // This is the same matched reading, even when buffering or offline sync
                // separates the two collectors. Only one saved glucose value is retained.
                XCTAssertTrue(value.recordPhoneCollection())
                XCTAssertFalse(value.recordPhoneCollection())
                try context.save()
                let objectID = value.objectID
                context.reset()
                let restored = try XCTUnwrap(context.existingObject(with: objectID) as? BgReading)
                XCTAssertFalse(restored.valueIsFromWatch)
                XCTAssertEqual(restored.watchCollectedAt, acquiredAt)
                XCTAssertEqual(restored.watchReceivedAt, receipt)
                XCTAssertEqual(restored.calculatedValue, 100)
                XCTAssertEqual(restored.timeStamp, start)
            }
            // Legacy Watch readings still confirm participation through their receipt timestamp.
            let legacy = BgReading(timeStamp: start, sensor: nil, calibration: nil, rawData: 100,
                                   deviceName: "Anubis G6", nsManagedObjectContext: context)
            legacy.valueIsFromWatch = true
            legacy.watchReceivedAt = start
            XCTAssertTrue(legacy.recordPhoneCollection())
            XCTAssertFalse(legacy.valueIsFromWatch)
            XCTAssertEqual(legacy.watchReceivedAt, start)
            XCTAssertNil(legacy.watchCollectedAt)
            let phoneOnly = BgReading(timeStamp: start, sensor: nil, calibration: nil, rawData: 100,
                                      deviceName: "Anubis G6", nsManagedObjectContext: context)
            XCTAssertTrue(phoneOnly.recordPhoneCollection())
            XCTAssertFalse(phoneOnly.recordPhoneCollection())
            XCTAssertNil(phoneOnly.watchReceivedAt)
        }
    }

    func testLiveCollectionAttributionSurvivesBackfillInEitherArrivalOrder() throws {
        let modelDirectory = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v36.mom")))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for phoneFirst in [false, true] {
                for phoneLive in [false, true] {
                    for watchLive in [false, true] {
                        let value = BgReading(timeStamp: start, sensor: nil, calibration: nil, rawData: 100,
                                              deviceName: "Anubis G6", nsManagedObjectContext: context)
                        value.calculatedValue = 100
                        // A live Watch reading can reach the phone an hour later. Only its
                        // acquisition path matters, never the order of sync and phone backfill.
                        let collectedAt = start.addingTimeInterval(watchLive ? 60 : 600)
                        let receivedAt = start.addingTimeInterval(3600)
                        if phoneFirst {
                            value.phoneCollectedLive = NSNumber(value: phoneLive)
                            value.watchCollectedLive = false
                            value.backfilledAt = phoneLive ? nil : start.addingTimeInterval(1800)
                            value.recordWatchCollection(at: receivedAt, collectedAt: collectedAt, isBackfill: !watchLive)
                        } else {
                            value.valueIsFromWatch = true
                            value.phoneCollectedLive = false
                            value.watchCollectedLive = NSNumber(value: watchLive)
                            value.watchReceivedAt = receivedAt
                            value.watchCollectedAt = collectedAt
                            value.backfilledAt = watchLive ? nil : collectedAt
                            value.recordPhoneCollection(isBackfill: !phoneLive)
                        }
                        try context.save()
                        let objectID = value.objectID
                        context.reset()
                        let restored = try XCTUnwrap(context.existingObject(with: objectID) as? BgReading)
                        XCTAssertEqual(restored.wasAlsoCollectedByWatch, phoneLive && watchLive)
                        XCTAssertEqual(restored.valueIsFromWatch, phoneFirst ? (!phoneLive && watchLive) : !phoneLive)
                        XCTAssertEqual(restored.phoneCollectedLive?.boolValue, phoneLive)
                        XCTAssertEqual(restored.watchCollectedLive?.boolValue, watchLive)
                        XCTAssertEqual(restored.watchReceivedAt, receivedAt)
                        XCTAssertEqual(restored.watchCollectedAt, collectedAt)
                        XCTAssertEqual(restored.calculatedValue, 100)
                        XCTAssertEqual(restored.timeStamp, start)
                        if phoneLive || watchLive { XCTAssertNil(restored.backfilledAt) }

                        // Repeated historical copies must never erase earlier live evidence.
                        XCTAssertFalse(restored.recordPhoneCollection(isBackfill: true))
                        restored.recordWatchCollection(at: receivedAt, collectedAt: collectedAt, isBackfill: true)
                        XCTAssertEqual(restored.wasAlsoCollectedByWatch, phoneLive && watchLive)
                        XCTAssertEqual(restored.phoneCollectedLive?.boolValue, phoneLive)
                        XCTAssertEqual(restored.watchCollectedLive?.boolValue, watchLive)
                    }
                }
            }
        }
    }

    func testSessionHistoryRecordsAppliedTransitionsWithoutSplittingReconnects() throws {
        let connection = configuration().connectionIdentity
        var sessions: [DirectWatchCollectionSession] = []
        DirectWatchCollectionSession.update(&sessions, collecting: true, connection: connection, paused: false, now: start)
        let originalID = sessions[0].id
        // Repeated controls, foreground activation and a process restart keep the same session.
        sessions = try JSONDecoder().decode([DirectWatchCollectionSession].self, from: JSONEncoder().encode(sessions))
        DirectWatchCollectionSession.update(&sessions, collecting: true, connection: connection, paused: false, now: start.addingTimeInterval(60))
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, originalID)
        let appliedPause = start.addingTimeInterval(120)
        DirectWatchCollectionSession.update(&sessions, collecting: false, connection: connection, paused: true, now: appliedPause)
        DirectWatchCollectionSession.update(&sessions, collecting: false, connection: connection, paused: true, now: start.addingTimeInterval(180))
        XCTAssertEqual(sessions[0].endedAt, appliedPause)
        DirectWatchCollectionSession.update(&sessions, collecting: true, connection: connection, paused: false, now: start.addingTimeInterval(240))
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions[1].isResume)
        XCTAssertNotEqual(sessions[1].id, originalID)
        XCTAssertNil(sessions[1].endedAt)
    }

    func testSessionHistoryClosesChangedBindingWithoutCallingItAPause() {
        var sessions: [DirectWatchCollectionSession] = []
        let first = configuration(slot: 1).connectionIdentity
        let second = configuration(slot: 2).connectionIdentity
        DirectWatchCollectionSession.update(&sessions, collecting: true, connection: first, paused: false, now: start)
        DirectWatchCollectionSession.update(&sessions, collecting: true, connection: second, paused: false, now: start.addingTimeInterval(60))
        XCTAssertEqual(sessions.count, 2)
        XCTAssertFalse(sessions[0].endedByPause)
        XCTAssertEqual(sessions[0].endedAt, start.addingTimeInterval(60))
        XCTAssertFalse(sessions[1].isResume)
    }

    func testBackfilledReadingRetainsItsCollectionSessionThroughEncoding() throws {
        var value = reading()
        value.collectedAt = value.measuredAt.addingTimeInterval(900)
        value.collectionSessionID = UUID()
        let restored = try JSONDecoder().decode(DirectWatchReading.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.collectionSessionID, value.collectionSessionID)
        XCTAssertEqual(restored.measuredAt, value.measuredAt)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        legacy.removeValue(forKey: "collectionSessionID")
        XCTAssertNil(try JSONDecoder().decode(DirectWatchReading.self, from: JSONSerialization.data(withJSONObject: legacy)).collectionSessionID)
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private func configuration(slot: UInt8 = 1, anubis: Bool = false) -> DirectWatchConfiguration {
        DirectWatchConfiguration(transmitterID: "8ABCDE", slot: slot, isAnubis: anubis, sensorStartDate: start, isMgDl: true, low: 70, high: 180)
    }
    private func reading(state: UInt8 = 6, mgDl: Double = 100, startOffset: Double = 0, seconds: UInt32 = 4600) -> DirectWatchReading {
        DirectWatchReading(transmitterID: "8ABCDE", sensorStartCounter: 1000, sensorStartDate: start.addingTimeInterval(startOffset), transmitterSeconds: seconds, measuredAt: start.addingTimeInterval(3600), mgDl: mgDl, state: state)
    }

    func testCollectionControlRejectsOlderOfflineChoicesAndOrdersConcurrentChoices() throws {
        let connection = configuration().connectionIdentity
        let pause = DirectWatchCollectionControl(connection: connection, isPaused: true, now: start)
        let resume = DirectWatchCollectionControl(connection: connection, isPaused: false,
                                                  previousRevision: pause.revision, now: start.addingTimeInterval(-100))
        XCTAssertTrue(resume.isNewer(than: pause))
        XCTAssertFalse(pause.isNewer(than: resume))
        XCTAssertFalse(pause.isNewer(than: pause))
        XCTAssertEqual(DirectWatchCollectionControl.decode(pause.payload), pause)
        let concurrent = DirectWatchCollectionControl(connection: connection, isPaused: false, now: start)
        XCTAssertNotEqual(pause.isNewer(than: concurrent), concurrent.isNewer(than: pause))
        XCTAssertEqual(try JSONDecoder().decode(DirectWatchCollectionControl.self,
                                               from: JSONEncoder().encode(pause)), pause)
        XCTAssertNil(DirectWatchCollectionControl.decode(["directWatchCollectionControl": Data(repeating: 0, count: 2049)]))
    }

    func testCollectionControlIsScopedToTransmitterFamilyAndSlot() {
        let control = DirectWatchCollectionControl(connection: configuration().connectionIdentity, isPaused: true, now: start)
        XCTAssertTrue(control.supersedes(nil, for: configuration().connectionIdentity))
        XCTAssertFalse(control.supersedes(nil, for: configuration(slot: 2).connectionIdentity))
        XCTAssertFalse(control.supersedes(nil, for: DirectWatchConnectionIdentity(transmitterID: "OTHER1", family: .g6, slot: 1)))
        XCTAssertFalse(control.supersedes(nil, for: DirectWatchConnectionIdentity(transmitterID: "8ABCDE", family: .g7, slot: 1)))
        XCTAssertFalse(control.supersedes(nil, for: nil))
        let oldTarget = DirectWatchCollectionControl(connection: configuration(slot: 2).connectionIdentity, isPaused: false,
                                                     now: start.addingTimeInterval(100))
        XCTAssertTrue(control.supersedes(oldTarget, for: configuration().connectionIdentity))
    }

    func testPausedBannerDoesNotReportOldReadingsAsAConnectionFailure() {
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false,
                                               latestReadingAt: start, now: start.addingTimeInterval(3600), isPaused: true), .paused)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: false, isSuspended: false,
                                               latestReadingAt: nil, now: start, isPaused: true), .off)
    }

    func testCounterStopsWhilePausedAndUsesTheLatestResumeOrConnection() {
        let oldConnection = start.addingTimeInterval(-3600)
        XCTAssertNil(DirectWatchCollectionPolicy.counterElapsed(resumedAt: start, lastConnectedAt: oldConnection,
                                                               isPaused: true, now: start))
        XCTAssertEqual(DirectWatchCollectionPolicy.counterElapsed(resumedAt: start, lastConnectedAt: oldConnection,
                                                                 isPaused: false, now: start), 0)
        let nextConnection = start.addingTimeInterval(60)
        XCTAssertEqual(DirectWatchCollectionPolicy.counterElapsed(resumedAt: start, lastConnectedAt: nextConnection,
                                                                 isPaused: false, now: start.addingTimeInterval(75)), 15)
        XCTAssertNil(DirectWatchCollectionPolicy.counterElapsed(resumedAt: nil, lastConnectedAt: nil,
                                                               isPaused: false, now: start))
        let control = DirectWatchCollectionControl(connection: configuration().connectionIdentity, isPaused: false,
                                                   previousRevision: start.timeIntervalSince1970 + 1000, now: start)
        XCTAssertEqual(control.resumedAt(for: configuration().connectionIdentity), start)
        XCTAssertNil(control.resumedAt(for: configuration(slot: 2).connectionIdentity))
    }

    func testConnectionTelemetryRejectsEarlierControlsOtherSlotsAndFutureTimes() throws {
        let config = configuration()
        let control = DirectWatchCollectionControl(connection: config.connectionIdentity, isPaused: false, now: start)
        let event = DirectWatchConnectionEvent(connection: config.connectionIdentity, connectedAt: start.addingTimeInterval(5), controlID: control.id)
        XCTAssertTrue(event.matches(config, control: control, now: start.addingTimeInterval(10)))
        XCTAssertFalse(event.matches(configuration(slot: 2), control: control, now: start.addingTimeInterval(10)))
        let newControl = DirectWatchCollectionControl(connection: config.connectionIdentity, isPaused: false,
                                                     previousRevision: control.revision, now: start.addingTimeInterval(10))
        XCTAssertFalse(event.matches(config, control: newControl, now: start.addingTimeInterval(10)))
        let future = DirectWatchConnectionEvent(connection: config.connectionIdentity, connectedAt: start.addingTimeInterval(1000), controlID: control.id)
        XCTAssertFalse(future.matches(config, control: control, now: start))
        XCTAssertEqual(DirectWatchConnectionEvent.decode(event.payload)?.connectedAt, event.connectedAt)
        var legacy = try XCTUnwrap(control.payload["directWatchCollectionControl"] as? Data)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        object.removeValue(forKey: "changedAt")
        legacy = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(DirectWatchCollectionControl.decode(["directWatchCollectionControl": legacy])?.changedAt)
    }

    func testResumeWaitsForANewConnectionWithoutReportingOldReadingsAsOverdue() {
        let oldReading = start.addingTimeInterval(-3600)
        let oldConnection = start.addingTimeInterval(-3500)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: oldReading,
                                               now: start, resumedAt: start, lastConnectedAt: oldConnection), .connecting)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: nil,
                                               now: start, resumedAt: start, lastConnectedAt: nil), .connecting)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: start.addingTimeInterval(-30),
                                               now: start, resumedAt: start, lastConnectedAt: oldConnection), .connecting)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: oldReading,
                                               now: start, isPaused: true, resumedAt: start, lastConnectedAt: oldConnection), .paused)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: start,
                                               now: start, resumedAt: start, lastConnectedAt: start), .current)
    }

    func testSharedBannerUsesReadingAgeAndSetupState() {
        func status(_ seconds: Double, configured: Bool = true, suspended: Bool = false) -> DirectWatchReadingStatus {
            DirectWatchReadingStatus(isConfigured: configured, isSuspended: suspended,
                                     latestReadingAt: start, now: start.addingTimeInterval(seconds))
        }
        XCTAssertEqual(status(ConstantsDirectWatch.readingDelayedAfter), .current)
        XCTAssertEqual(status(ConstantsDirectWatch.readingDelayedAfter + 1), .delayed)
        XCTAssertEqual(status(ConstantsDirectWatch.readingOverdueAfter), .delayed)
        XCTAssertEqual(status(ConstantsDirectWatch.readingOverdueAfter + 1), .overdue)
        XCTAssertEqual(status(0, configured: false), .off)
        XCTAssertEqual(status(0, suspended: true), .suspended)
        XCTAssertEqual(DirectWatchReadingStatus(isConfigured: true, isSuspended: false,
                                               latestReadingAt: nil, now: start), .waiting)
    }

    func testStandardG6AllowsEitherUnusedStandardSlot() {
        XCTAssertTrue(configuration().isValid(phoneSlot: 2))
        XCTAssertTrue(configuration(slot: 2).isValid(phoneSlot: 1))
        XCTAssertFalse(configuration(slot: 3).isValid(phoneSlot: 2))
        XCTAssertFalse(configuration(slot: 2).isValid(phoneSlot: 2))
        XCTAssertFalse(configuration(slot: 1).isValid(phoneSlot: 1))
    }

    func testPendingRecoveryRetriesKnownPeripheralBeforeForegroundDiscovery() {
        let policy = DirectWatchCollectionPolicy.self
        XCTAssertEqual(policy.pendingRecovery(startedAt: nil, now: start, isForeground: true, savedRetryCount: 0), .wait)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: start.addingTimeInterval(5 * 60), isForeground: true, savedRetryCount: 0), .wait)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: start.addingTimeInterval(6 * 60), isForeground: true, savedRetryCount: 0), .retrySavedPeripheral)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: start.addingTimeInterval(12 * 60), isForeground: true, savedRetryCount: 1), .retrySavedPeripheral)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: start.addingTimeInterval(18 * 60), isForeground: true, savedRetryCount: 2), .discoverInForeground)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: start.addingTimeInterval(8 * 3600), isForeground: false, savedRetryCount: 2), .retrySavedPeripheral)
    }

    func testBackgroundWakeRetriesOnlyOverdueRequestsAndNeverStartsDiscovery() {
        let policy = DirectWatchCollectionPolicy.self
        let overdue = start.addingTimeInterval(ConstantsDirectWatch.readingOverdueAfter)
        XCTAssertEqual(policy.pendingRecovery(startedAt: nil, now: overdue, isForeground: false, savedRetryCount: 0), .wait)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: overdue.addingTimeInterval(-1), isForeground: false, savedRetryCount: 0), .wait)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: overdue, isForeground: false, savedRetryCount: 0), .retrySavedPeripheral)
        XCTAssertEqual(policy.pendingRecovery(startedAt: start, now: overdue, isForeground: false, savedRetryCount: 100), .retrySavedPeripheral)
        // A new request gets a full grace period, even if another phone transfer wakes us immediately.
        XCTAssertEqual(policy.pendingRecovery(startedAt: overdue, now: overdue.addingTimeInterval(1), isForeground: false, savedRetryCount: 1), .wait)
        XCTAssertEqual(policy.pendingRecovery(startedAt: overdue, now: start, isForeground: false, savedRetryCount: 1), .wait)
    }

    func testDisplayAndAlertConfigurationUpdatesKeepBluetoothConnection() {
        let original = configuration()
        var updated = original
        updated.isMgDl = false
        updated.low = 80
        updated.high = 200
        updated.deviceName = "Anubis G6"
        XCTAssertFalse(DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: original, next: updated))
        XCTAssertTrue(DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: original, next: nil))
        XCTAssertTrue(DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: nil, next: original))
        updated.sensorStartDate = start.addingTimeInterval(3600)
        XCTAssertTrue(DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: original, next: updated))
        XCTAssertTrue(DirectWatchCollectionPolicy.requiresBluetoothRestart(previous: original, next: configuration(slot: 2)))
    }

    func testG6ReconnectWaitsOutCompletedCycleWithoutMissingNextCycle() {
        let policy = DirectWatchCollectionPolicy.self
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: nil, failedAttempts: 0, now: start), 0)
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 0, now: start), 60)
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 0, now: start.addingTimeInterval(20)), 40)
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 0, now: start.addingTimeInterval(60)), 0)
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 0, now: start.addingTimeInterval(300)), 0)
        // Clock correction must not turn a one-minute pause into a long collection outage.
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start.addingTimeInterval(3600), failedAttempts: 0, now: start), 60)
        XCTAssertEqual(policy.reconnectDelay(family: .g7, completedAt: start, failedAttempts: 0, now: start), 0)
    }

    func testFailedConnectionsBackOffWithoutUnboundedDelay() {
        let policy = DirectWatchCollectionPolicy.self
        for (attempt, expected) in [(1, 2.0), (2, 4.0), (3, 8.0), (4, 16.0), (5, 30.0), (100, 30.0)] {
            XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: nil, failedAttempts: attempt, now: start), expected)
        }
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 5, now: start), 60)
        XCTAssertEqual(policy.reconnectDelay(family: .g6, completedAt: start, failedAttempts: 5, now: start.addingTimeInterval(50)), 30)
    }

    func testInvalidDelayedRequestFallsBackOnlyOnceAndNeverLoops() {
        XCTAssertEqual(DirectWatchCollectionPolicy.invalidConnectionRecovery(usedDelayOption: true), .retryWithoutOptions)
        // The fallback sends no options. Rejection of that request must stop, rather than
        // generating the thousands of invalid-parameter retries seen on the physical Watch.
        for _ in 0..<10 {
            XCTAssertEqual(DirectWatchCollectionPolicy.invalidConnectionRecovery(usedDelayOption: false), .stopInvalidRequest)
        }
    }
    func testAnubisAllowsExtraSlotButRejectsPhoneConflict() {
        XCTAssertTrue(configuration(slot: 3, anubis: true).isValid(phoneSlot: 2))
        XCTAssertTrue(configuration(slot: 1, anubis: true).isValid(phoneSlot: 2))
        XCTAssertTrue(configuration(slot: 2, anubis: true).isValid(phoneSlot: 1))
        XCTAssertFalse(configuration(slot: 3, anubis: true).isValid(phoneSlot: 3))
    }
    func testAESChallengeMatchesIndependentOpenSSLVector() {
        XCTAssertEqual(DexcomG6WatchProtocol.challengeHash(transmitterID: "ABCDEF", challenge: Data(1...8)), Data([0x58, 0x71, 0x90, 0xca, 0x9b, 0xd5, 0x37, 0xe8]))
        XCTAssertNil(DexcomG6WatchProtocol.challengeHash(transmitterID: "BAD", challenge: Data(1...8)))
        XCTAssertNil(DexcomG6WatchProtocol.challengeHash(transmitterID: "ABCDEF", challenge: Data([1])))
    }
    func testCRCMatchesXModemCheckVector() {
        XCTAssertEqual(DexcomG6WatchProtocol.checksum(Data("123456789".utf8)), 0x31c3)
        XCTAssertEqual(DexcomG6WatchProtocol.command(0x30), Data([0x30, 0x53, 0x36]))
        XCTAssertTrue(DexcomG6WatchProtocol.hasValidCRC(DexcomG6WatchProtocol.command(0x24)))
    }
    func testGlucoseParserUsesTransmitterClockAndRejectsCorruption() {
        var bytes = Data([0x31, 0, 1, 0, 0, 0, 0xf8, 0x11, 0, 0, 123, 0, 6, 0])
        let crc = DexcomG6WatchProtocol.checksum(bytes)
        bytes.append(contentsOf: [UInt8(truncatingIfNeeded: crc), UInt8(truncatingIfNeeded: crc >> 8)])
        let glucose = DexcomG6WatchProtocol.glucose(bytes)
        XCTAssertEqual(glucose?.seconds, 4600)
        XCTAssertEqual(glucose?.value, 123)
        XCTAssertEqual(glucose?.state, 6)
        bytes[10] = 124
        XCTAssertNil(DexcomG6WatchProtocol.glucose(bytes))
        XCTAssertNil(DexcomG6WatchProtocol.glucose(Data(bytes.prefix(12))))
    }
    func testOnlyUsableNativeStatesCanBeImported() {
        XCTAssertTrue(reading().isUsable)
        XCTAssertTrue(reading(state: 7).isUsable)
        for state: UInt8 in [0, 1, 2, 3, 4, 5, 15, 16, 18] { XCTAssertFalse(reading(state: state).isUsable) }
        XCTAssertFalse(reading(mgDl: .nan).isUsable)
        XCTAssertFalse(reading(mgDl: 0).isUsable)
    }
    func testDifferentSessionAndFutureReadingsAreRejected() {
        let now = start.addingTimeInterval(7200)
        XCTAssertTrue(reading().belongs(to: configuration(), now: now))
        XCTAssertFalse(reading(startOffset: 3600).belongs(to: configuration(), now: now))
        XCTAssertFalse(reading().belongs(to: configuration(), now: start))
        XCTAssertFalse(reading(seconds: 1).belongs(to: configuration(), now: now))
    }
    func testIdentityDoesNotDependOnWallClockDriftOrGlucoseValue() {
        XCTAssertEqual(reading().id, reading(mgDl: 101, startOffset: 2).id)
        XCTAssertNotEqual(reading().id, reading(seconds: 4900).id)
    }
    func testRecordsRoundTripWithoutLosingMeasurementIdentity() throws {
        let source = [reading(), reading(seconds: 4900)]
        let restored = try JSONDecoder().decode([DirectWatchReading].self, from: JSONEncoder().encode(source))
        XCTAssertEqual(restored, source)
        XCTAssertEqual(Set(restored.map(\.id)).count, 2)
    }

    func testWatchBackfillUsesWatchCollectionTimeRatherThanPhoneSyncTime() throws {
        var collected = reading()
        collected.collectedAt = collected.measuredAt.addingTimeInterval(5 * 60 - 1)
        XCTAssertFalse(collected.isWatchBackfill)
        collected.collectedAt = collected.measuredAt.addingTimeInterval(5 * 60)
        XCTAssertTrue(collected.isWatchBackfill)
        let restored = try JSONDecoder().decode(DirectWatchReading.self, from: JSONEncoder().encode(collected))
        XCTAssertEqual(restored.collectedAt, collected.collectedAt)
        var legacyPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(collected)) as? [String: Any])
        legacyPayload.removeValue(forKey: "collectedAt") // Earlier Watch builds did not send this timestamp.
        let legacy = try JSONDecoder().decode(DirectWatchReading.self, from: JSONSerialization.data(withJSONObject: legacyPayload))
        XCTAssertNil(legacy.collectedAt)
        XCTAssertFalse(legacy.isWatchBackfill)
    }

    func testG7RequiresCodeAndASeparateSlot() {
        var g7 = DirectWatchConfiguration(transmitterID: "DXCM1234", slot: 3, isAnubis: false,
                                       sensorStartDate: start, isMgDl: true, low: 70, high: 180,
                                       family: .g7, pairingCode: "1234")
        XCTAssertTrue(g7.isValid(phoneSlot: 2))
        XCTAssertFalse(g7.isValid(phoneSlot: 3))
        g7.pairingCode = nil
        XCTAssertFalse(g7.isValid(phoneSlot: 2))
        g7.pairingCode = "12A4"
        XCTAssertFalse(g7.isValid(phoneSlot: 2))
    }

    func testExistingG6ConfigurationDecodesAsG6() throws {
        let restored = try JSONDecoder().decode(DirectWatchConfiguration.self,
                                                from: JSONEncoder().encode(configuration()))
        XCTAssertEqual(restored.transmitterFamily, .g6)
        XCTAssertNil(restored.pairingCode)
    }

    func testG7PrimaryGlucoseRejectsCachedStatusAndWrongSensorSession() {
        let receivedAt = start.addingTimeInterval(2005)
        let config = DirectWatchConfiguration(transmitterID: "DXCM1234", slot: 3, isAnubis: false,
                                          sensorStartDate: start, isMgDl: true, low: 70, high: 180,
                                          family: .g7, pairingCode: "1234")
        var packet = Data([0x4e, 0x00, 0xd5, 0x07, 0x00, 0x00, 0x09, 0x00, 0x00, 0x01,
                           0x05, 0x00, 0x61, 0x00, 0x06, 0x01, 0xff, 0xff, 0x0e])
        let reading = DexcomG7WatchProtocol.reading(packet, configuration: config, receivedAt: receivedAt)
        XCTAssertEqual(reading?.mgDl, 97)
        XCTAssertEqual(reading?.measuredAt, start.addingTimeInterval(2000))
        XCTAssertEqual(reading?.sensorStartDate, start)
        XCTAssertEqual(reading?.family, .g7)
        packet[1] = 0x80
        XCTAssertNil(DexcomG7WatchProtocol.reading(packet, configuration: config, receivedAt: receivedAt))
        packet[1] = 0
        packet[14] = 0x12
        XCTAssertNil(DexcomG7WatchProtocol.reading(packet, configuration: config, receivedAt: receivedAt))
        packet[14] = 6
        var wrongSession = config
        wrongSession.sensorStartDate = start.addingTimeInterval(3600)
        XCTAssertNil(DexcomG7WatchProtocol.reading(packet, configuration: wrongSession, receivedAt: receivedAt))
    }

    func testLegacyMessagesRemainUsableWhileDevicesUpdateSeparately() {
        let payload: [String: Any] = ["g6WatchRevision": 1.0, "directWatchRevision": 2.0,
                                      "g6WatchEnabled": true, "requestWatchUpdate": "bgReadings"]
        let normalized = DirectWatchCompatibility.normalized(payload)
        XCTAssertEqual(normalized["directWatchRevision"] as? Double, 2)
        XCTAssertEqual(normalized["directWatchEnabled"] as? Bool, true)
        XCTAssertEqual(normalized["requestWatchUpdate"] as? String, "bgReadings")

        let readings = Data([1, 2, 3])
        let outgoing = DirectWatchCompatibility.outgoing(["directWatchReadings": readings])
        XCTAssertEqual(outgoing["directWatchReadings"] as? Data, readings)
        XCTAssertEqual(outgoing["g6WatchReadings"] as? Data, readings)
        XCTAssertEqual(DirectWatchCompatibility.normalized(["g6WatchAcknowledged": ["sample"]])["directWatchAcknowledged"] as? [String], ["sample"])
    }

    func testSettingsMigrationKeepsConfigurationAndDoesNotRestoreRemovedSetup() throws {
        let suite = "DirectWatchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let data = try JSONEncoder().encode(configuration(slot: 3, anubis: true))
        defaults.set(data, forKey: "g6Watch.configuration.v1")
        defaults.set("8ABCDE", forKey: "g6Watch.pausedPhoneTransmitter")
        defaults.set(12.0, forKey: "g6Watch.configurationRevision")
        defaults.set(start, forKey: "g6Watch.lastCollectedDate")
        defaults.set(start.addingTimeInterval(60), forKey: DirectWatchSettings.lastCollectedDateKey)

        DirectWatchCompatibility.migrateSettings(in: defaults)
        XCTAssertEqual(defaults.data(forKey: DirectWatchSettings.configurationKey), data)
        XCTAssertEqual(defaults.string(forKey: DirectWatchSettings.pausedKey), "8ABCDE")
        XCTAssertEqual(defaults.double(forKey: DirectWatchSettings.revisionKey), 12)
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.lastCollectedDateKey) as? Date, start.addingTimeInterval(60))
        defaults.removeObject(forKey: DirectWatchSettings.configurationKey)
        DirectWatchCompatibility.migrateSettings(in: defaults)
        XCTAssertNil(defaults.object(forKey: DirectWatchSettings.configurationKey))
    }

    func testFileMigrationPreservesPendingReadingsAndExistingCurrentStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pending = try JSONEncoder().encode([reading()])
        let legacy = directory.appendingPathComponent("G6WatchCollector.json")
        try pending.write(to: legacy)
        let migrated = DirectWatchCompatibility.collectorStoreURL(in: directory)
        XCTAssertEqual(migrated.lastPathComponent, "DirectWatchCollector.json")
        XCTAssertEqual(try Data(contentsOf: migrated), pending)
        XCTAssertEqual(try Data(contentsOf: legacy), pending)
        let current = try JSONEncoder().encode([reading(seconds: 4900)])
        try current.write(to: migrated)
        XCTAssertEqual(try Data(contentsOf: DirectWatchCompatibility.collectorStoreURL(in: directory)), current)
    }

    func testDelayedBatchCannotMoveLatestWatchReadingBackwards() throws {
        let suite = "DirectWatchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let newer = start.addingTimeInterval(600)
        DirectWatchSettings.recordContact(latestReadingAt: newer, now: newer, in: defaults)
        DirectWatchSettings.recordContact(latestReadingAt: start, now: newer.addingTimeInterval(60), in: defaults)
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.lastCollectedDateKey) as? Date, newer)
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.lastContactDateKey) as? Date, newer.addingTimeInterval(60))
        DirectWatchSettings.recordContact(latestReadingAt: newer.addingTimeInterval(3600), now: newer, in: defaults)
        XCTAssertEqual(defaults.object(forKey: DirectWatchSettings.lastCollectedDateKey) as? Date, newer)
    }


    func testBluetoothIdentityIsIndependentOfSensorAndDisplayConfiguration() {
        let original = configuration(slot: 3, anubis: true)
        var updated = original
        updated.sensorStartDate = start.addingTimeInterval(3600)
        updated.low = 80
        updated.isMgDl = false
        XCTAssertEqual(updated.connectionIdentity, original.connectionIdentity)
        updated = configuration(slot: 1, anubis: true)
        XCTAssertNotEqual(updated.connectionIdentity, original.connectionIdentity)
        updated = original
        updated.family = .g7
        XCTAssertNotEqual(updated.connectionIdentity, original.connectionIdentity)
    }


    func testExistingGlucoseStoresMigrateWithOriginsAndValuesPreserved() throws {
        for sourceVersion in ["32", "33 Watch", "34", "35"] {
            let modelDirectory = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
            let oldModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v\(sourceVersion).mom")))
            let currentModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v36.mom")))
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("Readings.sqlite")

            let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
            let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
            let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            oldContext.persistentStoreCoordinator = oldCoordinator
            try oldContext.performAndWait {
                let value = NSEntityDescription.insertNewObject(forEntityName: "BgReading", into: oldContext)
                value.setValue("existing-reading", forKey: "id")
                value.setValue(start, forKey: "timeStamp")
                value.setValue(false, forKey: "calibrationFlag")
                value.setValue(false, forKey: "hideSlope")
                value.setValue(100.0, forKey: "calculatedValue")
                if sourceVersion != "32" {
                    value.setValue(true, forKey: "valueIsFromWatch")
                    value.setValue(start.addingTimeInterval(10), forKey: "watchReceivedAt")
                    if ["34", "35"].contains(sourceVersion) { value.setValue(start.addingTimeInterval(5), forKey: "watchCollectedAt") }
                }
                try oldContext.save()
            }
            try oldCoordinator.remove(oldStore)

            let currentCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
            let currentStore = try currentCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
                options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
            defer { try? currentCoordinator.remove(currentStore) }
            let currentContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            currentContext.persistentStoreCoordinator = currentCoordinator
            try currentContext.performAndWait {
                let values = try currentContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "BgReading"))
                let value = try XCTUnwrap(values.first)
                XCTAssertEqual(values.count, 1)
                XCTAssertEqual(value.value(forKey: "id") as? String, "existing-reading")
                XCTAssertEqual(value.value(forKey: "calculatedValue") as? Double, 100)
                XCTAssertEqual(value.value(forKey: "valueIsFromWatch") as? Bool, sourceVersion != "32")
                XCTAssertEqual(value.value(forKey: "watchReceivedAt") as? Date, sourceVersion != "32" ? start.addingTimeInterval(10) : nil)
                XCTAssertEqual(value.value(forKey: "watchCollectedAt") as? Date, ["34", "35"].contains(sourceVersion) ? start.addingTimeInterval(5) : nil)
            }
        }
    }


    func testConfigurationRevisionsStayOrderedWhenTheClockMovesBackwards() throws {
        let suite = "DirectWatchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(start.timeIntervalSince1970 + 1000, forKey: "g6Watch.configurationRevision")
        DirectWatchSettings.advanceRevision(now: start, in: defaults)
        let first = defaults.double(forKey: DirectWatchSettings.revisionKey)
        XCTAssertEqual(first, start.timeIntervalSince1970 + 1001)
        DirectWatchSettings.advanceRevision(now: start.addingTimeInterval(-3600), in: defaults)
        XCTAssertEqual(defaults.double(forKey: DirectWatchSettings.revisionKey), first + 1)
    }

}
