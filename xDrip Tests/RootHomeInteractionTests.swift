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

final class RootHomeStatisticsEasterEggTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 16, minute: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func easterEgg(_ date: Date, days: Int = 0, low: Double = 0, inRange: Double = 100,
                            high: Double = 0, enabled: Bool = true) -> RootHomeStatisticsEasterEgg? {
        RootHomeStatisticsEasterEggPolicy.easterEgg(low: low, inRange: inRange, high: high,
            days: days, now: date, calendar: calendar, enabled: enabled)
    }

    func testRequiresExactInRangeData() {
        let now = date(9, 10)
        XCTAssertEqual(easterEgg(now), .sunglasses)
        XCTAssertNil(easterEgg(now, low: 0.1, inRange: 99.9))
        XCTAssertNil(easterEgg(now, inRange: 99.9, high: 0.1))
        XCTAssertNil(easterEgg(now, inRange: 0))
        XCTAssertNil(easterEgg(now, inRange: .nan))
        XCTAssertNil(easterEgg(now, enabled: false))
    }

    func testTodayThresholdAndMidnight() {
        XCTAssertNil(easterEgg(date(9, 10, hour: 15, minute: 59)))
        XCTAssertEqual(easterEgg(date(9, 10)), .sunglasses)
        XCTAssertEqual(easterEgg(date(9, 10, hour: 23, minute: 59)), .sunglasses)
        XCTAssertNil(easterEgg(date(9, 11, hour: 0)))
        for days in [1, 7, 30, 90] {
            XCTAssertEqual(easterEgg(date(9, 10, hour: 0), days: days), .sunglasses)
        }
    }

    func testSeasonalDatesAndAdjacentDays() {
        for (month, day, expected) in [
            (1, 1, RootHomeStatisticsEasterEgg.newYear),
            (1, 2, .sunglasses),
            (10, 30, .sunglasses), (10, 31, .halloween), (11, 1, .sunglasses),
            (12, 22, .sunglasses), (12, 23, .christmas), (12, 31, .christmas)
        ] {
            XCTAssertEqual(easterEgg(date(month, day)), expected)
            XCTAssertNil(easterEgg(date(month, day, hour: 15)))
            XCTAssertEqual(easterEgg(date(month, day, hour: 0), days: 7), expected)
        }
        XCTAssertEqual(easterEgg(date(1, 1, year: 2027), days: 7), .newYear)
    }

    func testThresholdUsesWallClockAcrossDaylightSavingChanges() {
        for (month, day) in [(3, 29), (10, 25)] {
            XCTAssertNil(easterEgg(date(month, day, hour: 15, minute: 59)))
            XCTAssertEqual(easterEgg(date(month, day)), .sunglasses)
        }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertNil(RootHomeStatisticsEasterEggPolicy.easterEgg(low: 0, inRange: 100, high: 0,
            days: 0, now: date(9, 10), calendar: utc))
    }

    func testLoadingClearsEasterEggAndTimeRefreshDoesNotRestoreIt() {
        let model = RootHomeStateModel()
        model.updateStatistics(StatisticsManager.Statistics(lowStatisticValue: 0, highStatisticValue: 0,
            inRangeStatisticValue: 100, averageStatisticValue: 100, a1CStatisticValue: 5,
            cVStatisticValue: 0, lowLimitForTIR: 70, highLimitForTIR: 180, numberOfDaysUsed: 1))
        model.updateStatisticsEasterEgg(days: 0, now: date(9, 10), calendar: calendar)
        XCTAssertEqual(model.state.statistics.easterEgg, .sunglasses)
        model.setStatisticsLoading()
        XCTAssertNil(model.state.statistics.easterEgg)
        model.updateStatisticsEasterEgg(days: 0, now: date(9, 10), calendar: calendar)
        XCTAssertNil(model.state.statistics.easterEgg)
    }

    func testTimeRefreshHandlesForegroundReturnAndSeasonChange() {
        let model = RootHomeStateModel()
        model.updateStatistics(StatisticsManager.Statistics(lowStatisticValue: 0, highStatisticValue: 0,
            inRangeStatisticValue: 100, averageStatisticValue: 100, a1CStatisticValue: 5,
            cVStatisticValue: 0, lowLimitForTIR: 70, highLimitForTIR: 180, numberOfDaysUsed: 1))
        model.updateStatisticsEasterEgg(days: 0, now: date(9, 10, hour: 15), calendar: calendar)
        XCTAssertNil(model.state.statistics.easterEgg)
        model.updateStatisticsEasterEgg(days: 0, now: date(9, 10), calendar: calendar)
        XCTAssertEqual(model.state.statistics.easterEgg, .sunglasses)
        model.updateStatisticsEasterEgg(days: 0, now: date(9, 11, hour: 0), calendar: calendar)
        XCTAssertNil(model.state.statistics.easterEgg)
        model.updateStatisticsEasterEgg(days: 7, now: date(12, 31), calendar: calendar)
        XCTAssertEqual(model.state.statistics.easterEgg, .christmas)
        model.updateStatisticsEasterEgg(days: 7, now: date(1, 1, hour: 0, year: 2027), calendar: calendar)
        XCTAssertEqual(model.state.statistics.easterEgg, .newYear)
    }

    func testRequestContextRejectsChangedPeriodRangeDayAndTimeZone() {
        func context(days: Int = 0, range: Int = 0, low: Double = 70, high: Double = 180,
                     now: Date, calendar: Calendar) -> RootHomeStatisticsContext {
            RootHomeStatisticsContext(days: days, range: range, lowLimit: low, highLimit: high,
                isMgDl: true, now: now, calendar: calendar)
        }
        let now = date(9, 10)
        let original = context(now: now, calendar: calendar)
        XCTAssertEqual(original, context(now: date(9, 10, hour: 23), calendar: calendar))
        XCTAssertNotEqual(original, context(now: date(9, 11, hour: 0), calendar: calendar))
        XCTAssertNotEqual(original, context(days: 7, now: now, calendar: calendar))
        XCTAssertNotEqual(original, context(range: 1, now: now, calendar: calendar))
        XCTAssertNotEqual(original, context(high: 140, now: now, calendar: calendar))
        XCTAssertNotEqual(original, context(low: 80, now: now, calendar: calendar))
        var utc = calendar
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertNotEqual(original, context(now: now, calendar: utc))
        XCTAssertEqual(context(days: 7, now: now, calendar: calendar),
                       context(days: 7, now: date(9, 11), calendar: calendar))
    }
}
