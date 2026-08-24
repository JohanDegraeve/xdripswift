//
//  FollowerBackgroundKeepAliveManagerTests.swift
//  xdripTests
//
//  Created by Paul Plant on 13/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import Combine
import XCTest
@testable import xdrip

final class FollowerBackgroundKeepAliveManagerTests: XCTestCase {
    func testCreatesBothPlayersWithExistingShortSoundAndDoesNotPlayInForeground() {
        let test = makeTestManager(mode: .normal)

        test.manager.start(for: .nightscout)

        XCTAssertEqual(
            test.requestedSoundFiles(),
            [ConstantsSuspensionPrevention.soundFileName, ConstantsSuspensionPrevention.soundFileName]
        )
        XCTAssertEqual(test.oneShotAudioPlayer.numberOfLoops, 0)
        XCTAssertEqual(test.continuousAudioPlayer.numberOfLoops, -1)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 0)
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 0)
        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5])
        XCTAssertEqual(test.applicationManager.backgroundClosures.count, 1)
        XCTAssertEqual(test.applicationManager.foregroundClosures.count, 1)
    }

    func testBackgroundStartsTimerAndEndedPlayback() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .nightscout)

        test.applicationManager.enterBackground()

        XCTAssertEqual(test.timerFactory.timers.last?.resumeCount, 1)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 0)
    }

    func testTimerReplaysOnlyAfterShortSoundEnds() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .careLink)
        test.applicationManager.enterBackground()
        let timer = test.timerFactory.timers.last

        timer?.fire()
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)

        test.oneShotAudioPlayer.isPlaying = false
        timer?.fire()
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 2)
    }

    func testForegroundSuspendsTimerWithoutChangingPlayer() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .dexcomShare)
        test.applicationManager.enterBackground()

        test.applicationManager.enterForeground()

        XCTAssertEqual(test.timerFactory.timers.last?.suspendCount, 1)
        XCTAssertTrue(test.oneShotAudioPlayer.isPlaying)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
        XCTAssertEqual(test.oneShotAudioPlayer.stopCount, 0)
    }

    func testAggressiveModeUsesTwoSeconds() {
        let test = makeTestManager(mode: .aggressive)

        test.manager.start(for: .medtrumEasyView)

        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [2])
    }

    func testDisabledAndHeartbeatNeverCreateOrPlayAudioTimer() {
        for mode in [FollowerBackgroundKeepAliveType.disabled, .heartbeat] {
            let test = makeTestManager(mode: mode)
            test.manager.start(for: .libreLinkUp)

            test.applicationManager.enterBackground()

            XCTAssertTrue(test.timerFactory.timers.isEmpty)
            XCTAssertEqual(test.oneShotAudioPlayer.playCount, 0)
            XCTAssertEqual(test.continuousAudioPlayer.playCount, 0)
        }
    }

    func testModeChangesReplaceOrRemoveOnlyTheReplayTimer() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .nightscout)
        let normalTimer = test.timerFactory.timers.last

        test.setMode(.aggressive)
        test.manager.refreshForSelectedMode()

        XCTAssertEqual(normalTimer?.suspendCount, 1)
        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5, 2])

        let aggressiveTimer = test.timerFactory.timers.last
        test.setMode(.heartbeat)
        test.manager.refreshForSelectedMode()

        XCTAssertEqual(aggressiveTimer?.suspendCount, 1)
        test.applicationManager.enterBackground()
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 0)
    }

    func testRepeatedStartDoesNotDuplicateTimerOrLifecycleCallbacks() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .nightscout)
        let firstTimer = test.timerFactory.timers.last

        test.manager.start(for: .nightscout)

        XCTAssertEqual(firstTimer?.suspendCount, 0)
        XCTAssertEqual(test.timerFactory.timers.count, 1)
        XCTAssertEqual(test.applicationManager.backgroundClosures.count, 1)
        XCTAssertEqual(test.applicationManager.foregroundClosures.count, 1)
    }

    func testStaleSourceCannotStopNewActiveSource() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .nightscout)
        test.manager.start(for: .careLink)

        test.manager.stop(for: .nightscout)
        test.applicationManager.enterBackground()

        XCTAssertEqual(test.timerFactory.timers.last?.resumeCount, 1)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
    }

    func testCalendarRefreshRunsOnBackgroundEntryAndEveryTick() {
        let test = makeTestManager(mode: .normal)
        var refreshCount = 0
        test.manager.start(for: .sharedCalendar) {
            refreshCount += 1
        }

        test.applicationManager.enterBackground()
        test.timerFactory.timers.last?.fire()

        XCTAssertEqual(refreshCount, 2)
    }

    func testOtherFollowersHaveNoBackgroundRefreshAction() {
        let test = makeTestManager(mode: .normal)
        var refreshCount = 0
        test.manager.start(for: .sharedCalendar) {
            refreshCount += 1
        }
        test.manager.start(for: .careLink)

        test.applicationManager.enterBackground()
        test.timerFactory.timers.last?.fire()

        XCTAssertEqual(refreshCount, 0)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
    }

    func testEverySelectableFollowerSourceCanBecomeTheOperationalSource() {
        let test = makeTestManager(mode: .normal)
        let sources: [FollowerBackgroundKeepAliveSource] = [
            .nightscout,
            .libreLinkUp,
            .dexcomShare,
            .medtrumEasyView,
            .sharedCalendar,
            .careLink
        ]

        for source in sources {
            test.manager.start(for: source)
        }
        for staleSource in sources.dropLast() {
            test.manager.stop(for: staleSource)
        }
        test.applicationManager.enterBackground()

        XCTAssertEqual(test.timerFactory.timers.count, sources.count)
        XCTAssertEqual(test.timerFactory.timers.last?.resumeCount, 1)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
    }

    func testContinuousStartsLoopInBackgroundAndUsesFiveSecondHealthTimer() {
        let test = makeTestManager(mode: .continuous)
        test.manager.start(for: .nightscout)

        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5])
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 0)

        test.applicationManager.enterBackground()

        XCTAssertEqual(test.timerFactory.timers.last?.resumeCount, 1)
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 1)
        XCTAssertTrue(test.continuousAudioPlayer.isPlaying)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 0)
    }

    func testContinuousHealthTickLeavesHealthyLoopAloneAndRestartsEndedPlayback() {
        let test = makeTestManager(mode: .continuous)
        test.manager.start(for: .careLink)
        test.applicationManager.enterBackground()
        let timer = test.timerFactory.timers.last

        timer?.fire()
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 1)

        test.continuousAudioPlayer.isPlaying = false
        test.continuousAudioPlayer.currentTime = 0.25
        timer?.fire()

        XCTAssertEqual(test.continuousAudioPlayer.playCount, 2)
        XCTAssertEqual(test.continuousAudioPlayer.currentTime, 0)
    }

    func testForegroundStopsOnlyContinuousPlayer() {
        let test = makeTestManager(mode: .continuous)
        test.manager.start(for: .dexcomShare)
        test.applicationManager.enterBackground()

        test.applicationManager.enterForeground()

        XCTAssertEqual(test.timerFactory.timers.last?.suspendCount, 1)
        XCTAssertEqual(test.continuousAudioPlayer.stopCount, 1)
        XCTAssertFalse(test.continuousAudioPlayer.isPlaying)
        XCTAssertEqual(test.continuousAudioPlayer.currentTime, 0)
        XCTAssertEqual(test.oneShotAudioPlayer.stopCount, 0)
    }

    func testContinuousModeChangesStopLoopAndRestoreOneShotEngineWhileBackgrounded() {
        let test = makeTestManager(mode: .continuous)
        test.manager.start(for: .nightscout)
        test.applicationManager.enterBackground()
        let continuousTimer = test.timerFactory.timers.last

        test.setMode(.aggressive)
        test.manager.refreshForSelectedMode()

        XCTAssertEqual(continuousTimer?.suspendCount, 1)
        XCTAssertEqual(test.continuousAudioPlayer.stopCount, 1)
        XCTAssertEqual(test.oneShotAudioPlayer.playCount, 1)
        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5, 2])

        test.oneShotAudioPlayer.isPlaying = false
        test.setMode(.continuous)
        test.manager.refreshForSelectedMode()

        XCTAssertEqual(test.continuousAudioPlayer.playCount, 2)
        XCTAssertEqual(test.oneShotAudioPlayer.stopCount, 0)
        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5, 2, 5])
    }

    func testDisabledAndHeartbeatStopContinuousImmediatelyButRetainSource() {
        for mode in [FollowerBackgroundKeepAliveType.disabled, .heartbeat] {
            let test = makeTestManager(mode: .continuous)
            test.manager.start(for: .libreLinkUp)
            test.applicationManager.enterBackground()

            test.setMode(mode)
            test.manager.refreshForSelectedMode()

            XCTAssertEqual(test.continuousAudioPlayer.stopCount, 1)
            XCTAssertFalse(test.continuousAudioPlayer.isPlaying)

            test.setMode(.continuous)
            test.manager.refreshForSelectedMode()
            XCTAssertEqual(test.continuousAudioPlayer.playCount, 2)
        }
    }

    func testEndedAudioInterruptionRestartsOnlyBackgroundContinuousPlayback() {
        let test = makeTestManager(mode: .continuous)
        test.manager.start(for: .careLink)
        test.applicationManager.enterBackground()
        test.continuousAudioPlayer.isPlaying = false

        test.notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        XCTAssertEqual(test.continuousAudioPlayer.playCount, 2)

        test.applicationManager.enterForeground()
        test.notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )
        XCTAssertEqual(test.continuousAudioPlayer.playCount, 2)
    }

    func testTimerAndInterruptionCallbacksSerializeAudioStateAccess() {
        let applicationManager = FakeFollowerApplicationManager()
        let oneShotPlayer = FakeFollowerAudioPlayer()
        let continuousPlayer = SerialAccessProbeAudioPlayer()
        let timerFactory = FakeFollowerTimerFactory()
        let notificationCenter = NotificationCenter()
        var playerFactoryCall = 0
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { .continuous },
            audioPlayerFactory: { _ in
                defer { playerFactoryCall += 1 }
                return playerFactoryCall == 0 ? oneShotPlayer : continuousPlayer
            },
            timerFactory: timerFactory.makeTimer,
            notificationCenter: notificationCenter
        )
        manager.start(for: .careLink)
        applicationManager.enterBackground()
        let timer = timerFactory.timers.last

        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                timer?.fire()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                notificationCenter.post(
                    name: AVAudioSession.interruptionNotification,
                    object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
                )
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(continuousPlayer.maximumConcurrentStateAccesses, 1)
    }

    func testActualKeepAlivePreferenceObservationReconfiguresTheSharedManager() {
        let defaults = UserDefaults.standard
        let key = UserDefaults.Key.followerBackgroundKeepAliveType.rawValue
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.followerBackgroundKeepAliveType = .normal

        let applicationManager = FakeFollowerApplicationManager()
        let players = [FakeFollowerAudioPlayer(), FakeFollowerAudioPlayer()]
        let timerFactory = FakeFollowerTimerFactory()
        var playerIndex = 0
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { defaults.followerBackgroundKeepAliveType },
            audioPlayerFactory: { _ in
                defer { playerIndex += 1 }
                return players[playerIndex]
            },
            timerFactory: timerFactory.makeTimer,
            notificationCenter: NotificationCenter()
        )
        manager.start(for: .nightscout)
        let normalTimer = timerFactory.timers.last

        defaults.followerBackgroundKeepAliveType = .aggressive

        XCTAssertEqual(normalTimer?.suspendCount, 1)
        XCTAssertEqual(timerFactory.timers.map(\.interval), [5, 2])
    }

    func testPersistedRawValuesAndMenuOrderIncludeContinuousWithoutReorderingExistingModes() {
        XCTAssertEqual(FollowerBackgroundKeepAliveType.disabled.rawValue, 0)
        XCTAssertEqual(FollowerBackgroundKeepAliveType.normal.rawValue, 1)
        XCTAssertEqual(FollowerBackgroundKeepAliveType.aggressive.rawValue, 2)
        XCTAssertEqual(FollowerBackgroundKeepAliveType.heartbeat.rawValue, 3)
        XCTAssertEqual(FollowerBackgroundKeepAliveType.continuous.rawValue, 4)
        XCTAssertEqual(
            FollowerBackgroundKeepAliveType.allCases,
            [.disabled, .normal, .aggressive, .continuous, .heartbeat]
        )
        XCTAssertEqual(FollowerBackgroundKeepAliveType.continuous.keepAliveImageString, "c.circle")
    }

    func testAudioPlayerCreationFailureIsNonfatal() {
        let applicationManager = FakeFollowerApplicationManager()
        let timerFactory = FakeFollowerTimerFactory()
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { .normal },
            audioPlayerFactory: { _ in throw TestError.audioUnavailable },
            timerFactory: timerFactory.makeTimer,
            notificationCenter: NotificationCenter()
        )
        manager.start(for: .nightscout)

        applicationManager.enterBackground()
        timerFactory.timers.last?.fire()

        XCTAssertEqual(timerFactory.timers.last?.resumeCount, 1)
    }

    func testEitherPlayerCanOperateWhenTheOtherPlayerCannotBeCreated() {
        let scenarios: [(failedFactoryCall: Int, mode: FollowerBackgroundKeepAliveType)] = [
            (0, .continuous),
            (1, .normal)
        ]

        for scenario in scenarios {
            let applicationManager = FakeFollowerApplicationManager()
            let workingPlayer = FakeFollowerAudioPlayer()
            let timerFactory = FakeFollowerTimerFactory()
            var factoryCall = 0
            let manager = FollowerBackgroundKeepAliveManager(
                applicationManager: applicationManager,
                selectedKeepAliveType: { scenario.mode },
                audioPlayerFactory: { _ in
                    defer { factoryCall += 1 }
                    if factoryCall == scenario.failedFactoryCall {
                        throw TestError.audioUnavailable
                    }
                    return workingPlayer
                },
                timerFactory: timerFactory.makeTimer,
                notificationCenter: NotificationCenter()
            )

            manager.start(for: .nightscout)
            applicationManager.enterBackground()

            XCTAssertEqual(workingPlayer.playCount, 1)
        }
    }

    func testAllNetworkFollowerManagersWireOperationalAndTeardownStatesToSharedManager() {
        let snapshot = StandardDefaultsSnapshot(keys: [
            .isMaster,
            .followerDataSourceType,
            .nightscoutUrl,
            .nightscoutEnabled,
            .libreLinkUpEmail,
            .libreLinkUpPassword,
            .libreLinkUpManuallyLoggedOut,
            .dexcomShareAccountName,
            .dexcomSharePassword,
            .dexcomShareManuallyLoggedOut,
            .medtrumEasyViewEmail,
            .medtrumEasyViewPassword,
            .medtrumEasyViewManuallyLoggedOut
        ])
        defer { snapshot.restore() }

        let defaults = UserDefaults.standard
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let delegate = KeepAliveFollowerDelegateSpy()
        let keepAlive = RecordingFollowerBackgroundKeepAliveManager()
        defaults.isMaster = false

        defaults.followerDataSourceType = .nightscout
        defaults.nightscoutUrl = "https://example.invalid"
        defaults.nightscoutEnabled = true
        var nightscout: NightscoutFollowManager? = NightscoutFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: keepAlive,
            startsInitialDownload: false
        )
        XCTAssertEqual(keepAlive.startedSources, [.nightscout])
        defaults.followerDataSourceType = .dexcomShare
        XCTAssertEqual(keepAlive.stoppedSources.last, .nightscout)
        nightscout = nil
        XCTAssertNil(nightscout)

        keepAlive.reset()
        defaults.libreLinkUpEmail = "follower@example.invalid"
        defaults.libreLinkUpPassword = "password"
        defaults.libreLinkUpManuallyLoggedOut = false
        for source in [FollowerDataSourceType.libreLinkUp, .libreLinkUpRussia] {
            defaults.followerDataSourceType = source
            var libre: LibreLinkUpFollowManager? = LibreLinkUpFollowManager(
                coreDataManager: coreDataManager,
                followerDelegate: delegate,
                backgroundKeepAliveManager: keepAlive,
                startsInitialDownload: false
            )
            XCTAssertEqual(keepAlive.startedSources.last, .libreLinkUp)
            libre?.logOut()
            XCTAssertEqual(keepAlive.stoppedSources.last, .libreLinkUp)
            libre = nil
            defaults.libreLinkUpManuallyLoggedOut = false
        }

        keepAlive.reset()
        defaults.followerDataSourceType = .dexcomShare
        defaults.dexcomShareAccountName = "account"
        defaults.dexcomSharePassword = "password"
        defaults.dexcomShareManuallyLoggedOut = false
        var dexcom: DexcomShareFollowManager? = DexcomShareFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: keepAlive,
            startsInitialDownload: false
        )
        XCTAssertEqual(keepAlive.startedSources, [.dexcomShare])
        dexcom?.logOut()
        XCTAssertEqual(keepAlive.stoppedSources.last, .dexcomShare)
        dexcom = nil
        XCTAssertNil(dexcom)

        keepAlive.reset()
        defaults.followerDataSourceType = .medtrumEasyView
        defaults.medtrumEasyViewEmail = "follower@example.invalid"
        defaults.medtrumEasyViewPassword = "password"
        defaults.medtrumEasyViewManuallyLoggedOut = false
        var medtrum: MedtrumEasyViewFollowManager? = MedtrumEasyViewFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: keepAlive,
            startsInitialDownload: false
        )
        XCTAssertEqual(keepAlive.startedSources, [.medtrumEasyView])
        medtrum?.logOut()
        XCTAssertEqual(keepAlive.stoppedSources.last, .medtrumEasyView)
        medtrum = nil
        XCTAssertNil(medtrum)
    }

    func testCalendarAloneSuppliesBackgroundRefreshAndStopsOnSourceChange() {
        let snapshot = StandardDefaultsSnapshot(keys: [
            .isMaster,
            .followerDataSourceType,
            .calendarFollowCalendarId,
            .calendarFollowStatus
        ])
        defer { snapshot.restore() }

        let defaults = UserDefaults.standard
        defaults.isMaster = false
        defaults.followerDataSourceType = .calendar
        defaults.calendarFollowCalendarId = "Shared Calendar"
        let keepAlive = RecordingFollowerBackgroundKeepAliveManager()
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        var manager: CalendarFollowManager? = CalendarFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: KeepAliveFollowerDelegateSpy(),
            backgroundKeepAliveManager: keepAlive,
            startsInitialDownload: false
        )

        XCTAssertEqual(keepAlive.startedSources, [.sharedCalendar])
        XCTAssertEqual(keepAlive.backgroundRefreshWasProvided, [true])

        defaults.followerDataSourceType = .nightscout
        XCTAssertEqual(keepAlive.stoppedSources.last, .sharedCalendar)
        manager = nil
        XCTAssertNil(manager)
    }

    @MainActor
    func testCareLinkRequiresOAuthSessionButNotOptionalPrefillBeforeStartingSharedManager() async {
        let snapshot = StandardDefaultsSnapshot(keys: [
            .isMaster,
            .followerDataSourceType,
            .careLinkUsername,
            .careLinkPassword,
            .careLinkSelectedPatientID,
            .followerBackgroundKeepAliveType
        ])
        defer { snapshot.restore() }

        let defaults = UserDefaults.standard
        defaults.isMaster = false
        defaults.followerDataSourceType = .careLink
        defaults.followerBackgroundKeepAliveType = .continuous
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let delegate = KeepAliveFollowerDelegateSpy()

        defaults.careLinkUsername = "care-partner@example.invalid"
        defaults.careLinkPassword = "password"
        let credentialsOnlyKeepAlive = RecordingFollowerBackgroundKeepAliveManager()
        let credentialsOnlyState = CareLinkAccountState()
        var credentialsOnlyManager: CareLinkFollowManager? = CareLinkFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: credentialsOnlyKeepAlive,
            client: CareLinkClient(tokenStore: CareLinkMemoryTokenStore()),
            state: credentialsOnlyState,
            startsInitialDownload: false
        )
        await waitUntil { credentialsOnlyState.snapshot.status == .loginRequired }
        XCTAssertTrue(credentialsOnlyKeepAlive.startedSources.isEmpty)
        credentialsOnlyManager = nil
        XCTAssertNil(credentialsOnlyManager)

        defaults.careLinkUsername = nil
        defaults.careLinkPassword = nil
        let orphanedTokenStore = CareLinkMemoryTokenStore()
        orphanedTokenStore.token = makeCareLinkTestToken()
        let authenticatedKeepAlive = RecordingFollowerBackgroundKeepAliveManager()
        let authenticatedState = CareLinkAccountState()
        let authenticatedPollingSchedulerFactory = FakeFollowerTimerFactory()
        var authenticatedStatuses = [CareLinkConnectionStatus]()
        let authenticatedObserver = authenticatedState.$snapshot.sink {
            authenticatedStatuses.append($0.status)
        }
        var authenticatedManager: CareLinkFollowManager? = CareLinkFollowManager(
            coreDataManager: coreDataManager,
            followerDelegate: delegate,
            backgroundKeepAliveManager: authenticatedKeepAlive,
            client: CareLinkClient(tokenStore: orphanedTokenStore),
            state: authenticatedState,
            startsInitialDownload: false,
            pollingSchedulerFactory: authenticatedPollingSchedulerFactory.makeTimer
        )
        await waitUntil { authenticatedKeepAlive.startedSources == [.careLink] }
        XCTAssertEqual(authenticatedKeepAlive.startedSources, [.careLink])
        XCTAssertEqual(authenticatedPollingSchedulerFactory.timers.map(\.interval), [ConstantsCareLink.schedulerCheckInterval])
        XCTAssertEqual(authenticatedPollingSchedulerFactory.timers.first?.resumeCount, 1)
        XCTAssertEqual(authenticatedState.snapshot.status, .connecting)
        XCTAssertFalse(authenticatedStatuses.contains(.loginRequired))
        XCTAssertNotNil(orphanedTokenStore.token)
        authenticatedManager = nil
        XCTAssertEqual(authenticatedKeepAlive.stoppedSources.last, .careLink)
        XCTAssertEqual(authenticatedPollingSchedulerFactory.timers.first?.suspendCount, 1)
        XCTAssertNil(authenticatedManager)
        withExtendedLifetime(authenticatedObserver) {}
        authenticatedObserver.cancel()
    }

    @MainActor
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func makeCareLinkTestToken() -> CareLinkToken {
        CareLinkToken(
            accessToken: "test-token",
            refreshToken: "test-refresh-token",
            expiresAt: Date().addingTimeInterval(3_600),
            region: .outsideUnitedStates,
            countryCode: "GB",
            oauthConfiguration: CareLinkOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://carelink-login.minimed.eu/authorize")!,
                tokenEndpoint: URL(string: "https://carelink-login.minimed.eu/oauth/token")!,
                revocationEndpoint: URL(string: "https://carelink-login.minimed.eu/oauth/revoke")!,
                clientID: "test-client",
                scope: "profile openid offline_access",
                redirectURI: URL(string: "com.medtronic.carepartner:/sso")!,
                audience: "carepartner.patient.ous"
            )
        )
    }

    private func makeTestManager(mode initialMode: FollowerBackgroundKeepAliveType) -> TestManager {
        let applicationManager = FakeFollowerApplicationManager()
        let oneShotAudioPlayer = FakeFollowerAudioPlayer()
        let continuousAudioPlayer = FakeFollowerAudioPlayer()
        let players = [oneShotAudioPlayer, continuousAudioPlayer]
        let timerFactory = FakeFollowerTimerFactory()
        let notificationCenter = NotificationCenter()
        var selectedMode = initialMode
        var requestedSoundFiles: [String] = []
        var playerIndex = 0
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { selectedMode },
            audioPlayerFactory: { resourceName in
                requestedSoundFiles.append(resourceName)
                defer { playerIndex += 1 }
                return players[playerIndex]
            },
            timerFactory: timerFactory.makeTimer,
            notificationCenter: notificationCenter
        )
        return TestManager(
            manager: manager,
            applicationManager: applicationManager,
            oneShotAudioPlayer: oneShotAudioPlayer,
            continuousAudioPlayer: continuousAudioPlayer,
            timerFactory: timerFactory,
            notificationCenter: notificationCenter,
            setMode: { selectedMode = $0 },
            requestedSoundFiles: { requestedSoundFiles }
        )
    }
}

