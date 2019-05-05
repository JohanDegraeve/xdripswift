import UIKit

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
}
