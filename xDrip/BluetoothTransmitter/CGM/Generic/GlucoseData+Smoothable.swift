import Foundation

extension GlucoseData: SavitzkyGolaySmoothable {
    
    var value: Double {
        get {
            return glucoseLevelRaw
        }
        set {
            glucoseLevelRaw = newValue
        }
    }
    
    
}
