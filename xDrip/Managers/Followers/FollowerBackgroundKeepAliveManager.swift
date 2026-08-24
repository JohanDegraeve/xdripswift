//
//  FollowerBackgroundKeepAliveManager.swift
//  xdrip
//
//  Created by Paul Plant on 13/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import Foundation
import os

/// Central owner of the proven silent-audio background keep-alive used by follower modes.
///
/// Historically each follower manager duplicated the same `AVAudioPlayer`, `RepeatingTimer`, and
/// `ApplicationManager` lifecycle wiring. That made the follower implementations heavier and made
/// small lifecycle fixes easy to apply to one source but miss in another. The root application
/// coordinator now owns one instance of this class and injects its narrow interface into every
/// selectable follower manager.
///
/// ## Wiring a follower manager
///
/// Use this sequence whenever a follower source is added or its lifecycle is changed:
///
/// 1. Do not create this concrete manager inside the follower. Add a retained
///    `FollowerBackgroundKeepAliveManaging` dependency to the follower's initializer and let
///    `RootApplicationCoordinator` inject its one application-wide instance.
/// 2. In the follower's existing activation or lifecycle-reconciliation method, first verify that
///    follower mode is active, this source is selected, required configuration is present, and the
///    source has not been logged out. Sources requiring authentication, such as CareLink, must also
///    confirm a usable authenticated session.
/// 3. Immediately after those checks pass, call `start(for:)` with this follower's
///    `FollowerBackgroundKeepAliveSource`. This reports operational state only; keep the follower's
///    initial download, recurring polling, retries, and heartbeat response in their existing code.
/// 4. Shared Calendar alone calls `start(for:backgroundRefresh:)`, passing its existing throttled
///    `downloadFromKeepAliveTick()` path. Every network-backed follower must use `start(for:)` so an
///    audio health check can never initiate a network request.
/// 5. Call `stop(for:)` on every path that makes the source non-operational: source deselection,
///    master-mode selection, missing configuration, explicit logout, authentication loss, and
///    `deinit`. It is safe for several teardown paths to call `stop`; a stale source cannot stop a
///    newer source that has already registered.
/// 6. Do not observe the keep-alive setting, create audio or keep-alive timers, register audio
///    lifecycle callbacks, or call `refreshForSelectedMode()` from a follower manager. This class
///    owns those responsibilities. Heartbeat polling guards and heartbeat-triggered downloads stay
///    in the follower because they control networking rather than silent audio.
///
/// Both LibreLinkUp selections deliberately register the same `.libreLinkUp` source. The source
/// descriptor is internal coordination state and must not be added to or substituted for the
/// persisted `FollowerDataSourceType` setting.
///
/// This class deliberately preserves the established Normal and Aggressive engine:
///
/// - one retained one-shot player for `1-millisecond-of-silence.caf`;
/// - ordinary one-shot playback, replayed only after `isPlaying` becomes `false`;
/// - one suspended `RepeatingTimer`, using the existing 5-second or 2-second interval;
/// - one shared background callback to resume/check playback;
/// - one shared foreground callback to suspend the timer without altering the player.
///
/// Continuous mode is intentionally isolated on a second retained player created from the same
/// proven CAF. That player uses `AVAudioPlayer.numberOfLoops = -1` while the app is backgrounded.
/// Keeping the players separate means entering or leaving Continuous mode can stop and reset its
/// loop without ever stopping, replacing, or changing the established one-shot player. A five-
/// second health timer can restart an interrupted loop and preserves Shared Calendar's established
/// throttled refresh opportunity, but continuous playback does not depend on that timer firing.
///
/// The operational source remains registered in disabled and heartbeat modes. This is important
/// because changing back to an audio mode can restore playback immediately without asking a
/// follower manager to rebuild authentication, polling, or other source state. Heartbeat excludes
/// silent audio here, while the separate heartbeat guards in each follower manager continue to
/// control its own polling timers.
///
/// Networking is outside this class. It must never call a follower's `download`, `refreshNow`, or
/// polling API. Shared Calendar is the only exception to the otherwise audio-only tick: it may
/// provide its existing throttled background-read closure through `start(for:backgroundRefresh:)`.
final class FollowerBackgroundKeepAliveManager: NSObject, FollowerBackgroundKeepAliveManaging {
    typealias AudioPlayerFactory = (String) throws -> FollowerBackgroundAudioPlaying
    typealias TimerFactory = (TimeInterval, @escaping () -> Void) -> FollowerBackgroundTimer

