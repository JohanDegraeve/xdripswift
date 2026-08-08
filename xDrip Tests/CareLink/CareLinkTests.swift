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

    func testConnectionIndicatorPaletteDoesNotUseReadingFreshness() {
        XCTAssertEqual(CareLinkConnectionStatus.loginRequired.indicatorColor, Color.gray)
        XCTAssertEqual(CareLinkConnectionStatus.connecting.indicatorColor, ConstantsAppColors.warning)
        XCTAssertEqual(CareLinkConnectionStatus.noData.indicatorColor, ConstantsAppColors.warning)
        XCTAssertEqual(CareLinkConnectionStatus.active.indicatorColor, ConstantsAppColors.normal)
        XCTAssertEqual(CareLinkConnectionStatus.stale.indicatorColor, Color.orange)
        XCTAssertEqual(CareLinkConnectionStatus.rateLimited.indicatorColor, Color.orange)
        XCTAssertEqual(CareLinkConnectionStatus.error.indicatorColor, ConstantsAppColors.urgent)
    }

    func testWatchStatusCarriesCareLinkConnectionState() {
        var status = WatchStatus()
        status.followerDataSourceTypeRawValue = FollowerDataSourceType.careLink.rawValue
        status.followerConnectionStatusRawValue = CareLinkConnectionStatus.connecting.rawValue

        XCTAssertEqual(status.asDictionary?["followerDataSourceTypeRawValue"] as? Int, FollowerDataSourceType.careLink.rawValue)
        XCTAssertEqual(status.asDictionary?["followerConnectionStatusRawValue"] as? String, CareLinkConnectionStatus.connecting.rawValue)
    }

    func testAuthenticationCompletionCanRunOnlyOnce() {
        let completion = CareLinkOneShot()
        var value = ""
        XCTAssertTrue(completion.run { value = "cookies" })
        XCTAssertFalse(completion.run { value = "dismissal" })
        XCTAssertEqual(value, "cookies")
    }

    func testBrowserExpiryFormatsAndRefreshMargin() {
        XCTAssertNotNil(CareLinkClient.parseExpiry("Tue Jan 1 00:00:00 UTC 2030"))
        XCTAssertNotNil(CareLinkClient.parseExpiry("2030-01-01T00:00:00Z"))
        XCTAssertNotNil(CareLinkClient.parseExpiry("2030-01-01T00%3A00%3A00UTC"))
        let token = credential(expiresAt: now.addingTimeInterval(601))
        XCTAssertFalse(token.needsRefresh(at: now))
        XCTAssertTrue(credential(expiresAt: now.addingTimeInterval(599)).needsRefresh(at: now))
    }

    func testWebSessionInstallationRequiresBothCookiesAndPersistsRegion() async throws {
        let store = CareLinkMemoryTokenStore()
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        let cookies = [cookie("auth_tmp_token", "web-token"), cookie("c_token_valid_to", "2030-01-01T00:00:00Z"), cookie("unrelated_sso", "discard-me", domain: ".medtronic.com")]
        let installed = try await client.installWebSession(cookies: cookies, region: .outsideUnitedStates, countryCode: "ES")
        XCTAssertEqual(installed.accessToken, "web-token")
        XCTAssertEqual(installed.region, .outsideUnitedStates)
        XCTAssertEqual(installed.countryCode, "ES")
        XCTAssertEqual(installed.cookies.count, 2)
        let authenticatedRegion = await client.authenticatedRegion()
        XCTAssertEqual(authenticatedRegion, .outsideUnitedStates)

        do {
            _ = try await client.installWebSession(cookies: [cookies[0]], region: .outsideUnitedStates)
            XCTFail("Expected both personal-session cookies")
        } catch {
            XCTAssertEqual(error as? CareLinkError, .invalidCallback)
        }
    }

    func testLoginURLUsesPersonalHostAndCountry() async {
        let client = CareLinkClient(tokenStore: CareLinkMemoryTokenStore())
        let us = await client.loginURL(region: .unitedStates)
        XCTAssertEqual(us.host, "carelink.minimed.com")
        XCTAssertEqual(us.path, "/patient/sso/login")
        XCTAssertTrue(us.query?.contains("country=us") == true)
        let ous = await client.loginURL(region: .outsideUnitedStates)
        XCTAssertEqual(ous.host, "carelink.minimed.eu")
        XCTAssertNotEqual(URLComponents(url: ous, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "country" })?.value, "us")
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

    func testTherapyParserNormalizesPumpBolusMealAndAutoBasal() throws {
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
        XCTAssertEqual(payload.treatments.count, 3)
        let basal = try XCTUnwrap(payload.treatments.first(where: { $0.type == .Basal }))
        XCTAssertEqual(basal.value, 1.5, accuracy: 0.0001)
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
        XCTAssertNotEqual(original.value, recalculated.value)
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
        XCTAssertEqual(CareLinkPollingPolicy.interval, 60)
        XCTAssertTrue(CareLinkPollingPolicy.isStale(lastReadingAt: now.addingTimeInterval(-1201), now: now))
        XCTAssertEqual(CareLinkPollingPolicy.backoff(failureCount: 99), 300)
        XCTAssertEqual(CareLinkStatePolicy.status(for: .reconnectRequired), .loginRequired)
        XCTAssertEqual(CareLinkConnectionStatus.loginRequired.title, "Log In Required")
        XCTAssertEqual(CareLinkConnectionStatus.connecting.title, "Connecting...")
        XCTAssertEqual(CareLinkStatePolicy.status(for: .rateLimited(now)), .rateLimited)
        XCTAssertEqual(CareLinkStatePolicy.status(for: .noGlucoseData), .noData)
    }

    func testLoginCredentialsRequireBothStoredValues() throws {
        let suiteName = "CareLinkTests.credentials.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertNil(CareLinkLoginCredentials.stored(in: defaults))
        defaults.careLinkUsername = " person@example.com "
        XCTAssertNil(CareLinkLoginCredentials.stored(in: defaults))
        defaults.careLinkPassword = "password with spaces"
        XCTAssertEqual(
            CareLinkLoginCredentials.stored(in: defaults),
            CareLinkLoginCredentials(username: "person@example.com", password: "password with spaces")
        )
    }

    func testCredentialPrefillIsRestrictedToMedtronicPagesAndEscapesValues() {
        XCTAssertTrue(CareLinkLoginPrefill.allows(URL(string: "https://carelink-login.minimed.eu/u/login")))
        XCTAssertTrue(CareLinkLoginPrefill.allows(URL(string: "https://carelink.minimed.com/patient/sso/login")))
        XCTAssertFalse(CareLinkLoginPrefill.allows(URL(string: "https://minimed.eu.example.com/login")))
        XCTAssertFalse(CareLinkLoginPrefill.allows(URL(string: "https://example.com/login")))

        let script = CareLinkLoginPrefill.script(credentials: CareLinkLoginCredentials(username: "person\"@example.com", password: "pass\\word"))
        XCTAssertTrue(script.contains("person\\\"@example.com"))
        XCTAssertTrue(script.contains("pass\\\\word"))
        XCTAssertTrue(script.contains("MutationObserver"))
    }

    func testSuccessfulResponseWithDisconnectedPumpReportsNoData() {
        let disconnected = CareLinkPumpSnapshot(isCommunicating: false, isInRange: false)
        let connected = CareLinkPumpSnapshot(isCommunicating: true, isInRange: true)

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
    }

    // MARK: - Pump history

    func testCareLinkPumpSnapshotCreatesStableHistoricalStatus() throws {
        let pump = CareLinkPumpSnapshot(
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
            type: .Basal,
            value: 1.5,
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
            type: .Basal,
            value: 1.5,
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
    }

    // MARK: - Client requests and session lifecycle

    func testPersonalAccountUsesBearerCookiesAndProfileFallback() async throws {
        URLProtocolStub.omitUsername = true
        let client = makeClient()
        let result = try await client.userAndPatients(region: .outsideUnitedStates)
        XCTAssertEqual(result.metadata.role, "PATIENT_OUS")
        XCTAssertEqual(result.metadata.accountName, "profile-user")
        XCTAssertEqual(result.patients.count, 1)
        let headers = try XCTUnwrap(URLProtocolStub.headers.last)
        XCTAssertEqual(headers["Authorization"], "Bearer valid")
        XCTAssertTrue(headers["Cookie"]?.contains("auth_tmp_token=valid") == true)
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

    func testRejectedReauthRetainsCredentialAndReturnsToLogin() async throws {
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
        XCTAssertTrue(URLProtocolStub.paths.contains("/patient/sso/logout"))
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
        URLProtocolStub.reauthDelay = 0.2
        let store = CareLinkMemoryTokenStore()
        try store.save(credential(expiresAt: now))
        let client = CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
        let reauthStarted = expectation(description: "Reauthentication started")
        URLProtocolStub.expectReauth(reauthStarted)

        let accountRequest = Task {
            try? await client.userAndPatients(region: .outsideUnitedStates)
        }
        await fulfillment(of: [reauthStarted], timeout: 2)

        await client.revokeAndClear()
        _ = await accountRequest.value

        XCTAssertNil(try store.load())
    }

    // MARK: - Helpers

    private func makeClient() -> CareLinkClient {
        let store = CareLinkMemoryTokenStore()
        try! store.save(credential())
        return CareLinkClient(session: URLSession(configuration: stubConfiguration()), tokenStore: store, now: { self.now })
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
        CareLinkToken(accessToken: "valid", expiresAt: expiresAt ?? now.addingTimeInterval(3600), cookies: [
            CareLinkCookie(name: "auth_tmp_token", value: "valid", domain: ".minimed.eu", path: "/", secure: true, expiresAt: nil),
            CareLinkCookie(name: "c_token_valid_to", value: "2030-01-01T00:00:00Z", domain: ".minimed.eu", path: "/", secure: true, expiresAt: nil)
        ], region: .outsideUnitedStates, countryCode: "ES")
    }

    private func cookie(_ name: String, _ value: String, domain: String = "carelink.minimed.eu") -> HTTPCookie {
        HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: "/", .secure: "TRUE"])!
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
    static var refreshCount = 0
    static var directPeriodicUnavailable = false
    static var emptyPersonalAccount = false
    static var pumpOnly = false
    static var logoutDelay: TimeInterval = 0
    static var reauthDelay: TimeInterval = 0
    static var reauthStartedExpectation: XCTestExpectation?
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
        refreshCount = 0
        directPeriodicUnavailable = false
        emptyPersonalAccount = false
        pumpOnly = false
        logoutDelay = 0
        reauthDelay = 0
        reauthStartedExpectation = nil
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

    static func expectReauth(_ expectation: XCTestExpectation) {
        lock.lock()
        reauthStartedExpectation = expectation
        lock.unlock()
    }

    override func startLoading() {
        guard let url = request.url else { return fail() }
        Self.lock.lock()
        Self.paths.append(url.path)
        Self.headers.append(request.allHTTPHeaderFields ?? [:])
        if let body = Self.bodyData(from: request),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
            Self.requestBodies.append(object)
        }
        Self.lock.unlock()
        let path = url.path

        if path == "/patient/sso/reauth" {
            Self.lock.lock()
            Self.refreshCount += 1
            let reject = Self.rejectRefresh
            let startedExpectation = Self.reauthStartedExpectation
            Self.reauthStartedExpectation = nil
            Self.lock.unlock()
            startedExpectation?.fulfill()
            if reject { return respond(401, [:]) }
            Self.lock.lock()
            let delay = Self.reauthDelay
            Self.lock.unlock()
            if delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.respond(200, [:], headers: ["Set-Cookie": "auth_tmp_token=rotated; Path=/; HttpOnly"])
                }
                return
            }
            return respond(200, [:], headers: ["Set-Cookie": "auth_tmp_token=rotated; Path=/; HttpOnly"])
        }
        if path == "/patient/sso/logout" {
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
    func followerInfoReceived(followGlucoseDataArray: inout [FollowerBgReading]) { received = followGlucoseDataArray }
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