private struct TestManager {
    let manager: FollowerBackgroundKeepAliveManager
    let applicationManager: FakeFollowerApplicationManager
    let oneShotAudioPlayer: FakeFollowerAudioPlayer
    let continuousAudioPlayer: FakeFollowerAudioPlayer
    let timerFactory: FakeFollowerTimerFactory
    let notificationCenter: NotificationCenter
    let setMode: (FollowerBackgroundKeepAliveType) -> Void
    let requestedSoundFiles: () -> [String]
}

/// Records the operational-state calls made by real follower managers without playing audio.
private final class RecordingFollowerBackgroundKeepAliveManager: FollowerBackgroundKeepAliveManaging {
    private(set) var startedSources: [FollowerBackgroundKeepAliveSource] = []
    private(set) var stoppedSources: [FollowerBackgroundKeepAliveSource] = []
    private(set) var backgroundRefreshWasProvided: [Bool] = []

    func start(for source: FollowerBackgroundKeepAliveSource, backgroundRefresh: (() -> Void)?) {
        startedSources.append(source)
        backgroundRefreshWasProvided.append(backgroundRefresh != nil)
    }

    func stop(for source: FollowerBackgroundKeepAliveSource) {
        stoppedSources.append(source)
    }

    func reset() {
        startedSources.removeAll()
        stoppedSources.removeAll()
        backgroundRefreshWasProvided.removeAll()
    }
}

