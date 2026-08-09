//
//  FollowerSettingsTests.swift
//  xdripTests
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class FollowerSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "FollowerSettingsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Connection presentation

    func testNightscoutRequiresEnabledValidURL() {
        defaults.nightscoutEnabled = false
        defaults.nightscoutUrl = "https://example.com"
        XCTAssertEqual(status(.nightscout).state, .notConfigured)

        defaults.nightscoutEnabled = true
        defaults.nightscoutUrl = "not a URL"
        XCTAssertEqual(status(.nightscout).state, .notConfigured)

        defaults.nightscoutUrl = "https://example.com"
        XCTAssertEqual(status(.nightscout).state, .checking)
    }

    func testLibreTermsTakePrecedenceOverLoginFailure() {
        defaults.libreLinkUpEmail = "user@example.com"
        defaults.libreLinkUpPassword = "password"
        defaults.libreLinkUpPreventLogin = true
        defaults.libreLinkUpReAcceptNeeded = true
        XCTAssertEqual(status(.libreLinkUp).state, .acceptTerms)

        defaults.libreLinkUpReAcceptNeeded = false
        XCTAssertEqual(status(.libreLinkUp).state, .failed)
    }

    func testDexcomRegionAloneDoesNotMeanConnected() {
        defaults.dexcomShareAccountName = "account"
        defaults.dexcomSharePassword = "password"
        defaults.dexcomShareRegion = .global
        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggedOut).state, .loginRequired)
        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggingIn).state, .checking)
    }

    func testConnectionTimestampStatesAreDeterministic() {
        defaults.dexcomShareAccountName = "account"
        defaults.dexcomSharePassword = "password"
        defaults.dexcomShareRegion = .global

        defaults.timeStampOfLastFollowerConnection = now.addingTimeInterval(-60)
        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggedIn).state, .connected)

        let interval = TimeInterval(FollowerDataSourceType.dexcomShare.secondsUntilFollowerDisconnectWarning)
        defaults.timeStampOfLastFollowerConnection = now.addingTimeInterval(-interval - 1)
        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggedIn).state, .stale)

        defaults.timeStampOfLastFollowerConnection = .distantPast
        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggedIn).state, .failed)
    }

    func testMedtrumCaregiverRequiresPatientSelection() {
        defaults.medtrumEasyViewEmail = "user@example.com"
        defaults.medtrumEasyViewPassword = "password"
        defaults.medtrumEasyViewUserType = "M"
        defaults.medtrumEasyViewSelectedPatientUid = 0
        XCTAssertEqual(status(.medtrumEasyView, sessionStatus: .loggedIn).state, .selectPatient)

        defaults.medtrumEasyViewSelectedPatientUid = 123
        XCTAssertEqual(status(.medtrumEasyView, sessionStatus: .loggedIn).state, .checking)
    }

    @MainActor
    func testFollowerEnumRawValuesAndFactoryCoverageRemainExhaustive() {
        XCTAssertEqual(FollowerDataSourceType.allCases.map(\.rawValue), Array(0 ... 6))
        for source in FollowerDataSourceType.allCases {
            let screen = FollowerSettingsScreenFactory.make(source: source, actions: .none)
            XCTAssertEqual(screen.title, source.description)
        }
    }

    func testHiddenRussiaSelectionFallsBackWithoutChangingStoredRawValues() {
        let enabled = FollowerDataSourceType.allCasesForList.filter { $0 != .libreLinkUpRussia }
        XCTAssertEqual(FollowerDataSourceType.libreLinkUpRussia.rawValue, 2)
        XCTAssertEqual(
            FollowerDataSourceType.validatedSelection(storedRawValue: 2, enabledCases: enabled),
            .nightscout
        )
    }

    func testAutomaticBasalRenderingDefaultsToDeliveredDoses() {
        XCTAssertEqual(defaults.automaticBasalRenderingStyle, .deliveredDoses)
        defaults.automaticBasalRenderingStyle = .simulatedTempBasals
        XCTAssertEqual(defaults.automaticBasalRenderingStyle, .simulatedTempBasals)
    }

    // MARK: - Service status

    func testOperationalPayloadDecodingAndResponseValidation() {
        let nightscout = Data(#"{"status":"ok"}"#.utf8)
        XCTAssertEqual(
            FollowerServiceStatusMonitor.decode(source: .nightscout, data: nightscout, httpStatus: 200),
            .available
        )
        XCTAssertEqual(FollowerOperationalStatus.available.title, Texts_SettingsView.followerOperational)

        let statusPage = Data(#"{"status":{"indicator":"minor","description":"Partial outage"}}"#.utf8)
        XCTAssertEqual(
            FollowerServiceStatusMonitor.decode(source: .dexcomShare, data: statusPage, httpStatus: 200),
            .degraded
        )
        XCTAssertEqual(
            FollowerServiceStatusMonitor.decode(source: .libreLinkUp, data: Data("bad json".utf8), httpStatus: 200),
            .fetchError
        )
        XCTAssertEqual(
            FollowerServiceStatusMonitor.decode(source: .dexcomShare, data: statusPage, httpStatus: 503),
            .fetchError
        )

        defaults.nightscoutUrl = "not a URL"
        XCTAssertNil(FollowerServiceStatusMonitor.statusURL(source: .nightscout, defaults: defaults))
    }

    func testManualLogoutOverridesOldSuccessfulConnection() {
        defaults.dexcomShareAccountName = "account"
        defaults.dexcomSharePassword = "password"
        defaults.dexcomShareRegion = .global
        defaults.timeStampOfLastFollowerConnection = now.addingTimeInterval(-60)
        defaults.dexcomShareManuallyLoggedOut = true

        XCTAssertEqual(status(.dexcomShare, sessionStatus: .loggedIn).state, .loginRequired)
    }

    // MARK: - Child screens

    @MainActor
    func testNightscoutChildContainsStatusOnly() {
        let screen = NightscoutFollowerSettingsScreen.make()
        let ids = screenRowIDs(screen)
        XCTAssertEqual(ids, ["nightscout.connection.banner", "nightscout.server.status"])
        XCTAssertFalse(ids.contains { $0.hasPrefix("nightscout.account") || $0.contains("test") })
    }

    @MainActor
    func testCareLinkChildExposesAutomaticBasalRenderingChoice() {
        let screen = CareLinkFollowerSettingsScreen.make()
        XCTAssertTrue(screenRowIDs(screen).contains("careLink.automaticBasalRenderingStyle"))
    }

    @MainActor
    func testAutodetectedRegionsLiveInProfile() {
        let libre = LibreLinkUpFollowerSettingsScreen.make(
            source: .libreLinkUp,
            actions: .none
        )
        let dexcom = DexcomShareFollowerSettingsScreen.make(actions: .none)
        let libreIDs = screenRowIDs(libre)
        let dexcomIDs = screenRowIDs(dexcom)

        XCTAssertFalse(libreIDs.contains("libreLinkUp.account.region"))
        XCTAssertTrue(libreIDs.contains("libreLinkUp.profile.region"))
        XCTAssertFalse(dexcomIDs.contains("dexcomShare.account.region"))
        XCTAssertTrue(dexcomIDs.contains("dexcomShare.profile.region"))
    }

    @MainActor
    func testLoginRowAndLogoutToolbarFollowRealSessionState() {
        let previousStatus = FollowerSessionState.shared.status(for: .dexcomShare)
        defer { FollowerSessionState.shared.update(previousStatus, for: .dexcomShare) }
        FollowerSessionState.shared.update(.loggedOut, for: .dexcomShare)
        XCTAssertNotNil(FollowerSettingsRows.loginRow(id: "login", source: .dexcomShare, hasCredentials: true, action: {}))
        let actions = FollowerSettingsRows.accountToolbarActions(source: .dexcomShare, logOut: {})
        XCTAssertFalse(actions[0].isEnabled())

        FollowerSessionState.shared.update(.loggingIn, for: .dexcomShare)
        XCTAssertNil(FollowerSettingsRows.loginRow(id: "login", source: .dexcomShare, hasCredentials: true, action: {}))
        XCTAssertFalse(actions[0].isEnabled())

        FollowerSessionState.shared.update(.loggedIn, for: .dexcomShare)
        XCTAssertNil(FollowerSettingsRows.loginRow(id: "login", source: .dexcomShare, hasCredentials: true, action: {}))
        XCTAssertTrue(actions[0].isEnabled())
    }

    @MainActor
    func testCareLinkConditionalLoginAndPatientRows() {
        let previousSnapshot = CareLinkAccountState.shared.snapshot
        let previousUsername = UserDefaults.standard.careLinkUsername
        let previousPassword = UserDefaults.standard.careLinkPassword
        defer {
            CareLinkAccountState.shared.update { $0 = previousSnapshot }
            UserDefaults.standard.careLinkUsername = previousUsername
            UserDefaults.standard.careLinkPassword = previousPassword
        }
        UserDefaults.standard.careLinkUsername = "user"
        UserDefaults.standard.careLinkPassword = "password"

        CareLinkAccountState.shared.update { $0 = CareLinkStatusSnapshot(status: .loginRequired) }
        let loggedOutRows = screenRows(CareLinkFollowerSettingsScreen.make())
        XCTAssertTrue(loggedOutRows.contains { $0.id == "careLink.connection.login" })
        XCTAssertEqual(loggedOutRows.first { $0.id == "careLink.patient" }?.detail, "-")

        let singlePatient = CareLinkPatient(id: "1", username: "one", firstName: "One", lastName: nil)
        CareLinkAccountState.shared.update {
            $0 = CareLinkStatusSnapshot(status: .active, patients: [singlePatient], selectedPatientID: "1")
        }
        let singlePatientRow = screenRows(CareLinkFollowerSettingsScreen.make()).first { $0.id == "careLink.patient" }
        XCTAssertEqual(singlePatientRow?.detail, "One")
        XCTAssertNil(singlePatientRow?.control)

        let patients = [
            CareLinkPatient(id: "1", username: "one", firstName: "One", lastName: nil),
            CareLinkPatient(id: "2", username: "two", firstName: "Two", lastName: nil)
        ]
        CareLinkAccountState.shared.update {
            $0 = CareLinkStatusSnapshot(status: .active, patients: patients, selectedPatientID: "1")
        }
        let activeScreen = CareLinkFollowerSettingsScreen.make()
        XCTAssertFalse(screenRowIDs(activeScreen).contains("careLink.connection.login"))
        let patientRow = screenRows(activeScreen).first { $0.id == "careLink.patient" }
        guard case .menuWithSelectionTitle? = patientRow?.control else {
            return XCTFail("Multiple CareLink patients should use the selectable Profile row")
        }
    }

    // MARK: - Parent screen

    func testFollowerParentContainsOnlySourceAndStatusRows() {
        let standard = UserDefaults.standard
        let previousMaster = standard.isMaster
        let previousSource = standard.followerDataSourceType
        defer {
            standard.isMaster = previousMaster
            standard.followerDataSourceType = previousSource
        }

        standard.isMaster = false
        for source in [FollowerDataSourceType.careLink, .calendar, .dexcomShare] {
            standard.followerDataSourceType = source
            let model = SettingsViewDataSourceSettingsViewModel(coreDataManager: nil)
            let sections = model.settingsSections(sectionIDBase: 0)
            XCTAssertEqual(
                sections[1].rows.filter(\.isVisible).map(\.id),
                ["dataSource.followerDataSource", "dataSource.followerStatus"]
            )
        }
    }

    func testSourcePickerClearsConnectionTimestampWithoutDeletingCredentials() {
        let standard = UserDefaults.standard
        let previousMaster = standard.isMaster
        let previousSource = standard.followerDataSourceType
        let previousTimestamp = standard.timeStampOfLastFollowerConnection
        let previousUsername = standard.dexcomShareAccountName
        defer {
            standard.isMaster = previousMaster
            standard.followerDataSourceType = previousSource
            standard.timeStampOfLastFollowerConnection = previousTimestamp
            standard.dexcomShareAccountName = previousUsername
        }

        standard.isMaster = false
        standard.followerDataSourceType = .nightscout
        standard.timeStampOfLastFollowerConnection = now
        standard.dexcomShareAccountName = "retained account"

        let model = SettingsViewDataSourceSettingsViewModel(coreDataManager: nil)
        let sourceRow = model.settingsSections(sectionIDBase: 0)[1].rows[0]
        guard case let .menu(_, selectOption)? = sourceRow.control,
              let dexcomIndex = FollowerDataSourceType.allEnabledCases.firstIndex(of: .dexcomShare) else {
            return XCTFail("Follower source row did not expose its typed menu action")
        }
        selectOption?(dexcomIndex)

        XCTAssertEqual(standard.followerDataSourceType, .dexcomShare)
        XCTAssertNil(standard.timeStampOfLastFollowerConnection)
        XCTAssertEqual(standard.dexcomShareAccountName, "retained account")
    }

    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func status(
        _ source: FollowerDataSourceType,
        sessionStatus: FollowerSessionStatus? = nil
    ) -> FollowerConnectionPresentation {
        FollowerConnectionPresentation.resolve(
            source: source,
            defaults: defaults,
            now: now,
            sessionStatus: sessionStatus
        )
    }

    @MainActor
    private func screenRows(_ screen: SettingsScreen) -> [SettingsRow] {
        let presenter = SettingsActionPresenter(router: SettingsRouter())
        return screen.makeSections(presenter).flatMap { $0.section().rows.filter(\.isVisible) }
    }

    @MainActor
    private func screenRowIDs(_ screen: SettingsScreen) -> [String] {
        screenRows(screen).map(\.id)
    }
}
