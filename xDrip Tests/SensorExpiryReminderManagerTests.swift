import UserNotifications
import XCTest
@testable import xdrip

/// Tests expiry dates, saved reminder state and cancellation.
@MainActor
final class SensorExpiryReminderManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var scheduler: ExpirySchedulerSpy!
    private var referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "SensorExpiryReminderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        scheduler = ExpirySchedulerSpy()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeManager() -> SensorExpiryReminderManager {
        SensorExpiryReminderManager(userDefaults: defaults, notificationScheduler: scheduler, now: { self.referenceDate })
    }

    private func snapshot(id: String = "sensor-A", days: Double = 10.5, start: Date? = nil, source: String = "direct:G7") -> SensorExpirySnapshot {
        SensorExpirySnapshot(source: source, sessionID: id, startDate: start ?? referenceDate, lifetimeDays: days)
    }

    private func configurations(enabled: Bool = true, hours: Int = 24, sound: String? = nil) -> [SensorExpiryReminderConfiguration] {
        [SensorExpiryReminderConfiguration(kind: .sensorEndingSoon, enabled: enabled, hoursBefore: hours, soundName: sound),
         SensorExpiryReminderConfiguration(kind: .sensorExpectedExpiry, enabled: enabled, hoursBefore: 0, soundName: sound)]
    }

    private func apply(_ manager: SensorExpiryReminderManager, _ snapshot: SensorExpirySnapshot?, enabled: Bool = true, hours: Int = 24, sound: String? = nil) async {
        manager.reconcile(snapshot: snapshot, configurations: configurations(enabled: enabled, hours: hours, sound: sound), force: true)
        await manager.waitForReconciliation()
    }

    private var deadlines: [Date] {
        scheduler.requests.values.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.sorted()
    }

    func testDefaultsAndWholeHourValidationPreserveRawValues() {
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.rawValue, 13)
        XCTAssertEqual(AlertKind.sensorEndingSoon.rawValue, 14)
        XCTAssertEqual(AlertKind.sensorExpectedExpiry.rawValue, 15)
        XCTAssertEqual(AlertKind.sensorEndingSoon.defaultAlertValue(), 24)
        for kind in [AlertKind.sensorEndingSoon, .sensorExpectedExpiry] {
            XCTAssertTrue(kind.defaultIsDisabled())
            XCTAssertFalse(kind.supportsAlertSchedules())
            XCTAssertFalse(kind.supportsSnooze())
        }
        XCTAssertTrue(AlertKind.sensorEndingSoon.needsAlertValue())
        XCTAssertFalse(AlertKind.sensorExpectedExpiry.needsAlertValue())
        for value in [0.0, -1, 1.5, 48.1, 49, Double.infinity, Double.nan] {
            XCTAssertNil(AlertKind.sensorEndingSoon.storedAlertValue(fromDisplayedValue: value))
        }
        XCTAssertEqual(AlertKind.sensorEndingSoon.storedAlertValue(fromDisplayedValue: 1), 1)
        XCTAssertEqual(AlertKind.sensorEndingSoon.storedAlertValue(fromDisplayedValue: 48), 48)
    }

    func testG7GracePeriodAndNonRepeatingUTCTriggers() async {
        let manager = makeManager()
        await apply(manager, snapshot())
        XCTAssertEqual(deadlines, [referenceDate.addingTimeInterval(9.5 * 86400), referenceDate.addingTimeInterval(10.5 * 86400)])
        XCTAssertTrue(scheduler.requests.values.allSatisfy { $0.trigger?.repeats == false })
        XCTAssertTrue(scheduler.requests.values.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.timeZone?.secondsFromGMT() == 0 })
        XCTAssertTrue(scheduler.requests.values.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.calendar?.identifier == .gregorian })
        XCTAssertTrue(scheduler.requests.keys.allSatisfy { !$0.contains("sensor-A") })
    }

    func testLifetimeOverridesLibreLinkUpAndLongerG7() async {
        for (source, days) in [("direct:Anubis", 30.0), ("libreLinkUp:account", 14.0), ("libreLinkUpRussia:account", 15.0), ("direct:G7", 15.5)] {
            let manager = makeManager()
            await apply(manager, snapshot(id: source, days: days, source: source), hours: 48)
            XCTAssertEqual(deadlines, [referenceDate.addingTimeInterval(days * 86400 - 48 * 3600), referenceDate.addingTimeInterval(days * 86400)])
        }
    }

    func testDisabledDefaultsAndUnknownLifetimeDoNotSchedule() async {
        let manager = makeManager()
        await apply(manager, snapshot(), enabled: false)
        XCTAssertTrue(scheduler.requests.isEmpty)
        for days in [0, -1, Double.nan, Double.infinity] {
            await apply(manager, snapshot(days: days))
            XCTAssertTrue(scheduler.requests.isEmpty)
        }
        XCTAssertNil(SensorExpirySnapshot.expiryDate(startDate: nil, lifetimeDays: 14))
    }

    func testLateEnableSchedulesOnlyFutureExpiryAndNothingAfterExpiry() async {
        let manager = makeManager()
        await apply(manager, snapshot(days: 0.5))
        XCTAssertEqual(deadlines, [referenceDate.addingTimeInterval(12 * 3600)])
        await apply(manager, snapshot(days: 1, start: referenceDate.addingTimeInterval(-2 * 86400)))
        XCTAssertTrue(scheduler.requests.isEmpty)
    }

    func testExactWarningBoundaryIsSkipped() async {
        let manager = makeManager()
        await apply(manager, snapshot(days: 1))
        XCTAssertEqual(scheduler.requests.count, 1)
        XCTAssertEqual(deadlines, [referenceDate.addingTimeInterval(86400)])
    }

    func testRepeatedUpdatesAndRestartKeepSameTwoRequests() async {
        let sensor = snapshot()
        var manager = makeManager()
        await apply(manager, sensor)
        let identifiers = Set(scheduler.requests.keys)
        await apply(manager, sensor)
        manager = makeManager()
        await apply(manager, sensor)
        XCTAssertEqual(Set(scheduler.requests.keys), identifiers)
        XCTAssertEqual(scheduler.addCount, 2)
        XCTAssertEqual(manager.snapshot, sensor)
    }

    func testFutureStartAndLifetimeCorrectionsReplaceRequests() async {
        let manager = makeManager()
        await apply(manager, snapshot())
        let identifiers = Set(scheduler.requests.keys)
        let correctedStart = referenceDate.addingTimeInterval(3600)
        await apply(manager, snapshot(days: 15.5, start: correctedStart))
        XCTAssertEqual(Set(scheduler.requests.keys), identifiers)
        XCTAssertEqual(deadlines, [correctedStart.addingTimeInterval(14.5 * 86400), correctedStart.addingTimeInterval(15.5 * 86400)])
    }

    func testPassedRemindersNeverReplayAfterRestartAndExpiryExtension() async {
        let sensor = snapshot(days: 2)
        var manager = makeManager()
        await apply(manager, sensor)
        referenceDate = referenceDate.addingTimeInterval(3 * 86400)
        scheduler.requests.removeAll() // Simulate dismissed notifications.
        manager = makeManager()
        await apply(manager, SensorExpirySnapshot(source: sensor.source, sessionID: sensor.sessionID, startDate: sensor.startDate, lifetimeDays: 10))
        XCTAssertTrue(scheduler.requests.isEmpty)
        await apply(manager, sensor, enabled: false)
        await apply(manager, snapshot(start: sensor.startDate))
        XCTAssertTrue(scheduler.requests.isEmpty)
    }

    func testDisableReenableBeforeDeadlineAndSoundEdits() async {
        let manager = makeManager()
        let sensor = snapshot()
        await apply(manager, sensor)
        await apply(manager, sensor, enabled: false)
        XCTAssertTrue(scheduler.requests.isEmpty)
        await apply(manager, sensor, sound: "")
        XCTAssertEqual(scheduler.requests.count, 2)
        XCTAssertTrue(scheduler.requests.values.allSatisfy { $0.content.sound == nil })
        await apply(manager, sensor, sound: "xdripalert.aif")
        XCTAssertTrue(scheduler.requests.values.allSatisfy { $0.content.sound != nil && $0.content.categoryIdentifier.isEmpty })
        XCTAssertEqual(scheduler.addCount, 6)
    }

    func testStopReplacementAndSourceSwitchCancelOnlyOwnedRequests() async {
        let manager = makeManager()
        await apply(manager, snapshot())
        let oldIDs = Set(scheduler.requests.keys)
        await apply(manager, snapshot(id: "sensor-B"))
        XCTAssertEqual(scheduler.requests.count, 2)
        XCTAssertTrue(oldIDs.isDisjoint(with: scheduler.requests.keys))
        XCTAssertTrue(oldIDs.isSubset(of: scheduler.removedDelivered))
        await apply(manager, snapshot(id: "patient|serial", source: "libreLinkUp:account"))
        XCTAssertEqual(scheduler.requests.count, 2)
        await apply(manager, nil)
        XCTAssertTrue(scheduler.requests.isEmpty)
    }

    func testFutureWarningMovedIntoPastCancelsOldRequestWithoutCatchup() async {
        let manager = makeManager()
        let sensor = snapshot(days: 1.5)
        await apply(manager, sensor, hours: 1)
        await apply(manager, sensor, hours: 48)
        XCTAssertEqual(deadlines, [referenceDate.addingTimeInterval(1.5 * 86400)])
    }

    func testMissingOSRequestsAreRestoredAndSchedulingFailureIsRetryable() async {
        let manager = makeManager()
        let sensor = snapshot()
        scheduler.failAdds = true
        await apply(manager, sensor)
        XCTAssertTrue(scheduler.requests.isEmpty)
        scheduler.failAdds = false
        await apply(manager, sensor)
        XCTAssertEqual(scheduler.requests.count, 2)
        scheduler.requests.removeAll()
        await apply(manager, sensor)
        XCTAssertEqual(scheduler.requests.count, 2)
    }

    func testInterruptedAcceptanceReusesPersistedIdentifiersOnRestart() async {
        let sensor = snapshot()
        var manager = makeManager()
        scheduler.failAfterAccept = true
        await apply(manager, sensor)
        let identifiers = Set(scheduler.requests.keys)
        scheduler.failAfterAccept = false
        manager = makeManager()
        await apply(manager, sensor)
        XCTAssertEqual(Set(scheduler.requests.keys), identifiers)
        XCTAssertEqual(scheduler.addCount, 2)
    }

    func testSessionChangeDuringSchedulingRemovesStaleRequest() async {
        let manager = makeManager()
        let replacement = snapshot(id: "sensor-B")
        scheduler.onAdd = {
            self.scheduler.onAdd = nil
            manager.reconcile(snapshot: replacement, configurations: self.configurations())
        }
        await apply(manager, snapshot())
        XCTAssertEqual(manager.snapshot, replacement)
        XCTAssertEqual(scheduler.requests.count, 2)
        XCTAssertEqual(scheduler.addCount, 3)
    }

    func testStaleAcceptanceAfterDeadlineCannotReplayAnAlreadyDueWarning() async {
        let manager = makeManager()
        let sensor = snapshot(days: 2)
        scheduler.onAdd = {
            self.scheduler.onAdd = nil
            self.referenceDate = sensor.startDate.addingTimeInterval(86400 + 1)
            manager.reconcile(snapshot: self.snapshot(days: 10, start: sensor.startDate), configurations: self.configurations())
        }
        await apply(manager, sensor)
        XCTAssertEqual(scheduler.requests.count, 1)
        XCTAssertEqual(deadlines, [sensor.startDate.addingTimeInterval(10 * 86400)])
    }

    func testRestoredSnapshotSurvivesTransientDisplayCacheClearing() async {
        let manager = makeManager()
        let sensor = snapshot()
        await apply(manager, sensor)
        defaults.activeSensorStartDate = nil
        let restored = makeManager()
        XCTAssertEqual(restored.snapshot, sensor)
        await apply(restored, restored.snapshot)
        XCTAssertEqual(scheduler.addCount, 2)
    }

    func testSourceEligibilityAndLogoutCannotBorrowOldMetadata() {
        defaults.isMaster = false
        defaults.followerDataSourceType = .nightscout
        XCTAssertNil(SensorExpirySnapshot.currentSource(defaults: defaults))
        defaults.followerDataSourceType = .libreLinkUp
        defaults.libreLinkUpEmail = "first@example.com"
        let first = SensorExpirySnapshot.currentSource(defaults: defaults)
        XCTAssertNotNil(first)
        defaults.libreLinkUpEmail = "second@example.com"
        XCTAssertNotEqual(first, SensorExpirySnapshot.currentSource(defaults: defaults))
        defaults.libreLinkUpManuallyLoggedOut = true
        XCTAssertNil(SensorExpirySnapshot.currentSource(defaults: defaults))
    }

    func testAlertEntryDefaultsAndEditorRows() {
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entries = AlertEntriesAccessor(coreDataManager: core)
        let types = AlertTypesAccessor(coreDataManager: core)
        for kind in [AlertKind.sensorEndingSoon, .sensorExpectedExpiry] {
            let entry = entries.getAllEntries(forAlertKind: kind, alertTypesAccessor: types)[0]
            XCTAssertTrue(entry.isDisabled)
            XCTAssertEqual(Int(entry.value), kind.defaultAlertValue())
            entry.isDisabled = false
            let editor = AlertEntryEditorViewModel(mode: .edit(alertEntry: entry, minimumStart: 0, maximumStart: 1439), coreDataManager: core, close: {})
            XCTAssertFalse(editor.rows.contains(.start))
            XCTAssertEqual(editor.rows.contains(.value), kind == .sensorEndingSoon)
            XCTAssertFalse(editor.canAdd)
            XCTAssertFalse(editor.canDelete)
        }
    }

    func testOrdinaryReconciliationDoesNotPollNotificationCenterForUnchangedInputs() async {
        let manager = makeManager()
        let sensor = snapshot()
        await apply(manager, sensor)
        let reads = scheduler.pendingReadCount
        manager.reconcile(snapshot: sensor, configurations: configurations())
        await manager.waitForReconciliation()
        XCTAssertEqual(scheduler.pendingReadCount, reads)
    }

    func testSnoozeAllDoesNotAffectScheduling() async {
        defaults.snoozeAllAlertsUntilDate = referenceDate.addingTimeInterval(30 * 86400)
        let manager = makeManager()
        await apply(manager, snapshot())
        XCTAssertEqual(scheduler.requests.count, 2)
    }
}

@MainActor
private final class ExpirySchedulerSpy: SensorExpiryNotificationScheduling {
    var requests = [String: UNNotificationRequest]()
    var removedDelivered = Set<String>()
    var addCount = 0
    var pendingReadCount = 0
    var failAdds = false
    var failAfterAccept = false
    var onAdd: (() -> Void)?

    func pendingRequests() async -> [UNNotificationRequest] {
        pendingReadCount += 1
        return Array(requests.values)
    }

    func add(_ request: UNNotificationRequest) async throws {
        if failAdds { throw NSError(domain: "ExpirySchedulerTests", code: 1) }
        addCount += 1
        requests[request.identifier] = request
        onAdd?()
        if failAfterAccept { throw NSError(domain: "ExpirySchedulerTests", code: 2) }
    }

    func remove(identifiers: [String], delivered: Bool) {
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
        if delivered { removedDelivered.formUnion(identifiers) }
    }
}