/// Satisfies the real follower initializers while the wiring tests deliberately suppress downloads.
private final class KeepAliveFollowerDelegateSpy: FollowerDelegate {
    func followerInfoReceived(followGlucoseDataArray: inout [FollowerBgReading]) {}
}

/// Restores the exact standard-defaults state changed while real follower managers are exercised.
private final class StandardDefaultsSnapshot {
    private let defaults: UserDefaults
    private let keys: [UserDefaults.Key]
    private var existingValues: [String: Any] = [:]
    private var missingKeys: Set<String> = []

    init(defaults: UserDefaults = .standard, keys: [UserDefaults.Key]) {
        self.defaults = defaults
        self.keys = keys

        for key in keys {
            if let value = defaults.object(forKey: key.rawValue) {
                existingValues[key.rawValue] = value
            } else {
                missingKeys.insert(key.rawValue)
            }
        }
    }

    func restore() {
        for key in keys {
            if missingKeys.contains(key.rawValue) {
                defaults.removeObject(forKey: key.rawValue)
            } else if let value = existingValues[key.rawValue] {
                defaults.set(value, forKey: key.rawValue)
            }
        }
    }
}

private final class FakeFollowerAudioPlayer: FollowerBackgroundAudioPlaying {
    var isPlaying = false
    var numberOfLoops = 0
    var currentTime: TimeInterval = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0