    private let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager
    )
    /// Supplies the single pair of application foreground/background callbacks.
    private let applicationManager: FollowerBackgroundApplicationManaging

    /// Reads the current setting at every lifecycle event and timer tick, so a stale callback can
    /// never play audio after the user selects disabled or heartbeat mode.
    private let selectedKeepAliveType: () -> FollowerBackgroundKeepAliveType
    private let timerFactory: TimerFactory
    private let notificationCenter: NotificationCenter

    /// Serializes every entry point that touches timer, lifecycle, source, closure, or audio state.
    /// A recursive lock is required because `start` delegates to `refreshForSelectedMode`, while
    /// synchronous KVO and test callbacks intentionally preserve their immediate behavior.
    private let stateLock = NSRecursiveLock()

    /// The proven player used only for the existing Normal and Aggressive one-shot replays.
    private var oneShotAudioPlayer: FollowerBackgroundAudioPlaying?

    /// A separate player that Continuous mode can stop without altering the one-shot engine.
    private var continuousAudioPlayer: FollowerBackgroundAudioPlaying?

    /// The only shared timer. It replays one-shot audio or health-checks Continuous playback.
    private var keepAliveTimer: FollowerBackgroundTimer?

    /// Invalidates callbacks already queued by a timer that has since been replaced.
    private var timerGeneration = 0

    /// Tracks lifecycle state so a setting change can take effect while already backgrounded.
    private var applicationIsInBackground = false

    /// The follower that has passed its own operational checks, even if audio is currently off.
    private var activeSource: FollowerBackgroundKeepAliveSource?

    /// Optional Shared Calendar work to run after the audio check on background entry and ticks.
    private var backgroundRefresh: (() -> Void)?

    /// Notification token for the single application-wide audio-interruption observer.
    private var audioInterruptionObserver: NSObjectProtocol?

    private let applicationManagerKeyResumePlaySoundTimer = "FollowerBackgroundKeepAliveManager-ResumePlaySoundTimer"
    private let applicationManagerKeySuspendPlaySoundTimer = "FollowerBackgroundKeepAliveManager-SuspendPlaySoundTimer"

    /// Creates the single application-wide follower background keep-alive engine.
    ///
    /// The root application coordinator creates this manager while application services are being
    /// assembled and the app is still in the foreground. Initializing it at that point creates the
    /// proven one-shot player and the isolated Continuous player before any follower needs
    /// background execution. It also installs exactly one pair of application lifecycle callbacks,
    /// one keep-alive setting observer, and one audio-interruption observer.
    ///
    /// Each audio-player creation is independently nonfatal. If one player cannot be created, the
    /// other mode can still operate, while follower authentication and polling always remain
    /// available because this class never owns or controls those operations.
    ///
    /// - Parameters:
    ///   - applicationManager: Supplies the foreground and background lifecycle callbacks. The
    ///     production default uses the shared `ApplicationManager`; tests inject a passive fake.
    ///   - selectedKeepAliveType: Reads the user's current keep-alive selection. It is evaluated at
    ///     configuration time and again at every lifecycle event and timer tick so queued work
    ///     cannot use an obsolete normal, aggressive, continuous, disabled, or heartbeat value.
    ///   - audioPlayerFactory: Creates both retained players from the existing silent CAF resource.
    ///     It is called once for the one-shot player and once for the isolated Continuous player.
    ///   - timerFactory: Creates the single suspended keep-alive timer at the selected interval.
    ///     Injection allows tests to drive ticks deterministically without waiting in real time.
    ///   - notificationCenter: Supplies audio-interruption notifications. The production default
    ///     uses `NotificationCenter.default`; tests inject an isolated notification center.
    init(
        applicationManager: FollowerBackgroundApplicationManaging = ApplicationManager.shared,
        selectedKeepAliveType: @escaping () -> FollowerBackgroundKeepAliveType = {
            UserDefaults.standard.followerBackgroundKeepAliveType
        },
        audioPlayerFactory: @escaping AudioPlayerFactory = FollowerBackgroundKeepAliveManager.makeAudioPlayer,
        timerFactory: @escaping TimerFactory = { interval, eventHandler in
            RepeatingTimer(timeInterval: interval, eventHandler: eventHandler)
        },
        notificationCenter: NotificationCenter = .default
    ) {
        self.applicationManager = applicationManager
        self.selectedKeepAliveType = selectedKeepAliveType
        self.timerFactory = timerFactory
        self.notificationCenter = notificationCenter
        super.init()

        // Build both retained players while application services are initialized in the foreground.
        // Failures are independent and nonfatal: follower networking can continue without audio.
        do {
            oneShotAudioPlayer = try audioPlayerFactory(ConstantsSuspensionPrevention.soundFileName)
        } catch {
            trace(
                "in init, exception while creating one-shot audioplayer, error = %{public}@",
                log: log,
                category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
                type: .error,
                error.localizedDescription
            )
        }
        do {
            continuousAudioPlayer = try audioPlayerFactory(ConstantsSuspensionPrevention.soundFileName)
            continuousAudioPlayer?.numberOfLoops = -1
        } catch {
            trace(
                "in init, exception while creating continuous audioplayer, error = %{public}@",
                log: log,
                category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
                type: .error,
                error.localizedDescription
            )
        }

        applicationManager.addClosureToRunWhenAppDidEnterBackground(
            key: applicationManagerKeyResumePlaySoundTimer
        ) { [weak self] in
            self?.applicationDidEnterBackground()
        }
        applicationManager.addClosureToRunWhenAppWillEnterForeground(
            key: applicationManagerKeySuspendPlaySoundTimer
        ) { [weak self] in
            self?.applicationWillEnterForeground()
        }

        // Keep setting interpretation here rather than making every follower observe the same key.
        // Changing the audio interval must not restart a download or rebuild authenticated state.
        UserDefaults.standard.addObserver(
            self,
            forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue,
            options: .new,
            context: nil
        )

        audioInterruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.audioSessionWasInterrupted(notification)
        }
    }

    /// Records the operational follower and configures the shared engine for the current setting.
    ///
    /// A follower calls this only after it has passed its own operational requirements, such as
    /// source selection, required settings, logout state, and (for CareLink) authenticated-session
    /// validation. Calling it does not start a download, change authentication, or imply that audio
    /// is enabled. This manager independently interprets the current keep-alive selection.
    ///
    /// Re-registering the same source updates only its optional Calendar action and cannot create a
    /// duplicate timer or lifecycle callback. Registering another source replaces the previous
    /// registration and rebuilds the one shared timer for the new source. Disabled and heartbeat
    /// retain the operational source without creating an audio timer, allowing a later change to
    /// an audio mode to restore playback without restarting the follower.
    ///
    /// - Parameters:
    ///   - source: The follower that is currently configured, selected, and operational.
    ///   - backgroundRefresh: Optional work invoked after the audio check on background entry and
    ///     after each keep-alive tick. Only Shared Calendar supplies this closure; network-backed
    ///     followers must pass `nil` so audio ticks remain independent of follower polling.
    func start(for source: FollowerBackgroundKeepAliveSource, backgroundRefresh: (() -> Void)?) {
        stateLock.lock()
        defer { stateLock.unlock() }

        if activeSource == source {
            self.backgroundRefresh = backgroundRefresh
            return
        }
        activeSource = source
        self.backgroundRefresh = backgroundRefresh
        refreshForSelectedMode()
    }

    /// Stops the shared engine only when the caller is still the registered operational follower.
    ///
    /// Follower managers call this whenever their source is deselected or becomes non-operational,
    /// including logout, missing configuration, authentication loss, master-mode selection, and
    /// teardown. The source match is intentional: an asynchronous or delayed stop from the old
    /// follower cannot suspend a newer follower that has already called `start`.
    ///
    /// A matching stop suspends and removes the shared timer, stops only the dedicated Continuous
    /// player, then clears the source and optional Calendar action. It never alters the proven
    /// one-shot player, follower sessions, or polling timers.
    ///
    /// - Parameter source: The follower whose operational registration should be cleared.
    func stop(for source: FollowerBackgroundKeepAliveSource) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard activeSource == source else { return }
        replaceKeepAliveTimer(with: nil)
        stopContinuousPlayback()
        activeSource = nil
        backgroundRefresh = nil
    }

    /// Rebuilds only shared audio scheduling to reflect the user's current keep-alive setting.
    ///
    /// Normal and Aggressive retain their exact existing 5-second and 2-second replay intervals.
    /// Continuous uses a 5-second health check while its separate player loops independently.
    /// Disabled and Heartbeat leave the operational source intact but remove audio scheduling.
    /// No follower download, login, session, retry schedule, or authentication state is touched.
    ///
    /// This operation is internal so the setting observer and focused tests can exercise the same
    /// reconfiguration path. Follower managers should report operational state through `start` and
    /// `stop` instead of calling this method when settings change.
    func refreshForSelectedMode() {
        stateLock.lock()
        defer { stateLock.unlock() }

        replaceKeepAliveTimer(with: nil)

        let keepAliveType = selectedKeepAliveType()
        if keepAliveType != .continuous {
            stopContinuousPlayback()
        }
        guard activeSource != nil,
              let interval = keepAliveInterval(for: keepAliveType) else { return }

        timerGeneration += 1
        let generation = timerGeneration
        let timer = timerFactory(TimeInterval(interval)) { [weak self] in
            self?.keepAliveTimerFired(interval: interval, generation: generation)
        }
        keepAliveTimer = timer

        // Settings normally change while the app is visible, but applying this state immediately
        // also makes an already-backgrounded transition deterministic.
        if applicationIsInBackground, let activeSource {
            timer.resume()
            ensureAudioIsPlaying(for: keepAliveType, interval: interval, source: activeSource)
        }
    }

    /// Responds to the shared keep-alive preference changing without restarting any follower.
    ///
    /// Only the `followerBackgroundKeepAliveType` key path is accepted. The callback delegates to
    /// `refreshForSelectedMode`, centralizing mode interpretation here instead of duplicating KVO
    /// handling in every follower manager.
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == UserDefaults.Key.followerBackgroundKeepAliveType.rawValue else { return }
        refreshForSelectedMode()
    }

    deinit {
        stateLock.lock()
        defer { stateLock.unlock() }

        UserDefaults.standard.removeObserver(
            self,
            forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue
        )
        replaceKeepAliveTimer(with: nil)
        stopContinuousPlayback()
        if let audioInterruptionObserver {
            notificationCenter.removeObserver(audioInterruptionObserver)
        }
        applicationManager.removeClosureToRunWhenAppDidEnterBackground(
            key: applicationManagerKeyResumePlaySoundTimer
        )
        applicationManager.removeClosureToRunWhenAppWillEnterForeground(
            key: applicationManagerKeySuspendPlaySoundTimer
        )
    }

    /// Activates the selected audio mode and performs the immediate background-entry audio check.
    ///
    /// The callback first confirms that an operational follower is registered and that the current
    /// setting still permits silent audio. Shared Calendar's optional refresh runs only after the
    /// audio check. All other follower sources have no work attached to this lifecycle event.
    private func applicationDidEnterBackground() {
        stateLock.lock()
        defer { stateLock.unlock() }

        applicationIsInBackground = true
        let keepAliveType = selectedKeepAliveType()
        guard let activeSource,
              let interval = keepAliveInterval(for: keepAliveType) else { return }

        // Normal and Aggressive keep their exact existing immediate one-shot check. Continuous
        // starts its isolated loop. The Calendar action follows either audio check.
        keepAliveTimer?.resume()
        ensureAudioIsPlaying(for: keepAliveType, interval: interval, source: activeSource)
        backgroundRefresh?()
    }

    /// Suspends background replay when the application is returning to the foreground.
    ///
    /// Suspending the timer preserves the proven lifecycle behavior. The one-shot player is not
    /// stopped, replaced, or reset. Only the separate Continuous player is stopped and rewound so
    /// its indefinite loop cannot continue while the application is visible.
    private func applicationWillEnterForeground() {
        stateLock.lock()
        defer { stateLock.unlock() }

        applicationIsInBackground = false
        keepAliveTimer?.suspend()
        // Preserve the proven one-shot player exactly. Only the dedicated Continuous player stops.
        stopContinuousPlayback()
    }

    /// Handles one shared replay-timer tick after revalidating current source and setting state.
    ///
    /// Revalidation makes an already-queued callback harmless after source deselection or a change
    /// to disabled or heartbeat. The optional Shared Calendar refresh follows the audio check; this
    /// method never invokes a network follower's polling API.
    ///
    /// - Parameters:
    ///   - interval: The established interval captured when this timer was created.
    ///   - generation: Identifies the currently installed timer and rejects a queued obsolete tick.
    private func keepAliveTimerFired(interval: Int, generation: Int) {
        stateLock.lock()
        defer { stateLock.unlock() }

        // Revalidate both pieces of state on every tick. This makes a pending callback harmless if
        // its source stopped or the user selected disabled/heartbeat while it was queued.
        let keepAliveType = selectedKeepAliveType()
        guard generation == timerGeneration,
              applicationIsInBackground,
              let activeSource,
              keepAliveInterval(for: keepAliveType) == interval else { return }
        ensureAudioIsPlaying(for: keepAliveType, interval: interval, source: activeSource)
        backgroundRefresh?()
    }

    /// Returns the shared timer interval for an audio-enabled keep-alive mode.
    ///
    /// Normal and Aggressive retain their proven intervals. Continuous uses the normal five-second
    /// cadence only as a health check and Shared Calendar refresh opportunity; the audio itself is
    /// already looping independently. Disabled and Heartbeat have no audio timer.
    private func keepAliveInterval(for keepAliveType: FollowerBackgroundKeepAliveType) -> Int? {
        switch keepAliveType {
        case .normal, .continuous:
            return ConstantsSuspensionPrevention.intervalNormal
        case .aggressive:
            return ConstantsSuspensionPrevention.intervalAggressive
        case .disabled, .heartbeat:
            return nil
        }
    }

    /// Suspends and replaces the one shared keep-alive timer without leaving stale ticks active.
    ///
    /// - Parameter replacement: The newly configured timer, or `nil` when audio scheduling is off.
    private func replaceKeepAliveTimer(with replacement: FollowerBackgroundTimer?) {
        timerGeneration += 1
        keepAliveTimer?.suspend()
        keepAliveTimer = replacement
    }

    /// Selects the isolated Continuous player or the proven one-shot player for an audio check.
    ///
    /// This method contains no follower networking. Shared Calendar work remains outside it and is
    /// invoked only after the audio check by the lifecycle and timer callers.
    ///
    /// - Parameters:
    ///   - keepAliveType: The currently selected and revalidated keep-alive setting.
    ///   - interval: The active timer interval, used only for diagnostic logging.
    ///   - source: The currently registered follower, used only for diagnostic logging.
    private func ensureAudioIsPlaying(
        for keepAliveType: FollowerBackgroundKeepAliveType,
        interval: Int,
        source: FollowerBackgroundKeepAliveSource
    ) {
        if keepAliveType == .continuous {
            playContinuousAudioIfNeeded(source: source)
        } else {
            playOneShotAudioIfNeeded(interval: interval, source: source)
        }
    }

    /// Replays the retained one-shot sound only after its previous playback has ended.
    ///
    /// The `isPlaying` check is the core behavior of the proven engine and intentionally remains
    /// unchanged. This method does not loop the player, reconfigure the audio session, create a new
    /// player, or initiate follower networking.
    ///
    /// - Parameters:
    ///   - interval: The active timer interval, used only to make diagnostic logging explicit.
    ///   - source: The currently registered follower, used only to identify the owner in logging.
    private func playOneShotAudioIfNeeded(interval: Int, source: FollowerBackgroundKeepAliveSource) {
        trace(
            "in eventhandler checking if audioplayer exists",
            log: log,
            category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
            type: .info
        )
        guard let oneShotAudioPlayer, !oneShotAudioPlayer.isPlaying else { return }
        trace(
            "playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@",
            log: log,
            category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
            type: .info,
            interval.description,
            source.description,
            selectedKeepAliveType().description
        )
        oneShotAudioPlayer.play()
    }

    /// Starts or restores the isolated continuously looping silent-audio player.
    ///
    /// The loop uses the existing CAF and `numberOfLoops = -1`. The `isPlaying` check prevents
    /// lifecycle, health-timer, and interruption callbacks from restarting healthy playback. This
    /// operation never touches the one-shot player or initiates follower networking.
    ///
    /// - Parameter source: The currently registered follower, used only for diagnostic logging.
    private func playContinuousAudioIfNeeded(source: FollowerBackgroundKeepAliveSource) {
        guard let continuousAudioPlayer, !continuousAudioPlayer.isPlaying else { return }
        continuousAudioPlayer.currentTime = 0
        trace(
            "starting continuous silent audio. %{public}@ keep-alive",
            log: log,
            category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
            type: .info,
            source.description
        )
        continuousAudioPlayer.play()
    }

    /// Stops and rewinds only the player reserved for Continuous keep-alive.
    ///
    /// The proven Normal and Aggressive player is deliberately untouched, including when the app
    /// enters the foreground or the selected mode changes.
    private func stopContinuousPlayback() {
        guard let continuousAudioPlayer else { return }
        if continuousAudioPlayer.isPlaying {
            continuousAudioPlayer.stop()
        }
        continuousAudioPlayer.currentTime = 0
    }

    /// Restores Continuous playback after the system ends an audio-session interruption.
    ///
    /// iOS may interrupt audio for calls, alarms, Siri, or another non-mixing audio session. The
    /// manager restarts only when an operational follower remains registered, the app is still in
    /// the background, Continuous remains selected, and playback actually stopped. It does not
    /// reconfigure `AVAudioSession` or request follower networking.
    ///
    /// - Parameter notification: The `AVAudioSession.interruptionNotification` to interpret.
    private func audioSessionWasInterrupted(_ notification: Notification) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: typeValue) == .ended,
              applicationIsInBackground,
              selectedKeepAliveType() == .continuous,
              let activeSource else { return }
        playContinuousAudioIfNeeded(source: activeSource)
    }

    /// Creates the production `AVAudioPlayer` for the existing bundled silent-audio resource.
    ///
    /// The resource name already includes its extension, matching the legacy lookup exactly. The
    /// factory is called once for the proven one-shot player and once for the separate Continuous
    /// player so stopping the loop can never alter Normal or Aggressive playback.
    ///
    /// - Parameter resourceName: The complete bundled filename from `ConstantsSuspensionPrevention`.
    /// - Returns: A new audio player used by one side of the shared keep-alive engine.
    /// - Throws: A descriptive error when the resource is absent, or the error produced while
    ///   initializing `AVAudioPlayer` when the resource cannot be opened.
    private static func makeAudioPlayer(resourceName: String) throws -> FollowerBackgroundAudioPlaying {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "") else {
            throw FollowerBackgroundKeepAliveError.missingSoundFile(resourceName)
        }
        return try AVAudioPlayer(contentsOf: url)
    }
}

