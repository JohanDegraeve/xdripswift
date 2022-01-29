/// supported languages for speak readings - defines name and language code, example "Dutch" and "nl-NL", both are defined in one case, seperated by a backslash
///
/// alphabetically ordered
enum ConstantsSpeakReadingLanguages: String, CaseIterable {
    
    case chinese = "Chinese/zh"
    case dutch = "Dutch/nl"
    case english = "English/en"
    case french = "French/fr"
    case italian = "Italian/it"
    case polish = "Polish/pl-PL"
    case portugese_portugal = "Portuguese/pt"
    case portugese_brasil = "Portuguese (Brazil)/pt-BR"
    case russian = "Russian/ru"
    case slovenian = "Slovenian/sl"
    case spanish_mexico = "Spanish (Mexico)/es-MX"
    case spanish_spain = "Spanish (Spain)/es-ES"
    case turkish = "Turkish/tr-TR"
    
    /// gets all language names and language codes in two arrays
    /// - returns:
    ///     ie part of the case before the / in the first array, part of the case after the / in the second array
    public static var allLanguageNamesAndCodes: (names:[String], codes:[String]) {
        var languageNames = [String]()
        var languageCodes = [String]()
        
        languageloop: for speakReadingLanguage in ConstantsSpeakReadingLanguages.allCases {
            
            // SpeakReadingLanguages defines available languages. Per case there is a string which is the language as shown in the UI and the language code, seperated by backslash
            // get array of indexes, of location of "/"
            let indexOfBackSlash = speakReadingLanguage.rawValue.indexes(of: "/")
            
            // define range to get the language (as shown in UI)
            let languageNameRange = speakReadingLanguage.rawValue.startIndex..<indexOfBackSlash[0]
            
            // now get the language in a string
            let language = String(speakReadingLanguage.rawValue[languageNameRange])
            
            // add the soundName to the returnvalue
            languageNames.append(language)
            
            // define range to get the languagecode
            let languageCodeRange = speakReadingLanguage.rawValue.index(after: indexOfBackSlash[0])..<speakReadingLanguage.rawValue.endIndex
            
            // now get the language in a string
            let languageCode = String(speakReadingLanguage.rawValue[languageCodeRange])
            // add the languageCode to the returnvalue
            
            languageCodes.append(languageCode)
            
        }
        return (languageNames, languageCodes)
    }
    
    /// gets the language name for specific case
    static func languageName(forLanguageCode:String?) -> String {
        
        if let forLanguageCode = forLanguageCode {
            for (index, languageCode) in allLanguageNamesAndCodes.codes.enumerated() {
                if languageCode == forLanguageCode {
                    return allLanguageNamesAndCodes.names[index]
                }
            }
        }
        return Texts_SpeakReading.defaultLanguageCode
    }
    
}
