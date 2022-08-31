import Foundation

/// language for texts for speakReading can be selected by user.
///
/// while other Texts enum's (eg TextsCommon.swift) will always use the language as defined in the iOS settings, Texts_SpeakReading can use another language. This is because when speaking the language, also the language specific pronunciation is used. If for example the device would be set to Thai, and assume there's no translation files for Thai. Then the English texts would be used but they would be pronounced with a Thai pronunciation.
///
/// Therefore the languageCode must be set, which will pick the correct texts and also this same languageCode can be used when creating AVSpeechSynthesisVoice. The languageCode assigned must be one for which a corresponding strings directory exists (ending on .proj), otherwise English will be used
enum Texts_SpeakReading {
    
    // MARK: - private properties
    
    private static let filename = "SpeakReading"

    /// the language for speak reading texts, default en
    ///
    /// Must be a valid language code, example "en-EN" or "en-US" but also "en" is allowed - should be a language code that exists in ConstantsSpeakReadingLanguages - and the corresponding strings file must exist. Example there's only "en" for the moment, not en-GB or en-US
    ///
    /// if there's no folder languageCode.lproj (example fr.lproj if languageCode would be assigned to "fr") then the default language will be used ie en
    private(set) static var languageCode = defaultLanguageCode
    
    /// name of currently selected language, should be matching value currently stored in user defaults - it can be used for performance reasons, to avoid that when needed the whole enum in ConstantsSpeakReadingLanguages needs to be iterated through each time again
    private(set) static var languageName = ConstantsSpeakReadingLanguages.languageName(forLanguageCode: languageCode)

    /// bundle to use, will be reassigned if user changes language for speak reading texts
    private static var bundle = Bundle(path: Bundle.main.path(forResource: defaultLanguageCode, ofType: "lproj")!)
    
    // MARK: - public properties

    /// default language code, value en
    public static let defaultLanguageCode = "en"
    
    // MARK: - public functions
    
    /// set the language for speak reading texts, default en
    ///
    /// Must be a valid language code, example "en-EN" or "en-US" but also "en" is allowed - should be a language code that exists in ConstantsSpeakReadingLanguages - and the corresponding strings file must exist. Example there's only "en" for the moment
    ///
    /// if there's no folder languageCode.lproj (example fr.lproj if languageCode would be assigned to "fr") then the default language will be used ie en
public static func setLanguageCode(code:String?) {

        // if code not nil, then newValue will be the code, otherwise newValue will be default languagecode
        languageCode = defaultLanguageCode
        if let code = code {languageCode = code}
        
        //try to assign path first with the full languagecode
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            bundle = Bundle(path: path)
        } else {
            // full languageCode doesn't work, try now to split by - and use the first part only
            // should never be in this branch if ConstantsSpeakReadingLanguages is aligned with actual .lproj folders
            if languageCode.contains(find: "-") {
                let indexOfHyphen = languageCode.indexes(of: "-")
                let languageRange =  languageCode.startIndex..<indexOfHyphen[0]
                let language = String(languageCode[languageRange])
                if let path = Bundle.main.path(forResource: language, ofType: "lproj") {
                    bundle = Bundle(path: path)
                }
                languageCode = language
            } else {
                // assigning default language code and bundle
                languageCode = defaultLanguageCode
                bundle = Bundle(path: Bundle.main.path(forResource: defaultLanguageCode, ofType: "lproj")!)
            }
        }
    
    // set languageName
    languageName = ConstantsSpeakReadingLanguages.languageName(forLanguageCode: languageCode)

    }
    
    // MARK: - texts
    
    static var high:String {
        get {
            return NSLocalizedString("high", tableName: filename, bundle: bundle!, value: "high", comment: "the word high")
        }
    }
    
    static var low:String {
        get {
            return NSLocalizedString("low", tableName: filename, bundle: bundle!, value: "low", comment: "the word low")
        }
    }
    
    static var currentGlucose:String {
        get {
            return NSLocalizedString("currentglucose", tableName: filename, bundle: bundle!, value: "Your current blood glucose is", comment: "For speak reading functionality")
        }
    }
    
    static var currentTrend:String {
        get {
            return NSLocalizedString("currenttrend", tableName: filename, bundle: bundle!, value: "It's trending", comment: "For speak reading functionality")
        }
    }
    
    static var currentDelta:String {
        get {
            return NSLocalizedString("currentdelta", tableName: filename, bundle: bundle!, value: "It's trending", comment: "For speak reading functionality")
        }
    }
    
    static var trendnoncomputable:String {
        get {
            return NSLocalizedString("trendnoncomputable", tableName: filename, bundle: bundle!, value: "non computable", comment: "For speak reading functionality")
        }
    }
    
    static var deltanoncomputable:String {
        get {
            return NSLocalizedString("deltanoncomputable", tableName: filename, bundle: bundle!, value: "non computable", comment: "For speak reading functionality")
        }
    }
    
    static var trenddoubledown:String {
        get {
            return NSLocalizedString("trenddoubledown", tableName: filename, bundle: bundle!, value: "dramatically downward", comment: "For speak reading functionality")
        }
    }
    
    static var trendsingledown:String {
        get {
            return NSLocalizedString("trendsingledown", tableName: filename, bundle: bundle!, value: "significantly downward", comment: "For speak reading functionality")
        }
    }
    
    static var trendfortyfivedown:String {
        get {
            return NSLocalizedString("trendfortyfivedown", tableName: filename, bundle: bundle!, value: "down", comment: "For speak reading functionality")
        }
    }
    
    static var trendflat:String {
        get {
            return NSLocalizedString("trendflat", tableName: filename, bundle: bundle!, value: "flat", comment: "For speak reading functionality")
        }
    }
    
    static var trendfortyfiveup:String {
        get {
            return NSLocalizedString("trendfortyfiveup", tableName: filename, bundle: bundle!, value: "up", comment: "For speak reading functionality")
        }
    }
    
    static var trendsingleup:String {
        get {
            return NSLocalizedString("trendsingleup", tableName: filename, bundle: bundle!, value: "significantly upward", comment: "For speak reading functionality")
        }
    }
    
    static var trenddoubleup:String {
        get {
            return NSLocalizedString("trenddoubleup", tableName: filename, bundle: bundle!, value: "dramatically upward", comment: "For speak reading functionality")
        }
    }

}
