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