    func play() -> Bool {
        playCount += 1
        isPlaying = true
        return true
    }

    func stop() {
        stopCount += 1
        isPlaying = false
    }
}

/// Widens each `isPlaying` read enough for concurrent callback entry points to overlap. The shared
/// manager must keep the observed maximum at one even when timer and interruption callbacks arrive
/// simultaneously on different queues.
private final class SerialAccessProbeAudioPlayer: FollowerBackgroundAudioPlaying {
    var numberOfLoops = 0
    var currentTime: TimeInterval = 0

    private let monitor = NSLock()
    private var activeStateAccesses = 0
    private(set) var maximumConcurrentStateAccesses = 0

    var isPlaying: Bool {
        monitor.lock()
        activeStateAccesses += 1
        maximumConcurrentStateAccesses = max(maximumConcurrentStateAccesses, activeStateAccesses)
        monitor.unlock()

        Thread.sleep(forTimeInterval: 0.002)

        monitor.lock()
        activeStateAccesses -= 1
        monitor.unlock()
        return false
    }

    func play() -> Bool { true }
    func stop() {}
}

private final class FakeFollowerTimer: FollowerBackgroundTimer {
    let interval: TimeInterval
    private let eventHandler: () -> Void
    private(set) var resumeCount = 0
    private(set) var suspendCount = 0

