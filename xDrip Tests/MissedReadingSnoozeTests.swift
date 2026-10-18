import XCTest
import UserNotifications
@testable import xdrip

final class MissedReadingSnoozeTests: XCTestCase {
    private var center: MissedReadingNotificationCenter!

    override func setUp() async throws {
        try await super.setUp()
        center = MissedReadingNotificationCenter()
    }

    @MainActor func testPreSnoozeReplacesExistingNotificationWhileReadingsAreMissing() async throws {
        let (core, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        let content = UNMutableNotificationContent()
        content.title = "Previous missed reading alert"
        try await self.center!.add(UNNotificationRequest(
            identifier: AlertKind.missedreading.notificationIdentifier(),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        ))

        let picker = manager.createPickerViewData(forAlertKind: .missedreading, content: nil, actionHandler: nil, cancelHandler: nil)
        picker.actionHandler(try XCTUnwrap(ConstantsAlerts.snoozeValueMinutes.firstIndex(of: 120)))

        let trigger = try await missedReadingTrigger()
        XCTAssertEqual(trigger.timeInterval, 7200, accuracy: 2)
        XCTAssertTrue(trigger.repeats)
        XCTAssertTrue(manager.getSnoozeParameters(alertKind: .missedreading).getSnoozeValue().isSnoozed)
        withExtendedLifetime(core) {}
    }

    @MainActor func testSnoozeStateSurvivesRebuildingAfterANewReading() async throws {
        let (_, manager, reading) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        let parameters = manager.getSnoozeParameters(alertKind: .missedreading)
        XCTAssertEqual(parameters.snoozePeriodInMinutes, 120)
        XCTAssertNotNil(parameters.snoozeTimeStamp)

        reading.timeStamp = Date()
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)

        let trigger = try await missedReadingTrigger()
        XCTAssertEqual(trigger.timeInterval, 7200, accuracy: 2)
        XCTAssertTrue(parameters.getSnoozeValue().isSnoozed)
    }

    @MainActor func testStaleReadingCheckPreservesSnoozedNotification() async throws {
        let (_, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        let before = try await missedReadingTrigger()
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)
        let after = try await missedReadingTrigger()
        XCTAssertEqual(after.timeInterval, before.timeInterval)
        XCTAssertTrue(after.repeats)
    }

