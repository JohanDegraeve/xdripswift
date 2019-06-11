import Foundation
import AVFoundation
import AudioToolbox
import os
import Speech

class SpeakNewReading {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// audioplayer used by app
    ///
    /// is used to verify if app happens to be playing a sound, in which case new readings shouldn't be spoken
    private var sharedAudioPlayer:AVAudioPlayer
    
    // MARK: - initializer
    
    /// init is private, to avoid creation
    init(sharedAudioPlayer:AVAudioPlayer, coreDataManager:CoreDataManager) {
        
        // initialize non optional private properties
        self.sharedAudioPlayer = sharedAudioPlayer
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
    }
    
    // MARK: - public functions
    
    public func speakNewReading() {
        
        // get latest reading, ignore sensor, rawdata, timestamp - only 1
        let bgReadingsToSpeak = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        
    }
    
    // MARK: - private functions
    
    /// will speak the text, only if sharedAudioPlayer is not playing
    private func say(text:String, language:String?) {
        
        if (!sharedAudioPlayer.isPlaying) {
            let syn = AVSpeechSynthesizer.init()
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.51
            utterance.pitchMultiplier = 1
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            syn.speak(utterance)
        }
    }

}
