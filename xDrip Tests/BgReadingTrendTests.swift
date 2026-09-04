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
