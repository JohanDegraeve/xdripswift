import Foundation

extension Array where Element: GlucoseData {
    
    /// - as it sometimes happens that an expired Libre sensor continues to give always the same value
    /// - a check is done, if two consecutive values are equal, then add only the first but ignore the next, equal value(s)
    /// - returns:
    ///     - new array
    func checkFlatValues () -> [GlucoseData] {
        
        return check(glucoseData: self)
        
    }
    
    
}

fileprivate func check(glucoseData:  [GlucoseData]) -> [GlucoseData] {
    
    // value to keep track of last value
    var lastValue: Double?
    
    // reverse the array, start with the oldest reading
    var glucoseData = glucoseData
    glucoseData.reverse()
    
    // filter
    glucoseData = glucoseData.filter({
        
        if lastValue != nil {
            if $0.glucoseLevelRaw == lastValue! {
                return false
            }
        }
        lastValue = $0.glucoseLevelRaw
        return true
    })
    
    // reverse back, so the first is the most recent
    glucoseData.reverse()
    
    return glucoseData
    
}
