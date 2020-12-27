import Foundation

extension Array where Element: GlucoseData {
    
    /// - as it sometimes happens that an expired Libre sensor continues to give always the same value
    /// - a check is done, as soon as a value stays the same, all next readings will not be added anymore
    /// - parameters:
    ///     - for : glucosedata to check
    /// - returns:
    ///     - new array, as soon as value is found equal to it's previous value (in time), then this and all next values are removed
    func checkFlatValues () -> [GlucoseData] {
        
        return check(glucoseData: self)
        
    }
    
    
}

fileprivate func check(glucoseData:  [GlucoseData]) -> [GlucoseData] {
    
    // value to keep track of last value
    var lastValue: Double?
    
    // as soon as two identical values are reached stop processing next values
    var stopProcessing = false
    
    // reverse the array, start with the oldest reading
    var glucoseData = glucoseData
    glucoseData.reverse()
    
    // filter, as soon as one value reached identical to the older value then stop adding
    glucoseData = glucoseData.filter({
        if stopProcessing {return false} //
        if lastValue != nil {
            if $0.glucoseLevelRaw == lastValue! {
                stopProcessing = true
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
