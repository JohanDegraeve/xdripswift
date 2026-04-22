import Foundation

/// all texts for Quick Actions
class Texts_QuickActions {
    static private let filename = "QuickActions"
    
    static let speakReadings: String = {
        return NSLocalizedString("quickactions_speak_readings", tableName: filename, bundle: Bundle.main, value: "Speak readings", comment: "Home screen quick action, turns speaking on, available when speaking is off")
    }()
    
    static let stopSpeakingReadings: String = {
        return NSLocalizedString("quickactions_stop_speaking_readings", tableName: filename, bundle: Bundle.main, value: "Stop speaking readings", comment: "Home screen quick action, turns speaking off, available when speaking is on")
    }()
}
