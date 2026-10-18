import XCTest
import UserNotifications
@testable import xdrip

final class MissedReadingSnoozeTests: XCTestCase {
    @MainActor func testPreSnoozeReplacesExistingNotificationWhileReadingsAreMissing() async throws {
        let (core, manager, _) = makeManager(readingAge: 35 * 60)
        defer { clearNotifications() }
        let content = UNMutableNotificationContent()
        content.title = "Previous missed reading alert"
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(
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
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
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
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        XCTAssertFalse(requests.contains { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
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
        return (core, AlertManager(coreDataManager: core, soundPlayer: nil), reading)
    }

    private func missedReadingTrigger() async throws -> UNTimeIntervalNotificationTrigger {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let request = try XCTUnwrap(requests.first { $0.identifier == AlertKind.missedreading.notificationIdentifier() })
        return try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
    }

    private func clearNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [AlertKind.missedreading.notificationIdentifier()])
    }
}
