//
//  CareLinkTests.swift
//  xdripTests
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import SwiftUI
import XCTest
@testable import xdrip

/// Contract tests for web authentication, account roles, parsing, scheduling and follower delivery.
/// Every request is intercepted in-process. No test can contact a live CareLink account.
final class CareLinkTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    // MARK: - Stored values and account presentation

    func testPersistedFollowerRawValueIsAppended() {
        XCTAssertEqual(FollowerDataSourceType.calendar.rawValue, 5)
        XCTAssertEqual(FollowerDataSourceType.careLink.rawValue, 6)
    }

    func testBackupClassifiesEveryCareLinkAccountValueAsSensitive() {
        XCTAssertEqual(
            BackupAccountCategory.careLink.keys,
            [
                UserDefaults.Key.careLinkUsername.rawValue,
                UserDefaults.Key.careLinkPassword.rawValue,
                UserDefaults.Key.careLinkRegion.rawValue,
                UserDefaults.Key.careLinkSelectedPatientID.rawValue,
            ]
        )
        XCTAssertEqual(
            BackupAccountCategory.careLink.availabilityKeys,
            [UserDefaults.Key.careLinkUsername.rawValue]
        )
        XCTAssertFalse(
            BackupAccountCategory.allKeys.contains(UserDefaults.Key.automaticBasalRenderingStyle.rawValue)
        )
    }

    func testBackupTreatmentPreservesCareLinkIdentityAndDecodesLegacyRecords() throws {
        let treatment = BackupTreatment(
            careLinkSourceIdentifier: "patient|AUTO_BASAL_DELIVERY|marker-1",
            date: now,
            enteredBy: "CareLink",
            id: "",
            nightscoutEventType: nil,
            notes: nil,
            treatmentDeleted: false,
            treatmentType: TreatmentType.AutomaticBasal.rawValue,
            uploaded: false,
            value: 0.125,
            valueSecondary: 5
        )
        let encoded = try JSONEncoder().encode(treatment)
        XCTAssertEqual(
            try JSONDecoder().decode(BackupTreatment.self, from: encoded).careLinkSourceIdentifier,
            treatment.careLinkSourceIdentifier
        )

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "careLinkSourceIdentifier")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        XCTAssertNil(try JSONDecoder().decode(BackupTreatment.self, from: legacyData).careLinkSourceIdentifier)
    }

    func testConnectionIndicatorPaletteDoesNotUseReadingFreshness() {
        XCTAssertEqual(CareLinkConnectionStatus.loginRequired.indicatorColor, Color.gray)
        XCTAssertEqual(CareLinkConnectionStatus.connecting.indicatorColor, ConstantsAppColors.warning)
        XCTAssertEqual(CareLinkConnectionStatus.noData.indicatorColor, ConstantsAppColors.warning)
        XCTAssertEqual(CareLinkConnectionStatus.active.indicatorColor, ConstantsAppColors.normal)
        XCTAssertEqual(CareLinkConnectionStatus.stale.indicatorColor, Color.orange)
        XCTAssertEqual(CareLinkConnectionStatus.rateLimited.indicatorColor, Color.orange)
        XCTAssertEqual(CareLinkConnectionStatus.error.indicatorColor, ConstantsAppColors.urgent)
    }

    func testCareLinkAIDStatusUsesSharedSymbolAndColorRules() throws {
        var checkingSnapshot = CareLinkStatusSnapshot()
        checkingSnapshot.pump.isReported = true
        let checking = try XCTUnwrap(checkingSnapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(checking.systemImage, ConstantsHomeView.careLinkSmartGuardSystemImage)
        XCTAssertEqual(checking.color, Color("colorSecondary"))

        var snapshot = CareLinkStatusSnapshot(status: .active)
        snapshot.pump.isReported = true
        snapshot.pump.observedAt = now
        snapshot.pump.algorithmState = "AUTO_BASAL"
        var presentation = try XCTUnwrap(snapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkSmartGuardSystemImage)
        XCTAssertEqual(presentation.color, .green)

        snapshot.pump.isSuspended = true
        presentation = try XCTUnwrap(snapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkSuspendedSystemImage)
        XCTAssertEqual(presentation.color, .yellow)

        snapshot.pump.isSuspended = false
        snapshot.pump.isCommunicating = false
        presentation = try XCTUnwrap(snapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkDisconnectedSystemImage)
        XCTAssertEqual(presentation.color, .red)

        snapshot.pump.isCommunicating = true
        snapshot.pump.observedAt = now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes - 1)
        presentation = try XCTUnwrap(snapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkStaleSystemImage)
        XCTAssertEqual(presentation.color, .yellow)
        XCTAssertEqual(presentation.title, Texts_SettingsView.careLinkNoData)
    }

    func testCommonAIDStatusPreservesLoopFreshnessRules() {
        var deviceStatus = NightscoutDeviceStatus()
        deviceStatus.lastCheckedDate = now
        deviceStatus.createdAt = now
        deviceStatus.lastLoopDate = now

        var presentation = deviceStatus.aidStatus.presentation(referenceDate: now)
        XCTAssertTrue(deviceStatus.aidStatus.supportsCOB)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.loopStatusRecentSystemImage)
        XCTAssertEqual(presentation.color, .green)

        deviceStatus.lastLoopDate = now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes - 1)
        presentation = deviceStatus.aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.loopStatusAcceptableSystemImage)
        XCTAssertEqual(presentation.color, .yellow)

        deviceStatus.lastLoopDate = now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes - 1)
        presentation = deviceStatus.aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.loopStatusNotLoopingSystemImage)
        XCTAssertEqual(presentation.color, .red)

        deviceStatus.createdAt = now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes - 1)
        presentation = deviceStatus.aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.loopStatusNoDataSystemImage)
        XCTAssertEqual(presentation.color, .gray)
    }

    func testCareLinkAIDStatusUsesPumpUpdateTimestampAndOptionalMetrics() throws {
        var snapshot = CareLinkStatusSnapshot(status: .active)
        snapshot.pump.isReported = true
        snapshot.pump.lastDataUpdateAt = now
        let aidStatus = try XCTUnwrap(snapshot.aidStatus)

        XCTAssertEqual(aidStatus.statusUpdatedAt, now)
        XCTAssertEqual(aidStatus.lastActivityAt, now)
        XCTAssertNil(aidStatus.iob)
        XCTAssertNil(aidStatus.cob)
        XCTAssertFalse(aidStatus.supportsCOB)

        let state = RootHomeStateModel().careLinkLoopState(snapshot: snapshot, referenceDate: now)
        XCTAssertEqual(state.iob.value, "- U")
        XCTAssertEqual(state.cob.value, "- g")
        XCTAssertFalse(state.showsCOB)
    }

    func testCareLinkNoPumpPublishesIOBFreshnessButGlucoseOnlyPublishesNoTherapyStatus() throws {
        var snapshot = CareLinkStatusSnapshot(status: .active, lastReadingAt: now)
        snapshot.pump.isCommunicating = false
        snapshot.pump.isInRange = false
        XCTAssertNil(snapshot.aidStatus)
        XCTAssertNil(snapshot.pump.homeDeviceStatus(metadata: snapshot.metadata, checkedAt: now))
        XCTAssertNil(RootHomeStateModel().careLinkLoopState(snapshot: snapshot, referenceDate: now).statusSystemImage)

        snapshot.pump.activeInsulin = 1.25
        snapshot.pump.activeInsulinAt = now
        var aidStatus = try XCTUnwrap(snapshot.aidStatus)
        XCTAssertEqual(aidStatus.style, .careLinkIOB)
        XCTAssertEqual(aidStatus.statusTitle, Texts_Common.Ok)
        XCTAssertFalse(aidStatus.supportsCOB)

        var presentation = aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkPumpSystemImage)
        XCTAssertEqual(presentation.color, .green)
        XCTAssertTrue(presentation.hasFreshData)

        snapshot.pump.activeInsulinAt = now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes - 1)
        aidStatus = try XCTUnwrap(snapshot.aidStatus)
        presentation = aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkPumpSystemImage)
        XCTAssertEqual(presentation.color, .yellow)
        XCTAssertTrue(presentation.hasFreshData)

        snapshot.pump.activeInsulinAt = now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes - 1)
        aidStatus = try XCTUnwrap(snapshot.aidStatus)
        presentation = aidStatus.presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkPumpSystemImage)
        XCTAssertEqual(presentation.color, .red)
        XCTAssertFalse(presentation.hasFreshData)
        XCTAssertEqual(presentation.title, Texts_SettingsView.careLinkNoData)
    }

    func testHistoricalCareLinkAIDStatusHidesCOBAfterDeviceStatusNormalization() throws {
        let record = CareLinkTherapyRecord(
            sourceIdentifier: "patient|AUTO_BASAL_DELIVERY|historical-cob",
            date: now.addingTimeInterval(-300),
            type: .AutomaticBasal,
            value: 0.125,
            durationMinutes: 5,
            nightscoutEventType: "Temp Basal",
            notes: nil
        )
        let deviceStatus = try XCTUnwrap(record.historicalPumpDeviceStatus(
            metadata: CareLinkMetadata(deviceModel: "MMT-1886"),
            checkedAt: now
        ))
        let stateModel = RootHomeStateModel()
        let normalizedState = stateModel.loopState(deviceStatus: deviceStatus, referenceDate: record.date)

        let historicalState = stateModel.historicalLoopState(
            normalizedState,
            aidAnalyticsSource: .careLink
        )

        XCTAssertTrue(historicalState.isHistorical)
        XCTAssertFalse(historicalState.showsCOB)
    }

    func testHistoricalCareLinkAIDStatusHidesCOBWhenNoStatusRecordExists() {
        let state = RootHomeStateModel().historicalLoopState(
            RootHomeLoopState(),
            aidAnalyticsSource: .careLink
        )

        XCTAssertTrue(state.isHistorical)
        XCTAssertFalse(state.showsCOB)
    }

    func testHistoricalNightscoutLoopStatusKeepsCOB() {
        let state = RootHomeStateModel().historicalLoopState(
            RootHomeLoopState(),
            aidAnalyticsSource: .nightscout(.loop)
        )

        XCTAssertTrue(state.isHistorical)
        XCTAssertTrue(state.showsCOB)
    }

    func testNewStatusSnapshotStartsWhileTheStoredSessionIsBeingChecked() {
        XCTAssertEqual(CareLinkStatusSnapshot().status, .connecting)
        XCTAssertEqual(CareLinkAccountState().snapshot.status, .connecting)
    }

    func testStoredSessionCheckDistinguishesAnAbsentTokenFromAReadFailure() async throws {
        let emptyClient = CareLinkClient(tokenStore: CareLinkMemoryTokenStore())
        let hasStoredToken = try await emptyClient.hasToken()
        XCTAssertFalse(hasStoredToken)

        let failingClient = CareLinkClient(tokenStore: FailingCareLinkTokenStore())
        do {
            _ = try await failingClient.hasToken()
            XCTFail("Expected the stored session check to preserve the read failure")
        } catch {
            XCTAssertTrue(error is FailingCareLinkTokenStore.Failure)
        }
    }

    func testDiagnosticsRedactPatientScopedURLsQueriesAndRequestBodies() throws {
        let url = try XCTUnwrap(URL(string: "https://carelink.minimed.eu/patient/m2m/connect/data/gc/patients/private-patient?token=private-query"))
        let diagnosticURL = CareLinkClient.diagnosticURL(url)

        XCTAssertFalse(diagnosticURL.contains("private-patient"))
        XCTAssertFalse(diagnosticURL.contains("private-query"))
        XCTAssertEqual(
            diagnosticURL,
            "https://carelink.minimed.eu/patient/m2m/connect/data/gc/patients/<redacted>"
        )

        let body = Data(#"{"username":"private-account","patientId":"private-patient"}"#.utf8)
        let diagnosticBody = CareLinkClient.diagnosticBody(body)
        XCTAssertEqual(diagnosticBody, "<\(body.count) bytes>")
        XCTAssertFalse(diagnosticBody.contains("private-account"))
        XCTAssertFalse(diagnosticBody.contains("private-patient"))
    }

    func testWatchStatusCarriesCareLinkConnectionState() {
        var status = WatchStatus()
        status.followerDataSourceTypeRawValue = FollowerDataSourceType.careLink.rawValue
        status.followerConnectionStatusRawValue = CareLinkConnectionStatus.connecting.rawValue

        XCTAssertEqual(status.asDictionary?["followerDataSourceTypeRawValue"] as? Int, FollowerDataSourceType.careLink.rawValue)
        XCTAssertEqual(status.asDictionary?["followerConnectionStatusRawValue"] as? String, CareLinkConnectionStatus.connecting.rawValue)
    }

    func testCommonAIDStatusEncodesInWatchWidgetAndLiveActivityPayloads() throws {
        var snapshot = CareLinkStatusSnapshot(status: .active)
        snapshot.pump.activeInsulin = 1.25
        snapshot.pump.activeInsulinAt = now
        let aidStatus = try XCTUnwrap(snapshot.aidStatus)

        var watchStatus = WatchStatus()
        watchStatus.aidStatus = aidStatus
        let watchDictionary = try XCTUnwrap(watchStatus.asDictionary)
        let watchAIDDictionary = try XCTUnwrap(watchDictionary["aidStatus"] as? [String: Any])
        let watchAIDData = try JSONSerialization.data(withJSONObject: watchAIDDictionary)
        XCTAssertEqual(try JSONDecoder().decode(AIDStatus.self, from: watchAIDData), aidStatus)

        let widgetStatus = WidgetSharedUserDefaultsModel(
            bgReadingValues: [],
            bgReadingDatesAsDouble: [],
            isMgDl: true,
            slopeOrdinal: 0,
            deltaValueInUserUnit: 0,
            urgentLowLimitInMgDl: 60,
            lowLimitInMgDl: 80,
            highLimitInMgDl: 170,
            urgentHighLimitInMgDl: 250,
            dataSourceDescription: "CareLink",
            followerPatientName: nil,
            aidStatus: aidStatus,
            allowStandByHighContrast: true,
            forceStandByBigNumbers: false
        )
        let widgetData = try JSONEncoder().encode(widgetStatus)
        XCTAssertEqual(try JSONDecoder().decode(WidgetSharedUserDefaultsModel.self, from: widgetData).aidStatus, aidStatus)

        let liveActivityStatus = XDripWidgetAttributes.ContentState(
            bgReadingValues: [110],
            bgReadingDates: [now],
            isMgDl: true,
            slopeOrdinal: 4,
            deltaValueInUserUnit: 0,
            urgentLowLimitInMgDl: 60,
            lowLimitInMgDl: 80,
            highLimitInMgDl: 170,
            urgentHighLimitInMgDl: 250,
            liveActivityType: .normal,
            dataSourceDescription: "CareLink",
            aidStatus: aidStatus
        )
        let liveActivityData = try JSONEncoder().encode(liveActivityStatus)
        XCTAssertEqual(try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: liveActivityData).aidStatus, aidStatus)
    }

    func testAuthenticationCompletionCanRunOnlyOnce() {
        let completion = CareLinkOneShot()
        var value = ""
        XCTAssertTrue(completion.run { value = "callback" })
        XCTAssertFalse(completion.run { value = "dismissal" })
        XCTAssertEqual(value, "callback")
    }

    func testOAuthRefreshMargin() {
        let token = credential(expiresAt: now.addingTimeInterval(601))
        XCTAssertFalse(token.needsRefresh(at: now))
        XCTAssertTrue(credential(expiresAt: now.addingTimeInterval(599)).needsRefresh(at: now))
    }

    func testOAuthCallbackRequiresMatchingStateAndPersistsRotatingToken() async throws {
        let store = CareLinkMemoryTokenStore()
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        let transaction = authorizationTransaction()
        let callback = try XCTUnwrap(URL(string: "com.medtronic.carepartner:/sso?code=one-time&state=state"))
        let installed = try await client.installOAuthSession(callbackURL: callback, transaction: transaction, region: .outsideUnitedStates)
        XCTAssertEqual(installed.accessToken, "rotated")
        XCTAssertEqual(installed.refreshToken, "rotated-refresh")
        XCTAssertEqual(installed.region, .outsideUnitedStates)
        let authenticatedRegion = await client.authenticatedRegion()
        XCTAssertEqual(authenticatedRegion, .outsideUnitedStates)

        do {
            let wrong = try XCTUnwrap(URL(string: "com.medtronic.carepartner:/sso?code=one-time&state=wrong"))
            _ = try await client.installOAuthSession(callbackURL: wrong, transaction: transaction, region: .outsideUnitedStates)
            XCTFail("Expected state validation")
        } catch {
            XCTAssertEqual(error as? CareLinkError, .invalidCallback)
        }
    }

    func testOAuthCallbackMatchesOnlyTheDiscoveredRedirect() throws {
        let redirect = try XCTUnwrap(URL(string: "com.medtronic.carepartner:/sso"))
        XCTAssertTrue(CareLinkOAuthCallback.matches(
            try XCTUnwrap(URL(string: "com.medtronic.carepartner:/sso?code=value&state=value")),
            redirectURI: redirect
        ))
        XCTAssertFalse(CareLinkOAuthCallback.matches(
            try XCTUnwrap(URL(string: "com.medtronic.carepartner:/other?code=value&state=value")),
            redirectURI: redirect
        ))
        XCTAssertFalse(CareLinkOAuthCallback.matches(
            try XCTUnwrap(URL(string: "https://carelink-login.minimed.eu/sso?code=value&state=value")),
            redirectURI: redirect
        ))
    }

    func testDiscoveredAuthorizationUsesRegionStateAndPKCE() async throws {
        let client = CareLinkClient(
            session: URLSession(configuration: stubConfiguration()),
            tokenStore: CareLinkMemoryTokenStore(),
            appVersionProvider: { "9.7.6" }
        )
        let transaction = try await client.authorizationTransaction(region: .outsideUnitedStates)
        let query = try XCTUnwrap(URLComponents(url: transaction.authorizationURL, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(transaction.authorizationURL.host, "carelink-login.minimed.eu")
        XCTAssertEqual(query.first(where: { $0.name == "state" })?.value, transaction.state)
        XCTAssertEqual(query.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
        XCTAssertNotNil(query.first(where: { $0.name == "code_challenge" })?.value)
        XCTAssertTrue(transaction.configuration.scope.contains("offline_access"))
        XCTAssertTrue(URLProtocolStub.recorded(path: "/connect/carepartner/v13/discover/android/9.7"))
    }

    func testCareLinkDiscoveryVersionRequiresMajorMinorPatch() {
        XCTAssertEqual(
            ConstantsCareLink.carePartnerDiscoveryURL(appVersion: "3.8.0")?.path,
            "/connect/carepartner/v13/discover/android/3.8"
        )
        ["", "3.8", "3.8.0.1", "3..0", "3.8.x", "٣.٨.٠"].forEach {
            XCTAssertNil(ConstantsCareLink.carePartnerDiscoveryURL(appVersion: $0))
        }
    }

    // MARK: - Glucose and therapy parsing

    func testGlucoseParserCombinesDeduplicatesSortsAndRejectsInvalidValues() throws {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        let data = try JSONSerialization.data(withJSONObject: [
            "currentServerTime": ms,
            "sMedicalDeviceTime": "2027-01-15T08:00:00",
            "medicalDeviceFamily": "GUARDIAN",
            "sgs": [["sg": 110, "timestamp": ms - 300_000], ["sg": 119, "datetime": "2027-01-15T08:00:00"], ["sg": 0, "timestamp": ms]],
            "lastSG": ["sg": 120, "timestamp": ms]
        ])
        let result = try CareLinkGlucoseParser.readings(from: data, now: now)
        XCTAssertEqual(result.readings.map(\.sgv), [120, 110])
        XCTAssertEqual(result.metadata.sensorType, "Guardian")
    }

    func testGlucoseParserNormalizesDeviceLocalTimestamps() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "currentServerTime": now.timeIntervalSince1970 * 1000,
            "sMedicalDeviceTime": "2027-01-15T10:00:00",
            "sgs": [["sg": 125, "datetime": "2027-01-15T10:00:00"]]
        ])
        let result = try CareLinkGlucoseParser.readings(from: data, now: now)
        XCTAssertEqual(try XCTUnwrap(result.readings.first).timeStamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
    }

    func testGlucoseParserUsesNumericMedicalDeviceClockForOffset() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "currentServerTime": now.timeIntervalSince1970 * 1000,
            "medicalDeviceTime": now.addingTimeInterval(3600).timeIntervalSince1970 * 1000,
            "sgs": [["sg": 126, "timestamp": "2027-01-15T09:00:00"]]
        ])
        let reading = try XCTUnwrap(CareLinkGlucoseParser.readings(from: data, now: now).readings.first)
        XCTAssertEqual(reading.timeStamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
    }

    func testTherapyParserStoresNativeAutoBasalAmountAndNormalizesPumpRate() throws {
        let markers: [[String: Any]] = [
            marker(type: "AUTO_BASAL_DELIVERY", timestamp: "2027-01-15T08:55:00", values: ["bolusAmount": "0.125"]),
            marker(type: "AUTO_BASAL_DELIVERY", timestamp: "2027-01-15T08:55:00", values: ["bolusAmount": "0.125"]),
            marker(type: "INSULIN", timestamp: "2027-01-15T08:50:00", values: ["deliveredFastAmount": "1.2", "deliveredExtendedAmount": "0.3", "programmedFastAmount": "9", "completed": true, "activationType": "AUTOCORRECTION"]),
            marker(type: "MEAL", timestamp: "2027-01-15T08:45:00", values: ["amount": 45]),
            marker(type: "INSULIN", timestamp: "2027-01-15T08:40:00", values: ["deliveredFastAmount": "0", "completed": false]),
            marker(type: "AUTO_MODE_STATUS", timestamp: "2027-01-15T08:35:00", values: [:])
        ]
        let data = try JSONSerialization.data(withJSONObject: [
            "patientData": [
                "currentServerTime": now.timeIntervalSince1970 * 1000,
                "medicalDeviceTime": now.addingTimeInterval(3600).timeIntervalSince1970 * 1000,
                "lastMedicalDeviceDataUpdateServerTime": now.addingTimeInterval(-60).timeIntervalSince1970 * 1000,
                "activeInsulin": ["amount": 1.65, "datetime": "2027-01-15T09:00:00"],
                "therapyAlgorithmState": ["autoModeShieldState": "AUTO_BASAL", "autoModeReadinessState": "NO_ACTION_REQUIRED", "plgmLgsState": "FEATURE_OFF"],
                "reservoirRemainingUnits": 61.3,
                "reservoirLevelPercent": 20,
                "pumpBatteryLevelPercent": 75,
                "pumpSuspended": false,
                "pumpCommunicationState": true,
                "conduitMedicalDeviceInRange": true,
                "maxAutoBasalRate": 2.2,
                "maxBolusAmount": 25,
                "markers": markers
            ]
        ])

        let payload = try CareLinkTherapyParser.payload(from: data, patientID: "patient-1", now: now)
        XCTAssertTrue(payload.pump.isReported)
        XCTAssertEqual(payload.treatments.count, 3)
        let basal = try XCTUnwrap(payload.treatments.first(where: { $0.type == .AutomaticBasal }))
        XCTAssertEqual(basal.value, 0.125, accuracy: 0.0001)
        XCTAssertEqual(basal.durationMinutes, 5)
        let insulin = try XCTUnwrap(payload.treatments.first(where: { $0.type == .Insulin }))
        XCTAssertEqual(insulin.value, 1.5, accuracy: 0.0001)
        XCTAssertEqual(insulin.notes, "Autocorrection")
        XCTAssertEqual(payload.treatments.first(where: { $0.type == .Carbs })?.value, 45)
        XCTAssertEqual(try XCTUnwrap(payload.pump.observedAt).timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(payload.pump.activeInsulin, 1.65)
        XCTAssertEqual(payload.pump.currentBasalRate, 1.5)
        XCTAssertEqual(payload.pump.reservoirUnits, 61.3)
        XCTAssertEqual(payload.pump.batteryPercent, 75)
        XCTAssertEqual(payload.pump.algorithmState, "AUTO_BASAL")
        XCTAssertTrue(payload.pump.reportsActiveSmartGuard)
    }

    func testTherapyParserDoesNotInferPumpFromSimpleraIOBAndUnavailablePumpFields() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            // Simplera is a medical device, but MMT-5100J is a CGM sensor rather than a pump.
            // CareLink nevertheless returns it through the historically named pump model field.
            "pumpModelNumber": "MMT-5100J",
            "medicalDeviceTime": now.timeIntervalSince1970 * 1000,
            "lastMedicalDeviceDataUpdateServerTime": now.timeIntervalSince1970 * 1000,
            "activeInsulin": ["amount": 1.25, "datetime": now.timeIntervalSince1970 * 1000],
            "basal": -1,
            "reservoirRemainingUnits": -1,
            "reservoirLevelPercent": -1,
            "pumpBatteryLevelPercent": -1,
            "pumpSuspended": false,
            "pumpCommunicationState": false,
            "conduitMedicalDeviceInRange": true,
            "maxAutoBasalRate": -1,
            "maxBolusAmount": -1
        ])

        let pump = try CareLinkTherapyParser.payload(from: data, patientID: "patient", now: now).pump
        XCTAssertFalse(pump.isReported)
        XCTAssertEqual(pump.activeInsulin, 1.25)
        XCTAssertEqual(try XCTUnwrap(pump.activeInsulinAt).timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(pump.isCommunicating, false)
        XCTAssertEqual(pump.isInRange, true)
        XCTAssertNil(pump.currentBasalRate)
        XCTAssertNil(pump.reservoirUnits)
        XCTAssertNil(pump.batteryPercent)
        XCTAssertNil(pump.maximumAutoBasalRate)
        XCTAssertNil(pump.maximumBolusAmount)

        var snapshot = CareLinkStatusSnapshot(status: .active, lastReadingAt: now, pump: pump)
        let presentation = try XCTUnwrap(snapshot.aidStatus).presentation(referenceDate: now)
        XCTAssertEqual(presentation.systemImage, ConstantsHomeView.careLinkPumpSystemImage)
        XCTAssertEqual(presentation.title, Texts_Common.Ok)
        XCTAssertEqual(presentation.color, .green)

        // The service connection remains healthy; absent-pump communication flags must not turn
        // either the service or the Home therapy strip into a red disconnected-pump warning.
        snapshot.status = CareLinkStatePolicy.status(hasGlucose: true, lastReadingAt: now, pump: pump, now: now)
        XCTAssertEqual(snapshot.status, .active)
    }

    func testAutoBasalIdentityDoesNotChangeWhenNextMarkerArrives() throws {
        let first = marker(type: "AUTO_BASAL_DELIVERY", timestamp: "2027-01-15T07:55:00", values: ["bolusAmount": "0.125"])
        let next = marker(type: "AUTO_BASAL_DELIVERY", timestamp: "2027-01-15T07:59:00", values: ["bolusAmount": "0.100"])
        let firstData = try JSONSerialization.data(withJSONObject: ["markers": [first]])
        let secondData = try JSONSerialization.data(withJSONObject: ["markers": [first, next]])
        let firstPayload = try CareLinkTherapyParser.payload(from: firstData, patientID: "patient", now: now)
        let secondPayload = try CareLinkTherapyParser.payload(from: secondData, patientID: "patient", now: now)

        let original = try XCTUnwrap(firstPayload.treatments.first)
        let recalculated = try XCTUnwrap(secondPayload.treatments.min(by: { $0.date < $1.date }))
        XCTAssertEqual(original.sourceIdentifier, recalculated.sourceIdentifier)
        XCTAssertEqual(original.value, recalculated.value)
        XCTAssertNotEqual(original.durationMinutes, recalculated.durationMinutes)
    }

    func testSmartGuardShieldRequiresAnAutomaticBasalState() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "therapyAlgorithmState": ["autoModeShieldState": "FEATURE_OFF"]
        ])
        let payload = try CareLinkTherapyParser.payload(from: data, patientID: "patient-1", now: now)
        XCTAssertFalse(payload.pump.reportsActiveSmartGuard)
    }

    func testTherapyParserRejectsUnavailablePumpSentinelsButKeepsZeroValues() throws {
        let unavailableData = try JSONSerialization.data(withJSONObject: [
            "activeInsulin": ["amount": -1],
            "basal": -1,
            "reservoirRemainingUnits": -1,
            "reservoirLevelPercent": -1,
            "pumpBatteryLevelPercent": -1,
            "maxAutoBasalRate": -1,
            "maxBolusAmount": -1
        ])
        let unavailable = try CareLinkTherapyParser.payload(from: unavailableData, patientID: "patient", now: now).pump

        XCTAssertNil(unavailable.activeInsulin)
        XCTAssertNil(unavailable.currentBasalRate)
        XCTAssertNil(unavailable.reservoirUnits)
        XCTAssertNil(unavailable.reservoirPercent)
        XCTAssertNil(unavailable.batteryPercent)
        XCTAssertNil(unavailable.maximumAutoBasalRate)
        XCTAssertNil(unavailable.maximumBolusAmount)

        let zeroData = try JSONSerialization.data(withJSONObject: [
            "activeInsulin": ["amount": 0],
            "basal": 0,
            "reservoirRemainingUnits": 0,
            "reservoirLevelPercent": 0,
            "pumpBatteryLevelPercent": 0
        ])
        let zero = try CareLinkTherapyParser.payload(from: zeroData, patientID: "patient", now: now).pump

        XCTAssertEqual(zero.activeInsulin, 0)
        XCTAssertEqual(zero.currentBasalRate, 0)
        XCTAssertEqual(zero.reservoirUnits, 0)
        XCTAssertEqual(zero.reservoirPercent, 0)
        XCTAssertEqual(zero.batteryPercent, 0)
    }

    func testTherapyParserRejectsInvalidFutureAndUnknownMarkers() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "markers": [
                marker(type: "MEAL", timestamp: "2027-01-15T08:30:00", values: ["amount": 0]),
                marker(type: "INSULIN", timestamp: "2027-01-15T09:30:00", values: ["deliveredFastAmount": 1, "completed": true]),
                marker(type: "LOW_GLUCOSE_SUSPENDED", timestamp: "2027-01-15T07:30:00", values: [:])
            ]
        ])
        XCTAssertTrue(try CareLinkTherapyParser.payload(from: data, patientID: "patient-1", now: now).treatments.isEmpty)
    }

    func testTherapySourceIdentityIncludesPatient() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "markers": [marker(type: "MEAL", timestamp: "2027-01-15T07:30:00", values: ["amount": 20])]
        ])
        let first = try XCTUnwrap(CareLinkTherapyParser.payload(from: data, patientID: "one", now: now).treatments.first)
        let second = try XCTUnwrap(CareLinkTherapyParser.payload(from: data, patientID: "two", now: now).treatments.first)
        XCTAssertNotEqual(first.sourceIdentifier, second.sourceIdentifier)
    }

    func testTherapyParserUsesStableMarkerIDsAndTopLevelFields() throws {
        let timestamp = "2027-01-15T07:30:00"
        let data = try JSONSerialization.data(withJSONObject: [
            "markers": [
                [
                    "id": 101,
                    "type": "INSULIN",
                    "dateTime": timestamp,
                    "programmedFastAmount": 0.8,
                    "programmedExtendedAmount": 0.2,
                    "bolusType": "DUAL",
                    "programmedDuration": 30
                ],
                [
                    "id": 102,
                    "type": "INSULIN",
                    "dateTime": timestamp,
                    "programmedFastAmount": 0.8,
                    "programmedExtendedAmount": 0.2,
                    "bolusType": "DUAL"
                ],
                [
                    "id": 103,
                    "type": "MEAL",
                    "dateTime": timestamp,
                    "amount": 18
                ]
            ]
        ])

        let treatments = try CareLinkTherapyParser.payload(from: data, patientID: "one", now: now).treatments
        XCTAssertEqual(treatments.filter { $0.type == .Insulin }.count, 2)
        XCTAssertEqual(treatments.filter { $0.type == .Insulin }.map(\.value), [1, 1])
        XCTAssertEqual(treatments.first(where: { $0.sourceIdentifier.hasSuffix("|101") })?.notes, "Dual bolus, 30 min")
        XCTAssertEqual(treatments.first(where: { $0.type == .Carbs })?.value, 18)
        XCTAssertEqual(Set(treatments.map(\.sourceIdentifier)).count, 3)
    }

    func testGlucoseParserUnwrapsDisplayMessage() throws {
        let data = try JSONSerialization.data(withJSONObject: ["patientData": ["lastSG": ["sg": 132, "timestamp": now.timeIntervalSince1970 * 1000]]])
        XCTAssertEqual(try CareLinkGlucoseParser.readings(from: data, now: now).readings.map(\.sgv), [132])
    }

    func testGlucoseParserNormalizesSensorRemainingLife() throws {
        let minutesData = try JSONSerialization.data(withJSONObject: ["patientData": [
            "sensorDurationMinutes": 7624,
            "sensorDurationHours": 255
        ]])
        let hoursData = try JSONSerialization.data(withJSONObject: ["patientData": [
            "sensorDurationMinutes": -1,
            "sensorDurationHours": 8
        ]])
        let unavailableData = try JSONSerialization.data(withJSONObject: ["patientData": [
            "sensorDurationMinutes": -1,
            "sensorDurationHours": 255
        ]])

        XCTAssertEqual(try CareLinkGlucoseParser.readings(from: minutesData, now: now).metadata.sensorRemainingMinutes, 7624)
        XCTAssertEqual(try CareLinkGlucoseParser.readings(from: hoursData, now: now).metadata.sensorRemainingMinutes, 480)
        XCTAssertNil(try CareLinkGlucoseParser.readings(from: unavailableData, now: now).metadata.sensorRemainingMinutes)
    }

    // MARK: - Account, scheduling and status policies

    func testSelectionRoleSchedulingAndStatusPolicies() {
        let one = CareLinkPatient(id: "one", username: "patient1", firstName: nil, lastName: nil)
        let two = CareLinkPatient(id: "two", username: "patient2", firstName: nil, lastName: nil)
        XCTAssertEqual(CareLinkPatientSelection.resolve(patients: [one], savedID: nil), "one")
        XCTAssertEqual(CareLinkPatientSelection.resolve(patients: [one, two], savedID: "patient2"), "patient2")
        XCTAssertNil(CareLinkPatientSelection.resolve(patients: [one, two], savedID: "missing"))
        XCTAssertTrue(CareLinkAccountRole.isPatient("PATIENT_OUS"))
        XCTAssertFalse(CareLinkAccountRole.isPatient("CARE_PARTNER"))
        XCTAssertTrue(CareLinkAccountRole.isSupportedFollower("CARE_PARTNER_OUS"))
        XCTAssertTrue(CareLinkPollingPolicy.isStale(lastReadingAt: now.addingTimeInterval(-1201), now: now))
        XCTAssertEqual(CareLinkPollingPolicy.backoff(failureCount: 99), 300)
        XCTAssertEqual(CareLinkStatePolicy.status(for: .reconnectRequired), .loginRequired)
        XCTAssertEqual(CareLinkConnectionStatus.loginRequired.title, "Log In Required")
        XCTAssertEqual(CareLinkConnectionStatus.connecting.title, "Connecting...")
        XCTAssertEqual(CareLinkStatePolicy.status(for: .rateLimited(now)), .rateLimited)
        XCTAssertEqual(CareLinkStatePolicy.status(for: .noGlucoseData), .noData)
    }

    func testCareLinkPollingAnticipatesNextServerDataUpdate() {
        let next = CareLinkPollingPolicy.nextPollDate(
            latestReadingAt: now.addingTimeInterval(-60),
            lastDataUpdateAt: now,
            now: now
        )
        XCTAssertEqual(next, now.addingTimeInterval(330))
    }

    func testCareLinkPollingClampsFutureGlucoseTimestamp() {
        let next = CareLinkPollingPolicy.nextPollDate(
            latestReadingAt: now.addingTimeInterval(90),
            lastDataUpdateAt: now.addingTimeInterval(-10),
            now: now
        )
        XCTAssertEqual(next, now.addingTimeInterval(320))
    }

    func testCareLinkPollingClampsFutureGlucoseTimestampWithoutServerUpdate() {
        let next = CareLinkPollingPolicy.nextPollDate(
            latestReadingAt: now.addingTimeInterval(90),
            lastDataUpdateAt: nil,
            now: now
        )
        XCTAssertEqual(next, now.addingTimeInterval(330))
    }

    func testCareLinkPollingRetriesMissingDataEveryMinute() {
        let anchor = now.addingTimeInterval(-400)
        let next = CareLinkPollingPolicy.nextPollDate(
            latestReadingAt: anchor,
            lastDataUpdateAt: anchor,
            now: now
        )
        XCTAssertEqual(next, now.addingTimeInterval(50))
    }

    func testCareLinkPollingWithoutTimestampsRetriesAfterOneMinute() {
        XCTAssertEqual(
            CareLinkPollingPolicy.nextPollDate(latestReadingAt: nil, lastDataUpdateAt: nil, now: now),
            now.addingTimeInterval(60)
        )
    }

    func testLoginPrefillAllowsPartialStoredValues() throws {
        let suiteName = "CareLinkTests.credentials.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(CareLinkLoginPrefill.stored(in: defaults), CareLinkLoginPrefill(username: nil, password: nil))
        defaults.careLinkUsername = " person@example.com "
        XCTAssertEqual(CareLinkLoginPrefill.stored(in: defaults).username, "person@example.com")
        defaults.careLinkPassword = "password with spaces"
        XCTAssertEqual(
            CareLinkLoginPrefill.stored(in: defaults),
            CareLinkLoginPrefill(username: "person@example.com", password: "password with spaces")
        )
    }

    func testCredentialPrefillIsRestrictedToMedtronicPagesAndEscapesValues() {
        XCTAssertTrue(CareLinkLoginPrefillScript.allows(URL(string: "https://carelink-login.minimed.eu/u/login")))
        XCTAssertTrue(CareLinkLoginPrefillScript.allows(URL(string: "https://carelink.minimed.com/patient/sso/login")))
        XCTAssertFalse(CareLinkLoginPrefillScript.allows(URL(string: "https://minimed.eu.example.com/login")))
        XCTAssertFalse(CareLinkLoginPrefillScript.allows(URL(string: "https://example.com/login")))

        let script = CareLinkLoginPrefillScript.script(prefill: CareLinkLoginPrefill(username: "person\"@example.com", password: "pass\\word"))
        XCTAssertTrue(script.contains("person\\\"@example.com"))
        XCTAssertTrue(script.contains("pass\\\\word"))
        XCTAssertTrue(script.contains("MutationObserver"))
    }

    func testSuccessfulResponseWithDisconnectedPumpReportsNoData() {
        let disconnected = CareLinkPumpSnapshot(isReported: true, isCommunicating: false, isInRange: false)
        let connected = CareLinkPumpSnapshot(isReported: true, isCommunicating: true, isInRange: true)
        let noPump = CareLinkPumpSnapshot(isCommunicating: false, isInRange: false)

        XCTAssertEqual(
            CareLinkStatePolicy.status(hasGlucose: true, lastReadingAt: now.addingTimeInterval(-60), pump: disconnected, now: now),
            .noData
        )
        XCTAssertEqual(
            CareLinkStatePolicy.detail(hasGlucose: true, pump: disconnected),
            "CareLink is connected, but the pump is not currently communicating with the phone."
        )
        XCTAssertEqual(
            CareLinkStatePolicy.status(hasGlucose: true, lastReadingAt: now.addingTimeInterval(-60), pump: connected, now: now),
            .active
        )
        XCTAssertEqual(
            CareLinkStatePolicy.status(hasGlucose: true, lastReadingAt: now.addingTimeInterval(-60), pump: noPump, now: now),
            .active
        )
        XCTAssertNil(CareLinkStatePolicy.detail(hasGlucose: true, pump: noPump))
    }

    // MARK: - Pump history

    func testCareLinkPumpSnapshotCreatesStableHistoricalStatus() throws {
        let pump = CareLinkPumpSnapshot(
            isReported: true,
            observedAt: now,
            activeInsulin: 1.25,
            currentBasalRate: 0.8,
            reservoirUnits: 42,
            batteryPercent: 75,
            isSuspended: false,
            algorithmState: "AUTO_BASAL"
        )
        let metadata = CareLinkMetadata(deviceModel: "MMT-1886")
        let status = try XCTUnwrap(pump.homeDeviceStatus(metadata: metadata, checkedAt: now.addingTimeInterval(5)))

        XCTAssertEqual(status.id, "carelink-1800000000000")
        XCTAssertEqual(status.createdAt, now)
        XCTAssertEqual(status.lastLoopDate, now)
        XCTAssertEqual(status.iob, 1.25)
        XCTAssertEqual(status.rate, 0.8)
        XCTAssertEqual(status.pumpReservoir, 42)
        XCTAssertEqual(status.pumpBatteryPercent, 75)
        XCTAssertEqual(status.pumpModel, "MMT-1886")
    }

    func testDisconnectedCareLinkPumpStatusIsStoredConsistently() throws {
        let pump = CareLinkPumpSnapshot(
            isReported: true,
            observedAt: now,
            isSuspended: false,
            isCommunicating: false,
            isInRange: false
        )
        let status = try XCTUnwrap(pump.homeDeviceStatus(metadata: CareLinkMetadata(), checkedAt: now))

        XCTAssertEqual(pump.pumpStatusTitle, "Disconnected")
        XCTAssertEqual(status.pumpStatus, "Disconnected")
        XCTAssertEqual(status.lastLoopDate, .distantPast)
    }

    func testAutoBasalCreatesSparseHistoricalPumpStatus() throws {
        let record = CareLinkTherapyRecord(
            sourceIdentifier: "patient|AUTO_BASAL_DELIVERY|marker-1",
            date: now.addingTimeInterval(-300),
            type: .AutomaticBasal,
            value: 0.125,
            durationMinutes: 5,
            nightscoutEventType: "Temp Basal",
            notes: nil
        )
        let status = try XCTUnwrap(record.historicalPumpDeviceStatus(
            metadata: CareLinkMetadata(deviceModel: "MMT-1886"),
            checkedAt: now
        ))

        XCTAssertEqual(status.createdAt, record.date)
        XCTAssertEqual(status.lastLoopDate, record.date)
        XCTAssertEqual(status.rate, 1.5)
        XCTAssertEqual(status.duration, 5)
        XCTAssertEqual(status.pumpModel, "MMT-1886")
        XCTAssertNil(status.iob)
        XCTAssertNil(status.pumpReservoir)
        XCTAssertNil(status.pumpBatteryPercent)
    }

    func testSparseHistoricalStatusRetainsPriorPumpTelemetryForDisplay() throws {
        let fullStatus = try XCTUnwrap(CareLinkPumpSnapshot(
            isReported: true,
            observedAt: now.addingTimeInterval(-600),
            activeInsulin: 1.25,
            currentBasalRate: 0.8,
            reservoirUnits: 42,
            batteryPercent: 75,
            algorithmState: "AUTO_BASAL"
        ).homeDeviceStatus(metadata: CareLinkMetadata(deviceModel: "MMT-1886"), checkedAt: now))
        let basalStatus = try XCTUnwrap(CareLinkTherapyRecord(
            sourceIdentifier: "patient|AUTO_BASAL_DELIVERY|marker-2",
            date: now.addingTimeInterval(-300),
            type: .AutomaticBasal,
            value: 0.125,
            durationMinutes: 5,
            nightscoutEventType: "Temp Basal",
            notes: nil
        ).historicalPumpDeviceStatus(metadata: CareLinkMetadata(deviceModel: "MMT-1886"), checkedAt: now))

        let composed = try XCTUnwrap(NightscoutDeviceStatus.composingDisplayValues(
            fromNewestFirst: [basalStatus, fullStatus]
        ))

        XCTAssertEqual(composed.createdAt, basalStatus.createdAt)
        XCTAssertEqual(composed.rate, 1.5)
        XCTAssertEqual(composed.duration, 5)
        XCTAssertEqual(composed.iob, 1.25)
        XCTAssertEqual(composed.pumpReservoir, 42)
        XCTAssertEqual(composed.pumpBatteryPercent, 75)
    }

    func testAutomaticBasalRateMathPreservesDeliveredDose() throws {
        XCTAssertEqual(
            try XCTUnwrap(AutomaticBasalTreatmentMath.rate(amount: 0.125, durationSeconds: 5 * 60)),
            1.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(AutomaticBasalTreatmentMath.rate(
                amount: 0.125,
                durationSeconds: ConstantsGlucoseChart.automaticBasalPulseDisplayDuration
            )),
            3.0,
            accuracy: 0.0001
        )
        XCTAssertNil(AutomaticBasalTreatmentMath.rate(amount: 0.125, durationSeconds: 0))
    }

    func testAutomaticBasalTreatmentTypeIsAppended() {
        XCTAssertEqual(TreatmentType.AutomaticBasal.rawValue, 9)
        XCTAssertEqual(TreatmentType.AutomaticBasal.unit(), Texts_TreatmentsView.insulinUnit)
    }

    func testVisibleBasalStepsPreserveEqualTimestampOrder() {
        let transition = now.addingTimeInterval(-60)
        let points = [
            GlucoseChartPoint(date: transition, value: 80, idPrefix: "previous"),
            GlucoseChartPoint(date: transition, value: 40, idPrefix: "next")
        ]

        let visible = points.visibleStepPoints(
            from: transition.addingTimeInterval(-1),
            to: transition.addingTimeInterval(1),
            idPrefix: "visible"
        )

        XCTAssertEqual(visible.map(\.value), [80, 40, 40])
    }

    // MARK: - Manager integration

    func testManagerActivationAndDelegateDelivery() async {
        XCTAssertTrue(CareLinkFollowManager.shouldActivate(isMaster: false, dataSource: .careLink))
        XCTAssertFalse(CareLinkFollowManager.shouldActivate(isMaster: true, dataSource: .careLink))
        let delegate = FollowerDelegateSpy()
        await CareLinkFollowManager.deliver([FollowerBgReading(timeStamp: now, sgv: 121)], to: delegate)
        XCTAssertEqual(delegate.received.map(\.sgv), [121])
    }

    @MainActor
    func testCareLinkVersionUpdateCatcherPromotesOlderDefaultsWithoutDowngradingNewerOverride() {
        let defaultsSnapshot = CareLinkDefaultsSnapshot(keys: [
            .isMaster,
            .careLinkVersion,
        ])
        let defaults = UserDefaults.standard
        defaults.isMaster = true
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)

        func makeManager() -> CareLinkFollowManager {
            CareLinkFollowManager(
                coreDataManager: coreDataManager,
                followerDelegate: FollowerDelegateSpy(),
                backgroundKeepAliveManager: CareLinkNoOpKeepAliveManager(),
                startsInitialDownload: false,
                pollingSchedulerFactory: { _, _ in CareLinkNoOpTimer() }
            )
        }

        defaults.careLinkVersion = "3.6.0"
        var manager: CareLinkFollowManager? = makeManager()
        XCTAssertNotNil(manager)
        XCTAssertEqual(defaults.careLinkVersion, ConstantsCareLink.carePartnerAppVersionDefault)
        manager = nil

        defaults.careLinkVersion = "9.9.9"
        manager = makeManager()
        XCTAssertNotNil(manager)
        XCTAssertEqual(defaults.careLinkVersion, "9.9.9")
        manager = nil

        defaultsSnapshot.restore()
    }

    func testPendingTherapyBatchRetainsUniqueRecordsAndUsesNewestValues() {
        let first = CareLinkTherapyRecord(
            sourceIdentifier: "first",
            date: now,
            type: .Carbs,
            value: 10,
            durationMinutes: 0,
            nightscoutEventType: "Carb Correction",
            notes: nil
        )
        let oldShared = CareLinkTherapyRecord(
            sourceIdentifier: "shared",
            date: now.addingTimeInterval(1),
            type: .Insulin,
            value: 1,
            durationMinutes: 0,
            nightscoutEventType: "Bolus",
            notes: nil
        )
        let newShared = CareLinkTherapyRecord(
            sourceIdentifier: "shared",
            date: now.addingTimeInterval(1),
            type: .Insulin,
            value: 2,
            durationMinutes: 0,
            nightscoutEventType: "Bolus",
            notes: nil
        )
        var firstPump = CareLinkPumpSnapshot()
        firstPump.activeInsulin = 1
        var newestPump = CareLinkPumpSnapshot()
        newestPump.activeInsulin = 2
        var batch = CareLinkTherapyImportBatch(
            generation: 4,
            treatments: [first, oldShared],
            pump: firstPump,
            metadata: CareLinkMetadata(accountName: "old"),
            checkedAt: now
        )

        batch.merge(CareLinkTherapyImportBatch(
            generation: 4,
            treatments: [newShared],
            pump: newestPump,
            metadata: CareLinkMetadata(accountName: "new"),
            checkedAt: now.addingTimeInterval(5)
        ))

        XCTAssertEqual(batch.treatments.map { $0.sourceIdentifier }, ["first", "shared"])
        XCTAssertEqual(batch.treatments.last?.value, 2)
        XCTAssertEqual(batch.pump.activeInsulin, 2)
        XCTAssertEqual(batch.metadata.accountName, "new")
        XCTAssertEqual(batch.checkedAt, now.addingTimeInterval(5))
    }

    @MainActor
    func testBlockedTherapyImportCannotBlockGlucoseOrAnotherPoll() async throws {
        let defaultsSnapshot = CareLinkDefaultsSnapshot(keys: [
            .isMaster,
            .followerDataSourceType,
            .followerBackgroundKeepAliveType,
            .therapyDataSourceType,
            .careLinkRegion,
            .careLinkSelectedPatientID,
        ])
        let defaults = UserDefaults.standard
        defaults.isMaster = false
        defaults.followerDataSourceType = .careLink
        defaults.followerBackgroundKeepAliveType = .heartbeat
        defaults.therapyDataSourceType = .automatic
        defaults.careLinkRegion = CareLinkRegion.outsideUnitedStates.rawValue
        defaults.careLinkSelectedPatientID = nil

        let delegate = FollowerDelegateSpy()
        let state = CareLinkAccountState()
        let importer = BlockingCareLinkTherapyImporter()
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        var manager: CareLinkFollowManager? = CareLinkFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: CareLinkNoOpKeepAliveManager(),
            client: makeClient(),
            state: state,
            therapyImporter: importer,
            pollingSchedulerFactory: { _, _ in CareLinkNoOpTimer() }
        )
        defer {
            manager = nil
            defaultsSnapshot.restore()
            Task { await importer.releaseAll() }
        }

        let firstDeliveryCompleted = await waitUntil { delegate.deliveryCount == 1 }
        XCTAssertTrue(firstDeliveryCompleted)
        XCTAssertEqual(delegate.received.first?.sgv, 123)
        let firstImportStarted = await waitUntil { await importer.treatmentCallCount == 1 }
        XCTAssertTrue(firstImportStarted)

        manager?.refreshNow()

        // This is the smoking-gun assertion: the second response reaches the established follower
        // delegate even though the first response's therapy persistence has not returned.
        let secondDeliveryCompleted = await waitUntil { delegate.deliveryCount == 2 }
        XCTAssertTrue(secondDeliveryCompleted)
        let blockedTreatmentCallCount = await importer.treatmentCallCount
        let blockedMaximumConcurrentImports = await importer.maximumConcurrentTreatmentImports
        XCTAssertEqual(blockedTreatmentCallCount, 1)
        XCTAssertEqual(blockedMaximumConcurrentImports, 1)

        await importer.releaseNext()
        let secondImportStarted = await waitUntil { await importer.treatmentCallCount == 2 }
        XCTAssertTrue(secondImportStarted)
        let firstImportPublished = await waitUntil { state.snapshot.lastTherapyImportAt != nil }
        XCTAssertTrue(firstImportPublished)
        let publishedImportDate = state.snapshot.lastTherapyImportAt

        defaults.followerDataSourceType = .nightscout
        await Task.yield()
        await importer.releaseNext()
        let bothImportsCompleted = await waitUntil { await importer.completedTreatmentImportCount == 2 }
        XCTAssertTrue(bothImportsCompleted)
        XCTAssertEqual(state.snapshot.lastTherapyImportAt, publishedImportDate)
        let maximumConcurrentImports = await importer.maximumConcurrentTreatmentImports
        XCTAssertEqual(maximumConcurrentImports, 1)
    }

    func testLifecyclePolicyRequiresSelectionAndOAuthSessionForPolling() {
        XCTAssertEqual(
            CareLinkLifecyclePolicy.state(isSelected: false, hasSession: true),
            .inactive
        )
        XCTAssertEqual(
            CareLinkLifecyclePolicy.state(isSelected: true, hasSession: false),
            .awaitingLogin
        )
        XCTAssertEqual(
            CareLinkLifecyclePolicy.state(isSelected: true, hasSession: true),
            .authenticated
        )
        XCTAssertTrue(CareLinkLifecyclePolicy.permitsPolling(.authenticated))
        for state in [
            CareLinkLifecycleState.inactive,
            .awaitingLogin,
            .invalidatingSession,
            .authenticating,
        ] {
            XCTAssertFalse(CareLinkLifecyclePolicy.permitsPolling(state))
        }
    }

    func testRefreshCommandDoesNotUseLogoutPath() {
        let state = CareLinkAccountState()
        let controller = CareLinkControllerSpy()
        state.controller = controller

        state.refresh()

        XCTAssertEqual(controller.refreshCount, 1)
        XCTAssertEqual(controller.logoutCount, 0)
    }

    func testAccountStatePublishesBackgroundUpdatesOnMainThread() async {
        let state = CareLinkAccountState()
        let published = expectation(description: "CareLink state published")
        let observer = state.$snapshot.dropFirst().sink { snapshot in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(snapshot.status, .active)
            published.fulfill()
        }
        let stateBox = CareLinkTestSendableBox(value: state)

        DispatchQueue.global().async {
            stateBox.value.update { $0.status = .active }
        }

        await fulfillment(of: [published], timeout: 2)
        withExtendedLifetime(observer) {}
        observer.cancel()
    }

    @MainActor
    func testAccountStatePublishesOnlyChangedSnapshots() {
        let state = CareLinkAccountState()
        var publicationCount = 0
        let observer = state.$snapshot.sink { _ in publicationCount += 1 }

        state.update { $0.status = .connecting }
        XCTAssertEqual(publicationCount, 1)

        state.update { $0.status = .loginRequired }
        XCTAssertEqual(publicationCount, 2)

        state.update { $0.status = .active }
        XCTAssertEqual(publicationCount, 3)

        withExtendedLifetime(observer) {}
        observer.cancel()
    }

    // MARK: - Data flow policy

    func testTherapySourceRawValuesAreAppendOnly() {
        XCTAssertEqual(TherapyDataSourceType.automatic.rawValue, 0)
        XCTAssertEqual(TherapyDataSourceType.none.rawValue, 1)
        XCTAssertEqual(TherapyDataSourceType.nightscout.rawValue, 2)
        XCTAssertEqual(TherapyDataSourceType.careLink.rawValue, 3)
    }

    func testMasterAutomaticUsesNightscoutWithoutChangingGlucoseOwnership() {
        let policy = dataFlowPolicy(
            isMaster: true,
            followerSource: .careLink,
            therapySelection: .automatic,
            masterUploadsGlucose: true,
            nightscoutFollowType: .loop
        )

        XCTAssertEqual(policy.therapyDataSource, .nightscout)
        XCTAssertTrue(policy.exportsGlucoseToNightscout)
        XCTAssertFalse(policy.importsGlucoseFromNightscout)
        XCTAssertTrue(policy.importsTreatmentsFromNightscout)
        XCTAssertTrue(policy.importsStatusFromNightscout)
        XCTAssertFalse(policy.importsTherapyFromCareLink)
        XCTAssertEqual(policy.aidAnalyticsSource, .nightscout(.loop))
        XCTAssertTrue(policy.supportsAIDEnhancedAnalytics)
    }

    func testNightscoutFollowerCannotCreateGlucoseUploadLoop() {
        let policy = dataFlowPolicy(
            isMaster: false,
            followerSource: .nightscout,
            therapySelection: .automatic,
            followerUploadsGlucose: true,
            nightscoutFollowType: .openAPS
        )

        XCTAssertTrue(policy.importsGlucoseFromNightscout)
        XCTAssertFalse(policy.exportsGlucoseToNightscout)
        XCTAssertEqual(policy.therapyDataSource, .nightscout)
        XCTAssertTrue(policy.importsTreatmentsFromNightscout)
        XCTAssertTrue(policy.showsAIDData)
        XCTAssertEqual(policy.aidAnalyticsSource, .nightscout(.openAPS))
        XCTAssertTrue(policy.supportsAIDEnhancedAnalytics)
    }

    func testCareLinkAutomaticOwnsGlucoseAndTherapyWhileNightscoutIsExportOnly() {
        let policy = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .automatic,
            followerUploadsGlucose: true,
            nightscoutFollowType: .openAPS
        )

        XCTAssertEqual(policy.therapyDataSource, .careLink)
        XCTAssertTrue(policy.importsTherapyFromCareLink)
        XCTAssertFalse(policy.importsTreatmentsFromNightscout)
        XCTAssertFalse(policy.importsStatusFromNightscout)
        XCTAssertTrue(policy.exportsGlucoseToNightscout)
        XCTAssertTrue(policy.exportsTreatmentsToNightscout)
        XCTAssertTrue(policy.showsPumpData)
        XCTAssertFalse(policy.showsAIDData)
        XCTAssertTrue(policy.showsTherapyStatus)
        XCTAssertEqual(policy.aidAnalyticsSource, .careLink)
        XCTAssertTrue(policy.supportsAIDEnhancedAnalytics)
    }

    func testCareLinkGlucoseCanUseNightscoutTherapyInstead() {
        let policy = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .nightscout,
            nightscoutFollowType: .loop
        )

        XCTAssertEqual(policy.therapyDataSource, .nightscout)
        XCTAssertFalse(policy.importsTherapyFromCareLink)
        XCTAssertTrue(policy.importsTreatmentsFromNightscout)
        XCTAssertTrue(policy.importsStatusFromNightscout)
        XCTAssertEqual(policy.aidAnalyticsSource, .nightscout(.loop))
    }

    func testAIDAnalyticsUsesResolvedTherapyOwnershipInsteadOfRawSettings() {
        let careLinkAutomatic = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .automatic,
            nightscoutFollowType: .openAPS
        )
        XCTAssertEqual(careLinkAutomatic.therapyDataSource, .careLink)
        XCTAssertEqual(careLinkAutomatic.aidAnalyticsSource, .careLink)

        let careLinkWithNightscoutTherapy = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .nightscout,
            nightscoutFollowType: .openAPS
        )
        XCTAssertEqual(careLinkWithNightscoutTherapy.therapyDataSource, .nightscout)
        XCTAssertEqual(careLinkWithNightscoutTherapy.aidAnalyticsSource, .nightscout(.openAPS))

        let noAIDFollowType = dataFlowPolicy(
            isMaster: false,
            followerSource: .dexcomShare,
            therapySelection: .automatic,
            nightscoutFollowType: .none
        )
        XCTAssertEqual(noAIDFollowType.therapyDataSource, .nightscout)
        XCTAssertNil(noAIDFollowType.aidAnalyticsSource)
        XCTAssertFalse(noAIDFollowType.supportsAIDEnhancedAnalytics)

        let noTherapy = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .none,
            nightscoutFollowType: .loop
        )
        XCTAssertEqual(noTherapy.therapyDataSource, .none)
        XCTAssertNil(noTherapy.aidAnalyticsSource)
    }

    func testAIDAnalyticsSourceOwnsOnlyItsNormalizedDeviceStatusRecords() {
        XCTAssertFalse(AIDAnalyticsSource.careLink.supportsCOB)
        XCTAssertFalse(AIDAnalyticsSource.careLink.supportsScheduledBasalAnalytics)
        XCTAssertTrue(AIDAnalyticsSource.careLink.ownsDeviceStatus(with: "carelink://pump"))
        XCTAssertTrue(AIDAnalyticsSource.careLink.ownsDeviceStatus(with: "carelink://pump-history"))
        XCTAssertFalse(AIDAnalyticsSource.careLink.ownsDeviceStatus(with: "Trio"))
        XCTAssertFalse(AIDAnalyticsSource.careLink.ownsDeviceStatus(with: nil))

        let nightscout = AIDAnalyticsSource.nightscout(.loop)
        XCTAssertTrue(nightscout.supportsCOB)
        XCTAssertTrue(nightscout.supportsScheduledBasalAnalytics)
        XCTAssertFalse(nightscout.ownsDeviceStatus(with: "carelink://pump"))
        XCTAssertTrue(nightscout.ownsDeviceStatus(with: "loop://phone"))
        // Compatible Nightscout servers may omit the device identifier. They still belong to the
        // Nightscout import path and must not be discarded solely because identity is incomplete.
        XCTAssertTrue(nightscout.ownsDeviceStatus(with: nil))
    }

    func testOtherFollowersCanCombineGlucoseWithNightscoutTherapy() {
        for source in [FollowerDataSourceType.dexcomShare, .libreLinkUp, .libreLinkUpRussia, .medtrumEasyView, .calendar] {
            let policy = dataFlowPolicy(
                isMaster: false,
                followerSource: source,
                therapySelection: .automatic,
                followerUploadsGlucose: true
            )

            XCTAssertEqual(policy.therapyDataSource, .nightscout)
            XCTAssertTrue(policy.importsTreatmentsFromNightscout)
            XCTAssertTrue(policy.exportsGlucoseToNightscout)
            XCTAssertFalse(policy.importsTherapyFromCareLink)
        }
    }

    func testNoneDisablesRemoteTherapyImportsButKeepsNightscoutExport() {
        let policy = dataFlowPolicy(
            isMaster: true,
            followerSource: .nightscout,
            therapySelection: .none,
            masterUploadsGlucose: false,
            nightscoutFollowType: .loop
        )

        XCTAssertEqual(policy.therapyDataSource, .none)
        XCTAssertFalse(policy.importsTreatmentsFromNightscout)
        XCTAssertFalse(policy.importsStatusFromNightscout)
        XCTAssertFalse(policy.importsTherapyFromCareLink)
        XCTAssertTrue(policy.exportsTreatmentsToNightscout)
        XCTAssertFalse(policy.exportsGlucoseToNightscout)
        XCTAssertNil(policy.aidAnalyticsSource)
        XCTAssertFalse(policy.supportsAIDEnhancedAnalytics)
    }

    func testUnavailableCareLinkSelectionFallsBackWithoutBeingOffered() {
        let policy = dataFlowPolicy(
            isMaster: true,
            followerSource: .dexcomShare,
            therapySelection: .careLink
        )

        XCTAssertEqual(policy.therapyDataSource, .nightscout)
        XCTAssertFalse(policy.availableTherapyDataSources.contains(.careLink))

        let careLinkFollower = dataFlowPolicy(
            isMaster: false,
            followerSource: .careLink,
            therapySelection: .automatic
        )
        XCTAssertTrue(careLinkFollower.availableTherapyDataSources.contains(.careLink))
    }

    func testDisabledNightscoutResolvesAutomaticAndExplicitNightscoutToNone() {
        let automatic = dataFlowPolicy(
            isMaster: false,
            followerSource: .dexcomShare,
            therapySelection: .automatic,
            nightscoutEnabled: false
        )
        let explicit = dataFlowPolicy(
            isMaster: false,
            followerSource: .dexcomShare,
            therapySelection: .nightscout,
            nightscoutEnabled: false
        )

        XCTAssertEqual(automatic.therapyDataSource, .none)
        XCTAssertEqual(explicit.therapyDataSource, .none)
        XCTAssertFalse(automatic.availableTherapyDataSources.contains(.nightscout))
        XCTAssertFalse(automatic.exportsTreatmentsToNightscout)
        XCTAssertNil(automatic.aidAnalyticsSource)
        XCTAssertNil(explicit.aidAnalyticsSource)
    }

    // MARK: - Client requests and session lifecycle

    func testPersonalAccountUsesBearerWithoutBrowserCookiesAndProfileFallback() async throws {
        URLProtocolStub.omitUsername = true
        let client = makeClient(appVersion: "9.7.6")
        let result = try await client.userAndPatients(region: .outsideUnitedStates)
        XCTAssertEqual(result.metadata.role, "PATIENT_OUS")
        XCTAssertEqual(result.metadata.accountName, "profile-user")
        XCTAssertEqual(result.patients.count, 1)
        let headers = try XCTUnwrap(URLProtocolStub.headers.last)
        XCTAssertEqual(headers["Authorization"], "Bearer valid")
        XCTAssertNil(headers["Cookie"])

        URLProtocolStub.route = .periodic
        _ = try await client.fetchPatientData(
            region: .outsideUnitedStates,
            patient: try XCTUnwrap(result.patients.first),
            username: result.metadata.accountName,
            accountRole: result.metadata.role,
            countryCode: result.metadata.countryCode,
            linkedPatientCount: result.patients.count
        )
        let bodies = URLProtocolStub.requestBodies.filter { $0["role"] == "patient" }
        XCTAssertFalse(bodies.isEmpty)
        XCTAssertTrue(bodies.allSatisfy { $0["appVersion"] == "9.7.6" })
    }

    func testCarePartnerResolvesLinkedPatientsAndScopesPeriodicRequest() async throws {
        URLProtocolStub.role = "CARE_PARTNER_OUS"
        URLProtocolStub.linkedPatients = [
            ["username": "child1", "firstName": "Child", "lastName": "One"],
            ["username": "child2", "firstName": "Child", "lastName": "Two"]
        ]
        let client = makeClient()
        let account = try await client.userAndPatients(region: .outsideUnitedStates)
        XCTAssertEqual(account.patients.map(\.username), ["child1", "child2"])
        URLProtocolStub.route = .periodic
        let response = try await client.fetchPatientData(region: .outsideUnitedStates, patient: account.patients[1], username: account.metadata.accountName, accountRole: account.metadata.role, countryCode: account.metadata.countryCode, linkedPatientCount: account.patients.count)
        XCTAssertEqual(response.1, .periodic)
        XCTAssertFalse(URLProtocolStub.paths.contains("/patient/monitor/data"))
        let bodies = URLProtocolStub.requestBodies.filter { $0["role"] == "carepartner" }
        XCTAssertFalse(bodies.isEmpty)
        XCTAssertTrue(bodies.allSatisfy { $0["username"] == "patient1" && $0["patientId"] == "child2" })
        XCTAssertTrue(bodies.allSatisfy { $0["appVersion"] == ConstantsCareLink.carePartnerAppVersionDefault })
    }

    func testCarePartnerWithNoLinksRemainsAValidAuthenticatedAccount() async throws {
        URLProtocolStub.role = "CARE_PARTNER_OUS"
        URLProtocolStub.linkedPatients = []
        let account = try await makeClient().userAndPatients(region: .outsideUnitedStates)
        XCTAssertEqual(account.metadata.role, "CARE_PARTNER_OUS")
        XCTAssertTrue(account.patients.isEmpty)
    }

    func testUnknownAccountRoleIsRejected() async throws {
        URLProtocolStub.role = "CLINICIAN"
        do {
            _ = try await makeClient().userAndPatients(region: .outsideUnitedStates)
            XCTFail("Expected unsupported role")
        } catch {
            guard case .unsupportedRole = error as? CareLinkError else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testExpiredSessionRefreshesOnceForConcurrentCallers() async throws {
        let store = CareLinkMemoryTokenStore()
        try store.save(credential(expiresAt: now))
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        async let first = client.userAndPatients(region: .outsideUnitedStates)
        async let second = client.userAndPatients(region: .outsideUnitedStates)
        _ = try await (first, second)
        XCTAssertEqual(URLProtocolStub.refreshCount, 1)
        XCTAssertEqual(try store.load()?.accessToken, "rotated")
    }

    func test401RefreshesAndRetriesOnce() async throws {
        URLProtocolStub.usersMe401Count = 1
        let store = CareLinkMemoryTokenStore()
        try store.save(credential())
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        _ = try await client.userAndPatients(region: .outsideUnitedStates)
        XCTAssertEqual(URLProtocolStub.refreshCount, 1)
        XCTAssertEqual(URLProtocolStub.usersMeCount, 2)
    }

    func testRejectedRefreshRetainsCredentialAndReturnsToLogin() async throws {
        URLProtocolStub.rejectRefresh = true
        let store = CareLinkMemoryTokenStore()
        let originalCredential = credential(expiresAt: now)
        try store.save(originalCredential)
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        do {
            _ = try await client.userAndPatients(region: .outsideUnitedStates)
            XCTFail("Expected an expired session")
        } catch {
            XCTAssertEqual(error as? CareLinkError, .reconnectRequired)
            XCTAssertEqual(try store.load(), originalCredential)
        }
    }

    func testTransientRefreshFailureRetainsRotatingCredentialWithoutRetry() async throws {
        URLProtocolStub.failRefreshTransport = true
        let store = CareLinkMemoryTokenStore()
        let originalCredential = credential(expiresAt: now)
        try store.save(originalCredential)
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })

        do {
            _ = try await client.userAndPatients(region: .outsideUnitedStates)
            XCTFail("Expected a transient refresh failure")
        } catch {
            XCTAssertEqual(error as? CareLinkError, .offline)
            XCTAssertEqual(try store.load(), originalCredential)
            XCTAssertEqual(URLProtocolStub.refreshCount, 1)
        }
    }

    func testAllPersonalGlucoseFamilies() async throws {
        for route in [CareLinkDataRoute.monitor, .periodic, .guardianM2M, .legacyConnect] {
            URLProtocolStub.route = route
            let response = try await makeClient().fetchPatientData(region: .outsideUnitedStates, patient: patient(), username: "patient1", accountRole: "PATIENT_OUS", countryCode: "ES")
            XCTAssertEqual(response.1, route)
            XCTAssertEqual(try CareLinkGlucoseParser.readings(from: response.0, now: now).readings.first?.sgv, 123)
        }
    }

    func testPeriodicCompatibilityEndpointFallback() async throws {
        URLProtocolStub.route = .periodic
        URLProtocolStub.directPeriodicUnavailable = true
        let response = try await makeClient().fetchPatientData(region: .outsideUnitedStates, patient: patient(), username: "patient1", accountRole: "PATIENT_OUS", countryCode: "ES")
        XCTAssertEqual(response.1, .periodic)
        XCTAssertTrue(URLProtocolStub.paths.contains("/patient/countries/settings"))
        XCTAssertTrue(URLProtocolStub.paths.contains("/periodic/data"))
    }

    func testPumpOnlyPeriodicPayloadRemainsUsableDuringSensorGap() async throws {
        URLProtocolStub.route = .periodic
        URLProtocolStub.pumpOnly = true

        let response = try await makeClient().fetchPatientData(
            region: .outsideUnitedStates,
            patient: patient(),
            username: "patient1",
            accountRole: "PATIENT_OUS",
            countryCode: "ES"
        )

        XCTAssertEqual(response.1, .periodic)
        XCTAssertTrue(try CareLinkGlucoseParser.readings(from: response.0, now: now).readings.isEmpty)
        XCTAssertEqual(try CareLinkTherapyParser.payload(from: response.0, patientID: "one", now: now).pump.activeInsulin, 1.25)
    }

    func testSuccessfulEmptyRouteTakesPrecedenceOverLaterFallbackErrors() async throws {
        URLProtocolStub.emptyPersonalAccount = true
        do {
            _ = try await makeClient().fetchPatientData(region: .outsideUnitedStates, patient: patient(), username: "patient1", accountRole: "PATIENT_OUS", countryCode: "ES")
            XCTFail("Expected an authenticated account with no glucose data")
        } catch {
            XCTAssertEqual(error as? CareLinkError, .noGlucoseData)
        }
        XCTAssertTrue(URLProtocolStub.paths.contains("/connect/carepartner/v13/display/message"))
        XCTAssertTrue(URLProtocolStub.paths.contains("/patient/m2m/connect/data/gc/patients/patient1"))
    }

    func testRateLimitHonorsRetryAfter() async throws {
        URLProtocolStub.rateLimit = true
        do {
            _ = try await makeClient().userAndPatients(region: .outsideUnitedStates)
            XCTFail("Expected rate limit")
        } catch let error as CareLinkError {
            guard case let .rateLimited(until) = error else { return XCTFail("Unexpected \(error)") }
            XCTAssertEqual(until, now.addingTimeInterval(90))
        }
    }

    func testLogoutClosesSessionAndClearsKeychainValue() async throws {
        let store = CareLinkMemoryTokenStore()
        try store.save(credential())
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        await client.revokeAndClear()
        XCTAssertNil(try store.load())
        XCTAssertTrue(URLProtocolStub.paths.contains("/oauth/revoke"))
    }

    func testLocalSessionClearRemovesOrphanWithoutNetworkRequest() async throws {
        let store = CareLinkMemoryTokenStore()
        try store.save(credential())
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })

        await client.clearLocalSession()

        XCTAssertNil(try store.load())
        XCTAssertTrue(URLProtocolStub.paths.isEmpty)
    }

    func testConcurrentRevocationsSendAtMostOneLogoutRequest() async throws {
        URLProtocolStub.logoutDelay = 0.2
        let store = CareLinkMemoryTokenStore()
        try store.save(credential())
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })

        async let first: Void = client.revokeAndClear()
        async let second: Void = client.revokeAndClear()
        _ = await (first, second)

        XCTAssertNil(try store.load())
        XCTAssertEqual(URLProtocolStub.paths.filter { $0 == "/oauth/revoke" }.count, 1)
    }

    func testSlowLogoutCannotClearANewerSession() async throws {
        URLProtocolStub.logoutDelay = 0.2
        let store = CareLinkMemoryTokenStore()
        try store.save(credential())
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })

        let logout = Task { await client.revokeAndClear() }
        for _ in 0 ..< 100 {
            if try store.load() == nil { break }
            await Task.yield()
        }
        XCTAssertNil(try store.load())

        var replacement = credential()
        replacement.accessToken = "replacement"
        try store.save(replacement)
        await logout.value

        XCTAssertEqual(try store.load()?.accessToken, "replacement")
    }

    func testTokenRefreshCannotRestoreASessionAfterLogout() async throws {
        URLProtocolStub.refreshDelay = 0.2
        let store = CareLinkMemoryTokenStore()
        try store.save(credential(expiresAt: now))
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        let refreshStarted = expectation(description: "Token refresh started")
        URLProtocolStub.expectRefresh(refreshStarted)

        let accountRequest = Task {
            try? await client.userAndPatients(region: .outsideUnitedStates)
        }
        await fulfillment(of: [refreshStarted], timeout: 2)

        await client.revokeAndClear()
        _ = await accountRequest.value

        XCTAssertNil(try store.load())
    }

    func testTokenRefreshCannotRestoreASessionAfterLocalClear() async throws {
        URLProtocolStub.refreshDelay = 0.2
        let store = CareLinkMemoryTokenStore()
        try store.save(credential(expiresAt: now))
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        let refreshStarted = expectation(description: "Token refresh started")
        URLProtocolStub.expectRefresh(refreshStarted)

        let accountRequest = Task {
            try? await client.userAndPatients(region: .outsideUnitedStates)
        }
        await fulfillment(of: [refreshStarted], timeout: 2)

        await client.clearLocalSession()
        _ = await accountRequest.value

        XCTAssertNil(try store.load())
        XCTAssertFalse(URLProtocolStub.paths.contains("/oauth/revoke"))
    }

    // MARK: - Helpers

    private func makeClient(appVersion: String = ConstantsCareLink.carePartnerAppVersionDefault) -> CareLinkClient {
        let store = CareLinkMemoryTokenStore()
        try! store.save(credential())
        return CareLinkClient(
            session: URLSession(configuration: stubConfiguration()),
            tokenStore: store,
            now: { self.now },
            appVersionProvider: { appVersion }
        )
    }

    private func dataFlowPolicy(
        isMaster: Bool,
        followerSource: FollowerDataSourceType,
        therapySelection: TherapyDataSourceType,
        nightscoutEnabled: Bool = true,
        masterUploadsGlucose: Bool = false,
        followerUploadsGlucose: Bool = false,
        nightscoutFollowType: NightscoutFollowType = .none
    ) -> DataFlowPolicy {
        DataFlowPolicy(
            isMaster: isMaster,
            followerDataSource: followerSource,
            therapyDataSourceSelection: therapySelection,
            nightscoutEnabled: nightscoutEnabled,
            masterUploadsGlucoseToNightscout: masterUploadsGlucose,
            followerUploadsGlucoseToNightscout: followerUploadsGlucose,
            nightscoutFollowType: nightscoutFollowType
        )
    }

    private func credential(expiresAt: Date? = nil) -> CareLinkToken {
        CareLinkToken(
            accessToken: "valid",
            refreshToken: "valid-refresh",
            expiresAt: expiresAt ?? now.addingTimeInterval(3600),
            region: .outsideUnitedStates,
            countryCode: "ES",
            oauthConfiguration: oauthConfiguration()
        )
    }

    private func oauthConfiguration() -> CareLinkOAuthConfiguration {
        CareLinkOAuthConfiguration(
            authorizationEndpoint: URL(string: "https://carelink-login.minimed.eu/authorize")!,
            tokenEndpoint: URL(string: "https://carelink-login.minimed.eu/oauth/token")!,
            revocationEndpoint: URL(string: "https://carelink-login.minimed.eu/oauth/revoke")!,
            clientID: "client",
            scope: "profile openid offline_access",
            redirectURI: URL(string: "com.medtronic.carepartner:/sso")!,
            audience: "carepartner.patient.ous"
        )
    }

    private func authorizationTransaction() -> CareLinkAuthorizationTransaction {
        CareLinkAuthorizationTransaction(
            authorizationURL: URL(string: "https://carelink-login.minimed.eu/authorize")!,
            configuration: oauthConfiguration(),
            state: "state",
            codeVerifier: "verifier"
        )
    }

    private func patient() -> CareLinkPatient { CareLinkPatient(id: "one", username: "patient1", firstName: nil, lastName: nil) }

    private func marker(type: String, timestamp: String, values: [String: Any]) -> [String: Any] {
        [
            "type": type,
            "timestamp": timestamp,
            "data": ["dataValues": values]
        ]
    }

    private func stubConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return configuration
    }

    @MainActor
    private func waitUntil(_ condition: @escaping () async -> Bool) async -> Bool {
        for _ in 0 ..< 200 {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}

// MARK: - Test doubles

private final class URLProtocolStub: URLProtocol {
    static let lock = NSLock()
    static var role = "PATIENT_OUS"
    static var route = CareLinkDataRoute.periodic
    static var omitUsername = false
    static var rateLimit = false
    static var usersMe401Count = 0
    static var usersMeCount = 0
    static var rejectRefresh = false
    static var failRefreshTransport = false
    static var refreshCount = 0
    static var directPeriodicUnavailable = false
    static var emptyPersonalAccount = false
    static var pumpOnly = false
    static var logoutDelay: TimeInterval = 0
    static var refreshDelay: TimeInterval = 0
    static var refreshStartedExpectation: XCTestExpectation?
    static var linkedPatients: [[String: Any]] = [["username": "linked1", "firstName": "Linked", "lastName": "Patient"]]
    static var paths: [String] = []
    static var headers: [[String: String]] = []
    static var requestBodies: [[String: String]] = []

    static func reset() {
        lock.lock()
        role = "PATIENT_OUS"
        route = .periodic
        omitUsername = false
        rateLimit = false
        usersMe401Count = 0
        usersMeCount = 0
        rejectRefresh = false
        failRefreshTransport = false
        refreshCount = 0
        directPeriodicUnavailable = false
        emptyPersonalAccount = false
        pumpOnly = false
        logoutDelay = 0
        refreshDelay = 0
        refreshStartedExpectation = nil
        linkedPatients = [["username": "linked1", "firstName": "Linked", "lastName": "Patient"]]
        paths = []
        headers = []
        requestBodies = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    static func recorded(path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return paths.contains(path)
    }

    static func expectRefresh(_ expectation: XCTestExpectation) {
        lock.lock()
        refreshStartedExpectation = expectation
        lock.unlock()
    }

    override func startLoading() {
        guard let url = request.url else { return fail() }
        let requestBody = Self.bodyData(from: request)
        Self.lock.lock()
        Self.paths.append(url.path)
        Self.headers.append(request.allHTTPHeaderFields ?? [:])
        if let body = requestBody,
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
            Self.requestBodies.append(object)
        }
        Self.lock.unlock()
        let path = url.path

        let formFields = Self.formFields(
            from: requestBody,
            contentType: request.value(forHTTPHeaderField: "Content-Type")
        )
        if path.hasPrefix("/connect/carepartner/v13/discover/android/") {
            return respond(200, [
                "CP": [
                    ["region": "US", "UseSSOConfiguration": "Auth0SSOConfiguration", "Auth0SSOConfiguration": "https://carelink.minimed.com/oauth-config.json"],
                    ["region": "EU", "UseSSOConfiguration": "Auth0SSOConfiguration", "Auth0SSOConfiguration": "https://carelink.minimed.eu/oauth-config.json"]
                ]
            ])
        }
        if path == "/oauth-config.json" {
            let isUS = url.host?.hasSuffix(".com") == true
            let suffix = isUS ? "com" : "eu"
            return respond(200, [
                "server": ["hostname": "carelink-login.minimed.\(suffix)", "port": 443, "prefix": ""],
                "client": [
                    "client_id": "client",
                    "scope": "profile openid offline_access",
                    "redirect_uri": "com.medtronic.carepartner:/sso",
                    "audience": isUS ? "carepartner.patient.us" : "carepartner.patient.ous"
                ],
                "system_endpoints": [
                    "authorization_endpoint_path": "/authorize",
                    "token_endpoint_path": "/oauth/token",
                    "token_revocation_endpoint_path": "/oauth/revoke"
                ]
            ])
        }
        if path == "/oauth/token" {
            Self.lock.lock()
            Self.refreshCount += 1
            let reject = Self.rejectRefresh && formFields["grant_type"] == "refresh_token"
            let failTransport = Self.failRefreshTransport && formFields["grant_type"] == "refresh_token"
            let startedExpectation = Self.refreshStartedExpectation
            Self.refreshStartedExpectation = nil
            Self.lock.unlock()
            startedExpectation?.fulfill()
            if reject { return respond(400, ["error": "invalid_grant"]) }
            if failTransport {
                client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
                return
            }
            Self.lock.lock()
            let delay = Self.refreshDelay
            Self.lock.unlock()
            if delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.respond(200, ["access_token": "rotated", "refresh_token": "rotated-refresh", "expires_in": 3600])
                }
                return
            }
            return respond(200, ["access_token": "rotated", "refresh_token": "rotated-refresh", "expires_in": 3600])
        }
        if path == "/oauth/revoke" {
            Self.lock.lock()
            let delay = Self.logoutDelay
            Self.lock.unlock()
            guard delay > 0 else { return respond(200, [:]) }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.respond(200, [:])
            }
            return
        }
        if path == "/patient/users/me" {
            Self.lock.lock()
            Self.usersMeCount += 1
            if Self.usersMe401Count > 0 {
                Self.usersMe401Count -= 1
                Self.lock.unlock()
                return respond(401, [:])
            }
            let limited = Self.rateLimit
            let role = Self.role
            let omit = Self.omitUsername
            Self.lock.unlock()
            if limited { return respond(429, [:], headers: ["Retry-After": "90"]) }
            var body: [String: Any] = ["id": "self", "firstName": "Personal", "lastName": "Account", "role": role, "country": "ES"]
            if !omit { body["username"] = "patient1" }
            return respond(200, body)
        }
        if path == "/patient/users/me/profile" { return respond(200, ["username": "profile-user", "country": "ES"]) }
        if path == "/patient/m2m/links/patients" { return respondArray(200, Self.linkedPatients) }
        if path == "/patient/monitor/data" { return Self.route == .monitor ? glucose() : respond(404, [:]) }
        if path == "/connect/carepartner/v13/display/message" {
            if Self.emptyPersonalAccount { return respondEmpty(204) }
            if Self.route == .periodic && !Self.directPeriodicUnavailable { return glucose(wrapped: true) }
            return respond(404, [:])
        }
        if path == "/patient/countries/settings" { return respond(200, ["blePereodicDataEndpoint": "https://clcloud.minimed.eu/periodic/data"]) }
        if path == "/periodic/data" { return Self.emptyPersonalAccount ? respondEmpty(204) : (Self.route == .periodic ? glucose(wrapped: true) : respond(404, [:])) }
        if path.hasPrefix("/patient/m2m/connect/data/gc/patients/") { return Self.emptyPersonalAccount ? respond(500, ["message": "Internal server error"]) : (Self.route == .guardianM2M ? glucose() : respond(404, [:])) }
        if path == "/patient/connect/data" { return Self.emptyPersonalAccount ? respond(500, ["message": "Internal server error"]) : (Self.route == .legacyConnect ? glucose() : respond(404, [:])) }
        respond(404, [:])
    }

    override func stopLoading() {}

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 1024)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func formFields(from data: Data?, contentType: String?) -> [String: String] {
        guard contentType?.hasPrefix("application/x-www-form-urlencoded") == true,
              let data,
              let value = String(data: data, encoding: .utf8) else { return [:] }
        var components = URLComponents()
        components.percentEncodedQuery = value
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func glucose(wrapped: Bool = false) {
        let payload: [String: Any] = Self.pumpOnly
            ? ["activeInsulin": ["amount": 1.25, "datetime": 1_800_000_000_000]]
            : ["lastSG": ["sg": 123, "timestamp": 1_800_000_000_000]]
        respond(200, wrapped ? ["patientData": payload] : payload)
    }

    private func respond(_ status: Int, _ object: [String: Any], headers: [String: String] = [:]) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        var fields = headers
        fields["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondArray(_ status: Int, _ object: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondEmpty(_ status: Int) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func fail() { client?.urlProtocol(self, didFailWithError: URLError(.badURL)) }
}

private final class FollowerDelegateSpy: FollowerDelegate {
    var received: [FollowerBgReading] = []
    var deliveryCount = 0

    func followerInfoReceived(followGlucoseDataArray: inout [FollowerBgReading]) {
        received = followGlucoseDataArray
        deliveryCount += 1
    }
}

private actor BlockingCareLinkTherapyImporter: CareLinkTherapyImporting {
    private var continuations: [CheckedContinuation<Int, Never>] = []
    private(set) var treatmentCallCount = 0
    private(set) var completedTreatmentImportCount = 0
    private(set) var maximumConcurrentTreatmentImports = 0
    private var activeTreatmentImports = 0

    func importTreatments(_ records: [CareLinkTherapyRecord]) async -> Int {
        treatmentCallCount += 1
        activeTreatmentImports += 1
        maximumConcurrentTreatmentImports = max(maximumConcurrentTreatmentImports, activeTreatmentImports)
        return await withCheckedContinuation { continuations.append($0) }
    }

    func importPumpStatuses(
        _ pump: CareLinkPumpSnapshot,
        treatments: [CareLinkTherapyRecord],
        metadata: CareLinkMetadata,
        checkedAt: Date
    ) async -> Int { 1 }

    func releaseNext() {
        guard !continuations.isEmpty else { return }
        activeTreatmentImports -= 1
        completedTreatmentImportCount += 1
        continuations.removeFirst().resume(returning: 1)
    }

    func releaseAll() {
        while !continuations.isEmpty { releaseNext() }
    }
}

private final class CareLinkNoOpKeepAliveManager: FollowerBackgroundKeepAliveManaging {
    func start(for source: FollowerBackgroundKeepAliveSource, backgroundRefresh: (() -> Void)?) {}
    func stop(for source: FollowerBackgroundKeepAliveSource) {}
}

private final class CareLinkNoOpTimer: FollowerBackgroundTimer {
    func resume() {}
    func suspend() {}
}

private final class CareLinkDefaultsSnapshot {
    private let defaults = UserDefaults.standard
    private let keys: [UserDefaults.Key]
    private var values: [String: Any] = [:]
    private var missingKeys = Set<String>()

    init(keys: [UserDefaults.Key]) {
        self.keys = keys
        for key in keys {
            if let value = defaults.object(forKey: key.rawValue) {
                values[key.rawValue] = value
            } else {
                missingKeys.insert(key.rawValue)
            }
        }
    }

    func restore() {
        for key in keys {
            if missingKeys.contains(key.rawValue) {
                defaults.removeObject(forKey: key.rawValue)
            } else {
                defaults.set(values[key.rawValue], forKey: key.rawValue)
            }
        }
    }
}

private final class CareLinkControllerSpy: CareLinkControlling {
    var refreshCount = 0
    var logoutCount = 0

    func logIn() {}
    func refresh() { refreshCount += 1 }
    func logOut() { logoutCount += 1 }
    func changeRegion() {}
    func setRegion(_ region: CareLinkRegion) {}
    func selectPatient(_ id: String) {}
}

private struct CareLinkTestSendableBox<Value>: @unchecked Sendable {
    let value: Value
}

private final class FailingCareLinkTokenStore: CareLinkTokenStoring {
    enum Failure: Error {
        case unavailable
    }

    func load() throws -> CareLinkToken? { throw Failure.unavailable }
    func save(_ token: CareLinkToken) throws {}
    func clear() throws {}
}
