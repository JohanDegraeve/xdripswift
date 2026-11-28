//
//  BgReadingTrendTests.swift
//  xdripTests
//
//  Created by Paul Plant on 4/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class BgReadingTrendTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private var coreDataManager: CoreDataManager!

    override func setUp() {
        super.setUp()
        coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
    }

    override func tearDown() {
        coreDataManager = nil
        super.tearDown()
    }

    func testLatestReadingSmoothingReducesIsolatedSpikesAndDrops() {
        XCTAssertEqual(smoothedReading([100, 102, 104, 130]), 122, accuracy: 0.001)
        XCTAssertEqual(smoothedReading([100, 98, 96, 70]), 78, accuracy: 0.001)
        XCTAssertEqual(smoothedReading([100, 102, 104, 130, 108]), 108, accuracy: 0.001)
    }

    func testLatestReadingSmoothingToleratesFiveMinuteCadenceVariation() {
        for interval in [299.0, 301.0] {
            XCTAssertEqual(smoothedReading([98, 100, 102, 104, 130], interval: interval), 122)
            XCTAssertEqual(smoothedReading([98, 100, 102, 104, 130, 132], interval: interval), 132)
        }
    }

    func testLatestReadingSmoothingPassesTrendsAndConfirmedChangesThrough() {
        XCTAssertEqual(smoothedReading([100, 110, 120, 130]), 130)
        XCTAssertEqual(smoothedReading([100, 102, 104, 130, 132]), 132)
        XCTAssertEqual(smoothedReading([100, 98, 96, 70, 68]), 68)
        XCTAssertEqual(smoothedReading([100, 102, 104, 130], interval: 15 * 60), 130)
        XCTAssertEqual(smoothedReading(Array(repeating: 100, count: 12) + [130], interval: 60), 122)
    }

    func testLiveSmoothingPresetsLimitBothDirectionsAndPassSustainedChanges() {
        let expectations: [(LatestReadingSmoothing.Mode, Double, Double, Double)] = [
            (.off, 120, 80, 160),
            (.light, 117, 83, 156),
            (.medium, 114, 86, 152),
            (.strong, 112, 88, 152)
        ]
        for (mode, rise, drop, cappedRise) in expectations {
            XCTAssertEqual(smoothedReading([100, 100, 100, 120], mode: mode), rise, accuracy: 0.001)
            XCTAssertEqual(smoothedReading([100, 100, 100, 80], mode: mode), drop, accuracy: 0.001)
            XCTAssertEqual(smoothedReading([100, 100, 100, 160], mode: mode), cappedRise, accuracy: 0.001)
            XCTAssertEqual(smoothedReading([100, 102, 104, 130, 132], mode: mode), 132)
            XCTAssertEqual(smoothedReading([100, 98, 96, 70, 68], mode: mode), 68)
            XCTAssertEqual(smoothedReading([100, 102, 104, 130], interval: 900, mode: mode), 130)
        }
    }

    func testSmoothingKeepsLiveAndHistoricalValuesSeparate() {
        let current = reading(value: 130, secondsAgo: 0)
        let previous = reading(value: 106, secondsAgo: 300)
        current.adjustedValue = 128
        current.smoothedValue = 120
        let oldState = LatestReadingSmoothing.liveState
        defer { LatestReadingSmoothing.liveState = oldState }
        LatestReadingSmoothing.liveState = .init(readingID: current.id, smoothedValue: 122,
                                                 comparisonID: previous.id, comparisonValue: 106)
        previous.smoothedValue = 111

        XCTAssertEqual(current.calculatedValue, 130)
        XCTAssertEqual(current.finalValue, 122)
        XCTAssertEqual(current.historicalValue, 120)
        XCTAssertEqual(current.baselineValue, 128)
        XCTAssertEqual(current.previousLiveValue(for: previous), 106)
        let attributes = current.entity.attributesByName
        XCTAssertNil(attributes["latestSmoothedValue"])
        XCTAssertNil(attributes["livePreviousValue"])
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "latestReadingSmoothingState"))
    }

    func testGlucoseAlertsEvaluateTheDisplayedReading() {
        let current = reading(value: 70, secondsAgo: 0)
        let previous = reading(value: 100, secondsAgo: 300)
        let context = coreDataManager.mainManagedObjectContext
        let alertType = AlertType(enabled: true, name: "Smoothing test", overrideMute: false, snooze: false,
                                  snoozePeriod: 0, vibrate: false, soundName: nil, alertEntries: nil,
                                  nsManagedObjectContext: context)
        let low = AlertEntry(isDisabled: false, value: 75, triggerValue: 0, alertKind: .low, start: 0,
                             alertType: alertType, nsManagedObjectContext: context)
        let fastDrop = AlertEntry(isDisabled: false, value: 26, triggerValue: 90, alertKind: .fastdrop,
                                  start: 0, alertType: alertType, nsManagedObjectContext: context)

        let oldState = LatestReadingSmoothing.liveState
        defer { LatestReadingSmoothing.liveState = oldState }
        LatestReadingSmoothing.liveState = .init(readingID: current.id, smoothedValue: 78)
        XCTAssertFalse(AlertKind.low.alertNeeded(currentAlertEntry: low, nextAlertEntry: nil, lastBgReading: current,
                                                previous, lastCalibration: nil, transmitterBatteryInfo: nil).alertNeeded)
        XCTAssertFalse(AlertKind.fastdrop.alertNeeded(currentAlertEntry: fastDrop, nextAlertEntry: nil, lastBgReading: current,
                                                     previous, lastCalibration: nil, transmitterBatteryInfo: nil).alertNeeded)

        LatestReadingSmoothing.liveState = .init(readingID: current.id, smoothedValue: 72)
        XCTAssertTrue(AlertKind.low.alertNeeded(currentAlertEntry: low, nextAlertEntry: nil, lastBgReading: current,
                                               previous, lastCalibration: nil, transmitterBatteryInfo: nil).alertNeeded)
        XCTAssertTrue(AlertKind.fastdrop.alertNeeded(currentAlertEntry: fastDrop, nextAlertEntry: nil, lastBgReading: current,
                                                    previous, lastCalibration: nil, transmitterBatteryInfo: nil).alertNeeded)
        XCTAssertEqual(current.calculatedValue, 70)
    }

    private func smoothedReading(_ values: [Double], interval: TimeInterval = 300, mode: LatestReadingSmoothing.Mode = .medium) -> Double {
        let samples = values.enumerated().map {
            LatestReadingSmoothing.Sample(date: now.addingTimeInterval(Double($0.offset) * interval), value: $0.element)
        }
        return LatestReadingSmoothing.value(for: samples[samples.count - 1], previous: Array(samples.dropLast()), mode: mode)
    }

    func testVeryRecentReadingUsesOlderTrendReading() {
        let current = reading(value: 101, secondsAgo: 0)
        let outOfTurnReading = reading(value: 98, secondsAgo: 20)
        let trendReading = reading(value: 97, secondsAgo: 5 * 60)

        let (slope, hideSlope) = current.calculateSlope(lastBgReadings: [outOfTurnReading, trendReading])
        current.calculatedValueSlope = slope
        current.hideSlope = hideSlope

        XCTAssertFalse(hideSlope)
        XCTAssertEqual(slope * 60_000, 0.8, accuracy: 0.001)
        XCTAssertEqual(current.slopeArrow(), "→")
    }

    func testTrendIsHiddenWhenOnlyVeryRecentReadingExists() {
        let current = reading(value: 101, secondsAgo: 0)
        let outOfTurnReading = reading(value: 98, secondsAgo: 20)

        let (slope, hideSlope) = current.calculateSlope(lastBgReadings: [outOfTurnReading])

        XCTAssertEqual(slope, 0)
        XCTAssertTrue(hideSlope)
    }

    func testNearestReadingWithEnoughElapsedTimeIsUsed() {
        let current = reading(value: 101, secondsAgo: 0)
        let olderReading = reading(value: 91, secondsAgo: 10 * 60)
        let nearestTrendReading = reading(value: 97, secondsAgo: 5 * 60)

        let (slope, hideSlope) = current.calculateSlope(lastBgReadings: [olderReading, nearestTrendReading])

        XCTAssertFalse(hideSlope)
        XCTAssertEqual(slope * 60_000, 0.8, accuracy: 0.001)
    }

    func testTrendIsHiddenAcrossLongReadingGap() {
        let current = reading(value: 101, secondsAgo: 0)
        let oldReading = reading(value: 97, secondsAgo: 22 * 60)

        let (slope, hideSlope) = current.calculateSlope(lastBgReadings: [oldReading])

        XCTAssertEqual(slope, 0)
        XCTAssertTrue(hideSlope)
    }

    private func reading(value: Double, secondsAgo: TimeInterval) -> BgReading {
        let bgReading = BgReading(timeStamp: now.addingTimeInterval(-secondsAgo), sensor: nil, calibration: nil, rawData: value, deviceName: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        bgReading.calculatedValue = value
        return bgReading
    }
}

