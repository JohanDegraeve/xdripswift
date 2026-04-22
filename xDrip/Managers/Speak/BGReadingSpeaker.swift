import Foundation
import AVFoundation
import AudioToolbox
import os
import Speech

class BGReadingSpeaker:NSObject {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// audioplayer used by app
    ///
    /// is used to verify if app happens to be playing a sound, in which case new readings shouldn't be spoken
    private var sharedSoundPlayer:SoundPlayer
    
    /// timestamp of last spoken reading, initially set to 1 jan 1970
    private var timeStampLastSpokenReading:Date
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// speech synthesizer object
    /// this must be created here instead of locally in the say() function for it to work correctly in iOS16
    /// https://developer.apple.com/forums/thread/714984
    private let syn = AVSpeechSynthesizer.init()
    
    // MARK: - initializer
    
    /// init is private, to avoid creation
    init(sharedSoundPlayer:SoundPlayer, coreDataManager:CoreDataManager) {
        
        // initialize non optional private properties
        self.sharedSoundPlayer = sharedSoundPlayer
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        // initialize timeStampLastSpokenReading
        timeStampLastSpokenReading = Date(timeIntervalSince1970: 0)
        
        // call super.init
        super.init()
        
        // set languageCode in Texts_SpeakReading to value stored in defaults
        Texts_SpeakReading.setLanguageCode(code: UserDefaults.standard.speakReadingLanguageCode)
        
        // changing speakerLanguage code requires action
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.speakReadingLanguageCode.rawValue, options: .new, context: nil)

    }
    
    // MARK: - public functions
    
    /// will speak the latest reading in the iPhone's language
    ///
    /// conditions:
    ///     - speakReadings is on
    ///     - no other sound is playing (via sharedAudioPlayer)
    ///     - there' s a recent reading less than 4.5 minutes old
    ///     - time since last spoken reading > interval defined by user (UserDefaults.standard.speakInterval)
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect
    public func speakNewReading(lastConnectionStatusChangeTimeStamp: Date) {
        
        // if speak reading not enabled, then no further processing
        if !UserDefaults.standard.speakReadings {
            return
        }
        
        // if app shared soundPlayer is playing, then don't say the text
        if sharedSoundPlayer.isPlaying() {
            return
        }
        
        // get latest reading, ignore sensor, rawdata, timestamp - only 1
        let lastReadings = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)

        // if there's no readings, then no further processing
        if lastReadings.count == 0 {
            return
        }
        
        // if an interval is defined, and if time since last spoken reading is less than interval, then don't speak
        // substract 10 seconds, because user will probably select a multiple of 5, and also readings usually arrive every 5 minutes
        // example user selects 10 minutes interval, next reading will arrive in exactly 10 minutes, time interval to be checked will be 590 seconds
        if Int(Date().timeIntervalSince(timeStampLastSpokenReading)) < (UserDefaults.standard.speakInterval * 60 - 10) {
            return
        }
        
        // check if timeStampLastSpokenReading is at least minimiumTimeBetweenTwoReadingsInMinutes earlier than now (or it's at least minimiumTimeBetweenTwoReadingsInMinutes minutes ago that reading was spoken) - otherwise don't speak the reading
        // exception : there's been a disconnect/reconnect after the last spoken reading
        if (abs(timeStampLastSpokenReading.timeIntervalSince(Date())) < ConstantsSpeakReading.minimiumTimeBetweenTwoReadingsInMinutes * 60.0 && lastConnectionStatusChangeTimeStamp.timeIntervalSince(timeStampLastSpokenReading) < 0) {
            
            return
            
        }
        
        // assign bgReadingToSpeak
        let bgReadingToSpeak = lastReadings[0]
        
        // if reading older dan 4.5 minutes, then no further processing
        if Date().timeIntervalSince(bgReadingToSpeak.timeStamp) > 4.5 * 60 {
            return
        }
        
        // start creating the text that needs to be spoken
        var currentBgReadingOutput = Texts_SpeakReading.currentGlucose
        
        //Glucose
        // create reading value
        var currentBgReadingFormatted = bgReadingToSpeak.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        // copied from Spike
        if !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            currentBgReadingFormatted = assertFractionalDigits(number: currentBgReadingFormatted)
        }
        currentBgReadingFormatted = formatLocaleSpecific(number: currentBgReadingFormatted, languageCode: Texts_SpeakReading.languageCode)
        if (currentBgReadingFormatted == "HIGH") {
            currentBgReadingFormatted = ". " + Texts_SpeakReading.high;
        } else if (currentBgReadingFormatted == "LOW") {
            currentBgReadingFormatted = ". " + Texts_SpeakReading.low;
        }
        currentBgReadingOutput = currentBgReadingOutput + " ,, " + currentBgReadingFormatted + ". ";
        
        // Trend
        // if trend needs to be spoken, then compose trend text
        if UserDefaults.standard.speakTrend {

            //add trend to text (slope)
            currentBgReadingOutput += Texts_SpeakReading.currentTrend + " " + searchTranslationForCurrentTrend(currentTrend: bgReadingToSpeak.slopeName) + ". ";
            
        }
        
        // Delta
        // if delta needs to be spoken then compose delta
        if UserDefaults.standard.speakDelta {
            
            var previousBgReading:BgReading?
            if lastReadings.count > 1 {previousBgReading = lastReadings[1]}
            var currentDelta:String = bgReadingToSpeak.unitizedDeltaString(previousBgReading: previousBgReading, showUnit: false, highGranularity: true, mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
            //Format current delta in case of anomalies
            if currentDelta == "ERR" || currentDelta == "???"{
                currentDelta = Texts_SpeakReading.deltanoncomputable
            }
            
            if (currentDelta == "0.0" || currentDelta == "+0" || currentDelta == "-0") {
                currentDelta = "0"
            }
            
            currentDelta = formatLocaleSpecific(number: currentDelta, languageCode: Texts_SpeakReading.languageCode)
            
            currentBgReadingOutput += Texts_SpeakReading.currentDelta + " " + currentDelta + "."
            
        }
        
        // say the text
        say(text: currentBgReadingOutput, language: Texts_SpeakReading.languageCode)
        
        // set timeStampLastSpokenReading
        timeStampLastSpokenReading = bgReadingToSpeak.timeStamp
        
    }
    
    // MARK: - private functions
    
    /// will speak the text, using language code for pronunciation
    private func say(text:String, language:String?) {
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.51
        utterance.pitchMultiplier = 1
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        syn.speak(utterance)

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
    ///     - languageCode : must be format like en-EN
    private func formatLocaleSpecific(number:String, languageCode:String?) -> String {
        
        let newNumber = number.replacingOccurrences(of: " ", with: "")
        
        if Double(newNumber) != nil, let languageCode = languageCode {
            if languageCode.uppercased().startsWith("DE") {
                return number.replacingOccurrences(of: ".", with: ",")
            }
        }
        
        return number
    }
    
    /// translates currentTrend string to local string
    ///
    /// example if currentTrend = trenddoubledown, then for en-EN, return dramatically downward
    private func searchTranslationForCurrentTrend(currentTrend:String) -> String {
        
        if (currentTrend == "NONE" || currentTrend == "NON COMPUTABLE") {
            return Texts_SpeakReading.trendnoncomputable
        }
        else if (currentTrend == "DoubleDown") {
            return Texts_SpeakReading.trenddoubledown
        }
        else if (currentTrend == "SingleDown") {
            return Texts_SpeakReading.trendsingledown
        }
        else if (currentTrend == "FortyFiveDown") {
            return Texts_SpeakReading.trendfortyfivedown
        }
        else if (currentTrend == "Flat") {
            return Texts_SpeakReading.trendflat
        }
        else if (currentTrend == "FortyFiveUp") {
            return Texts_SpeakReading.trendfortyfiveup
        }
        else if (currentTrend == "SingleUp") {
            return Texts_SpeakReading.trendsingleup
        }
        else if (currentTrend == "DoubleUp") {
            return Texts_SpeakReading.trenddoubleup
        }
        return currentTrend
    }
    
    // MARK:- observe function
    
    /// when user changes Speak Reading language code, action to do
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.speakReadingLanguageCode :
                    
                    // change by user, should not be done within 200 ms
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // UserDefaults.standard.speakReadingLanguageCode shouldn't be nil normally, if it is would be a coding error, however need to check anyway so assign default if nil
                        Texts_SpeakReading.setLanguageCode(code: UserDefaults.standard.speakReadingLanguageCode)
                        
                    }
                    
                default:
                    break
                }
            }
        }
    }
    

}
