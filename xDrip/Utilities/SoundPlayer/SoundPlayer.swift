import Foundation
import AVFoundation
import AudioToolbox
import os
import Speech

/// to play audio and speak text, overrides mute
class SoundPlayer {
    
    // MARK: - properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryPlaySound)

    /// audioplayer
    private var audioPlayer:AVAudioPlayer?

    /// Serialize audio-route negotiation away from the UI thread.
    private static let activationQueue = DispatchQueue(label: "SoundPlayer.audioSessionActivation")

    /// A stopped or superseded request must not start after activation completes.
    private var pendingPlaybackID: UUID?
    
    // MARK: - initializer
    
    /// plays the sound, overrides mute
    /// - parameters:
    ///     - soundFileName : name of the file with the sound, the filename must include the extension, eg mp3
    public func playSound(soundFileName:String) {
        
        guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "") else {
            trace("in playSound, could not create url with sound %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, soundFileName)
            return
        }
        
        let playbackID = UUID()
        pendingPlaybackID = playbackID
        let log = log
        Self.activationQueue.async { [weak self] in
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: .mixWithOthers)
                try session.setActive(true)
            } catch {
                trace("in playSound, could not set AVAudioSession category to playback and mixwithOthers, error = %{public}@", log: log, category: ConstantsLog.categoryPlaySound, type: .error, error.localizedDescription)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.pendingPlaybackID == playbackID else { return }
                self.pendingPlaybackID = nil
                self.startPlayback(url: url, soundFileName: soundFileName)
            }
        }
    }

    private func startPlayback(url: URL, soundFileName: String) {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: url)
            
            if let audioPlayer = audioPlayer {
                audioPlayer.play()
            } else {
                trace("in playSound, could not create url with sound %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, soundFileName)
            }
        } catch let error {
            trace("in playSound, exception while trying to play sound %{public}@, error = %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, error.localizedDescription)
        }
    }
    
    /// is the PlaySound playing or not
    public func isPlaying() -> Bool {
        if pendingPlaybackID != nil { return true }
        if let audioPlayer = audioPlayer {
            return audioPlayer.isPlaying
        }
        return false
    }
    
    /// if playSound is playing, then stop
    public func stopPlaying() {
        pendingPlaybackID = nil
        if isPlaying() {
            if let audioPlayer = audioPlayer {
                audioPlayer.stop()
            }
        }
    }
    
}
