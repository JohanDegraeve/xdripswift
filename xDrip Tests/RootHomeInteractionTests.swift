//
//  RootHomeInteractionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 9/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class RootHomeInteractionTests: XCTestCase {

    func testIPadLayoutClassRespondsToWindowWidth() {
        XCTAssertEqual(IPadLayoutClass.resolve(isPad: false, width: 1_366, usesAccessibilityText: false), .compact)
        XCTAssertEqual(IPadLayoutClass.resolve(isPad: true, width: 500, usesAccessibilityText: false), .compact)
        XCTAssertEqual(IPadLayoutClass.resolve(isPad: true, width: 744, usesAccessibilityText: false), .regular)
        XCTAssertEqual(IPadLayoutClass.resolve(isPad: true, width: 1_024, usesAccessibilityText: false), .wide)
    }

    func testIPadLayoutClassUsesCompactCompositionForAccessibilityText() {
        XCTAssertEqual(IPadLayoutClass.resolve(isPad: true, width: 1_366, usesAccessibilityText: true), .compact)
    }

    func testIPadOrientationPolicyAllowsAllTabsToRotate() {
        XCTAssertEqual(
            RootOrientationPolicy.supportedOrientations(isPad: true, isHome: false, allowsHomeRotation: false),
            .all
        )
        XCTAssertEqual(
            RootOrientationPolicy.supportedOrientations(isPad: false, isHome: false, allowsHomeRotation: true),
            .portrait
        )
    }

    func testChartRangesStepShorterWithoutWrapping() {
        XCTAssertNil(RootHomeChartRange.threeHours.nextShorterRange)
        XCTAssertEqual(RootHomeChartRange.fiveHours.nextShorterRange, .threeHours)
        XCTAssertEqual(RootHomeChartRange.eightHours.nextShorterRange, .fiveHours)
        XCTAssertEqual(RootHomeChartRange.twelveHours.nextShorterRange, .eightHours)
        XCTAssertEqual(RootHomeChartRange.twentyFourHours.nextShorterRange, .twelveHours)
    }

    func testChartRangesStepLongerWithoutWrapping() {
        XCTAssertEqual(RootHomeChartRange.threeHours.nextLongerRange, .fiveHours)
        XCTAssertEqual(RootHomeChartRange.fiveHours.nextLongerRange, .eightHours)
        XCTAssertEqual(RootHomeChartRange.eightHours.nextLongerRange, .twelveHours)
        XCTAssertEqual(RootHomeChartRange.twelveHours.nextLongerRange, .twentyFourHours)
        XCTAssertNil(RootHomeChartRange.twentyFourHours.nextLongerRange)
    }

    func testStatisticsPeriodOptionsUseFullLocalizedLabels() {
        XCTAssertEqual(RootHomeStatisticsPeriod.options, [0, 1, 7, 30, 90])
        XCTAssertEqual(RootHomeStatisticsPeriod.title(for: 0), Texts_Common.today)
        XCTAssertEqual(RootHomeStatisticsPeriod.title(for: 1), "1 \(Texts_Common.day)")
        XCTAssertEqual(RootHomeStatisticsPeriod.title(for: 7), "7 \(Texts_Common.days)")
        XCTAssertEqual(RootHomeStatisticsPeriod.title(for: 30), "30 \(Texts_Common.days)")
        XCTAssertEqual(RootHomeStatisticsPeriod.title(for: 90), "90 \(Texts_Common.days)")
    }

    func testCareLinkSensorIndicatorUsesHomeLifetimeThresholds() {
        let expired = ConstantsHomeView.careLinkSensorIndicator(remainingMinutes: 0)
        let urgent = ConstantsHomeView.careLinkSensorIndicator(
            remainingMinutes: Int(ConstantsHomeView.sensorProgressViewUrgentInMinutes)
        )
        let warning = ConstantsHomeView.careLinkSensorIndicator(
            remainingMinutes: Int(ConstantsHomeView.sensorProgressViewWarningInMinutes)
        )
        let normal = ConstantsHomeView.careLinkSensorIndicator(
            remainingMinutes: Int(ConstantsHomeView.sensorProgressViewWarningInMinutes) + 1
        )

        XCTAssertEqual(expired.systemImage, "sensor.tag.radiowaves.forward.fill")
        XCTAssertEqual(urgent.systemImage, expired.systemImage)
        XCTAssertEqual(warning.systemImage, expired.systemImage)
        XCTAssertEqual(normal.systemImage, expired.systemImage)
        XCTAssertEqual(expired.color, ConstantsAppColors.sensorExpired)
        XCTAssertEqual(urgent.color, ConstantsAppColors.sensorUrgent)
        XCTAssertEqual(warning.color, ConstantsAppColors.sensorWarning)
        XCTAssertEqual(normal.color, .green)
    }

    func testBatteryIndicatorMatchesLoopStatusBuckets() {
        XCTAssertNil(ConstantsHomeView.batteryIndicator(percent: nil))
        XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 10)?.color, ConstantsAppColors.urgent)
        XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 11)?.color, ConstantsAppColors.warning)
        XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 26)?.color, ConstantsAppColors.secondaryText)
        XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 66)?.color, ConstantsAppColors.secondaryText)
        XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 91)?.color, ConstantsAppColors.secondaryText)

        if #available(iOS 17.0, *) {
            XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 10)?.systemImage, "battery.0percent")
            XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 11)?.systemImage, "battery.25percent")
            XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 26)?.systemImage, "battery.50percent")
            XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 66)?.systemImage, "battery.75percent")
            XCTAssertEqual(ConstantsHomeView.batteryIndicator(percent: 91)?.systemImage, "battery.100percent")
        }
    }
}
