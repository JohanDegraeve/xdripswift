import Foundation

extension GlucoseData: Smoothable {
    
    var value: Double {
        get {
            return glucoseLevelRaw
        }
        set {
            glucoseLevelRaw = newValue
        }
    }
    
    
}