/// Identifies the operational follower that currently owns the shared keep-alive registration.
///
/// This is deliberately separate from `FollowerDataSourceType`. It is an internal coordination
/// value for the six follower managers and is not persisted, presented as a setting, or used to
/// change the stored follower-source contract. Both LibreLinkUp selections use `.libreLinkUp`.
enum FollowerBackgroundKeepAliveSource: CustomStringConvertible {
    case nightscout
    case libreLinkUp
    case dexcomShare
    case medtrumEasyView
    case sharedCalendar
    case careLink

    /// A developer-facing source name used in shared keep-alive diagnostic logging.
    var description: String {
        switch self {
        case .nightscout: return "Nightscout"
        case .libreLinkUp: return "LibreLinkUp"
        case .dexcomShare: return "Dexcom Share"
        case .medtrumEasyView: return "Medtrum EasyView"
        case .sharedCalendar: return "Shared Calendar"
        case .careLink: return "CareLink"
        }
    }
}

/// The narrow interface through which follower managers report their operational state.
///
/// Follower managers do not need to know whether silent audio is currently enabled. They simply
/// call `start` after their own configuration and authentication requirements have passed, and
/// call `stop` whenever that source is no longer operational. The shared manager interprets the
/// selected keep-alive mode and owns all audio and application-lifecycle behavior.
protocol FollowerBackgroundKeepAliveManaging: AnyObject {
    /// Registers a fully operational follower with the application-wide shared keep-alive engine.
    ///
    /// Consumers report operational state only. The shared engine decides whether the current
    /// normal, aggressive, continuous, disabled, or heartbeat setting permits silent audio and owns
    /// both players, the shared timer, mode observation, interruption recovery, and application
    /// lifecycle callbacks. Calling this operation never starts follower networking or changes
    /// authentication state.
    ///
    /// Calling `start` repeatedly for the same source is safe and does not create duplicate timers
    /// or lifecycle callbacks. Starting a different source replaces the previous operational source.
    ///
    /// - Parameters:
    ///   - source: The follower whose own configuration and operational checks have passed.
    ///   - backgroundRefresh: Optional work invoked after background audio checks. This is reserved
    ///     for Shared Calendar's existing throttled read; all network followers pass `nil`.
    func start(for source: FollowerBackgroundKeepAliveSource, backgroundRefresh: (() -> Void)?)

