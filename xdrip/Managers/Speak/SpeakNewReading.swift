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
        
        // if speak reading not enabled, then no further processing
        if !UserDefaults.standard.speakReadings {
            return
        }
        
        // get latest reading, ignore sensor, rawdata, timestamp - only 1
        let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        // if there's no readings, then no further processing
        if lastReadings.count == 0 {
            return
        }
        
        // assign bgReadingToSpeak
        let bgReadingToSpeak = lastReadings[0]
        
        // if reading older dan 4.5 minutes, then no further processing
        if Date().timeIntervalSince(bgReadingToSpeak.timeStamp) > 4.5 * 60 {
            return
        }
        
        // start creating the text that needs to be spoken
        /*var currentBgReadingFormatted = bgReadingToSpeak.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        if (currentBgReadingFormatted == "HIGH") {
            currentBgReadingFormatted = ". " + ModelLocator.resourceManagerInstance.getString('texttospeech','high');
        } else if (currentBgReadingFormatted == "LOW") {
            currentBgReadingFormatted = ". " + ModelLocator.resourceManagerInstance.getString('texttospeech','low');
        }*/
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

    /// copied from Spike -
    /// if number is a Double value, and if it has no "." then a "." is added - otherwise returns number
    private func assertFractionalDigits(number:String) -> String {
        
        let newNumber = number.replacingOccurrences(of: " ", with: "")
        
        if Double(newNumber) != nil {
            if !number.contains(find: ".") {
               return number + ".0"
            }
        }
        
        return number
        
    }
    
    /// copied from Spike
    /// - parameters:
    ///     - languageCode : must be format oike en-EN
    private func formatLocaleSpecific(number:String, languageCode:String) -> String {
        
        let newNumber = number.replacingOccurrences(of: " ", with: "")
        
        if Double(newNumber) != nil {
            if languageCode.uppercased() == "DE-DE" {
                return number.replacingOccurrences(of: ".", with: ",")
            }
        }
        
        return number
    }
}
