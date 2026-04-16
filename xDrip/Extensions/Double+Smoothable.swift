import Foundation

extension Double: SavitzkyGolaySmoothable {
    
    var value: Double {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
}
