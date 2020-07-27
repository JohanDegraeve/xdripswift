import Foundation

extension Int16 {
    
    /// example value 320 minutes is 5 hours and 20 minutes, would be converted to 05:20
    func convertMinutesToTimeAsString() -> String {
        return Int(self).convertMinutesToTimeAsString()
    }
    
}

