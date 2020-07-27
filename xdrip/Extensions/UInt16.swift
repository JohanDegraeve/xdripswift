import Foundation
// source https://gist.github.com/bpolania/704901156020944d3e20fef515e73d61

extension UInt16 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt16>.size)
    }
    
    /// example value 320 minutes is 5 hours and 20 minutes, would be converted to 05:20
    func convertMinutesToTimeAsString() -> String {
        return Int(self).convertMinutesToTimeAsString()
    }
    
}
