/// defines name of the Soundfile and name of the sound shown to the user with an extra function - both are defined in one case, seperated by a backslash - to be used for alerts - all these sounds will be shown
enum ConstantsSounds: String, CaseIterable {
    
    // here using case iso properties because we want to iterate through them
    /// name of the sound as shown to the user, and also stored in the alerttype
    case batterwakeup = "Better Wake Up/betterwakeup.mp3"
    case bruteforce = "Brute Force/bruteforce.mp3"
    case modernalarm2 = "Modern Alert 2/modern2.mp3"
    case modernalarm = "Modern Alert/modernalarm.mp3"
    case shorthigh1 = "Short High 1/shorthigh1.mp3"
    case shorthigh2 = "Short High 2/shorthigh2.mp3"
    case shorthigh3 = "Short High 3/shorthigh3.mp3"
    case shorthigh4 = "Short High 4/shorthigh4.mp3"
    case shortlow1  = "Short Low 1/shortlow1.mp3"
    case shortlow2  = "Short Low 2/shortlow2.mp3"
    case shortlow3  = "Short Low 3/shortlow3.mp3"
    case shortlow4  = "Short Low 4/shortlow4.mp3"
    case spaceship = "Space Ship/spaceship.mp3"
    case xdripalert = "xDrip Alert/xdripalert.aif"
    
    /// gets all sound names in array, ie part of the case before the /
    static func allSoundsBySoundNameAndFileName() -> (soundNames:[String], fileNames:[String]) {
        var soundNames = [String]()
        var soundFileNames = [String]()
        
        soundloop: for sound in ConstantsSounds.allCases {
            
            // ConstantsSounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash
            // get array of indexes, of location of "/"
            let indexOfBackSlash = sound.rawValue.indexes(of: "/")
            
            // define range to get the soundname (as shown in UI)
            let soundNameRange = sound.rawValue.startIndex..<indexOfBackSlash[0]
            
            // now get the soundName in a string
            let soundName = String(sound.rawValue[soundNameRange])
            
            // add the soundName to the returnvalue
            soundNames.append(soundName)
            
            // define range to get the soundFileName
            let languageCodeRange = sound.rawValue.index(after: indexOfBackSlash[0])..<sound.rawValue.endIndex
            
            // now get the language in a string
            let fileName = String(sound.rawValue[languageCodeRange])
            // add the languageCode to the returnvalue
            
            soundFileNames.append(fileName)
            
        }
        return (soundNames, soundFileNames)
    }
    
    /// gets the soundname for specific case
    static func getSoundName(forSound:ConstantsSounds) -> String {
        let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
        let soundNameRange = forSound.rawValue.startIndex..<indexOfBackSlash[0]
        return String(forSound.rawValue[soundNameRange])
    }
    
    /// gets the soundFie for specific case
    static func getSoundFile(forSound:ConstantsSounds) -> String {
        let indexOfBackSlash = forSound.rawValue.indexes(of: "/")
        let soundNameRange = forSound.rawValue.index(after: indexOfBackSlash[0])..<forSound.rawValue.endIndex
        return String(forSound.rawValue[soundNameRange])
    }
}