    @MainActor func testSnoozeAllStillCancelsPendingAlertWithAStaleReading() async throws {
        let (_, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        _ = try await missedReadingTrigger()
        UserDefaults.standard.snoozeAllAlertsUntilDate = Date().addingTimeInterval(3600)
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)
        let requests = await self.center!.pendingNotificationRequests()
        XCTAssertFalse(requests.contains { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
    }

    @MainActor func testUnsnoozeReplacesOverdueNotificationWithValidRepeatingTrigger() async throws {
        let (_, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        _ = try await missedReadingTrigger()
        manager.unSnooze(alertKind: .missedreading)
        let trigger = try await missedReadingTrigger()
        XCTAssertEqual(trigger.timeInterval, 60)
        XCTAssertTrue(trigger.repeats)
        XCTAssertFalse(manager.getSnoozeParameters(alertKind: .missedreading).getSnoozeValue().isSnoozed)
    }

    @MainActor func testExpiredSnoozeUsesNormalScheduleAfterANewReading() async throws {
        let (_, manager, reading) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        _ = try await missedReadingTrigger()
        manager.getSnoozeParameters(alertKind: .missedreading).snoozeTimeStamp = Date().addingTimeInterval(-121 * 60)
        reading.timeStamp = Date()
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)
        let trigger = try await missedReadingTrigger()
        XCTAssertEqual(trigger.timeInterval, 30 * 60)
        XCTAssertFalse(manager.getSnoozeParameters(alertKind: .missedreading).getSnoozeValue().isSnoozed)
    }

    @MainActor func testDisablingMissedReadingAlertClearsItsSnoozedNotification() async throws {
        let (core, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        _ = try await missedReadingTrigger()
        let entries = AlertEntriesAccessor(coreDataManager: core).getAllEntries(forAlertKind: .missedreading, alertTypesAccessor: AlertTypesAccessor(coreDataManager: core))
        entries.first?.isDisabled = true
        manager.unSnooze(alertKind: .missedreading)
        let requests = await self.center!.pendingNotificationRequests()
        XCTAssertFalse(requests.contains { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
    }

    @MainActor func testFreshReadingKeepsScheduledSensorExpiryReminders() async throws {
        let (_, manager, _) = makeManager(readingAge: 0)
        defer { clearNotifications() }
        let reminderIDs = try await scheduleSensorExpiryReminders()

        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)

        let pending = await self.center!.pendingNotificationRequests()
        XCTAssertTrue(reminderIDs.isSubset(of: Set(pending.map(\.identifier))))
        XCTAssertTrue(pending.contains { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
    }

    @MainActor func testSnoozeAllWithFreshReadingKeepsScheduledSensorExpiryReminders() async throws {
        try await checkSnoozeAllKeepsSensorExpiryReminders(readingAge: 0)
    }

    @MainActor func testSnoozeAllWithStaleReadingKeepsScheduledSensorExpiryReminders() async throws {
        try await checkSnoozeAllKeepsSensorExpiryReminders(readingAge: 35 * 60)
    }

    @MainActor private func checkSnoozeAllKeepsSensorExpiryReminders(readingAge: TimeInterval) async throws {
        let (_, manager, _) = makeManager(readingAge: readingAge)
        defer { clearNotifications() }
        manager.snooze(alertKind: .missedreading, snoozePeriodInMinutes: 120, response: nil)
        _ = try await missedReadingTrigger()
        let reminderIDs = try await scheduleSensorExpiryReminders()
        UserDefaults.standard.snoozeAllAlertsUntilDate = Date().addingTimeInterval(3600)

        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)

        let pending = await self.center!.pendingNotificationRequests()
        XCTAssertTrue(reminderIDs.isSubset(of: Set(pending.map(\.identifier))))
        XCTAssertFalse(pending.contains { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
    }

    @MainActor private func scheduleSensorExpiryReminders() async throws -> Set<String> {
        let suite = "ExpiryCleanupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let center = self.center!
        let existingIDs = Set(await center.pendingNotificationRequests().map(\.identifier))
        let reminders = SensorExpiryReminderManager(userDefaults: defaults, notificationScheduler: ExpiryCleanupScheduler(center: center))
        let sensor = SensorExpirySnapshot(source: "test", sessionID: UUID().uuidString, startDate: Date(), lifetimeDays: 2)
        reminders.reconcile(snapshot: sensor, configurations: [
            SensorExpiryReminderConfiguration(kind: .sensorEndingSoon, enabled: true, hoursBefore: 1, soundName: ""),
            SensorExpiryReminderConfiguration(kind: .sensorExpectedExpiry, enabled: true, hoursBefore: 0, soundName: "")
        ])
        await reminders.waitForReconciliation()
        let pending = await center.pendingNotificationRequests()
        let reminderIDs = Set(pending.map(\.identifier)).subtracting(existingIDs)
            .filter { $0.hasPrefix(SensorExpiryReminderManager.notificationPrefix) }
        addTeardownBlock {
            center.removePendingNotificationRequests(withIdentifiers: Array(reminderIDs))
            defaults.removePersistentDomain(forName: suite)
        }
        XCTAssertEqual(reminderIDs.count, 2)
        return reminderIDs
    }

    @MainActor private func makeManager(readingAge: TimeInterval) -> (CoreDataManager, AlertManager, BgReading) {
        // Keep these integration tests independent of the simulator app's saved alert settings.
        let keys = [UserDefaults.Key.isMaster.rawValue, UserDefaults.Key.snoozeAllAlertsUntilDate.rawValue]
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        addTeardownBlock {
            for (key, value) in zip(keys, saved) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        UserDefaults.standard.isMaster = true
        UserDefaults.standard.snoozeAllAlertsUntilDate = nil
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let types = AlertTypesAccessor(coreDataManager: core)
        let entries = AlertEntriesAccessor(coreDataManager: core).getAllEntries(forAlertKind: nil, alertTypesAccessor: types)
        for entry in entries {
            entry.isDisabled = entry.alertkind != AlertKind.missedreading.rawValue
        }
        let missedReading = entries.first { $0.alertkind == AlertKind.missedreading.rawValue }!
        missedReading.value = 30
        missedReading.alertType.enabled = true
        missedReading.alertType.soundname = ""
        let reading = BgReading(timeStamp: Date().addingTimeInterval(-readingAge), sensor: nil, calibration: nil, rawData: 120, deviceName: nil, nsManagedObjectContext: core.mainManagedObjectContext)
        reading.calculatedValue = 120
        return (core, AlertManager(coreDataManager: core, soundPlayer: nil, notificationCenter: center), reading)
    }

    private func missedReadingTrigger() async throws -> UNTimeIntervalNotificationTrigger {
        let requests = await self.center!.pendingNotificationRequests()
        let request = try XCTUnwrap(requests.first { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
        return try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
    }

    private func clearNotifications() {
        self.center!.removePendingNotificationRequests(withIdentifiers: [AlertKind.missedreading.notificationIdentifier()])
    }
}

/// Records notification changes without requiring simulator notification permission.
private final class MissedReadingNotificationCenter: AlertNotificationScheduling {
    private var requests = [String: UNNotificationRequest]()

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        requests[request.identifier] = request
        completionHandler?(nil)
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests[request.identifier] = request
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requests.values)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
    }
}

@MainActor
private struct ExpiryCleanupScheduler: SensorExpiryNotificationScheduling {
    let center: MissedReadingNotificationCenter

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func remove(identifiers: [String], delivered: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
