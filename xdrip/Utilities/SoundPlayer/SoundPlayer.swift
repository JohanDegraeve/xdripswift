import Foundation
import AVFoundation
import AudioToolbox
import os
import Speech

/// to play audio and speak text, overrides mute
class SoundPlayer: NSObject {
    
    // MARK: - properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryPlaySound)

    /// audioplayer
    private var audioPlayer:AVAudioPlayer?

    /// list of audio files to play after each other
    private var playingQueue = [String]()
    
    // MARK: - initializer
    
    /// plays the sound, overrides mute
    /// - parameters:
    ///     - soundFileName : name of the file with the sound, the filename must include the extension, eg mp3
    public func playSound(soundFileName:String) {
        playSound(soundFileNames: [soundFileName])
    }

    /// plays the sounds sequentially, overrides mute
    /// - parameters:
    ///     - soundFileNames : names of the files with the sound, the filenames must include the extension, eg mp3
    public func playSound(soundFileNames: [String]) {
        // Add the requested files to be played
        playingQueue += soundFileNames

        // If the player is not already playing, play the first file
        if !isPlaying() {
            dequeueFileIfAny()
        }
    }

    /// Play the first file in the queue, if any
    private func dequeueFileIfAny() {
        // Exit early if there's nothing to do.
        // This is expected as we call this in `audioPlayerDidFinishPlaying` to play the next sound in queue
        if playingQueue.isEmpty {
            return
        }

        // First in, first out of the queue
        let soundFileName = playingQueue.removeFirst()
        
        guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "") else {
            trace("in SoundPlayer, could not create url with sound %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, soundFileName)
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            trace("in playSound, could not set AVAudioSession category to playback and mixwithOthers, error = %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, error.localizedDescription)
        }
        
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: url)

            // Set delegate to get callback when the audio finished playing
            audioPlayer?.delegate = self
            
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
        if let audioPlayer = audioPlayer {
            return audioPlayer.isPlaying
        }
        return false
    }
    
    /// if playSound is playing, then stop
    public func stopPlaying() {
        if isPlaying() {
            if let audioPlayer = audioPlayer {
                audioPlayer.stop()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension SoundPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Play next in the queue. This enables adding a bunch of files to be played after each other.
        dequeueFileIfAny()
    }
}
