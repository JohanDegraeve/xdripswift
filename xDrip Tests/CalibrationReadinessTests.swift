//
//  CalibrationReadinessTests.swift
//  xdripTests
//
//  Created by Paul Plant on 15/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class CalibrationReadinessTests: XCTestCase {
    func testEnteredLowCalibrationValueProducesBadEvaluation() {
        let baseReadiness = readiness()

        let calibrationReadiness = baseReadiness.evaluating(calibrationValueInMgDl: 55)

        XCTAssertEqual(calibrationReadiness.calibrationValue.level, .bad)
        XCTAssertEqual(calibrationReadiness.level, .bad)
        XCTAssertEqual(calibrationReadiness.calibrationValue.detail, Texts_Common.lowStatistics)
        XCTAssertEqual(calibrationReadiness.summary, Texts_HomeView.sensorManagementCalibrationReadinessBad)
        XCTAssertEqual(calibrationReadiness.stableTrend.level, .good)
        XCTAssertEqual(calibrationReadiness.sensorNoise.level, .good)
    }

    func testEnteredInRangeCalibrationValueProducesGoodEvaluation() {
        let baseReadiness = readiness()

        let calibrationReadiness = baseReadiness.evaluating(calibrationValueInMgDl: 100)

        XCTAssertEqual(calibrationReadiness.calibrationValue.level, .good)
        XCTAssertEqual(calibrationReadiness.level, .good)
        XCTAssertEqual(calibrationReadiness.calibrationValue.detail, Texts_HomeView.sensorManagementCalibrationGood)
        XCTAssertEqual(calibrationReadiness.summary, Texts_HomeView.sensorManagementCalibrationReadinessGood)
    }

    func testCautionConditionProducesCautionEvaluation() {
        let baseReadiness = readiness(stableTrendLevel: .caution)

        let calibrationReadiness = baseReadiness.evaluating(calibrationValueInMgDl: 100)

        XCTAssertEqual(calibrationReadiness.level, .caution)
        XCTAssertEqual(calibrationReadiness.summary, Texts_HomeView.sensorManagementCalibrationReadinessCaution)
    }

    func testTraceAndActivitySnapshotsUseTheSubmittedThreeConditionEvaluation() {
        let baseReadiness = readiness(stableTrendLevel: .caution, sensorNoiseLevel: .bad)

        let evaluation = baseReadiness.evaluating(calibrationValueInMgDl: 100)
        let activitySnapshot = TroubleshootingCalibrationReadiness(evaluation)

        XCTAssertEqual(
            evaluation.traceDescription,
            "overall = bad, calibration value = good (Good), " +
                "stable trend = caution (stable), sensor noise = bad (noise)"
        )
        XCTAssertEqual(activitySnapshot.calibrationValue, .good)
        XCTAssertEqual(activitySnapshot.stableTrend, .caution)
        XCTAssertEqual(activitySnapshot.sensorNoise, .bad)
        XCTAssertEqual(activitySnapshot.overall, .bad)
    }

    private func readiness(
        stableTrendLevel: CalibrationReadinessLevel = .good,
        sensorNoiseLevel: CalibrationReadinessLevel = .good
    ) -> CalibrationReadiness {
        CalibrationReadiness(
            stableTrend: CalibrationReadinessCheck(level: stableTrendLevel, detail: "stable"),
            sensorNoise: CalibrationReadinessCheck(level: sensorNoiseLevel, detail: "noise")
        )
    }
}
