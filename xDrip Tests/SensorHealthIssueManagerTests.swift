//
//  SensorHealthIssueManagerTests.swift
//  xdripTests
//
//  Created by Paul Plant on 2/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import UserNotifications
import XCTest
@testable import xdrip

/// Covers sensor-health episode persistence, escalation, notification and recovery rules.
final class SensorHealthIssueManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var notificationCenter: NotificationCenterSpy!
    private var suiteName: String!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "SensorHealthIssueManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        notificationCenter = NotificationCenterSpy()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        notificationCenter = nil
        suiteName = nil
        super.tearDown()
    }

    func testTemporaryStatusRecoversBeforeThreeHours() {
        let manager = makeManager()

        manager.report(
            .temporary(source: .dexcom, reason: .dexcomTemporarySensorIssue),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )
        manager.report(
            .recovered(source: .dexcom),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.hours(2.9))
        )
        manager.report(
            .temporary(source: .dexcom, reason: .dexcomTemporarySensorIssue),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.hours(3))
        )

        XCTAssertNil(manager.visibleIssue)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testManufacturerStatusMappings() {
        XCTAssertEqual(
            DexcomAlgorithmState.excessNoise.sensorHealthEvent,
            .temporary(source: .dexcom, reason: .dexcomExcessNoise)
        )
        XCTAssertEqual(
            DexcomAlgorithmState.SessionFailedDueToTransmitterError.sensorHealthEvent,
            .terminal(source: .dexcom, reason: .dexcomTransmitterFailure)
        )
        XCTAssertEqual(
            DexcomAlgorithmState.sensorFailed.sensorHealthEvent,
            .terminal(source: .dexcom, reason: .dexcomSensorFailure)
        )
        XCTAssertEqual(DexcomAlgorithmState.SensorWarmup.sensorHealthEvent, .recovered(source: .dexcom))
        XCTAssertEqual(
            LibreSensorState.failure.sensorHealthEvent,
            .terminal(source: .libre, reason: .libreSensorFailure)
        )
        XCTAssertEqual(LibreSensorState.ready.sensorHealthEvent, .recovered(source: .libre))
        XCTAssertNil(LibreSensorState.starting.sensorHealthEvent)
        XCTAssertNil(LibreSensorState.shutdown.sensorHealthEvent)
    }

    func testTemporaryStatusTriggersAtThreeHours() {
        let manager = makeManager()
        let event = CGMSensorHealthEvent.temporary(source: .dexcom, reason: .dexcomExcessNoise)

        manager.report(event, sensorID: "A", sensorStartDate: start, now: start)
        manager.report(event, sensorID: "A", sensorStartDate: start, now: start.addingTimeInterval(.hours(3)))

        XCTAssertEqual(manager.visibleIssue?.kind, .temporaryTransmitterIssue)
        XCTAssertEqual(notificationCenter.requests.count, 1)
        XCTAssertNil(notificationCenter.requests.first?.content.sound)
    }

    func testTerminalFailureEscalatesAndUsesOneOffAlarmEntryPoint() {
        let manager = makeManager()
        let alarm = OneOffAlarmSpy()
        manager.configure(oneOffAlarmRaiser: alarm)

        manager.report(
            .temporary(source: .dexcom, reason: .dexcomExcessNoise),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )
        manager.report(
            .temporary(source: .dexcom, reason: .dexcomExcessNoise),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.hours(3))
        )
        manager.report(
            .terminal(source: .dexcom, reason: .dexcomSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.hours(3.1))
        )

        XCTAssertEqual(manager.visibleIssue?.severity, .terminal)
        XCTAssertEqual(alarm.issues.count, 1)
        XCTAssertEqual(
            notificationCenter.requests.count,
            1,
            "Only the earlier silent episode should bypass AlertManager"
        )
    }

    func testTerminalFailureNeverBypassesConfiguredAlarmEntryPoint() {
        let manager = makeManager()
        manager.report(
            .terminal(source: .libre, reason: .libreSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )

        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testWarningNotificationPreferenceDoesNotHideBanner() {
        defaults.sensorHealthNotificationsEnabled = false
        let manager = makeManager()

        manager.report(
            .temporary(source: .dexcom, reason: .dexcomTemporarySensorIssue),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )
        manager.report(
            .temporary(source: .dexcom, reason: .dexcomTemporarySensorIssue),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.hours(3))
        )

        XCTAssertNotNil(manager.visibleIssue)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testTerminalAlarmIsIndependentOfWarningNotificationPreference() {
        defaults.sensorHealthNotificationsEnabled = false
        let manager = makeManager()
        let alarm = OneOffAlarmSpy()
        manager.configure(oneOffAlarmRaiser: alarm)

        manager.report(
            .terminal(source: .libre, reason: .libreSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )

        XCTAssertEqual(alarm.issues.count, 1)
        XCTAssertNotNil(manager.visibleIssue)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testSensorTransmitterFailureAlarmHasNoValueScheduleOrSnooze() {
        let alertKind = AlertKind.sensorTransmitterFailure

        XCTAssertEqual(alertKind.rawValue, 11)
        XCTAssertEqual(alertKind.alertTitle(), "Sensor/Transmitter Failure")
        XCTAssertFalse(alertKind.needsAlertValue())
        XCTAssertFalse(alertKind.needsAlertTriggerValue())
        XCTAssertFalse(alertKind.supportsAlertSchedules())
        XCTAssertFalse(alertKind.supportsSnooze())
    }

    @MainActor func testSensorHealthNotificationRequestsHomeWithoutDetailNavigation() {
        let stateModel = RootTabStateModel()

        XCTAssertEqual(stateModel.sensorHealthHomeRequest, 0)
        stateModel.showHomeForSensorHealthNotification()
        XCTAssertEqual(stateModel.sensorHealthHomeRequest, 1)
    }

    func testMultipleSyntheticTerminalAlarmsCanBeQueuedIndependently() {
        let manager = makeManager()
        let alarm = OneOffAlarmSpy()
        manager.configure(oneOffAlarmRaiser: alarm)
        let fired = expectation(description: "queued terminal tests fire")

        manager.queueTestIssue(.sensorFailure, after: 0)
        manager.queueTestIssue(.transmitterFailure, after: 0)

        DispatchQueue.main.async {
            XCTAssertEqual(alarm.issues.count, 2)
            XCTAssertEqual(Set(alarm.issues.map(\.id)).count, 2)
            XCTAssertTrue(alarm.issues.allSatisfy { $0.sensorSessionID == "test" })
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1)
    }

    func testSyntheticWarningBypassesPreferenceForExplicitTesting() {
        defaults.sensorHealthNotificationsEnabled = false
        let manager = makeManager()
        let fired = expectation(description: "queued warning test fires")

        manager.queueTestIssue(.flatline, after: 0)

        DispatchQueue.main.async {
            XCTAssertEqual(self.notificationCenter.requests.count, 1)
            XCTAssertEqual(self.notificationCenter.requests[0].content.title, manager.visibleIssue?.title)
            XCTAssertEqual(self.notificationCenter.requests[0].content.body, manager.visibleIssue?.guidance)
            XCTAssertEqual(manager.visibleIssue?.sensorSessionID, "test")
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1)
    }

    func testSyntheticPersistentNoiseIsInAppOnly() {
        let manager = makeManager()
        let fired = expectation(description: "queued persistent noise test fires")

        manager.queueTestIssue(.persistentNoise, after: 0)

        DispatchQueue.main.async {
            XCTAssertTrue(self.notificationCenter.requests.isEmpty)
            XCTAssertEqual(manager.visibleIssue?.kind, .persistentNoise)
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1)
    }

    func testDismissalAndDeduplicationPersistAcrossLaunches() {
        let alarm = OneOffAlarmSpy()
        var manager: SensorHealthIssueManager? = makeManager()
        manager?.configure(oneOffAlarmRaiser: alarm)
        manager?.report(
            .terminal(source: .libre, reason: .libreSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )
        manager?.dismissVisibleIssue()
        manager = nil

        let relaunched = makeManager()
        relaunched.configure(oneOffAlarmRaiser: alarm)
        relaunched.report(
            .terminal(source: .libre, reason: .libreSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start.addingTimeInterval(.minutes(5))
        )

        XCTAssertNil(relaunched.visibleIssue)
        XCTAssertEqual(alarm.issues.count, 1)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testPersistentNoiseNeedsSixtyContinuousRecoveryMinutes() {
        let manager = makeManager()
        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .veryHigh, longTermNoise: 20),
            persistence: SensorNoisePersistenceAssessment(value: 20, coverage: 1),
            sensitivity: .normal,
            now: start.addingTimeInterval(.hours(12))
        )
        XCTAssertEqual(manager.visibleIssue?.kind, .persistentNoise)
        XCTAssertTrue(notificationCenter.requests.isEmpty)

        let recoveryStart = start.addingTimeInterval(.hours(12.1))
        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .low, longTermNoise: 1),
            persistence: SensorNoisePersistenceAssessment(value: 1, coverage: 1),
            sensitivity: .normal,
            now: recoveryStart
        )
        XCTAssertNotNil(manager.visibleIssue)

        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .low, longTermNoise: 1),
            persistence: SensorNoisePersistenceAssessment(value: 1, coverage: 1),
            sensitivity: .normal,
            now: recoveryStart.addingTimeInterval(.hours(1))
        )
        XCTAssertNil(manager.visibleIssue)
    }

    func testPersistentNoiseDetectionDoesNotDependOnShowingSensorNoiseUI() {
        defaults.showSensorNoise = false
        let manager = makeManager()

        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .veryHigh, longTermNoise: 20),
            persistence: SensorNoisePersistenceAssessment(value: 20, coverage: 1),
            sensitivity: .normal,
            now: start.addingTimeInterval(.hours(12))
        )

        XCTAssertFalse(defaults.showSensorNoise)
        XCTAssertEqual(manager.visibleIssue?.kind, .persistentNoise)
    }

    func testPersistentNoiseIncludesThresholdBoundaryForEverySensitivity() {
        for (index, sensitivity) in SensorNoiseSensitivity.allCases.enumerated() {
            let manager = makeManager()
            let threshold = ConstantsSensorNoise.threshold(
                ConstantsSensorNoise.veryHighNoiseStandardDeviation,
                sensitivity: sensitivity
            )
            let sensorID = "boundary-\(index)"

            manager.reportCalculatedState(
                sensorID: sensorID,
                sensorStartDate: start.addingTimeInterval(.hours(Double(index * 24))),
                measurement: measurement(state: .veryHigh, longTermNoise: threshold),
                persistence: SensorNoisePersistenceAssessment(
                    value: threshold,
                    coverage: ConstantsSensorNoise.minimumPersistentNoiseCoverage
                ),
                sensitivity: sensitivity,
                now: start.addingTimeInterval(.hours(Double(index * 24 + 12)))
            )

            XCTAssertEqual(manager.visibleIssue?.kind, .persistentNoise)
        }
    }

    func testFlatlineEpisodeResolvesWhenMeaningfulMovementReturns() {
        let manager = makeManager()
        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .flatlineSuspected, longTermNoise: 0),
            persistence: SensorNoisePersistenceAssessment(value: nil, coverage: 0),
            sensitivity: .normal,
            now: start
        )
        XCTAssertEqual(manager.visibleIssue?.kind, .flatline)

        manager.reportCalculatedState(
            sensorID: "A",
            sensorStartDate: start,
            measurement: measurement(state: .low, longTermNoise: 1),
            persistence: SensorNoisePersistenceAssessment(value: nil, coverage: 0),
            sensitivity: .normal,
            now: start.addingTimeInterval(.minutes(10))
        )

        XCTAssertNil(manager.visibleIssue)
    }

    func testNewSensorSessionClearsPreviousEpisode() {
        let manager = makeManager()
        manager.report(
            .terminal(source: .dexcom, reason: .dexcomSensorFailure),
            sensorID: "A",
            sensorStartDate: start,
            now: start
        )

        manager.reportCalculatedState(
            sensorID: "B",
            sensorStartDate: start.addingTimeInterval(.hours(24)),
            measurement: measurement(state: .low, longTermNoise: 1),
            persistence: SensorNoisePersistenceAssessment(value: nil, coverage: 0),
            sensitivity: .normal,
            now: start.addingTimeInterval(.hours(24))
        )

        XCTAssertNil(manager.visibleIssue)
    }

    private func makeManager() -> SensorHealthIssueManager {
        SensorHealthIssueManager(userDefaults: defaults, notificationCenter: notificationCenter)
    }

    private func measurement(state: SensorNoiseState, longTermNoise: Double?) -> SensorNoiseMeasurement {
        SensorNoiseMeasurement(
            shortTermNoise: longTermNoise,
            longTermNoise: longTermNoise,
            shortTermCoverage: 1,
            longTermCoverage: 1,
            state: state,
            latestReadingAt: start
        )
    }
}

private final class NotificationCenterSpy: SensorHealthNotificationScheduling {
    private(set) var requests = [UNNotificationRequest]()

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        requests.append(request)
        completionHandler?(nil)
    }

    func removeDeliveredNotifications(withIdentifiers _: [String]) {}
    func removePendingNotificationRequests(withIdentifiers _: [String]) {}
}

private final class OneOffAlarmSpy: SensorHealthOneOffAlarmRaising {
    private(set) var issues = [SensorHealthIssue]()

    func raiseOneOffSensorFailureAlarm(_ issue: SensorHealthIssue) {
        issues.append(issue)
    }
}
