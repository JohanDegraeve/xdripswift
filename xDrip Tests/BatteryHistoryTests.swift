//
//  BatteryHistoryTests.swift
//  xdripTests
//
//  Created by Paul Plant on 1/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import XCTest
@testable import xdrip

final class BatteryHistoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testBatteryHistoryModelSupportsLightweightMigration() throws {
        let directory = try XCTUnwrap(Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd"))
        let previous = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("xdrip v31.mom")))
        let current = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("xdrip v32.mom")))
        XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: previous, destinationModel: current))
        let entity = try XCTUnwrap(current.entitiesByName["BatteryHistorySample"])
        XCTAssertTrue(try XCTUnwrap(entity.relationshipsByName["blePeripheral"]).isOptional)
        XCTAssertTrue(try XCTUnwrap(entity.attributesByName["peripheralAddress"]).isOptional)
    }

    func testBackupFiltersRuntimeAndLegacyCredentialsButKeepsPreferences() {
        for key in ["nightscoutFollowerGapFillCoverageV2", "nightscoutFollowerGapFillSite",
                    "nightscoutFollowerGapFillLastAuditEndDate", "careLinkTimestampRepairCompleted",
                    "careLinkPatientAliases", "pendingHealthKitReplacements", "healthKitSyncVersion",
                    "dexcomG7PairingCode-ABC", "dexcomG7BluetoothSlot-ABC", "m5StackWiFiPassword1",
                    "m5StackWiFiPassword2", "m5StackWiFiPassword3", "careLinkPassword"] {
            XCTAssertFalse(BackupService.isPortableSetting(key), key)
        }
        for key in ["speakReadingsScheduleEnabled", "localInsulinPeak", "showIOBCOB", "carPlayLiveActivityType"] {
            XCTAssertTrue(BackupService.isPortableSetting(key), key)
        }
    }

    @MainActor
    func testBatteryBackupRestoresWithoutCreatingDeviceAndMergesRepeatedImports() async throws {
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = core.mainManagedObjectContext
        let service = BackupService(coreDataManager: core)
        let record = BackupBatteryHistorySample(
            id: "battery-backup", peripheralAddress: "ABC", observedAt: now,
            measurementKindRaw: BatteryMeasurementKind.percentage.rawValue, producerKindRaw: 0,
            percentage: 42, batteryStatusRaw: nil, dexcomFamilyRaw: nil, resistanceRaw: nil,
            runtimeRaw: nil, temperatureRaw: nil, voltageARaw: nil, voltageBRaw: nil,
            utcHourBucketStart: now
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(BackupBatteryHistorySample.self, from: data)
        try service.restoreBatteryHistory([decoded], mode: .keepCurrent, context: context)
        try context.save()
        try service.restoreBatteryHistory([decoded], mode: .fillGaps, context: context)
        XCTAssertEqual(try context.count(for: BatteryHistorySample.fetchRequest()), 1)
        XCTAssertEqual(try context.count(for: BLEPeripheral.fetchRequest()), 0)
        let sample = try XCTUnwrap(context.fetch(BatteryHistorySample.fetchRequest()).first)
        XCTAssertNil(sample.blePeripheral)
        XCTAssertEqual(sample.peripheralAddress, "ABC")
        XCTAssertEqual(sample.percentage?.intValue, 42)
        let archive = try await service.createBackup(options: BackupOptions(
            includesSettings: false, includesAccounts: false, includesBgReadings: true, includesTreatments: false
        ))
        defer { try? FileManager.default.removeItem(at: archive.url) }
        let inspection = try service.inspectBackup(at: archive.url)
        XCTAssertEqual(inspection.payload.batteryHistory?.first?.peripheralAddress, "ABC")
        XCTAssertEqual(inspection.payload.batteryHistory?.first?.percentage, 42)
        let device = DexcomG7(address: "abc", name: "DXCM01", alias: nil, nsManagedObjectContext: context)
        XCTAssertTrue(core.saveChangesSynchronously())
        let manager = BatteryHistoryManager(coreDataManager: core)
        XCTAssertTrue(manager.hasHistory(peripheralObjectID: device.blePeripheral.objectID))
        XCTAssertEqual(manager.history(peripheralObjectID: device.blePeripheral.objectID).first?.percentage, 42)
        try service.restoreBatteryHistory([], mode: .replaceRange, context: context)
        XCTAssertEqual(try context.count(for: BatteryHistorySample.fetchRequest()), 1)
        try service.restoreBatteryHistory([decoded], mode: .replaceRange, context: context)
        try context.save()
        XCTAssertEqual(try context.count(for: BatteryHistorySample.fetchRequest()), 1)
    }

    @MainActor
    func testRestoreDoesNotCopyRuntimeValuesFromOlderSettings() async throws {
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let service = BackupService(coreDataManager: core)
        let archive = try await service.createBackup(options: BackupOptions(
            includesSettings: true, includesAccounts: false, includesBgReadings: false, includesTreatments: false
        ))
        defer { try? FileManager.default.removeItem(at: archive.url) }
        let manifest = try service.inspectBackup(at: archive.url).payload.manifest
        let keys = ["healthKitSyncVersion", "m5StackWiFiPassword1", "dexcomG7PairingCode-TEST"]
        let defaults = UserDefaults.standard
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.set("destination", forKey: key) }
        let settings = try Dictionary(uniqueKeysWithValues: keys.map { ($0, try BackupPropertyListValue("source")) })
        let payload = BackupPayload(manifest: manifest, settings: settings, accounts: nil, alertTypes: [],
                                    bgReadings: [], treatments: [], deviceStatuses: nil, profiles: nil)
        _ = try await service.restore(inspection: BackupInspection(payload: payload), mode: .ignore,
                                      restoresSettings: true, restoredAccountCategories: [])
        for key in keys { XCTAssertEqual(defaults.string(forKey: key), "destination") }
    }

    func testBatteryRestoreDerivesMissingHourAndLimitsReplacementToOneDevice() throws {
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = core.mainManagedObjectContext
        let service = BackupService(coreDataManager: core)
        let hour = BatteryHistoryManager.utcHourStart(for: now)
        func record(_ id: String, address: String, date: Date, percentage: Int) -> BackupBatteryHistorySample {
            BackupBatteryHistorySample(id: id, peripheralAddress: address, observedAt: date,
                measurementKindRaw: BatteryMeasurementKind.percentage.rawValue, producerKindRaw: 0,
                percentage: percentage, batteryStatusRaw: nil, dexcomFamilyRaw: nil, resistanceRaw: nil,
                runtimeRaw: nil, temperatureRaw: nil, voltageARaw: nil, voltageBRaw: nil, utcHourBucketStart: nil)
        }
        let first = record("first", address: "ABC", date: hour, percentage: 40)
        let duplicateHour = record("same-hour", address: "abc", date: hour.addingTimeInterval(60), percentage: 41)
        let otherDevice = record("other", address: "DEF", date: hour, percentage: 50)
        let outside = record("outside", address: "ABC", date: hour.addingTimeInterval(7200), percentage: 60)
        try service.restoreBatteryHistory([first, otherDevice, outside], mode: .keepCurrent, context: context)
        try service.restoreBatteryHistory([duplicateHour], mode: .fillGaps, context: context)
        XCTAssertEqual(try context.count(for: BatteryHistorySample.fetchRequest()), 3)
        let replacement = record("replacement", address: "ABC", date: hour, percentage: 45)
        try service.restoreBatteryHistory([replacement], mode: .ignore, context: context)
        XCTAssertFalse(try context.fetch(BatteryHistorySample.fetchRequest()).contains { $0.id == "replacement" })
        try service.restoreBatteryHistory([replacement], mode: .replaceRange, context: context)
        try context.save()
        let samples = try context.fetch(BatteryHistorySample.fetchRequest())
        XCTAssertEqual(Set(samples.map(\.id)), ["replacement", "other", "outside"])
        XCTAssertEqual(samples.first { $0.id == "replacement" }?.utcHourBucketStart, hour)
    }

    @MainActor
    func testMissingSettingsPreserveAlertsAndEncryptedBackupRoundTrips() async throws {
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = core.mainManagedObjectContext
        let service = BackupService(coreDataManager: core)
        _ = AlertType(enabled: true, name: "Keep this alert", overrideMute: false, snooze: true,
                      snoozePeriod: 15, vibrate: false, soundName: nil, alertEntries: nil,
                      nsManagedObjectContext: context)
        XCTAssertTrue(core.saveChangesSynchronously())
        let archive = try await service.createBackup(options: BackupOptions(
            includesSettings: false, includesAccounts: false, includesBgReadings: false,
            includesTreatments: false, passphrase: "backup-test"
        ))
        defer { try? FileManager.default.removeItem(at: archive.url) }
        XCTAssertTrue(try service.backupRequiresPassphrase(at: archive.url))
        XCTAssertThrowsError(try service.inspectBackup(at: archive.url, passphrase: "incorrect"))
        let inspection = try service.inspectBackup(at: archive.url, passphrase: "backup-test")
        _ = try await service.restore(inspection: inspection, mode: .replaceRange,
                                      restoresSettings: true, restoredAccountCategories: [])
        XCTAssertEqual(try context.fetch(AlertType.fetchRequest()).map(\.name), ["Keep this alert"])
    }

    func testOlderBackupDecodesWithoutNewHistorySections() throws {
        let manifest = BackupManifest(
            format: "xdrip-backup", formatVersion: 1, createdAt: now, appVersion: "7.0.0", appBuild: "4231",
            bgReadingCount: 0, treatmentCount: 0, deviceStatusCount: nil, profileCount: nil,
            firstBgReadingDate: nil, lastBgReadingDate: nil, firstTreatmentDate: nil,
            firstDeviceStatusDate: nil, firstProfileDate: nil, includesSettings: false,
            includesAccounts: false, isPasswordProtected: false
        )
        let payload = BackupPayload(manifest: manifest, settings: nil, accounts: nil, alertTypes: [],
                                    bgReadings: [], treatments: [], deviceStatuses: nil, profiles: nil)
        let decoded = try JSONDecoder().decode(BackupPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertNil(decoded.batteryHistory)
        XCTAssertNil(decoded.careLinkPatientAliases)
        XCTAssertNil(decoded.deviceStatuses)
        XCTAssertNil(decoded.profiles)
    }

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
