import Foundation

extension Int {
    /// example value 320 minutes is 5 hours and 20 minutes, would be converted to 05:20
    /// this is then returned as a time string as per the user's locale and region
    /// Example return: "17:48" (spain locale)
    /// Example return: "5:48 pm" (us locale)
    func convertMinutesToTimeAsString() -> String {
        
        let hours = (self / 60)
        let minutes = self - hours * 60

        // create calendar object
        let calendar = Calendar.current
        
        // create a date based upon today's date (it could be any date as we will ignore it later) and set the hours and minutes
        let date = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: Date())

        let dateFormatter = DateFormatter()
        
        dateFormatter.amSymbol = ConstantsUI.timeFormatAM
        
        dateFormatter.pmSymbol = ConstantsUI.timeFormatPM
        
        dateFormatter.setLocalizedDateFormatFromTemplate("jj:mm")

        return dateFormatter.string(from: date!)
        
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
