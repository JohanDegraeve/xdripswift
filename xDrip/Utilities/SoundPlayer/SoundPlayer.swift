import Foundation
import AVFoundation
import os

/// Allows playback and cancellation to be tested without producing audio.
protocol AlarmAudioPlaying: AnyObject {
    var numberOfLoops: Int { get set }
    var delegate: AVAudioPlayerDelegate? { get set }
    func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: AlarmAudioPlaying {}

/// Plays audio through the playback session, overriding the silent switch.
class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryPlaySound)
    // Audio route negotiation must not block the main thread.
    private static let activationQueue = DispatchQueue(label: "SoundPlayer.audioSessionActivation")

    private var audioPlayer: AlarmAudioPlaying?
    private var playbackID: UUID?
    private var activationID: UUID?
    private var repeats = false
    private var interrupted = false
    private var paused = false
    private var completion: (() -> Void)?
    private var repeatVibration: (() -> Void)?
    private var vibrationID: UUID?
    private var cancelVibration: (() -> Void)?
    private var observers = [NSObjectProtocol]()
    private let activateSession: (@escaping (Error?) -> Void) -> Void
    private let makePlayer: (URL) throws -> AlarmAudioPlaying
    private let scheduleVibration: (@escaping () -> Void) -> (() -> Void)

    init(
        activateSession: @escaping (@escaping (Error?) -> Void) -> Void = SoundPlayer.activateAudioSession,
        makePlayer: @escaping (URL) throws -> AlarmAudioPlaying = { try AVAudioPlayer(contentsOf: $0) },
        scheduleVibration: @escaping (@escaping () -> Void) -> (() -> Void) = SoundPlayer.scheduleRepeatedVibration
    ) {
        self.activateSession = activateSession
        self.makePlayer = makePlayer
        self.scheduleVibration = scheduleVibration
        super.init()
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            self?.handleInterruption(type: type, shouldResume: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.interrupted = false
            self?.stopPlaying()
        })
    }

    private static func activateAudioSession(completion: @escaping (Error?) -> Void) {
        activationQueue.async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: .mixWithOthers)
                try session.setActive(true)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    private static func scheduleRepeatedVibration(action: @escaping () -> Void) -> (() -> Void) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // Repeat the standard vibration once per second while the sound loops.
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler(handler: action)
        timer.resume()
        return { timer.cancel() }
    }

    /// Play the file once unless repetition is requested.
    func playSound(soundFileName: String, repeatSound: Bool = false, repeatVibration: (() -> Void)? = nil, onFinished: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.playSound(soundFileName: soundFileName, repeatSound: repeatSound, repeatVibration: repeatVibration, onFinished: onFinished)
            }
            return
        }
        stopPlaying()
        playbackID = UUID()
        repeats = repeatSound
        self.repeatVibration = repeatVibration
        completion = onFinished
        do {
            guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "") else {
                throw CocoaError(.fileNoSuchFile)
            }
            audioPlayer = try makePlayer(url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = repeatSound ? -1 : 0
            if !interrupted { activateAndPlay() }
        } catch {
            playbackFailed(error)
        }
    }

    private func activateAndPlay() {
        guard let playbackID, !paused else { return }
        let activationID = UUID()
        self.activationID = activationID
        activateSession { [weak self] error in
            let finish = {
                guard let self, self.playbackID == playbackID,
                      self.activationID == activationID, !self.interrupted, !self.paused else { return }
                self.activationID = nil
                if let error {
                    self.playbackFailed(error)
                } else if self.audioPlayer?.play() != true {
                    self.playbackFailed(CocoaError(.fileReadUnknown))
                } else {
                    self.startRepeatedVibration()
                }
            }
            if Thread.isMainThread { finish() } else { DispatchQueue.main.async(execute: finish) }
        }
    }

    private func startRepeatedVibration() {
        stopRepeatedVibration()
        guard repeats, repeatVibration != nil, let playbackID, !paused, !interrupted else { return }
        // Ignore callbacks queued before a pause or a replacement alarm.
        let vibrationID = UUID()
        self.vibrationID = vibrationID
        cancelVibration = scheduleVibration { [weak self] in
            guard let self, self.playbackID == playbackID, self.vibrationID == vibrationID,
                  !self.paused, !self.interrupted else { return }
            self.repeatVibration?()
        }
    }

    private func stopRepeatedVibration() {
        vibrationID = nil
        cancelVibration?()
        cancelVibration = nil
    }

    /// Keep Speak Glucose suppressed while playback is pending or interrupted.
    func isPlaying() -> Bool {
        return playbackID != nil
    }

    /// Pause previews without losing the current position.
    func pausePlaying() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.pausePlaying() }
            return
        }
        guard playbackID != nil else { return }
        paused = true
        stopRepeatedVibration()
        activationID = nil
        audioPlayer?.pause()
    }

    func resumePlaying() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.resumePlaying() }
            return
        }
        guard playbackID != nil, paused else { return }
        paused = false
        if !interrupted { activateAndPlay() }
    }

    func stopPlaying() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stopPlaying() }
            return
        }
        stopRepeatedVibration()
        repeatVibration = nil
        playbackID = nil
        activationID = nil
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayer = nil
        let onFinished = completion
        completion = nil
        repeats = false
        paused = false
        onFinished?()
    }

    /// Resume only the current alarm after an audio interruption.
    func handleInterruption(type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        switch type {
        case .began:
            interrupted = true
            stopRepeatedVibration()
            activationID = nil
            audioPlayer?.pause()
            if !repeats { stopPlaying() }
        case .ended:
            interrupted = false
            if shouldResume && playbackID != nil {
                activateAndPlay()
            } else if !repeats {
                stopPlaying()
            }
        @unknown default:
            break
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let current = audioPlayer, current === player else { return }
        if !flag { trace("alarm sound did not finish successfully", log: log, category: ConstantsLog.categoryPlaySound, type: .error) }
        stopPlaying()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard let current = audioPlayer, current === player else { return }
        playbackFailed(error ?? CocoaError(.fileReadCorruptFile))
    }

    private func playbackFailed(_ error: Error) {
        trace("could not play alarm sound: %{public}@", log: log, category: ConstantsLog.categoryPlaySound, type: .error, error.localizedDescription)
        stopPlaying()
    }

    deinit {
        cancelVibration?()
        observers.forEach(NotificationCenter.default.removeObserver)
        audioPlayer?.stop()
    }
}