    /// Removes a follower from the application-wide shared keep-alive engine if it still owns it.
    ///
    /// The source check prevents delayed teardown from a previously selected follower from stopping
    /// a newer source. A matching stop removes only shared audio scheduling and the optional Calendar
    /// action; follower polling, authentication, retries, and session teardown remain the caller's
    /// responsibility.
    ///
    /// - Parameter source: The follower that is no longer selected, configured, or operational.
    func stop(for source: FollowerBackgroundKeepAliveSource)
}

extension FollowerBackgroundKeepAliveManaging {
    /// Registers a network-backed follower with the shared keep-alive engine.
    ///
    /// This convenience overload deliberately supplies no background action. It guarantees that a
    /// silent-audio lifecycle event or replay tick cannot trigger a network follower download.
    /// Shared Calendar uses `start(for:backgroundRefresh:)` directly because it alone retains its
    /// existing throttled background-read behavior.
    ///
    /// - Parameter source: The network-backed follower whose operational checks have passed.
    func start(for source: FollowerBackgroundKeepAliveSource) {
        start(for: source, backgroundRefresh: nil)
    }
}

// These small dependency interfaces keep the production implementation on the proven
// AVAudioPlayer/RepeatingTimer/ApplicationManager engine while allowing deterministic unit tests
// that do not play audio or move the test host between foreground and background.
protocol FollowerBackgroundAudioPlaying: AnyObject {
    /// Indicates whether the retained sound is currently playing.
    ///
    /// The shared engine checks this before every replay or Continuous health check and leaves an
    /// in-progress playback alone.
    var isPlaying: Bool { get }

