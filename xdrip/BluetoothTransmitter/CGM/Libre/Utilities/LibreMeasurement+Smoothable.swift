import Foundation

extension LibreMeasurement: Smoothable {
    
    var value: Double {
        get {
            return temperatureAlgorithmGlucose
        }
        set {
            temperatureAlgorithmGlucose = newValue
        }
    }
    
    
}
