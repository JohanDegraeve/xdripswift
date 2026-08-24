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

    private func shouldReport(activeSensorStartDate: Date?) -> Bool {
        CGMG5Transmitter.shouldReportDetectedSensor(
            activeSensorStartDate: activeSensorStartDate,
            receivedSensorStartDate: sensorStartDate
        )
    }
}
