import Foundation
import XCTest
@testable import xdrip

final class GlucoseTrendTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEveryArrowBoundaryMatchesPhoneThresholds() {
        let cases: [(Double, Int)] = [(-4, 7), (-3.5, 7), (-3.49, 6), (-2, 6), (-1.99, 5),
                                      (-1, 5), (-0.99, 4), (0, 4), (1, 4), (1.01, 3),
                                      (2, 3), (2.01, 2), (3.5, 2), (3.51, 1)]
        for (rate, expected) in cases {
            XCTAssertEqual(GlucoseTrend.ordinal(slope: rate / 60000, hideSlope: false), expected)
            XCTAssertEqual(GlucoseTrend.ordinal(slope: rate / 60000, hideSlope: true), 0)
        }
    }

    func testArrowUsesElapsedTimeBetweenLatestReadings() {
        for seconds in [60.0, 120, 300] {
            let (slope, hidden) = GlucoseTrend.slope(currentValue: 120 + seconds / 60 * 3,
                currentDate: now, previousValue: 120, previousDate: now.addingTimeInterval(-seconds))
            XCTAssertFalse(hidden)
            XCTAssertEqual(slope * 60000, 3, accuracy: 0.000001)
            XCTAssertEqual(GlucoseTrend.ordinal(slope: slope, hideSlope: hidden), 2)
        }
    }

    func testFlatReadingsShowHorizontalArrow() {
        let (slope, hidden) = GlucoseTrend.slope(currentValue: 120, currentDate: now,
            previousValue: 120, previousDate: now.addingTimeInterval(-60))
        XCTAssertEqual(GlucoseTrend.ordinal(slope: slope, hideSlope: hidden), 4)
    }

    func testEqualTimestampsAndGapsBeyondTwentyOneMinutesHideArrow() {
        let intervals: [TimeInterval] = [0, 21 * 60 + 0.001, 22 * 60]
        for seconds in intervals {
            let (slope, hidden) = GlucoseTrend.slope(currentValue: 130, currentDate: now,
                previousValue: 120, previousDate: now.addingTimeInterval(-seconds))
            XCTAssertTrue(hidden)
            XCTAssertEqual(GlucoseTrend.ordinal(slope: slope, hideSlope: hidden), 0)
        }
        let (_, hidden) = GlucoseTrend.slope(currentValue: 130, currentDate: now,
            previousValue: 120, previousDate: now.addingTimeInterval(-21 * 60))
        XCTAssertFalse(hidden)
    }
}
