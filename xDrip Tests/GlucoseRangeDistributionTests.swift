//
//  GlucoseRangeDistributionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 01/09/2026.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class GlucoseRangeDistributionTests: XCTestCase {
    func testLargestRemainderPreventsIndependentRoundingFromProducing101Percent() {
        XCTAssertEqual(
            ProportionalIntegerAllocator.allocate([3.6, 87.6, 8.8]),
            [4, 87, 9]
        )
    }

    func testLargestRemainderPreventsIndependentRoundingFromProducing99Percent() {
        let allocated = ProportionalIntegerAllocator.allocate([33.4, 33.3, 33.3])

        XCTAssertEqual(allocated, [34, 33, 33])
        XCTAssertEqual(allocated.reduce(0, +), 100)
    }

    func testAllocatorNormalizesWeightsThatDoNotAlreadyTotal100() {
        XCTAssertEqual(ProportionalIntegerAllocator.allocate([1, 2, 1]), [25, 50, 25])
    }

    func testAllocatorUsesStableInputOrderForEqualRemainders() {
        XCTAssertEqual(ProportionalIntegerAllocator.allocate([1, 1, 1]), [34, 33, 33])
    }

    func testAllocatorPreservesTinyNonZeroCategoryWhenItsRemainderEarnsAUnit() {
        let allocated = ProportionalIntegerAllocator.allocate([0.8, 98.4, 0.8])

        XCTAssertEqual(allocated, [1, 98, 1])
        XCTAssertEqual(allocated.reduce(0, +), 100)
    }

    func testAllocatorTreatsInvalidAndNegativeInputsAsZero() {
        XCTAssertEqual(
            ProportionalIntegerAllocator.allocate([-Double.infinity, .nan, -1, 4]),
            [0, 0, 0, 100]
        )
    }

    func testAllocatorReturnsZeroesWhenThereIsNoDistribution() {
        XCTAssertEqual(ProportionalIntegerAllocator.allocate([]), [])
        XCTAssertEqual(ProportionalIntegerAllocator.allocate([0, 0, 0]), [0, 0, 0])
    }

    func testClinicalMinuteAllocationAlwaysTotalsOneDay() {
        let distribution = GlucoseRangeDistribution(below: 3.6, inRange: 87.6, above: 8.8)
        let minutes = distribution.allocatedUnits(total: 24 * 60)

        XCTAssertEqual(minutes.reduce(0, +), 1_440)
    }

    func testClinicalTIRBucketsShareWholePercentAndMinuteAllocation() {
        let reportDistribution = GlucoseReportRangeDistribution(
            veryLow: 1.1,
            low: 2.5,
            target: 87.6,
            high: 5.8,
            veryHigh: 3.0
        )
        let buckets = reportDistribution.timeInRangeBuckets(usesMgDl: true)

        XCTAssertEqual(buckets.map(\.wholePercentage), [4, 87, 9])
        XCTAssertEqual(buckets.map(\.wholePercentage).reduce(0, +), 100)
        XCTAssertEqual(buckets.map(\.minutesPerDay).reduce(0, +), 1_440)
        XCTAssertEqual(buckets.map(\.percentage).reduce(0, +), 100, accuracy: 0.000_001)
    }

    func testClinicalTightRangeBucketsAlsoTotal100Percent() {
        let reportDistribution = GlucoseReportRangeDistribution.tightRange(
            below: 11.4,
            target: 77.3,
            above: 11.3
        )
        let buckets = reportDistribution.tightRangeBuckets(usesMgDl: true)

        XCTAssertEqual(buckets.map(\.wholePercentage).reduce(0, +), 100)
        XCTAssertEqual(buckets.map(\.minutesPerDay).reduce(0, +), 1_440)
    }

    func testGlucoseValuesOnLimitsAreInRange() {
        let distribution = GlucoseRangeDistribution(
            values: [53, 54, 69, 70, 180, 181, 250],
            lowLimit: 70,
            highLimit: 180
        )

        XCTAssertEqual(distribution.belowPercentage, 3.0 / 7.0 * 100, accuracy: 0.000_001)
        XCTAssertEqual(distribution.inRangePercentage, 2.0 / 7.0 * 100, accuracy: 0.000_001)
        XCTAssertEqual(distribution.abovePercentage, 2.0 / 7.0 * 100, accuracy: 0.000_001)
        XCTAssertEqual(distribution.wholePercentages.reduce(0, +), 100)
    }

    func testInvalidRangeProducesEmptyDistribution() {
        let distribution = GlucoseRangeDistribution(values: [100], lowLimit: 180, highLimit: 70)

        XCTAssertEqual(distribution, GlucoseRangeDistribution(below: 0, inRange: 0, above: 0))
        XCTAssertEqual(distribution.wholePercentages, [0, 0, 0])
    }

    func testClinicalRangeSummaryCalculatesBothModesFromTheSameSamples() {
        let summary = GlucoseClinicalRangeSummary(valuesMgDl: [69, 70, 140, 141, 181])

        XCTAssertEqual(summary.timeInRange.wholePercentages, [20, 60, 20])
        XCTAssertEqual(summary.timeInTightRange.wholePercentages, [20, 40, 40])
    }

    func testEmptyClinicalRangeSummaryProducesNoPercentages() {
        XCTAssertEqual(GlucoseClinicalRangeSummary.empty.timeInRange.wholePercentages, [0, 0, 0])
        XCTAssertEqual(GlucoseClinicalRangeSummary.empty.timeInTightRange.wholePercentages, [0, 0, 0])
    }
}
