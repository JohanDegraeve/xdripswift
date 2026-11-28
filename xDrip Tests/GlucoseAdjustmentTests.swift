import XCTest
import CoreData
import SwiftUI
@testable import xdrip

final class GlucoseAdjustmentTests: XCTestCase {
    @MainActor
    func testOpeningGlucoseAdjustmentsBuildsTheNavigationContent() throws {
        try withManager { manager, core, _ in
            let view = BgAdjustmentsView(bgReadingsAccessor: BgReadingsAccessor(coreDataManager: core),
                                         treatmentEntryAccessor: TreatmentEntryAccessor(coreDataManager: core),
                                         bgPostProcessingManager: manager)
            let host = UIHostingController(rootView: view)
            let size = host.sizeThatFits(in: CGSize(width: 390, height: 780))
            XCTAssertGreaterThan(size.height, 0)
        }
    }

    func testOffsetWarningAndLimitBoundariesInBothDirections() {
        for sign in [-1.0, 1.0] {
            XCTAssertFalse(ConstantsBgAdjustment.offsetNeedsWarning(sign * 30))
            XCTAssertTrue(ConstantsBgAdjustment.offsetNeedsWarning(sign * 30.1))
            XCTAssertTrue(ConstantsBgAdjustment.isValidOffset(sign * 50))
            XCTAssertFalse(ConstantsBgAdjustment.isValidOffset(sign * 50.1))
        }
        XCTAssertFalse(ConstantsBgAdjustment.isValidOffset(.nan))
        XCTAssertFalse(ConstantsBgAdjustment.isValidOffset(.infinity))
        XCTAssertFalse(ConstantsBgAdjustment.isValidOffset(-.infinity))
    }

    func testOffsetLimitsUseMgDlAfterMmolConversion() {
        XCTAssertFalse(ConstantsBgAdjustment.offsetNeedsWarning(1.6.mmolToMgdl()))
        XCTAssertTrue(ConstantsBgAdjustment.offsetNeedsWarning(1.7.mmolToMgdl()))
        XCTAssertTrue(ConstantsBgAdjustment.isValidOffset(2.7.mmolToMgdl()))
        XCTAssertFalse(ConstantsBgAdjustment.isValidOffset(2.8.mmolToMgdl()))
    }

    func testCurveDefaultsToDisabledWithoutMigration() throws {
        let name = "GlucoseAdjustmentTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.enableAdjustment = true
        XCTAssertTrue(defaults.enableGlucoseAdjustment)
        XCTAssertFalse(defaults.enableCurveAdjustment)
        XCTAssertNil(defaults.object(forKey: UserDefaults.Key.enableCurveAdjustment.rawValue))
    }

    func testSavitzkyGolayIsTheDefaultAndUsesTheHampelFilter() throws {
        let name = "GlucoseAdjustmentTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertEqual(BgSmoothingAlgorithm.allCases, [.savitzkyGolay, .exponential, .kalman, .loess])
        XCTAssertEqual(defaults.bgSmoothingAlgorithm, .savitzkyGolay)
        XCTAssertTrue(defaults.bgSmoothingAlgorithm.plugin is HampelSavitzkyGolayBgSmoothing)

        let key = UserDefaults.Key.bgSmoothingAlgorithm.rawValue
        defaults.set("hampelSavitzkyGolay", forKey: key)
        defaults.migrateLegacySmoothingAlgorithm()
        XCTAssertEqual(defaults.string(forKey: key), "savitzkyGolay")
        defaults.migrateLegacySmoothingAlgorithm()
        XCTAssertEqual(defaults.bgSmoothingAlgorithm, .savitzkyGolay)

        defaults.bgSmoothingAlgorithm = .kalman
        defaults.migrateLegacySmoothingAlgorithm()
        XCTAssertEqual(defaults.bgSmoothingAlgorithm, .kalman)
    }

