import XCTest
import CoreData
@testable import xdrip

final class GlucoseAdjustmentTests: XCTestCase {
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
    private func apply(_ manager: BgPostProcessingManager, at start: Date, offset: Double, slope: Double = 1, glucose: Bool = true, curve: Bool = false, smoothing: Bool = false) -> Bool {
        manager.applyPostProcessing(enableGlucoseAdjustment: glucose, enableCurveAdjustment: curve, slope: slope, intercept: offset, adjustmentShapeType: .neutral, applyFromTimeStamp: start, isBasicAdjustment: false, enteredBgValue: nil, sourceCalculatedValue: nil, enableSmoothing: smoothing, useFiveMinuteReadings: false, smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: 1)
    }

    @MainActor
    private func withManager(_ body: (BgPostProcessingManager, CoreDataManager, Date) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let keys: [UserDefaults.Key] = [.isMaster, .transmitterTypeAsString, .enableAdjustment,
            .enableGlucoseAdjustment, .enableCurveAdjustment, .enableSmoothing, .bgSmoothingStrength,
            .bgSmoothingAlgorithm, .bgSmoothingPeriodInMinutes, .useFiveMinuteReadings,
            .postProcessingSourceContextIdentifier, .activeSensorStartDate, .postProcessingApplyFromTimeStamp,
            .postProcessingStartTimeStamp, .fiveMinuteReadingsStartTimeStamp]
        let original = keys.map { ($0.rawValue, defaults.object(forKey: $0.rawValue)) }
        defer { for (key, value) in original { defaults.set(value, forKey: key) } }
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
