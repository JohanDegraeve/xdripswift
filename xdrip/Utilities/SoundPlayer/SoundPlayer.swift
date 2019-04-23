import Foundation
import AVFoundation
import AudioToolbox
import os
import Speech

/// to play audio and speak text, overrides mute
class SoundPlayer {
    
    // MARK: - properties
    
    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryPlaySound)

    /// audioplayer
    
    private var audioPlayer:AVAudioPlayer?
    
    // MARK: - initializer
    
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
        } catch let error {
            os_log("in init, could not set AVAudioSession category to playback and mixwithOthers, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
        }
    }

    /// plays the sound, overrides mute
    /// - parameters:
    ///     - soundFileName : name of the file with the sound, the filename must include the extension, eg mp3
    ///     - volume : optional, must be les than 100, fadeDuration 5 is used
    public func playSound(soundFileName:String, withVolume volume:Float?) {
        
        guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "") else {
            os_log("in playSound, could not create url with sound %{public}@", log: self.log, type: .error, soundFileName)
            return
        }
        
        do {
            //try AVAudioSession.sharedInstance().setActive(true)
            
            try audioPlayer = AVAudioPlayer(contentsOf: url)
            
            if let audioPlayer = audioPlayer {
                if var volume = volume {
                    if volume > 100.0 {
                        volume = 100.0
                    }
                    audioPlayer.setVolume(volume, fadeDuration: 30)
                }
                audioPlayer.play()
            } else {
                os_log("in playSound, could not create url with sound %{public}@", log: self.log, type: .error, soundFileName)
            }
        } catch let error {
            os_log("in playSound, exception while trying to play sound %{public}@, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
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
    
    /// will speak the text, doesn't speak if player is playing some other sound
    public func say(text:String, language:String?) {
        if !isPlaying() {
            let syn = AVSpeechSynthesizer.init()
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.51
            utterance.pitchMultiplier = 1
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            syn.speak(utterance)
        }
    }
}