    @MainActor
    func testInvalidOffsetRejectsTheWholeApplyBeforeChangingState() throws {
        try withManager { manager, core, start in
            XCTAssertTrue(apply(manager, at: start, offset: 24))
            let originalID = manager.latestActiveBgAdjustment()?.id
            for offset in [50.1, -50.1, .nan, .infinity] {
                XCTAssertFalse(apply(manager, at: start, offset: offset, smoothing: true))
                XCTAssertEqual(manager.latestActiveBgAdjustment()?.id, originalID)
                XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, 24)
                XCTAssertFalse(UserDefaults.standard.enableSmoothing)
                XCTAssertEqual(UserDefaults.standard.postProcessingApplyFromTimeStamp, start)
            }
            XCTAssertEqual(try core.mainManagedObjectContext.count(for: BgAdjustment.fetchRequest()), 1)
        }
    }

    @MainActor
    func testOffsetAndCurveCanBeAppliedIndependently() throws {
        try withManager { manager, _, start in
            XCTAssertTrue(apply(manager, at: start, offset: 80, slope: 1.2, glucose: false, curve: true))
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, 0)
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.slope, 1.2)
            XCTAssertFalse(UserDefaults.standard.enableGlucoseAdjustment)
            XCTAssertTrue(UserDefaults.standard.enableCurveAdjustment)
            XCTAssertTrue(UserDefaults.standard.enableAdjustment)

            XCTAssertTrue(apply(manager, at: start, offset: -50, slope: 1.7))
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, -50)
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.slope, 1)
            XCTAssertTrue(UserDefaults.standard.enableGlucoseAdjustment)
            XCTAssertFalse(UserDefaults.standard.enableCurveAdjustment)

            XCTAssertTrue(apply(manager, at: start, offset: 50, slope: 1.2, curve: true))
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, 50)
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.slope, 1.2)

            XCTAssertTrue(apply(manager, at: start, offset: 80, glucose: false, smoothing: true))
            XCTAssertFalse(UserDefaults.standard.enableAdjustment)
            XCTAssertFalse(UserDefaults.standard.enableCurveAdjustment)
            XCTAssertTrue(UserDefaults.standard.enableSmoothing)
        }
    }

    @MainActor
    func testRepeatedApplyDoesNotAccumulateOffsets() throws {
        try withManager { manager, core, start in
            let reading = BgReading(timeStamp: start, sensor: SensorsAccessor(coreDataManager: core).fetchActiveSensor(), calibration: nil, rawData: 112, deviceName: nil, nsManagedObjectContext: core.mainManagedObjectContext)
            reading.calculatedValue = 112
            XCTAssertTrue(core.saveChangesSynchronously())
            for _ in 0..<2 {
                XCTAssertTrue(apply(manager, at: start, offset: 24))
                XCTAssertEqual(reading.calculatedValue, 112)
                XCTAssertEqual(reading.adjustedValue?.doubleValue, 136)
            }
        }
    }

    @MainActor
    func testLegacyOversizedOffsetIsNotSilentlyReplaced() throws {
        try withManager { manager, core, start in
            let defaults = UserDefaults.standard
            let identifier = try XCTUnwrap(defaults.postProcessingSourceContextIdentifier)
            let legacy = BgAdjustmentsAccessor(coreDataManager: core).createBgAdjustment(timeStamp: start, applyFromTimeStamp: start, slope: 1, intercept: 80, adjustmentShapeType: 1, isEnabled: true, isBasicAdjustment: false, enteredBgValue: nil, sourceCalculatedValue: nil, sourceDescription: nil, sourceContextIdentifier: identifier, on: core.mainManagedObjectContext)
            defaults.enableAdjustment = true
            XCTAssertTrue(core.saveChangesSynchronously())
            XCTAssertFalse(apply(manager, at: start, offset: 80))
            XCTAssertTrue(legacy.isEnabled)
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, 80)
            XCTAssertTrue(apply(manager, at: start, offset: 50))
            XCTAssertFalse(legacy.isEnabled)
            XCTAssertEqual(manager.latestActiveBgAdjustment()?.intercept, 50)
        }
    }

    @MainActor
    func testPreviousAndLatestSmoothingAdvanceIndependently() throws {
        try withManager { manager, core, start in
            let sensor = SensorsAccessor(coreDataManager: core).fetchActiveSensor()
            func reading(_ value: Double, at minute: Double) -> BgReading {
                let reading = BgReading(timeStamp: start.addingTimeInterval(.minutes(minute)), sensor: sensor,
                                        calibration: nil, rawData: value, deviceName: nil,
                                        nsManagedObjectContext: core.mainManagedObjectContext)
                reading.calculatedValue = value
                return reading
            }

            _ = reading(98, at: 0)
            _ = reading(100, at: 5)
            _ = reading(102, at: 10)
            _ = reading(104, at: 15)
            let spike = reading(130, at: 20)
            spike.smoothedValue = 118
            XCTAssertTrue(core.saveChangesSynchronously())

            XCTAssertTrue(apply(manager, at: start, offset: 0, glucose: false, smoothing: true))
            XCTAssertNil(spike.smoothedValue)
            XCTAssertEqual(spike.finalValue, 130)

            XCTAssertTrue(manager.updateLatestReadingSmoothing(mode: .medium))
            XCTAssertNil(spike.smoothedValue)
            XCTAssertEqual(spike.finalValue, 122)
            let earlier = BgReadingsAccessor(coreDataManager: core).getLatestBgReadings(
                limit: nil, fromDate: nil, forSensor: sensor, ignoreRawData: true, ignoreCalculatedValue: false
            ).filter { $0.id != spike.id }
            let historicalValues = earlier.map(\.historicalValue)
            XCTAssertTrue(manager.updateLatestReadingSmoothing(mode: .light))
            XCTAssertEqual(spike.finalValue, 126)
            XCTAssertTrue(manager.updateLatestReadingSmoothing(mode: .strong))
            XCTAssertEqual(spike.finalValue, 122)
            XCTAssertEqual(earlier.map(\.historicalValue), historicalValues)
            XCTAssertEqual(UserDefaults.standard.postProcessingApplyFromTimeStamp, start)

            let next = reading(132, at: 25)
            XCTAssertTrue(core.saveChangesSynchronously())
            _ = manager.processLatestReadings(previousVisibleReadingTimeStamp: spike.timeStamp)
            XCTAssertNil(spike.latestSmoothedValue)
            XCTAssertNotNil(spike.smoothedValue)
            XCTAssertEqual(spike.calculatedValue, 130)
            XCTAssertEqual(next.finalValue, 132)
            XCTAssertEqual(next.previousLiveValue(for: spike), 122)
            XCTAssertNil(next.smoothedValue)
        }
    }

    @MainActor
    func testApplyingFromNowKeepsTheLiveTrendFromEarlierReadings() throws {
        try withManager { manager, core, start in
            let sensor = SensorsAccessor(coreDataManager: core).fetchActiveSensor()
            let readings = [100.0, 102, 104, 130].enumerated().map { index, value in
                let reading = BgReading(timeStamp: start.addingTimeInterval(.minutes(Double(index * 5))), sensor: sensor,
                                        calibration: nil, rawData: value, deviceName: nil,
                                        nsManagedObjectContext: core.mainManagedObjectContext)
                reading.calculatedValue = value
                return reading
            }
            XCTAssertTrue(core.saveChangesSynchronously())
            let latest = try XCTUnwrap(readings.last)
            XCTAssertTrue(apply(manager, at: latest.timeStamp, offset: 0, glucose: false, smoothing: true, liveMode: .medium))
            XCTAssertEqual(latest.finalValue, 122)
            XCTAssertFalse(latest.hideSlope)
            XCTAssertEqual(latest.calculatedValueSlope * 300_000, 18, accuracy: 0.001)
        }
    }

    @MainActor
    func testTurningOffLatestSmoothingRefreshesStoredSlope() throws {
        try withManager { manager, core, start in
            let sensor = SensorsAccessor(coreDataManager: core).fetchActiveSensor()
            let readings = [100.0, 102, 104, 130].enumerated().map { index, value in
                let reading = BgReading(timeStamp: start.addingTimeInterval(.minutes(Double(index * 5))), sensor: sensor,
                                        calibration: nil, rawData: value, deviceName: nil,
                                        nsManagedObjectContext: core.mainManagedObjectContext)
                reading.calculatedValue = value
                return reading
            }
            XCTAssertTrue(core.saveChangesSynchronously())
            let latest = try XCTUnwrap(readings.last)
            XCTAssertTrue(manager.updateLatestReadingSmoothing(mode: .medium))
            XCTAssertEqual(latest.finalValue, 122)
            XCTAssertEqual(latest.calculatedValueSlope * 300_000, 18, accuracy: 0.001)

            XCTAssertTrue(manager.updateLatestReadingSmoothing(mode: .off))
            XCTAssertEqual(latest.finalValue, 130)
            XCTAssertEqual(latest.calculatedValueSlope * 300_000, 26, accuracy: 0.001)
        }
    }

    @MainActor
    func testTurningOffOneAdjustmentRetainsItsAppliedValueForThisSource() throws {
        try withManager { manager, _, start in
            XCTAssertTrue(apply(manager, at: start, offset: 18, slope: 1.10, curve: true))
            XCTAssertTrue(apply(manager, at: start, offset: 0, slope: 1.20, glucose: false, curve: true))
            XCTAssertEqual(manager.adjustmentEditingPreferences.offset, 18)
            XCTAssertEqual(manager.adjustmentEditingPreferences.scale, 1.20)

            XCTAssertTrue(apply(manager, at: start, offset: 0, glucose: false))
            XCTAssertEqual(manager.adjustmentEditingPreferences.offset, 18)
            XCTAssertEqual(manager.adjustmentEditingPreferences.scale, 1.20)

            manager.handleSourceContextChanged()
            XCTAssertEqual(manager.adjustmentEditingPreferences.offset, 0)
            XCTAssertEqual(manager.adjustmentEditingPreferences.scale, 1)
        }
    }

    @MainActor
    private func apply(_ manager: BgPostProcessingManager, at start: Date, offset: Double, slope: Double = 1, glucose: Bool = true, curve: Bool = false, smoothing: Bool = false, liveMode: LatestReadingSmoothing.Mode? = nil) -> Bool {
        manager.applyPostProcessing(enableGlucoseAdjustment: glucose, enableCurveAdjustment: curve, slope: slope, intercept: offset, adjustmentShapeType: .neutral, applyFromTimeStamp: start, isBasicAdjustment: false, enteredBgValue: nil, sourceCalculatedValue: nil, enableSmoothing: smoothing, useFiveMinuteReadings: false, smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: 1, latestReadingSmoothingMode: liveMode)
    }

    @MainActor
    private func withManager(_ body: (BgPostProcessingManager, CoreDataManager, Date) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let keys: [UserDefaults.Key] = [.isMaster, .transmitterTypeAsString, .enableAdjustment,
            .enableGlucoseAdjustment, .enableCurveAdjustment, .enableSmoothing, .bgSmoothingStrength,
            .enableLatestReadingSmoothing, .latestReadingSmoothingStrength, .bgAdjustmentEditingPreferences,
            .loopShareSmoothedLatestReading, .loopShareLiveReadings,
            .bgSmoothingAlgorithm, .bgSmoothingPeriodInMinutes, .useFiveMinuteReadings,
            .postProcessingSourceContextIdentifier, .activeSensorStartDate, .postProcessingApplyFromTimeStamp,
            .postProcessingStartTimeStamp, .fiveMinuteReadingsStartTimeStamp]
        let original = keys.map { ($0.rawValue, defaults.object(forKey: $0.rawValue)) }
        let oldLiveState = LatestReadingSmoothing.liveState
        defer {
            for (key, value) in original { defaults.set(value, forKey: key) }
            LatestReadingSmoothing.liveState = oldLiveState
        }
        LatestReadingSmoothing.liveState = nil
        keys.forEach { defaults.removeObject(forKey: $0.rawValue) }
        defaults.isMaster = true
        defaults.cgmTransmitterTypeAsString = CGMTransmitterType.dexcomG7.rawValue
        let core = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let start = Date().addingTimeInterval(-60)
        _ = Sensor(startDate: start, nsManagedObjectContext: core.mainManagedObjectContext)
        XCTAssertTrue(core.saveChangesSynchronously())
        let manager = BgPostProcessingManager(coreDataManager: core, nightscoutSyncManager: nil, healthKitManager: nil)
        manager.refreshSourceContext()
        try body(manager, core, start)
    }
}
