import XCTest
@testable import xdrip

final class LiveActivityWarmupTests: XCTestCase {
    func testOlderActivityPayloadDecodesWithoutWarmup() throws {
        let state = makeState()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "sensorWarmupEndDate")
        json.removeValue(forKey: "sensorWarmupConfirmationUntil")
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.sensorWarmupEndDate)
        XCTAssertNil(decoded.sensorWarmupConfirmationUntil)
        XCTAssertFalse(decoded.showsSensorWarmupStatus)
        XCTAssertFalse(decoded.isSensorWarmingUp)
    }

    func testWarmupSurvivesEncodingWithoutAnyGlucose() throws {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(1800)
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(decoded.bgReadingValues.isEmpty)
        XCTAssertTrue(decoded.bgReadingDates.isEmpty)
        XCTAssertEqual(decoded.sensorWarmupEndDate, state.sensorWarmupEndDate)
        XCTAssertTrue(decoded.isSensorWarmingUp)
    }

    func testExpiredWarmupReturnsToNormalPresentation() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-1)
        XCTAssertFalse(state.isSensorWarmingUp)
        state.sensorWarmupEndDate = nil
        XCTAssertFalse(state.isSensorWarmingUp)
    }

    func testFreshWarmupReportBridgesElapsedEstimateWithoutGlucose() throws {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(240)
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertFalse(decoded.isSensorWarmingUp)
        XCTAssertTrue(decoded.isWaitingForSensorReading)
        XCTAssertTrue(decoded.showsSensorWarmupStatus)
        XCTAssertTrue(decoded.bgReadingValues.isEmpty)
    }

    func testWaitingDoesNotStartBeforeEstimateOrOutliveFreshReport() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(300)
        XCTAssertFalse(state.isWaitingForSensorReading)
        XCTAssertTrue(state.isSensorWarmingUp)
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(-1)
        XCTAssertFalse(state.showsSensorWarmupStatus)
    }

    func testClearingConfirmationRemovesWaitingWithoutGlucose() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(240)
        XCTAssertTrue(state.isWaitingForSensorReading)
        state.sensorWarmupConfirmationUntil = nil
        XCTAssertFalse(state.showsSensorWarmupStatus)
    }

    func testPayloadTrimmingPreservesWarmupAndLatestReading() throws {
        let now = Date()
        var state = makeState(values: Array(repeating: 120, count: 144), dates: (0..<144).map { now.addingTimeInterval(Double($0) * -300) })
        state.sensorWarmupEndDate = now.addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = now.addingTimeInterval(240)
        let limited = state.limitedForActivityPayload(maximumEncodedBytes: 1000)
        XCTAssertLessThan(limited.bgReadingValues.count, state.bgReadingValues.count)
        XCTAssertEqual(limited.bgReadingDate, now)
        XCTAssertEqual(limited.sensorWarmupEndDate, state.sensorWarmupEndDate)
        XCTAssertEqual(limited.sensorWarmupConfirmationUntil, state.sensorWarmupConfirmationUntil)
        XCTAssertTrue(limited.isWaitingForSensorReading)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(limited).count, 1000)
    }

    // MARK: - Enablement and remembered style

    // upgrading must preserve the old on/off state before Disabled becomes the initial Normal style
    func testLegacyDisabledAndMissingSettingsStayDisabled() throws {
        try withLiveActivityDefaults { defaults in
            XCTAssertFalse(defaults.liveActivitiesEnabled)
            XCTAssertEqual(defaults.liveActivityType, .normal)
        }
        try withLiveActivityDefaults { defaults in
            defaults.set(LiveActivityType.disabled.rawValue, forKey: UserDefaults.Key.liveActivityType.rawValue)
            XCTAssertEqual(defaults.liveActivityType, .normal)
            XCTAssertFalse(defaults.liveActivitiesEnabled)
        }
    }

    func testLegacyStylesStayEnabledAndKeepTheirRawValues() throws {
        for style in LiveActivityType.allCasesForList {
            try withLiveActivityDefaults { defaults in
                defaults.set(style.rawValue, forKey: UserDefaults.Key.liveActivityType.rawValue)
                XCTAssertTrue(defaults.liveActivitiesEnabled)
                XCTAssertEqual(defaults.liveActivityType, style)
                XCTAssertEqual(defaults.integer(forKey: UserDefaults.Key.liveActivityType.rawValue), style.rawValue)
            }
        }
    }

    // a stored false is an explicit choice, even when a valid style remains selected
    func testExplicitDisabledSettingRetainsStyleAcrossReadsAndToggles() throws {
        try withLiveActivityDefaults { defaults in
            defaults.set(false, forKey: UserDefaults.Key.liveActivitiesEnabled.rawValue)
            defaults.set(LiveActivityType.large.rawValue, forKey: UserDefaults.Key.liveActivityType.rawValue)
            XCTAssertFalse(defaults.liveActivitiesEnabled)
            XCTAssertEqual(defaults.liveActivityType, .large)
            defaults.liveActivitiesEnabled = true
            XCTAssertEqual(defaults.liveActivityType, .large)
            defaults.liveActivitiesEnabled = false
            XCTAssertFalse(defaults.liveActivitiesEnabled)
            XCTAssertEqual(defaults.liveActivityType, .large)
        }
    }

    func testStyleChangesDoNotEnableLiveActivities() throws {
        try withLiveActivityDefaults { defaults in
            defaults.liveActivityType = .minimal
            XCTAssertFalse(defaults.liveActivitiesEnabled)
            XCTAssertEqual(defaults.liveActivityType, .minimal)
            defaults.liveActivitiesEnabled = true
            XCTAssertTrue(defaults.liveActivitiesEnabled)
            XCTAssertEqual(defaults.liveActivityType, .minimal)
        }
    }

    // the settings rows and lifecycle both observe this key to react to the switch immediately
    func testEnablementChangesNotifySettingsObservers() throws {
        try withLiveActivityDefaults { defaults in
            defaults.liveActivitiesEnabled = false
            var observedValues = [Bool]()
            let observer = defaults.observe(\.liveActivitiesEnabled, options: .new) { _, change in
                if let value = change.newValue {
                    observedValues.append(value)
                }
            }
            defaults.liveActivitiesEnabled = true
            XCTAssertTrue(observedValues.contains(true))
            defaults.liveActivitiesEnabled = false
            XCTAssertEqual(observedValues.last, false)
            withExtendedLifetime(observer) {}
        }
    }

    func testStylePickerExcludesDisabledAndRetainsPresentationOrder() {
        XCTAssertEqual(LiveActivityType.allCasesForList, [.minimal, .normal, .large])
        XCTAssertEqual(LiveActivityType.disabled.rawValue, 0)
        XCTAssertEqual(LiveActivityType.normal.rawValue, 1)
        XCTAssertEqual(LiveActivityType.minimal.rawValue, 2)
        XCTAssertEqual(LiveActivityType.large.rawValue, 3)
    }

    // use an isolated defaults suite so migration tests cannot change the application's settings
    private func withLiveActivityDefaults(_ body: (UserDefaults) -> Void) throws {
        let suiteName = "LiveActivitySettingsTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    private func makeState(values: [Double] = [], dates: [Date] = []) -> XDripWidgetAttributes.ContentState {
        XDripWidgetAttributes.ContentState(
            bgReadingValues: values, bgReadingDates: dates, isMgDl: true,
            slopeOrdinal: 0, deltaValueInUserUnit: nil,
            urgentLowLimitInMgDl: 55, lowLimitInMgDl: 70,
            highLimitInMgDl: 180, urgentHighLimitInMgDl: 250,
            liveActivityType: .normal, aidStatus: nil
        )
    }
}
