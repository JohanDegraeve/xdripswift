//
//  FollowerBackgroundKeepAliveManagerTests.swift
//  xdripTests
//
//  Created by Paul Plant on 13/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class FollowerBackgroundKeepAliveManagerTests: XCTestCase {
    func testCreatesPlayerWithExistingShortSoundAndDoesNotPlayInForeground() {
        let test = makeTestManager(mode: .normal)

        test.manager.start(for: .nightscout)

        XCTAssertEqual(test.requestedSoundFile(), ConstantsSuspensionPrevention.soundFileName)
        XCTAssertEqual(test.audioPlayer.playCount, 0)
        XCTAssertEqual(test.timerFactory.timers.map(\.interval), [5])
        XCTAssertEqual(test.applicationManager.backgroundClosures.count, 1)
        XCTAssertEqual(test.applicationManager.foregroundClosures.count, 1)
    }

    func testBackgroundStartsTimerAndEndedPlayback() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .nightscout)

        test.applicationManager.enterBackground()

        XCTAssertEqual(test.timerFactory.timers.last?.resumeCount, 1)
        XCTAssertEqual(test.audioPlayer.playCount, 1)
    }

    func testTimerReplaysOnlyAfterShortSoundEnds() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .careLink)
        test.applicationManager.enterBackground()
        let timer = test.timerFactory.timers.last

        timer?.fire()
        XCTAssertEqual(test.audioPlayer.playCount, 1)

        test.audioPlayer.isPlaying = false
        timer?.fire()
        XCTAssertEqual(test.audioPlayer.playCount, 2)
    }

    func testForegroundSuspendsTimerWithoutChangingPlayer() {
        let test = makeTestManager(mode: .normal)
        test.manager.start(for: .dexcomShare)
        test.applicationManager.enterBackground()

        test.applicationManager.enterForeground()

        XCTAssertEqual(test.timerFactory.timers.last?.suspendCount, 1)
        XCTAssertTrue(test.audioPlayer.isPlaying)
        XCTAssertEqual(test.audioPlayer.playCount, 1)
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
            XCTAssertEqual(test.audioPlayer.playCount, 0)
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
        XCTAssertEqual(test.audioPlayer.playCount, 0)
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
        XCTAssertEqual(test.audioPlayer.playCount, 1)
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
        XCTAssertEqual(test.audioPlayer.playCount, 1)
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
        XCTAssertEqual(test.audioPlayer.playCount, 1)
    }

    func testAudioPlayerCreationFailureIsNonfatal() {
        let applicationManager = FakeFollowerApplicationManager()
        let timerFactory = FakeFollowerTimerFactory()
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { .normal },
            audioPlayerFactory: { _ in throw TestError.audioUnavailable },
            timerFactory: timerFactory.makeTimer
        )
        manager.start(for: .nightscout)

        applicationManager.enterBackground()
        timerFactory.timers.last?.fire()

        XCTAssertEqual(timerFactory.timers.last?.resumeCount, 1)
    }

    private func makeTestManager(mode initialMode: FollowerBackgroundKeepAliveType) -> TestManager {
        let applicationManager = FakeFollowerApplicationManager()
        let audioPlayer = FakeFollowerAudioPlayer()
        let timerFactory = FakeFollowerTimerFactory()
        var selectedMode = initialMode
        var requestedSoundFile: String?
        let manager = FollowerBackgroundKeepAliveManager(
            applicationManager: applicationManager,
            selectedKeepAliveType: { selectedMode },
            audioPlayerFactory: { resourceName in
                requestedSoundFile = resourceName
                return audioPlayer
            },
            timerFactory: timerFactory.makeTimer
        )
        return TestManager(
            manager: manager,
            applicationManager: applicationManager,
            audioPlayer: audioPlayer,
            timerFactory: timerFactory,
            setMode: { selectedMode = $0 },
            requestedSoundFile: { requestedSoundFile }
        )
    }
}

private struct TestManager {
    let manager: FollowerBackgroundKeepAliveManager
    let applicationManager: FakeFollowerApplicationManager
    let audioPlayer: FakeFollowerAudioPlayer
    let timerFactory: FakeFollowerTimerFactory
    let setMode: (FollowerBackgroundKeepAliveType) -> Void
    let requestedSoundFile: () -> String?
}

private final class FakeFollowerAudioPlayer: FollowerBackgroundAudioPlaying {
    var isPlaying = false
    private(set) var playCount = 0

    func play() -> Bool {
        playCount += 1
        isPlaying = true
        return true
    }
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