    /// Controls whether the player's audio repeats after reaching the end of the CAF.
    ///
    /// The dedicated Continuous player receives `-1`; the proven one-shot player retains the
    /// `AVAudioPlayer` default of `0` and is never modified by Continuous mode.
    var numberOfLoops: Int { get set }

    /// Reads or rewinds the current playback position.
    ///
    /// Only the dedicated Continuous player is rewound when its background run ends or restarts.
    var currentTime: TimeInterval { get set }

    /// Starts one ordinary playback of the existing silent-audio resource.
    ///
    /// The shared engine calls this only after `isPlaying` is false. The return value preserves the
    /// `AVAudioPlayer` contract but is intentionally not used to alter follower operation.
    ///
    /// - Returns: `true` when the player accepted the playback request.
    @discardableResult func play() -> Bool

    /// Stops only the dedicated Continuous player when its background run is no longer required.
    ///
    /// Normal and Aggressive never call this operation, preserving their established foreground
    /// behavior in which an already-started short sound is allowed to finish.
    func stop()
}

extension AVAudioPlayer: FollowerBackgroundAudioPlaying {}

protocol FollowerBackgroundTimer: AnyObject {
    /// Allows the suspended replay timer to fire while the app is in the background.
    func resume()

    /// Prevents replay ticks while preserving the timer's proven suspend/resume behavior.
    func suspend()
}

