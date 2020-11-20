import Foundation

extension Double: Smoothable {
    
    var value: Double {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
}
