import Foundation

extension Int {
    /// example value 320 minutes is 5 hours and 20 minutes, would be converted to 05:20
    func convertMinutesToTimeAsString() -> String {
        let hours = (self / 60)
        let minutes = self - hours * 60 
        
        var hoursAsString = String(describing: hours)
        var minutesAsString = String(describing: minutes)
        
        if hoursAsString.count == 1 {hoursAsString = "0" + hoursAsString}
        if minutesAsString.count == 1 {minutesAsString = "0" + minutesAsString}
        
        return hoursAsString + ":" + minutesAsString
    }
    
    /// converts Int to array of UInt8 - (probably only works for positive values <= 2147483647 ?)
    ///
    /// can be converted back
    func toByteArray() -> [UInt8] {
        let intSizeInBytes = Int.bitWidth/UInt8.bitWidth
        var result:[UInt8] = Array()
        var _number:Int = self
        let masks_8Bits = 0xFF
        for _ in (0..<intSizeInBytes).reversed() {
            result.append(UInt8(_number & masks_8Bits))
            _number >>= 8
        }
        return result
    }
    
    /// Int to Data - (probably only works for positive values <= 2147483647 ?)
    func toData() -> Data {
        return Data(toByteArray())
    }
}