extension RepeatingTimer: FollowerBackgroundTimer {}

protocol FollowerBackgroundApplicationManaging: AnyObject {
    /// Registers the one callback that activates shared follower keep-alive on background entry.
    ///
    /// - Parameters:
    ///   - key: The manager-owned identifier used to prevent or remove duplicate registration.
    ///   - closure: The shared manager callback to invoke after the app enters the background.
    func addClosureToRunWhenAppDidEnterBackground(key: String, closure: @escaping () -> Void)

    /// Registers the one callback that suspends shared follower keep-alive on foreground entry.
    ///
    /// - Parameters:
    ///   - key: The manager-owned identifier used to prevent or remove duplicate registration.
    ///   - closure: The shared manager callback to invoke before the app enters the foreground.
    func addClosureToRunWhenAppWillEnterForeground(key: String, closure: @escaping () -> Void)

    /// Removes the shared background-entry callback associated with the supplied identifier.
    ///
    /// - Parameter key: The same manager-owned identifier used during registration.
    func removeClosureToRunWhenAppDidEnterBackground(key: String)

    /// Removes the shared foreground-entry callback associated with the supplied identifier.
    ///
    /// - Parameter key: The same manager-owned identifier used during registration.
    func removeClosureToRunWhenAppWillEnterForeground(key: String)
}

extension ApplicationManager: FollowerBackgroundApplicationManaging {}

private enum FollowerBackgroundKeepAliveError: LocalizedError {
    case missingSoundFile(String)

    var errorDescription: String? {
        switch self {
        case let .missingSoundFile(resourceName):
            return "Missing background keep-alive sound file: \(resourceName)"
        }
    }
}
