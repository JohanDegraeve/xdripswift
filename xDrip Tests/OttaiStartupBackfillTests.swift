//
//  OttaiStartupBackfillTests.swift
//  xdripTests
//
//  Covers what the Ottai/Syai driver asks the sensor for right after a start.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class OttaiStartupBackfillTests: XCTestCase {

    private let dayOfRecords = 24 * 60

    func testNothingKnownAsksForTheLastDay() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 0, deliveredDataNo: 0)
        XCTAssertEqual(range?.start, 5000 - dayOfRecords)
        XCTAssertEqual(range?.count, dayOfRecords)
    }

    func testUntrustedLastDataNoAlsoAsksForTheLastDay() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: -1, deliveredDataNo: 4990)
        XCTAssertEqual(range?.start, 5000 - dayOfRecords)
        XCTAssertEqual(range?.count, dayOfRecords)
    }

    func testYoungSensorStartsAtZero() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 30, lastDataNo: 0, deliveredDataNo: 0)
        XCTAssertEqual(range?.start, 0)
        XCTAssertEqual(range?.count, 30)
    }

    func testOnlyTheRecordsSinceTheLastSeenOneAreRequested() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 4990, deliveredDataNo: 4990)
        XCTAssertEqual(range?.start, 4991)
        XCTAssertEqual(range?.count, 9)
    }

    func testDeliveredMarkBehindLastSeenWins() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 4998, deliveredDataNo: 4980)
        XCTAssertEqual(range?.start, 4981)
        XCTAssertEqual(range?.count, 19)
    }

    func testMissingDeliveredMarkFallsBackToLastSeen() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 4990, deliveredDataNo: 0)
        XCTAssertEqual(range?.start, 4991)
        XCTAssertEqual(range?.count, 9)
    }

    func testNothingMissingGivesNil() {
        XCTAssertNil(CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 4999, deliveredDataNo: 4999))
        XCTAssertNil(CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 4999, deliveredDataNo: 0))
    }

    func testLastSeenSlightlyAheadOfLiveGivesNil() {
        XCTAssertNil(CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5000, lastDataNo: 5003, deliveredDataNo: 5003))
    }

    func testLongAbsenceIsCappedToOneDay() {
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 9000, lastDataNo: 2000, deliveredDataNo: 2000)
        XCTAssertEqual(range?.start, 9000 - dayOfRecords)
        XCTAssertEqual(range?.count, dayOfRecords)
    }

    func testEndedSensorIncludesItsLastRecordWhenNeverDelivered() {
        // The ended path passes lastDataNo + 1 as the end, so the last record itself is inside the range.
        let range = CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 5001, lastDataNo: 4990, deliveredDataNo: 4990)
        XCTAssertEqual(range?.start, 4991)
        XCTAssertEqual(range?.count, 10)
    }

    func testNoLiveRecordGivesNil() {
        XCTAssertNil(CGMOttaiTransmitter.startupBackfillRange(liveDataNo: 0, lastDataNo: 0, deliveredDataNo: 0))
    }
}
