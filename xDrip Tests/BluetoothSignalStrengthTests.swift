//
//  BluetoothSignalStrengthTests.swift
//  xdrip
//
//  Created by Paul Plant on 11/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class BluetoothSignalStrengthTests: XCTestCase {
    func testUnavailableValuesAreRejected() {
        for value in [-128, 1, 127] {
            XCTAssertNil(BluetoothSignalStrength(rssi: value))
        }
        XCTAssertNotNil(BluetoothSignalStrength(rssi: -127))
        XCTAssertNotNil(BluetoothSignalStrength(rssi: 0))
    }

    func testInitialThresholdBoundaries() {
        XCTAssertEqual(BluetoothSignalStrength(rssi: -95)?.band, .strong)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -96)?.band, .moderate)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -110)?.band, .moderate)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -111)?.band, .weak)
    }

    func testHysteresisInBothDirections() {
        let strong = BluetoothSignalStrength(rssi: -93)!
        XCTAssertEqual(BluetoothSignalStrength(rssi: -97, previous: strong)?.band, .strong)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -98, previous: strong)?.band, .moderate)
        let moderate = BluetoothSignalStrength(rssi: -103)!
        XCTAssertEqual(BluetoothSignalStrength(rssi: -94, previous: moderate)?.band, .moderate)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -93, previous: moderate)?.band, .strong)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -112, previous: moderate)?.band, .moderate)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -113, previous: moderate)?.band, .weak)
        let weak = BluetoothSignalStrength(rssi: -115)!
        XCTAssertEqual(BluetoothSignalStrength(rssi: -109, previous: weak)?.band, .weak)
        XCTAssertEqual(BluetoothSignalStrength(rssi: -108, previous: weak)?.band, .moderate)
    }

    func testOldMeasurementDoesNotInfluenceNewBand() {
        let now = Date()
        let old = BluetoothSignalStrength(rssi: -85, measuredAt: now.addingTimeInterval(-15))!
        XCTAssertEqual(BluetoothSignalStrength(rssi: -96, measuredAt: now, previous: old)?.band, .moderate)
    }

    func testFutureMeasurementDoesNotInfluenceNewBand() {
        let now = Date()
        let future = BluetoothSignalStrength(rssi: -85, measuredAt: now.addingTimeInterval(1))!
        XCTAssertEqual(BluetoothSignalStrength(rssi: -96, measuredAt: now, previous: future)?.band, .moderate)
    }

    func testGaugeTransitionsRemainOrderedAcrossFullValidRange() {
        var gauge = BluetoothSignalStrengthGauge()
        for rssi in [-127, 0] {
            gauge.observe(BluetoothSignalStrength(rssi: rssi))
        }
        let positions = [-112, -108, -97, -93].map { gauge.position(for: $0) }
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(positions.allSatisfy { (0...1).contains($0) })
        XCTAssertGreaterThan(gauge.position(for: -127), 0)
        XCTAssertLessThan(gauge.position(for: 0), 1)
    }

    func testGaugeExpandsWithTwoDBmMarginAndResetsOnNewVisit() {
        var gauge = BluetoothSignalStrengthGauge()
        XCTAssertEqual(gauge.lowerBound, -120)
        XCTAssertEqual(gauge.upperBound, -80)
        gauge.observe(BluetoothSignalStrength(rssi: -78))
        XCTAssertEqual(gauge.upperBound, -76)
        XCTAssertEqual(gauge.position(for: -78), 42.0 / 44.0)
        gauge.observe(BluetoothSignalStrength(rssi: -122))
        XCTAssertEqual(gauge.lowerBound, -124)
        XCTAssertEqual(gauge.position(for: -122), 2.0 / 48.0)

        // New extremes inside the existing bounds still need a full margin.
        for rssi in [-124, -76, -95] {
            gauge.observe(BluetoothSignalStrength(rssi: rssi))
        }
        gauge.observe(nil)
        XCTAssertEqual(gauge.lowerBound, -126)
        XCTAssertEqual(gauge.upperBound, -74)

        gauge.observe(BluetoothSignalStrength(rssi: -74))
        XCTAssertEqual(gauge.upperBound, -72)
        gauge.observe(BluetoothSignalStrength(rssi: -126))
        XCTAssertEqual(gauge.lowerBound, -128)
        XCTAssertEqual(gauge.position(for: -126), 2.0 / 56.0)
        XCTAssertEqual(gauge.position(for: -140), 0)
        XCTAssertEqual(gauge.position(for: 0), 1)
        gauge = BluetoothSignalStrengthGauge()
        XCTAssertEqual(gauge.lowerBound, -120)
        XCTAssertEqual(gauge.upperBound, -80)
    }

    func testGaugeMaintainsPaddingAtInitialAndExpandedEdges() {
        var gauge = BluetoothSignalStrengthGauge()
        // Include exact initial bounds, the screenshot sequence and repeated interior readings.
        for rssi in [-80, -120, -63, -62, -61, -60, -123, -126, -127, -92, -92, 0] {
            let previousLower = gauge.lowerBound
            let previousUpper = gauge.upperBound
            gauge.observe(BluetoothSignalStrength(rssi: rssi))
            XCTAssertGreaterThanOrEqual(gauge.minimumRSSI! - gauge.lowerBound, 2)
            XCTAssertGreaterThanOrEqual(gauge.upperBound - gauge.maximumRSSI!, 2)
            XCTAssertLessThanOrEqual(gauge.lowerBound, previousLower)
            XCTAssertGreaterThanOrEqual(gauge.upperBound, previousUpper)
            if rssi == -60 { XCTAssertEqual(gauge.upperBound, -58) }
        }
    }

    func testGaugeRemembersActualExtremesAndResetsBothOnNewVisit() {
        var gauge = BluetoothSignalStrengthGauge()
        gauge.observe(nil)
        XCTAssertNil(gauge.minimumRSSI)
        XCTAssertNil(gauge.maximumRSSI)
        gauge.observe(BluetoothSignalStrength(rssi: -100))
        XCTAssertEqual(gauge.minimumRSSI, -100)
        XCTAssertEqual(gauge.maximumRSSI, -100)
        gauge.observe(BluetoothSignalStrength(rssi: -125))
        gauge.observe(BluetoothSignalStrength(rssi: -70))
        gauge.observe(BluetoothSignalStrength(rssi: -95))
        gauge.observe(nil)
        XCTAssertEqual(gauge.minimumRSSI, -125)
        XCTAssertEqual(gauge.maximumRSSI, -70)
        XCTAssertEqual(gauge.lowerBound, -127)
        XCTAssertEqual(gauge.upperBound, -68)
        XCTAssertEqual(gauge.position(for: gauge.minimumRSSI!), 2.0 / 59.0)
        XCTAssertEqual(gauge.position(for: gauge.maximumRSSI!), 57.0 / 59.0)
        gauge = BluetoothSignalStrengthGauge()
        XCTAssertNil(gauge.minimumRSSI)
        XCTAssertNil(gauge.maximumRSSI)
        gauge.observe(BluetoothSignalStrength(rssi: -95))
        XCTAssertEqual(gauge.minimumRSSI, -95)
        XCTAssertEqual(gauge.maximumRSSI, -95)
    }

    func testMeasurementRemainsCurrentForFiveAndAHalfMinutes() {
        let now = Date()
        let sample = BluetoothSignalStrength(rssi: -68, measuredAt: now)!
        XCTAssertTrue(sample.isCurrent(now: now.addingTimeInterval(329)))
        XCTAssertFalse(sample.isCurrent(now: now.addingTimeInterval(330)))
        XCTAssertFalse(sample.isCurrent(now: now.addingTimeInterval(-1)))
    }

    func testHistoryRejectsCachedDuplicateAndFutureMeasurements() {
        let now = Date()
        var history = BluetoothSignalStrengthHistory(startedAt: now)
        history.update(sample: BluetoothSignalStrength(rssi: -60, measuredAt: now.addingTimeInterval(-1)), now: now)
        history.update(sample: BluetoothSignalStrength(rssi: -60, measuredAt: now.addingTimeInterval(1)), now: now)
        XCTAssertTrue(history.points.isEmpty)
        let sample = BluetoothSignalStrength(rssi: -68, measuredAt: now)!
        history.update(sample: sample, now: now)
        history.update(sample: sample, now: now.addingTimeInterval(5))
        XCTAssertEqual(history.points.count, 1)
        XCTAssertEqual(history.points.first?.sample.measuredAt, now)
    }

    func testHistoryDropsOldPointsEvenWithoutNewMeasurements() {
        let now = Date()
        var history = BluetoothSignalStrengthHistory(startedAt: now)
        for second in stride(from: 0, through: 180, by: 5) {
            let date = now.addingTimeInterval(Double(second))
            history.update(sample: BluetoothSignalStrength(rssi: -68, measuredAt: date), now: date)
        }
        XCTAssertEqual(history.points.count, 25)
        XCTAssertEqual(history.points.first?.sample.measuredAt, now.addingTimeInterval(60))
        history.update(sample: nil, now: now.addingTimeInterval(301))
        XCTAssertTrue(history.points.isEmpty)
    }

    func testHistoryRetainsMeasurementsOnBothSidesOfGap() {
        let now = Date()
        var history = BluetoothSignalStrengthHistory(startedAt: now)
        for second in [0, 5, 25] {
            let date = now.addingTimeInterval(Double(second))
            history.update(sample: BluetoothSignalStrength(rssi: -68, measuredAt: date), now: date)
        }
        XCTAssertEqual(history.points.map { $0.sample.measuredAt.timeIntervalSince(now) }, [0, 5, 25])
    }
    func testTraceRequestsUseFiveMinuteCadence() {
        var cadence = BluetoothSignalStrengthTraceCadence()
        XCTAssertTrue(cadence.requestIsDue(at: 100))
        cadence.didRequest(at: 100)
        XCTAssertFalse(cadence.requestIsDue(at: 100))
        XCTAssertFalse(cadence.requestIsDue(at: 399.9))
        XCTAssertTrue(cadence.requestIsDue(at: 400))
    }

    func testFrequentUIRequestsDoNotFloodLogsOrNeedActivityRequests() {
        var cadence = BluetoothSignalStrengthTraceCadence()
        var logged = [Int]()
        for second in 0...600 {
            cadence.didRequest(at: Double(second))
            XCTAssertFalse(cadence.requestIsDue(at: Double(second)))
            if cadence.shouldLogResult(at: Double(second)) { logged.append(second) }
        }
        XCTAssertEqual(logged, [0, 300, 600])
        XCTAssertFalse(cadence.requestIsDue(at: 899))
        XCTAssertTrue(cadence.requestIsDue(at: 900))
    }

    func testMissingCallbacksDoNotCauseImmediateRetries() {
        var cadence = BluetoothSignalStrengthTraceCadence()
        cadence.didRequest(at: 0)
        // No result arrives. Normal activity can retry after five minutes, without a watchdog.
        XCTAssertFalse(cadence.requestIsDue(at: 10))
        XCTAssertTrue(cadence.requestIsDue(at: 300))
        cadence.didRequest(at: 300)
        XCTAssertTrue(cadence.shouldLogResult(at: 301))
        XCTAssertFalse(cadence.shouldLogResult(at: 302))
    }

    func testTraceCadenceIsIndependentForEachTransmitter() {
        var first = BluetoothSignalStrengthTraceCadence()
        var second = BluetoothSignalStrengthTraceCadence()
        first.didRequest(at: 0)
        XCTAssertTrue(first.shouldLogResult(at: 1))
        XCTAssertTrue(second.requestIsDue(at: 1))
        XCTAssertTrue(second.shouldLogResult(at: 1))
    }

}
