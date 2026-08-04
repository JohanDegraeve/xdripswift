//
//  SensorNoisePersistenceTests.swift
//  xdripTests
//
//  Created by Paul Plant on 2/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

/// Covers persistent-noise coverage, thresholds and flatline recovery.
final class SensorNoisePersistenceTests: XCTestCase {
    private let calculator = SensorNoiseCalculator()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testPersistenceRequiresMinimumCoverage() {
        let assessment = calculator.calculatePersistence(readings: noisyReadings(hours: 8))

        XCTAssertNil(assessment.value)
    }

    func testPersistenceReportsHighMedianWithCompleteCoverage() throws {
        let assessment = calculator.calculatePersistence(readings: noisyReadings(hours: 12.5))

        XCTAssertGreaterThanOrEqual(assessment.coverage, 0.70)
        let median = try XCTUnwrap(assessment.value)
        XCTAssertGreaterThanOrEqual(
            ConstantsSensorNoise.state(for: median, sensitivity: .normal).rawValue,
            SensorNoiseState.veryHigh.rawValue
        )
    }

    func testLargeDataGapReducesCoverageBelowTrigger() {
        let readings = noisyReadings(hours: 12.5).filter { reading in
            let elapsed = reading.timeStamp.timeIntervalSince(start)
            return elapsed < .hours(3) || elapsed > .hours(8)
        }

        let assessment = calculator.calculatePersistence(readings: readings)

        XCTAssertLessThan(assessment.coverage, 0.70)
        XCTAssertNil(assessment.value)
    }

    func testPersistedEstimateHistoryRebuildsTwelveHourMedianAndCoverage() throws {
        let estimates = (0 ... 72).map { index in
            (
                timeStamp: start.addingTimeInterval(.minutes(Double(index * 10))),
                noise: index.isMultiple(of: 3) ? 9.0 : 8.0
            )
        }

        let assessment = calculator.calculatePersistence(
            estimates: estimates,
            endingAt: start.addingTimeInterval(.hours(12))
        )

        XCTAssertEqual(assessment.coverage, 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(assessment.value), 8, accuracy: 0.001)
    }

    func testPersistedEstimateHistoryAllowsNormalSchedulingDelays() throws {
        let estimates = (0 ... 48).map { index in
            (
                timeStamp: start.addingTimeInterval(.minutes(Double(index * 15))),
                noise: index.isMultiple(of: 3) ? 9.0 : 8.0
            )
        }

        let assessment = calculator.calculatePersistence(
            estimates: estimates,
            endingAt: start.addingTimeInterval(.hours(12))
        )

        XCTAssertEqual(assessment.coverage, 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(assessment.value), 8, accuracy: 0.001)
    }

    func testPersistedEstimateHistoryRejectsLargeDataGap() {
        let estimates = (0 ... 72).compactMap { index -> (timeStamp: Date, noise: Double)? in
            let elapsedMinutes = index * 10
            guard elapsedMinutes < 180 || elapsedMinutes > 480 else { return nil }

            return (
                timeStamp: start.addingTimeInterval(.minutes(Double(elapsedMinutes))),
                noise: 8.0
            )
        }

        let assessment = calculator.calculatePersistence(
            estimates: estimates,
            endingAt: start.addingTimeInterval(.hours(12))
        )

        XCTAssertLessThan(assessment.coverage, ConstantsSensorNoise.minimumPersistentNoiseCoverage)
        XCTAssertNil(assessment.value)
    }

    func testPersistedEstimateHistoryDoesNotCarryAnOldValueForward() {
        let estimates = (0 ... 72).map { index in
            (
                timeStamp: start.addingTimeInterval(.minutes(Double(index * 10))),
                noise: 8.0
            )
        }

        let assessment = calculator.calculatePersistence(
            estimates: estimates,
            endingAt: start.addingTimeInterval(.hours(16))
        )

        XCTAssertNil(assessment.value)
    }

    func testSensitivityThresholdBoundaryForEveryLevel() {
        for sensitivity in SensorNoiseSensitivity.allCases {
            let boundary = ConstantsSensorNoise.threshold(
                ConstantsSensorNoise.veryHighNoiseStandardDeviation,
                sensitivity: sensitivity
            )

            XCTAssertEqual(ConstantsSensorNoise.state(for: boundary, sensitivity: sensitivity), .elevated)
            XCTAssertEqual(ConstantsSensorNoise.state(for: boundary.nextUp, sensitivity: sensitivity), .veryHigh)
        }
    }

    func testFlatlineRequiresCurrentSixReadingWindowAndRecoversWithMovement() {
        let flat = (0 ..< 6).map { index in
            SensorNoiseReading(
                timeStamp: start.addingTimeInterval(.minutes(Double(index * 5))),
                calculatedValue: 110,
                rawData: 110,
                calibrationID: nil
            )
        }
        XCTAssertEqual(calculator.calculate(readings: flat).state, .flatlineSuspected)

        let moving = flat + [
            SensorNoiseReading(
                timeStamp: start.addingTimeInterval(.minutes(30)),
                calculatedValue: 112,
                rawData: 112,
                calibrationID: nil
            )
        ]
        XCTAssertNotEqual(calculator.calculate(readings: moving).state, .flatlineSuspected)
    }

    private func noisyReadings(hours: Double) -> [SensorNoiseReading] {
        let count = Int(hours * 12) + 1
        return (0 ..< count).map { index in
            let value = index.isMultiple(of: 2) ? 80.0 : 180.0
            return SensorNoiseReading(
                timeStamp: start.addingTimeInterval(.minutes(Double(index * 5))),
                calculatedValue: value,
                rawData: value,
                calibrationID: nil
            )
        }
    }
}
