//
//  BatteryHistoryTests.swift
//  xdripTests
//
//  Created by Paul Plant on 1/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class BatteryHistoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testAdaptiveRangesReplaceNextUnavailableFixedRangeWithLifetime() {
        XCTAssertEqual(labels(afterDays: 2), ["2d"])
        XCTAssertEqual(labels(afterDays: 3), ["3d"])
        XCTAssertEqual(labels(afterDays: 5), ["3d", "5d"])
        XCTAssertEqual(labels(afterDays: 7), ["3d", "7d"])
        XCTAssertEqual(labels(afterDays: 10), ["3d", "7d", "10d"])
        XCTAssertEqual(labels(afterDays: 12), ["3d", "7d", "12d"])
    }

    func testLifetimeBeyondTwelveDaysRequiresOneHourOfAdditionalWidth() {
        XCTAssertEqual(labels(after: TimeInterval(days: 12) + 3599), ["3d", "7d", "12d"])
        XCTAssertEqual(labels(after: TimeInterval(days: 12) + 3600), ["3d", "7d", "12d", "12d1h"])
    }

    func testAdaptiveRangeIdentityDoesNotCollideWithTruncatedLifetimeLabel() {
        for lifetime in [
            TimeInterval(days: 3) + 1,
            TimeInterval(days: 3) + 3599,
            TimeInterval(days: 7) + 1,
            TimeInterval(days: 7) + 3599,
        ] {
            let ranges = BatteryHistoryRange.available(
                firstObservation: now.addingTimeInterval(-lifetime),
                now: now
            )

            XCTAssertEqual(Set(ranges.map(\.id)).count, ranges.count)
        }
    }

    func testLifetimeChartHasSixHourMinimumDomain() {
        let range = BatteryHistoryRange.lifetime(30 * 60).domain(now: now)
        XCTAssertEqual(range.upperBound.timeIntervalSince(range.lowerBound), 6 * 3600, accuracy: 0.001)
    }

    func testHourlyXAxisIncludesBothEndpointsAndOneMarkForEachIntermediateHour() {
        let start = utcDate(year: 2026, month: 9, day: 1, hour: 12, minute: 30)
        let end = utcDate(year: 2026, month: 9, day: 2, hour: 12, minute: 30)
        let axis = BatteryHistoryXAxis(domain: start ... end, calendar: utcCalendar)

        XCTAssertEqual(axis.dates.first, start)
        XCTAssertEqual(axis.dates.last, end)
        XCTAssertEqual(axis.dates.count, 25)
        XCTAssertEqual(axis.dates.dropFirst().dropLast().map { utcCalendar.component(.minute, from: $0) }, Array(repeating: 0, count: 23))
    }

    func testDailyXAxisIncludesOneMarkForEveryDisplayedCalendarDay() {
        let start = utcDate(year: 2026, month: 9, day: 1, hour: 12, minute: 30)
        let end = utcDate(year: 2026, month: 9, day: 4, hour: 12, minute: 30)
        let axis = BatteryHistoryXAxis(domain: start ... end, calendar: utcCalendar)

        XCTAssertEqual(axis.dates.first, start)
        XCTAssertEqual(axis.dates.last, end)
        XCTAssertEqual(axis.dates.map { utcCalendar.component(.day, from: $0) }, [1, 2, 3, 4])
    }

    func testXAxisLabelsOnlyFirstAndLastMarks() {
        let start = utcDate(year: 2026, month: 9, day: 1, hour: 12, minute: 30)
        let end = utcDate(year: 2026, month: 9, day: 2, hour: 12, minute: 30)
        let axis = BatteryHistoryXAxis(domain: start ... end, calendar: utcCalendar)

        XCTAssertTrue(axis.isEndpoint(start))
        XCTAssertTrue(axis.isEndpoint(end))
        XCTAssertTrue(axis.dates.dropFirst().dropLast().allSatisfy { !axis.isEndpoint($0) })
        XCTAssertEqual(axis.endpointDates, [start, end])
    }

    func testStandardBatteryParserAcceptsZeroAndRejectsMalformedValues() {
        XCTAssertEqual(StandardBluetoothBatteryLevel.percentage(from: Data([0])), 0)
        XCTAssertEqual(StandardBluetoothBatteryLevel.percentage(from: Data([100])), 100)
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: Data([101])))
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: Data([50, 51])))
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: nil))
    }

    func testPercentageThresholdsMatchBluetoothBatteryPresentation() {
        XCTAssertEqual(BluetoothBatteryLevelPresentation.urgentUpperBound, 10)
        XCTAssertEqual(BluetoothBatteryLevelPresentation.warningUpperBound, 25)
        XCTAssertEqual(BluetoothBatteryLevelPresentation.chartThresholds, [10, 25])
    }

    func testDexcomThresholdsRemainFamilySpecific() {
        XCTAssertEqual(DexcomBatteryFamily.g5.redBelow, 270)
        XCTAssertEqual(DexcomBatteryFamily.g5.greenFrom, 280)
        XCTAssertEqual(DexcomBatteryFamily.g7.redBelow, 215)
        XCTAssertEqual(DexcomBatteryFamily.g7.greenFrom, 250)
    }

    func testActiveDexcomBatteryStartDateUsesTheFamilyHardwareClock() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DexcomBatteryStartDateTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("xdrip.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let coreDataManager = try CoreDataManager(
            testModelName: ConstantsCoreData.modelName,
            persistentStoreURL: storeURL
        )
        defer { try? coreDataManager.disconnectPersistentStoresForTesting() }

        let g6StartDate = now.addingTimeInterval(-2 * 60 * 60)
        let g7StartDate = now.addingTimeInterval(-3 * 60 * 60)
        let g6 = DexcomG5(
            address: "dexcom-g6-battery-alert-test",
            name: "DexcomAB",
            alias: nil,
            nsManagedObjectContext: coreDataManager.mainManagedObjectContext
        )
        let g7 = DexcomG7(
            address: "dexcom-g7-battery-alert-test",
            name: "DXCMAB",
            alias: nil,
            nsManagedObjectContext: coreDataManager.mainManagedObjectContext
        )
        g6.transmitterStartDate = g6StartDate
        g7.sensorStartDate = g7StartDate

        // Only the enabled CGM supplies the age used by its family-specific battery alarm.
        g6.blePeripheral.shouldconnect = true
        g7.blePeripheral.shouldconnect = false
        let accessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
        XCTAssertEqual(accessor.activeDexcomBatteryStartDate(for: .g5), g6StartDate)
        XCTAssertNil(accessor.activeDexcomBatteryStartDate(for: .g7))

        g6.blePeripheral.shouldconnect = false
        g7.blePeripheral.shouldconnect = true
        XCTAssertNil(accessor.activeDexcomBatteryStartDate(for: .g5))
        XCTAssertEqual(accessor.activeDexcomBatteryStartDate(for: .g7), g7StartDate)
    }

    func testRecordedSampleSurvivesCoreDataStackRecreation() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatteryHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("xdrip.sqlite")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let address = "battery-history-test-peripheral"
        let observedAt = utcDate(year: 2026, month: 9, day: 3, hour: 12, minute: 30)

        // Create and commit the peripheral in its own stack first. Real battery callbacks refer to
        // devices loaded from the application store and therefore always carry a permanent ID.
        try autoreleasepool {
            let coreDataManager = try CoreDataManager(
                testModelName: ConstantsCoreData.modelName,
                persistentStoreURL: storeURL
            )
            defer { try? coreDataManager.disconnectPersistentStoresForTesting() }

            _ = Libre2HeartBeat(
                address: address,
                name: "Battery History Test",
                alias: nil,
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext
            )
            XCTAssertTrue(coreDataManager.saveChangesSynchronously())
        }

        // A second stack records against the persisted peripheral and flushes the observation all
        // the way through the private context before it disconnects from the SQLite store.
        try autoreleasepool {
            let coreDataManager = try CoreDataManager(
                testModelName: ConstantsCoreData.modelName,
                persistentStoreURL: storeURL
            )
            defer { try? coreDataManager.disconnectPersistentStoresForTesting() }

            let peripheral = try XCTUnwrap(
                BLEPeripheralAccessor(coreDataManager: coreDataManager)
                    .getBLEPeripherals()
                    .first { $0.address == address }
            )
            XCTAssertFalse(peripheral.objectID.isTemporaryID)

            BatteryHistoryManager(coreDataManager: coreDataManager).record(
                peripheralObjectID: peripheral.objectID,
                observedAt: observedAt,
                observation: .percentage(value: 42, producer: .genericHeartbeat)
            )

            XCTAssertEqual(
                BatteryHistoryManager(coreDataManager: coreDataManager)
                    .history(peripheralObjectID: peripheral.objectID)
                    .count,
                1
            )
        }

        // A third stack can see only committed store data, matching an app process restarted by an
        // over-the-top build rather than either earlier context's registered managed objects.
        try autoreleasepool {
            let coreDataManager = try CoreDataManager(
                testModelName: ConstantsCoreData.modelName,
                persistentStoreURL: storeURL
            )
            defer { try? coreDataManager.disconnectPersistentStoresForTesting() }

            let peripheral = try XCTUnwrap(
                BLEPeripheralAccessor(coreDataManager: coreDataManager)
                    .getBLEPeripherals()
                    .first { $0.address == address }
            )
            let point = try XCTUnwrap(
                BatteryHistoryManager(coreDataManager: coreDataManager)
                    .history(peripheralObjectID: peripheral.objectID)
                    .first
            )

            XCTAssertEqual(point.observedAt, observedAt)
            XCTAssertEqual(point.kind, .percentage)
            XCTAssertEqual(point.percentage, 42)
            XCTAssertNil(point.family)
            XCTAssertNil(point.voltageA)
            XCTAssertNil(point.voltageB)
        }
    }

    func testDexcomHistoryBeforeFirstReadSurvivesReopening() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatteryHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let storeURL = directoryURL.appendingPathComponent("xdrip.sqlite")
        let dates = (0..<12).map { now.addingTimeInterval(Double($0 - 11) * 7200) }

        try autoreleasepool {
            let core = try CoreDataManager(testModelName: ConstantsCoreData.modelName, persistentStoreURL: storeURL)
            defer { try? core.disconnectPersistentStoresForTesting() }
            let device = DexcomG7(address: "battery-g7", name: "DX02z1", alias: nil, nsManagedObjectContext: core.mainManagedObjectContext)
            XCTAssertTrue(core.saveChanges())
            XCTAssertFalse(device.blePeripheral.objectID.isTemporaryID)
            let manager = BatteryHistoryManager(coreDataManager: core)
            // Record a full day of identical voltages without ever querying history or opening UI.
            for date in dates {
                manager.record(peripheralObjectID: device.blePeripheral.objectID, observedAt: date,
                               observation: .dexcom(family: .g7, status: 0, voltageA: 289, voltageB: 273,
                                                    resistance: 0, runtime: 0, temperature: 25, producer: .dexcomG7))
            }
            XCTAssertTrue(core.saveChangesSynchronously())
        }

        try autoreleasepool {
            let core = try CoreDataManager(testModelName: ConstantsCoreData.modelName, persistentStoreURL: storeURL)
            defer { try? core.disconnectPersistentStoresForTesting() }
            let device = try XCTUnwrap(BLEPeripheralAccessor(coreDataManager: core).getBLEPeripherals().first)
            let points = BatteryHistoryManager(coreDataManager: core).history(peripheralObjectID: device.objectID)
            XCTAssertEqual(points.map(\.observedAt), dates)
            XCTAssertEqual(points.map(\.voltageB), Array(repeating: 273, count: dates.count))
        }
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func labels(afterDays days: Double) -> [String] {
        labels(after: TimeInterval(days: days))
    }

    private func labels(after lifetime: TimeInterval) -> [String] {
        BatteryHistoryRange.available(firstObservation: now.addingTimeInterval(-lifetime), now: now).map(\.label)
    }
}