final class BgReadingDownstreamPolicyTests: XCTestCase {
    func testFirstAndNewerVisibleReadingsEnterDownstreamProcessing() {
        let first = Date(timeIntervalSince1970: 2_000_000_000)
        let next = first.addingTimeInterval(5 * 60)

        XCTAssertTrue(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: nil,
            currentVisibleReadingTimeStamp: first
        ))
        XCTAssertTrue(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: first,
            currentVisibleReadingTimeStamp: next
        ))
    }

    func testUnchangedOrHistoricalVisibleReadingDoesNotEnterDownstreamProcessing() {
        let current = Date(timeIntervalSince1970: 2_000_000_000)

        XCTAssertFalse(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: current,
            currentVisibleReadingTimeStamp: current
        ))
        XCTAssertFalse(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: current,
            currentVisibleReadingTimeStamp: current.addingTimeInterval(-5 * 60)
        ))
        XCTAssertFalse(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: current,
            currentVisibleReadingTimeStamp: nil
        ))
    }

    func testManualPostProcessingGateRemainsUnrestricted() {
        XCTAssertTrue(BgPostProcessingDownstreamGate.unrestricted.shouldProcess(currentVisibleReadingTimeStamp: nil))
    }

    func testSuppressedMinuteReadingsDoNotEnterDownstreamProcessing() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let accessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        let firstTimeStamp = Date().addingTimeInterval(-6 * 60)
        let first = reading(timeStamp: firstTimeStamp, value: 100, coreDataManager: coreDataManager)
        coreDataManager.saveChanges()

        let previousVisibleTimeStamp = accessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4).first?.timeStamp
        XCTAssertEqual(previousVisibleTimeStamp, first.timeStamp)

        for minute in 1..<5 {
            let suppressed = reading(
                timeStamp: firstTimeStamp.addingTimeInterval(Double(minute) * 60),
                value: 100,
                coreDataManager: coreDataManager
            )
            suppressed.isSuppressedByFiveMinuteCadence = true
        }
        coreDataManager.saveChanges()

        let visibleTimeStampAfterSuppressedReading = accessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4).first?.timeStamp
        XCTAssertEqual(visibleTimeStampAfterSuppressedReading, first.timeStamp)
        XCTAssertFalse(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: previousVisibleTimeStamp,
            currentVisibleReadingTimeStamp: visibleTimeStampAfterSuppressedReading
        ))

        let nextVisible = reading(timeStamp: firstTimeStamp.addingTimeInterval(5 * 60), value: 100, coreDataManager: coreDataManager)
        coreDataManager.saveChanges()

        let visibleTimeStampAfterNextVisibleReading = accessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4).first?.timeStamp
        XCTAssertEqual(visibleTimeStampAfterNextVisibleReading, nextVisible.timeStamp)
        XCTAssertTrue(BgReadingDownstreamPolicy.shouldProcess(
            previousVisibleReadingTimeStamp: previousVisibleTimeStamp,
            currentVisibleReadingTimeStamp: visibleTimeStampAfterNextVisibleReading
        ))
    }

    private func reading(timeStamp: Date, value: Double, coreDataManager: CoreDataManager) -> BgReading {
        let reading = BgReading(
            timeStamp: timeStamp,
            sensor: nil,
            calibration: nil,
            rawData: value,
            deviceName: "downstream policy test",
            nsManagedObjectContext: coreDataManager.mainManagedObjectContext
        )
        reading.calculatedValue = value
        return reading
    }
}
