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
/// This class deliberately preserves the established keep-alive engine:
///
/// - one retained player for `1-millisecond-of-silence.caf`;
/// - ordinary one-shot playback, replayed only after `isPlaying` becomes `false`;
/// - one suspended `RepeatingTimer`, using the existing 5-second or 2-second interval;
/// - one shared background callback to resume/check playback;
/// - one shared foreground callback to suspend the timer without altering the player.
///
/// The operational source remains registered in disabled and heartbeat modes. This is important
/// because changing back to normal or aggressive can restore audio immediately without asking a
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

    /// Created once during application-service initialization and retained for one-shot replays.
    private var audioPlayer: FollowerBackgroundAudioPlaying?

    /// The only replay timer. A setting change suspends and replaces this instance as necessary.
    private var playSoundTimer: FollowerBackgroundTimer?

    /// The follower that has passed its own operational checks, even if audio is currently off.
    private var activeSource: FollowerBackgroundKeepAliveSource?

    /// Optional Shared Calendar work to run after the audio check on background entry and ticks.
    private var backgroundRefresh: (() -> Void)?

    private let applicationManagerKeyResumePlaySoundTimer = "FollowerBackgroundKeepAliveManager-ResumePlaySoundTimer"
    private let applicationManagerKeySuspendPlaySoundTimer = "FollowerBackgroundKeepAliveManager-SuspendPlaySoundTimer"

    /// Creates the single application-wide follower background keep-alive engine.
    ///
    /// The root application coordinator creates this manager while application services are being
    /// assembled and the app is still in the foreground. Initializing it at that point creates and
    /// retains the proven one-shot audio player before any follower needs background execution. It
    /// also installs exactly one pair of application lifecycle callbacks and one observer for the
    /// user's keep-alive setting, replacing the copies that previously lived in follower managers.
    ///
    /// Audio-player creation is deliberately nonfatal. A missing or unreadable sound is logged,
    /// while follower authentication and polling remain available because this class never owns or
    /// controls those operations.
    ///
    /// - Parameters:
    ///   - applicationManager: Supplies the foreground and background lifecycle callbacks. The
    ///     production default uses the shared `ApplicationManager`; tests inject a passive fake.
    ///   - selectedKeepAliveType: Reads the user's current keep-alive selection. It is evaluated at
    ///     configuration time and again at every lifecycle event and timer tick so queued work
    ///     cannot use an obsolete normal, aggressive, disabled, or heartbeat value.
    ///   - audioPlayerFactory: Creates the retained player for the existing silent CAF resource.
    ///     Injection allows tests to observe playback without producing audio.
    ///   - timerFactory: Creates the single suspended replay timer at the established interval.
    ///     Injection allows tests to drive ticks deterministically without waiting in real time.
    init(
        applicationManager: FollowerBackgroundApplicationManaging = ApplicationManager.shared,
        selectedKeepAliveType: @escaping () -> FollowerBackgroundKeepAliveType = {
            UserDefaults.standard.followerBackgroundKeepAliveType
        },
        audioPlayerFactory: @escaping AudioPlayerFactory = FollowerBackgroundKeepAliveManager.makeAudioPlayer,
        timerFactory: @escaping TimerFactory = { interval, eventHandler in
            RepeatingTimer(timeInterval: interval, eventHandler: eventHandler)
        }
    ) {
        self.applicationManager = applicationManager
        self.selectedKeepAliveType = selectedKeepAliveType
        self.timerFactory = timerFactory
        super.init()

        // Build the retained player while application services are initialized in the foreground.
        // Failure is intentionally nonfatal: follower networking can continue without audio.
        do {
            audioPlayer = try audioPlayerFactory(ConstantsSuspensionPrevention.soundFileName)
        } catch {
            trace(
                "in init, exception while trying to create audioplayer, error = %{public}@",
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
    /// registration and rebuilds the one replay timer for the new source. Disabled and heartbeat
    /// retain the operational source without creating an audio timer, allowing a later change to
    /// normal or aggressive to restore audio without restarting the follower.
    ///
    /// - Parameters:
    ///   - source: The follower that is currently configured, selected, and operational.
    ///   - backgroundRefresh: Optional work invoked after the audio check on background entry and
    ///     after each keep-alive tick. Only Shared Calendar supplies this closure; network-backed
    ///     followers must pass `nil` so audio ticks remain independent of follower polling.
    func start(for source: FollowerBackgroundKeepAliveSource, backgroundRefresh: (() -> Void)?) {
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
    /// A matching stop suspends and removes the replay timer, then clears the source and optional
    /// Calendar action. It does not stop or replace the retained audio player, invalidate follower
    /// sessions, or alter any polling timer.
    ///
    /// - Parameter source: The follower whose operational registration should be cleared.
    func stop(for source: FollowerBackgroundKeepAliveSource) {
        guard activeSource == source else { return }
        playSoundTimer?.suspend()
        playSoundTimer = nil
        activeSource = nil
        backgroundRefresh = nil
    }

    /// Rebuilds only the shared replay timer to reflect the user's current keep-alive setting.
    ///
    /// Normal and aggressive receive their exact existing intervals. Disabled and heartbeat leave
    /// the operational source intact but suspend and remove the timer. The new timer starts in the
    /// suspended state and is resumed only when the application enters the background. No follower
    /// download, login, session, retry schedule, or authentication state is touched.
    ///
    /// This operation is internal so the setting observer and focused tests can exercise the same
    /// reconfiguration path. Follower managers should report operational state through `start` and
    /// `stop` instead of calling this method when settings change.
    func refreshForSelectedMode() {
        playSoundTimer?.suspend()
        playSoundTimer = nil

        guard activeSource != nil else { return }
        let keepAliveType = selectedKeepAliveType()
        guard keepAliveType.shouldKeepAlive else { return }

        let interval = keepAliveType == .normal
            ? ConstantsSuspensionPrevention.intervalNormal
            : ConstantsSuspensionPrevention.intervalAggressive
        playSoundTimer = timerFactory(TimeInterval(interval)) { [weak self] in
            self?.keepAliveTimerFired(interval: interval)
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
        UserDefaults.standard.removeObserver(
            self,
            forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue
        )
        playSoundTimer?.suspend()
        applicationManager.removeClosureToRunWhenAppDidEnterBackground(
            key: applicationManagerKeyResumePlaySoundTimer
        )
        applicationManager.removeClosureToRunWhenAppWillEnterForeground(
            key: applicationManagerKeySuspendPlaySoundTimer
        )
    }

    /// Activates the existing replay timer and performs the immediate background-entry audio check.
    ///
    /// The callback first confirms that an operational follower is registered and that the current
    /// setting still permits silent audio. Shared Calendar's optional refresh runs only after the
    /// audio check. All other follower sources have no work attached to this lifecycle event.
    private func applicationDidEnterBackground() {
        guard let activeSource, selectedKeepAliveType().shouldKeepAlive else { return }

        // Match the proven follower behavior: start the wake timer and immediately ensure that the
        // short sound is playing. The Calendar action runs only after this audio check.
        playSoundTimer?.resume()
        playAudioIfNeeded(interval: selectedInterval, source: activeSource)
        backgroundRefresh?()
    }

    /// Suspends background replay when the application is returning to the foreground.
    ///
    /// Suspending the timer preserves the proven lifecycle behavior. The retained player is not
    /// stopped, replaced, reset, or converted into continuous playback.
    private func applicationWillEnterForeground() {
        // Do not stop, replace, or otherwise modify the retained player on foreground entry.
        playSoundTimer?.suspend()
    }

    /// Handles one shared replay-timer tick after revalidating current source and setting state.
    ///
    /// Revalidation makes an already-queued callback harmless after source deselection or a change
    /// to disabled or heartbeat. The optional Shared Calendar refresh follows the audio check; this
    /// method never invokes a network follower's polling API.
    ///
    /// - Parameter interval: The established replay interval captured when this timer was created.
    private func keepAliveTimerFired(interval: Int) {
        // Revalidate both pieces of state on every tick. This makes a pending callback harmless if
        // its source stopped or the user selected disabled/heartbeat while it was queued.
        guard let activeSource, selectedKeepAliveType().shouldKeepAlive else { return }
        playAudioIfNeeded(interval: interval, source: activeSource)
        backgroundRefresh?()
    }

    /// Returns the established replay interval for the currently selected audio-enabled mode.
    ///
    /// Callers reach this property only after confirming `shouldKeepAlive`, so normal maps to five
    /// seconds and the remaining audio-enabled case, aggressive, maps to two seconds.
    private var selectedInterval: Int {
        selectedKeepAliveType() == .normal
            ? ConstantsSuspensionPrevention.intervalNormal
            : ConstantsSuspensionPrevention.intervalAggressive
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
    private func playAudioIfNeeded(interval: Int, source: FollowerBackgroundKeepAliveSource) {
        trace(
            "in eventhandler checking if audioplayer exists",
            log: log,
            category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
            type: .info
        )
        guard let audioPlayer, !audioPlayer.isPlaying else { return }
        trace(
            "playing audio every %{public}@ seconds. %{public}@ keep-alive: %{public}@",
            log: log,
            category: ConstantsLog.categoryFollowerBackgroundKeepAliveManager,
            type: .info,
            interval.description,
            source.description,
            selectedKeepAliveType().description
        )
        audioPlayer.play()
    }

    /// Creates the production `AVAudioPlayer` for the existing bundled silent-audio resource.
    ///
    /// The resource name already includes its extension, matching the legacy lookup exactly. The
    /// resulting player is created once by the initializer and retained for all subsequent one-shot
    /// replays.
    ///
    /// - Parameter resourceName: The complete bundled filename from `ConstantsSuspensionPrevention`.
    /// - Returns: The audio player used by the shared keep-alive engine.
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
    /// normal, aggressive, disabled, or heartbeat setting permits silent audio and owns the player,
    /// replay timer, mode observation, and application lifecycle callbacks. Calling this operation
    /// never starts follower networking or changes authentication state.
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
    /// Indicates whether the retained one-shot sound is still playing.
    ///
    /// The shared engine checks this before every replay and leaves an in-progress playback alone.
    var isPlaying: Bool { get }

    /// Starts one ordinary playback of the existing silent-audio resource.
    ///
    /// The shared engine calls this only after `isPlaying` is false. The return value preserves the
    /// `AVAudioPlayer` contract but is intentionally not used to alter follower operation.
    ///
    /// - Returns: `true` when the player accepted the playback request.
    @discardableResult func play() -> Bool
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
