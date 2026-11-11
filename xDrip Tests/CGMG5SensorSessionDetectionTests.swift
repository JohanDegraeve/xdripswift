//
//  CGMG5SensorSessionDetectionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 14/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class CGMG5SensorSessionDetectionTests: XCTestCase {
    private let sensorStartDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testReportsSessionWhenInternalSensorIsMissingEvenIfDateWasAlreadyPersisted() {
        XCTAssertTrue(shouldReport(activeSensorStartDate: nil))
    }

    func testDoesNotReportMatchingInternalSession() {
        XCTAssertFalse(shouldReport(activeSensorStartDate: sensorStartDate))
    }

    func testDoesNotReportDifferenceWithinTolerance() {
        XCTAssertFalse(shouldReport(activeSensorStartDate: sensorStartDate.addingTimeInterval(15)))
        XCTAssertFalse(shouldReport(activeSensorStartDate: sensorStartDate.addingTimeInterval(-15)))
    }

    func testReportsDifferenceBeyondToleranceInEitherDirection() {
        XCTAssertTrue(shouldReport(activeSensorStartDate: sensorStartDate.addingTimeInterval(16)))
        XCTAssertTrue(shouldReport(activeSensorStartDate: sensorStartDate.addingTimeInterval(-16)))
    }

    func testReportsSameTransmitterSessionAgainAfterInternalSensorIsStopped() {
        XCTAssertTrue(shouldReport(activeSensorStartDate: nil))
        XCTAssertTrue(shouldReport(activeSensorStartDate: nil))
    }

    func testReportsMatchingSessionConfirmationOnlyOnce() {
        XCTAssertTrue(shouldReportConfirmation(reportedSensorStartDate: nil))
        XCTAssertFalse(shouldReportConfirmation(reportedSensorStartDate: sensorStartDate))
        XCTAssertFalse(shouldReportConfirmation(reportedSensorStartDate: sensorStartDate.addingTimeInterval(15)))
    }

    func testReportsConfirmationForDifferentSession() {
        XCTAssertTrue(shouldReportConfirmation(reportedSensorStartDate: sensorStartDate.addingTimeInterval(16)))
    }

    func testFirstValueIsAvailableOnlyForSecondStageOfSameSession() {
        var policy = DexcomG6InitialCalibrationPolicy()
        _ = policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        policy.calibrationSubmitted(valueInMgDl: 123, enteredAt: sensorStartDate)
        XCTAssertNil(policy.secondCalibrationPrefill)
        _ = policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        XCTAssertEqual(policy.secondCalibrationPrefill?.valueInMgDl, 123)
        XCTAssertEqual(policy.secondCalibrationPrefill?.enteredAt, sensorStartDate)
        XCTAssertTrue(policy.hasPendingPrompt)
        // Editing and confirming the second value must not replace the stored first value.
        policy.calibrationSubmitted(valueInMgDl: 128)
        XCTAssertEqual(policy.secondCalibrationPrefill?.valueInMgDl, 123)
        XCTAssertFalse(policy.hasPendingPrompt)
    }

    func testPrefillDoesNotLeakIntoAnotherSessionOrSurviveCompletedCalibration() {
        var policy = DexcomG6InitialCalibrationPolicy()
        _ = policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        policy.calibrationSubmitted(valueInMgDl: 123)
        _ = policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate.addingTimeInterval(86400))
        XCTAssertNil(policy.secondCalibrationPrefill)
        _ = policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        policy.calibrationSubmitted(valueInMgDl: 123)
        _ = policy.update(state: .okay, sensorStartDate: sensorStartDate)
        _ = policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        XCTAssertNil(policy.secondCalibrationPrefill)
    }

    func testAdoptedSecondStageHasNoInventedFirstValue() {
        var policy = DexcomG6InitialCalibrationPolicy()
        _ = policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        XCTAssertNil(policy.secondCalibrationPrefill)
        XCTAssertTrue(policy.hasPendingPrompt)
    }

    @MainActor func testPrefilledCalibrationRemainsEditableAndRequiresExplicitSubmission() {
        let state = RootTabStateModel()
        var submittedValue: String?
        state.presentTextInput(title: "Calibration (2/2)", placeholder: "...", usesDecimalKeyboard: false,
                               initialText: "123", message: "Previous calibration") { submittedValue = $0 }
        XCTAssertEqual(state.textInput, "123")
        XCTAssertNil(submittedValue)
        state.textInput = "128"
        state.textInputRequest?.action(state.textInput)
        XCTAssertEqual(submittedValue, "128")
        state.presentTextInput(title: "Calibration", placeholder: "...", usesDecimalKeyboard: false) { _ in }
        XCTAssertEqual(state.textInput, "")
        XCTAssertNil(state.textInputRequest?.message)
    }

    func testSessionCounterSurvivesWallClockDriftWithoutReportingNewSensor() throws {
        let identity = sessionIdentity()
        for drift in [-3600.0, -16.0, 16.0, 3600.0] {
            let clock = try sessionClock(now: sensorStartDate.addingTimeInterval(80_000 + drift))
            let reconstructed = try XCTUnwrap(clock.sensorStartDate)
            XCTAssertTrue(CGMG5Transmitter.shouldReportDetectedSensor(activeSensorStartDate: sensorStartDate, receivedSensorStartDate: reconstructed))
            let resolved = try XCTUnwrap(identity.resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: sensorStartDate))
            XCTAssertEqual(resolved, sensorStartDate)
            XCTAssertFalse(CGMG5Transmitter.shouldReportDetectedSensor(activeSensorStartDate: sensorStartDate, receivedSensorStartDate: resolved))
        }
    }

    func testSessionIdentitySurvivesRelaunch() throws {
        let persisted = try JSONEncoder().encode(sessionIdentity())
        let restored = try JSONDecoder().decode(DexcomSensorSessionIdentity.self, from: persisted)
        let clock = try sessionClock(now: sensorStartDate.addingTimeInterval(83_600))
        XCTAssertEqual(restored.resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: sensorStartDate), sensorStartDate)
    }

    func testDifferentTransmitterOrCounterCannotPreserveSession() throws {
        let identity = sessionIdentity()
        let clock = try sessionClock()
        XCTAssertNil(identity.resolvedStartDate(transmitterID: "8OTHER", clock: clock, activeStartDate: sensorStartDate))
        let replacement = try sessionClock(startCounter: 90_000)
        XCTAssertNil(identity.resolvedStartDate(transmitterID: "8ATEST", clock: replacement, activeStartDate: sensorStartDate))
        XCTAssertTrue(CGMG5Transmitter.shouldReportDetectedSensor(activeSensorStartDate: sensorStartDate, receivedSensorStartDate: try XCTUnwrap(replacement.sensorStartDate)))
    }

    func testBackwardsTransmitterClockCannotReuseIdentityEvenWithSameCounter() throws {
        // Covers an observed transmitter reset/Anubis restart and an out-of-order old clock.
        let restarted = try sessionClock(transmitterTime: 90_000)
        XCTAssertFalse(sessionIdentity().matches(transmitterID: "8ATEST", clock: restarted))
        XCTAssertNil(sessionIdentity().resolvedStartDate(transmitterID: "8ATEST", clock: restarted, activeStartDate: sensorStartDate))
    }

    func testStoppedOrReplacedInternalSessionCannotReuseIdentity() throws {
        let clock = try sessionClock()
        XCTAssertNil(sessionIdentity().resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: nil))
        XCTAssertNil(sessionIdentity().resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: sensorStartDate.addingTimeInterval(1)))
    }

    func testIncompleteAndSentinelClockUseLegacyDateFallback() throws {
        for counter: UInt32 in [0, UInt32.max, 100_001] {
            let clock = try sessionClock(startCounter: counter)
            XCTAssertNil(clock.sensorStartCounter)
            XCTAssertNil(sessionIdentity().resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: sensorStartDate))
        }
        let shortClock = try XCTUnwrap(DexcomTransmitterTimeRxMessage(data: Data([0x25, 0, 1, 0, 0, 0])))
        XCTAssertNil(shortClock.sensorStartCounter)
        XCTAssertNil(shortClock.sensorStartDate)
    }

    func testStableSessionDatePreservesNoCodeCalibrationProgress() throws {
        var policy = DexcomG6InitialCalibrationPolicy()
        _ = policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate)
        policy.calibrationSubmitted(valueInMgDl: 123, enteredAt: sensorStartDate)
        let clock = try sessionClock(now: sensorStartDate.addingTimeInterval(83_600))
        let resolved = try XCTUnwrap(sessionIdentity().resolvedStartDate(transmitterID: "8ATEST", clock: clock, activeStartDate: sensorStartDate))
        _ = policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: resolved)
        XCTAssertEqual(policy.secondCalibrationPrefill?.valueInMgDl, 123)
    }

    func testSessionIdentityIsExcludedFromPortableBackups() {
        XCTAssertFalse(BackupService.isPortableSetting(UserDefaults.Key.dexcomSensorSessionIdentityData.rawValue))
    }

    private func sessionIdentity() -> DexcomSensorSessionIdentity {
        DexcomSensorSessionIdentity(transmitterID: "8ATEST", startCounter: 20_000, lastTransmitterTime: 100_000, activeSensorStartDate: sensorStartDate)
    }

    private func sessionClock(transmitterTime: UInt32 = 100_000, startCounter: UInt32 = 20_000, now: Date? = nil) throws -> DexcomTransmitterTimeRxMessage {
        var data = Data([0x25, 0])
        for value in [transmitterTime, startCounter] {
            for index in 0..<4 { data.append(UInt8((value >> (8 * index)) & 0xff)) }
        }
        return try XCTUnwrap(DexcomTransmitterTimeRxMessage(data: data, receivedAt: now ?? sensorStartDate.addingTimeInterval(80_000)))
    }

    private func shouldReport(activeSensorStartDate: Date?) -> Bool {
        CGMG5Transmitter.shouldReportDetectedSensor(
            activeSensorStartDate: activeSensorStartDate,
            receivedSensorStartDate: sensorStartDate
        )
    }

    func testNativeG6CanEnterCalibrationBeforeAnyGlucoseReading() {
        XCTAssertTrue(DexcomG6InitialCalibrationPolicy.canEnterCalibration(canCalibrate: true, hasReading: false, isNativeG6: true))
        XCTAssertFalse(DexcomG6InitialCalibrationPolicy.canEnterCalibration(canCalibrate: false, hasReading: false, isNativeG6: true))
        XCTAssertFalse(DexcomG6InitialCalibrationPolicy.canEnterCalibration(canCalibrate: true, hasReading: false, isNativeG6: false))
        XCTAssertTrue(DexcomG6InitialCalibrationPolicy.canEnterCalibration(canCalibrate: true, hasReading: true, isNativeG6: false))
    }

    func testNoCodeWarmupDoesNotPromptUntilTransmitterRequestsCalibration() {
        var policy = DexcomG6InitialCalibrationPolicy()
        XCTAssertFalse(policy.update(state: .SensorWarmup, sensorStartDate: sensorStartDate))
        XCTAssertTrue(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertTrue(policy.matches(sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
    }

    func testSecondCalibrationGetsItsOwnPromptWithoutRepeatingEveryPacket() {
        var policy = DexcomG6InitialCalibrationPolicy()
        XCTAssertTrue(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertTrue(policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.update(state: .okay, sensorStartDate: sensorStartDate))
        XCTAssertNil(policy.requiredState)
        XCTAssertFalse(policy.matches(sensorStartDate: sensorStartDate))
    }

    func testSubmittingFirstCalibrationDoesNotReopenPromptForRepeatedFirstState() {
        var policy = DexcomG6InitialCalibrationPolicy()
        XCTAssertTrue(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertTrue(policy.hasPendingPrompt)
        policy.calibrationSubmitted()
        XCTAssertFalse(policy.hasPendingPrompt)
        XCTAssertFalse(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.hasPendingPrompt)
        XCTAssertTrue(policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertTrue(policy.hasPendingPrompt)
    }

    func testAdoptingRunningSessionDoesNotRequestInitialCalibration() {
        var policy = DexcomG6InitialCalibrationPolicy()
        let existingStartDate = sensorStartDate.addingTimeInterval(-86400)
        XCTAssertFalse(policy.update(state: .okay, sensorStartDate: existingStartDate))
        XCTAssertNil(policy.requiredState)
        // Routine calibration requests are outside this initial-calibration prompt.
        XCTAssertFalse(policy.update(state: .needsCalibration, sensorStartDate: existingStartDate))
        XCTAssertNil(policy.requiredState)
    }

    func testAdoptingSessionThatReallyNeedsSecondCalibrationPrompts() {
        var policy = DexcomG6InitialCalibrationPolicy()
        XCTAssertTrue(policy.update(state: .SecondofTwoBGsNeeded, sensorStartDate: sensorStartDate.addingTimeInterval(-86400)))
        XCTAssertFalse(policy.matches(sensorStartDate: sensorStartDate))
    }

    func testNewSessionCanPromptAgainAndStoppedSessionInvalidatesEntry() {
        var policy = DexcomG6InitialCalibrationPolicy()
        XCTAssertTrue(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: sensorStartDate.addingTimeInterval(1)))
        let nextSession = sensorStartDate.addingTimeInterval(86400)
        XCTAssertTrue(policy.update(state: .FirstofTwoBGsNeeded, sensorStartDate: nextSession))
        XCTAssertFalse(policy.matches(sensorStartDate: sensorStartDate))
        XCTAssertFalse(policy.update(state: .SessionStopped, sensorStartDate: nextSession))
        XCTAssertNil(policy.requiredState)
    }

    private func shouldReportConfirmation(reportedSensorStartDate: Date?) -> Bool {
        CGMG5Transmitter.shouldReportConfirmedSensorSession(
            reportedSensorStartDate: reportedSensorStartDate,
            receivedSensorStartDate: sensorStartDate
        )
    }
}
