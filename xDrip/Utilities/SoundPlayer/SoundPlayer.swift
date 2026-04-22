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
    
    // MARK: - initializer
    
    /// plays the sound, overrides mute
    /// - parameters:
    ///     - soundFileName : name of the file with the sound, the filename must include the extension, eg mp3
    public func playSound(soundFileName:String) {
        
        guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "") else {
            trace("in playSound, could not create url with sound %{public}@", log: self.log, category: ConstantsLog.categoryPlaySound, type: .error, soundFileName)
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
