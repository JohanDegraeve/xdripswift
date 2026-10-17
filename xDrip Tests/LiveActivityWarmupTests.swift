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

    func testPublicationSkipsOnlyCompletedIdenticalContent() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let a = makeState(values: [100, 95], dates: [now, now.addingTimeInterval(-300)]).publicationValue
        let b = makeState(values: [100, 90], dates: [now, now.addingTimeInterval(-300)]).publicationValue
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        XCTAssertTrue(cache.shouldPublish(a, at: now))
        cache.record(a, at: now, refreshDates: a.publicationRefreshDates)
        XCTAssertFalse(cache.shouldPublish(a, at: now.addingTimeInterval(10)))
        // A correction to chart history matters even when the newest value is unchanged.
        XCTAssertTrue(cache.shouldPublish(b, at: now.addingTimeInterval(10)))
        // While B is outstanding the manager must queue A, rather than skip against completed A.
        XCTAssertTrue(cache.shouldPublish(a, at: now.addingTimeInterval(10), force: true))
        cache.record(b, at: now.addingTimeInterval(10), refreshDates: b.publicationRefreshDates)
        XCTAssertTrue(cache.shouldPublish(a, at: now.addingTimeInterval(11)))
        cache.record(a, at: now.addingTimeInterval(11), refreshDates: a.publicationRefreshDates)
        XCTAssertFalse(cache.shouldPublish(a, at: now.addingTimeInterval(12)))
    }

    func testSameGlucoseAtANewReadingTimeIsPublished() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = makeState(values: [100], dates: [now]).publicationValue
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        cache.record(state, at: now, refreshDates: state.publicationRefreshDates)
        let newReading = makeState(values: [100], dates: [now.addingTimeInterval(300)]).publicationValue
        XCTAssertTrue(cache.shouldPublish(newReading, at: now.addingTimeInterval(300)))
    }

    func testPublicationIgnoresRequestTimeButPreservesWarningsAndSettings() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = makeState(values: [100], dates: [now])
        let original = state.publicationValue
        state.eventStartDate = now.addingTimeInterval(10)
        XCTAssertEqual(original, state.publicationValue)
        state.warnUserToOpenApp.toggle()
        XCTAssertNotEqual(original, state.publicationValue)
        state.warnUserToOpenApp.toggle()
        state.liveActivityType = .large
        XCTAssertNotEqual(original, state.publicationValue)
    }

    func testUnchangedReadingPublishesAtEachFreshnessBoundary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = makeState(values: [100], dates: [now]).publicationValue
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        cache.record(state, at: now, refreshDates: state.publicationRefreshDates)
        let staleAt = now.addingTimeInterval(ConstantsWidgetExtension.bgReadingDateStaleInMinutes)
        let veryStaleAt = now.addingTimeInterval(ConstantsWidgetExtension.bgReadingDateVeryStaleInMinutes)
        XCTAssertFalse(cache.shouldPublish(state, at: staleAt.addingTimeInterval(-1)))
        XCTAssertTrue(cache.shouldPublish(state, at: staleAt))
        cache.record(state, at: staleAt, refreshDates: state.publicationRefreshDates)
        XCTAssertFalse(cache.shouldPublish(state, at: veryStaleAt.addingTimeInterval(-1)))
        XCTAssertTrue(cache.shouldPublish(state, at: veryStaleAt))
    }

    func testTherapyFreshnessAndExpiryAreNotDeduplicated() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = makeState(values: [100], dates: [now])
        let metric = TherapyMetricState(amount: 1, source: .nightscout, referenceDate: now,
                                        expiresAt: now.addingTimeInterval(30), reason: nil)
        state.therapyMetrics = TherapyMetricsSnapshot(iob: metric, cob: metric)
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        cache.record(state.publicationValue, at: now, refreshDates: state.publicationRefreshDates)
        XCTAssertFalse(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(29)))
        XCTAssertTrue(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(30)))
        state.therapyMetrics?.iob.referenceDate = now.addingTimeInterval(10)
        XCTAssertTrue(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(10)))
    }

    func testEmptyTherapySnapshotDoesNotDefeatDuplicateDetection() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let empty = TherapyMetricState(source: .local, referenceDate: now, reason: .noTreatments)
        var state = makeState(values: [100], dates: [now])
        state.therapyMetrics = TherapyMetricsSnapshot(iob: empty, cob: empty)
        let original = state.publicationValue
        state.therapyMetrics?.iob.referenceDate = now.addingTimeInterval(10)
        state.therapyMetrics?.cob.referenceDate = now.addingTimeInterval(10)
        XCTAssertEqual(original, state.publicationValue)
        // A newly available amount must still publish.
        state.therapyMetrics?.iob.amount = 1
        state.therapyMetrics?.iob.visibilityDeadline = now.addingTimeInterval(100)
        state.therapyMetrics?.iob.reason = nil
        XCTAssertNotEqual(original, state.publicationValue)
    }

    func testWarmupAndStatusTimeTransitionsStillPublish() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = makeState()
        state.sensorWarmupEndDate = now.addingTimeInterval(30)
        state.sensorWarmupConfirmationUntil = now.addingTimeInterval(60)
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        cache.record(state.publicationValue, at: now, refreshDates: state.publicationRefreshDates)
        XCTAssertFalse(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(29)))
        XCTAssertTrue(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(30)))
        cache.record(state.publicationValue, at: now.addingTimeInterval(30), refreshDates: state.publicationRefreshDates)
        XCTAssertTrue(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(60)))
        let status = AIDStatus(condition: .active, style: .loop, statusUpdatedAt: now,
                               lastActivityAt: now, iob: nil, cob: nil, statusTitle: "", staleStatusTitle: "")
        let dates = companionPublicationRefreshDates(readingDate: nil, aidStatus: status, therapyMetrics: nil)
        cache.record(state.publicationValue, at: now, refreshDates: dates)
        XCTAssertTrue(cache.shouldPublish(state.publicationValue, at: now.addingTimeInterval(ConstantsHomeView.loopShowWarningAfterMinutes)))
    }

    func testForcedRefreshAndNewActivityDoNotReuseThePreviousCache() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = makeState().publicationValue
        var cache = CompanionPublicationCache<XDripWidgetAttributes.ContentState>()
        cache.record(state, at: now, refreshDates: [])
        XCTAssertFalse(cache.shouldPublish(state, at: now))
        XCTAssertTrue(cache.shouldPublish(state, at: now, force: true))
        cache = CompanionPublicationCache()
        XCTAssertTrue(cache.shouldPublish(state, at: now))
    }

    func testWidgetPublicationPreservesStatusAndPresentationSettings() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var model = WidgetSharedUserDefaultsModel(bgReadingValues: [100], bgReadingDatesAsDouble: [now.timeIntervalSince1970],
            isMgDl: true, slopeOrdinal: 4, deltaValueInUserUnit: 0, urgentLowLimitInMgDl: 55,
            lowLimitInMgDl: 70, highLimitInMgDl: 180, urgentHighLimitInMgDl: 250,
            dataSourceDescription: "G6", aidStatus: nil, allowStandByHighContrast: false, forceStandByBigNumbers: false)
        var cache = CompanionPublicationCache<WidgetSharedUserDefaultsModel>()
        cache.record(model, at: now, refreshDates: [])
        let decoded = try JSONDecoder().decode(WidgetSharedUserDefaultsModel.self, from: JSONEncoder().encode(model))
        XCTAssertFalse(cache.shouldPublish(decoded, at: now))
        model.forceStandByBigNumbers = true
        XCTAssertTrue(cache.shouldPublish(model, at: now))
        model.forceStandByBigNumbers = false
        model.followerPatientName = "Updated"
        XCTAssertTrue(cache.shouldPublish(model, at: now))
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