    init(interval: TimeInterval, eventHandler: @escaping () -> Void) {
        self.interval = interval
        self.eventHandler = eventHandler
    }

    func resume() {
        resumeCount += 1
    }

    func suspend() {
        suspendCount += 1
    }

    func fire() {
        eventHandler()
    }
}

private final class FakeFollowerTimerFactory {
    private(set) var timers: [FakeFollowerTimer] = []

    func makeTimer(interval: TimeInterval, eventHandler: @escaping () -> Void) -> FollowerBackgroundTimer {
        let timer = FakeFollowerTimer(interval: interval, eventHandler: eventHandler)
        timers.append(timer)
        return timer
    }
}

private final class FakeFollowerApplicationManager: FollowerBackgroundApplicationManaging {
    private(set) var backgroundClosures: [String: () -> Void] = [:]
    private(set) var foregroundClosures: [String: () -> Void] = [:]

    func addClosureToRunWhenAppDidEnterBackground(key: String, closure: @escaping () -> Void) {
        backgroundClosures[key] = closure
    }

    func addClosureToRunWhenAppWillEnterForeground(key: String, closure: @escaping () -> Void) {
        foregroundClosures[key] = closure
    }

    func removeClosureToRunWhenAppDidEnterBackground(key: String) {
        backgroundClosures[key] = nil
    }

    func removeClosureToRunWhenAppWillEnterForeground(key: String) {
        foregroundClosures[key] = nil
    }

    func enterBackground() {
        backgroundClosures.values.forEach { $0() }
    }

    func enterForeground() {
        foregroundClosures.values.forEach { $0() }
    }
}

private enum TestError: Error {
    case audioUnavailable
}
