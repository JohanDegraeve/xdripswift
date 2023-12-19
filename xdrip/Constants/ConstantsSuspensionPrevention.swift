/// suspension prevention
enum ConstantsSuspensionPrevention {
    
    /// name of the file that has the sound to play
    static let soundFileName = "1-millisecond-of-silence.caf"//20ms-of-silence.caf"
    
    /// how often to play the sound, in seconds, for the normal keep-alive mode
    static let intervalNormal = 5
    
    /// how often to play the sound, in seconds, for the aggressive keep-alive mode
    static let intervalAggressive = 2
}


