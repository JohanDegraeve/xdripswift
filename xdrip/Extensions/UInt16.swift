import Foundation
// source https://gist.github.com/bpolania/704901156020944d3e20fef515e73d61

extension UInt16 {
    
    /// initializer taking 2 bytes as parameter, first the high byte then the low byte
    init(_ high: UInt8, _ low: UInt8) {
        self = UInt16(high) << 8 + UInt16(low)
    }

    /// init from data[low...high]
    init(_ data: Data) {
        self = UInt16(data[data.startIndex + 1]) << 8 + UInt16(data[data.startIndex])
    }
    
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt16>.size)
    }
    
    /// example value 320 minutes is 5 hours and 20 minutes, would be converted to 05:20
    func convertMinutesToTimeAsString() -> String {
        return Int(self).convertMinutesToTimeAsString()
    }
    
}
