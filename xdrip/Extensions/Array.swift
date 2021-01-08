import Foundation
import CoreML

extension Array where Element: GlucoseData {
    
    /// - GlucoseData array has values with glucoseLevelRaw = 0.0 - this function will do extrapolation of prevous and next non 0 values to estimate/fill up 0 values
    /// - if first or last elements in the array have value 0.0, then these will not be filled
    /// - parameters:
    ///     - maxGapWidth :if there' s more consecutive elements with value 0.0, then no filling will be applied
    ///
    /// - Example:
    /// - values before filling gaps
    /// - value 0 : 76235,2883999999
    /// - value 1 : 0
    /// - value 2 : 79058,8176
    /// - value 3 : 0
    /// - value 4 : 80352,9351499999
    /// - value 5 : 0
    /// - value 6 : 82117,6409
    /// - value 7 : 83764,6995999999
    /// - values after filling gaps
    /// - value 0 : 76235,2883999999
    /// - value 1 : 77647,0529999999
    /// - value 2 : 79058,8176
    /// - value 3 : 79705,8763749999
    /// - value 4 : 80352,9351499999
    /// - value 5 : 81235,2880249999
    /// - value 6 : 82117,6409
    /// - value 7 : 83764,6995999999
    func fill0Gaps(maxGapWidth :Int) {
        
        // need to find a first non 0 value
        var previousNon0Value: Double?

        var nextNon0ValueIndex: Int?

        mainloop: for (var index, value) in self.enumerated() {

            // in case a 1 ormore values were already filled, no further processing needed, skip them
            if let nextNon0ValueIndex = nextNon0ValueIndex {
                if index < nextNon0ValueIndex {continue}
            }
            
            if previousNon0Value == nil {
                if value.glucoseLevelRaw == 0.0 {
                    continue
                } else {
                    previousNon0Value = value.glucoseLevelRaw
                }
            }
            
            if value.glucoseLevelRaw == 0.0 && index < self.count - 1 {
                
                nextNon0ValueIndex = nil
                
                // find next non 0 value
                findnextnon0value: for index2 in (index + 1)..<self.count {
                    
                    if self[index2].glucoseLevelRaw != 0.0 {
                        
                        // found a value which is not 0
                        nextNon0ValueIndex = index2
                        
                        break findnextnon0value
                        
                    }
                    
                }
                
                if nextNon0ValueIndex != nil, let nextNon0ValueIndex = nextNon0ValueIndex {
                    
                    // found a non 0 value, let's see if the gap is within maxGapWidth
                    // unwrap firstnon0Value, it must be non 0
                    if nextNon0ValueIndex - index <= maxGapWidth, let firstnon0Value = previousNon0Value {
                        
                        // fill up 0 values, increase each value increaseValueWith
                        let increaseValueWith = (self[nextNon0ValueIndex].glucoseLevelRaw - firstnon0Value) / Double((nextNon0ValueIndex - (index - 1)))
                        
                        if index < nextNon0ValueIndex {

                            for index3 in (index)..<nextNon0ValueIndex {
                                
                                let slope = Double(index3 - (index - 1))
                                
                                self[index3].glucoseLevelRaw = firstnon0Value + increaseValueWith * slope
                                
                            }

                        }
                        
                        
                    } else {
                        
                        // we will not fill up the gap with 0 values, continue main loop with index value set to nextNon0ValueIndex
                        index = nextNon0ValueIndex
                    }
                    
                    // assign firstnon0Value to next originally non 0 value
                    previousNon0Value = self[nextNon0ValueIndex].glucoseLevelRaw
                    
                } else {
                    // did not find a next non 0 value, we're done
                    break mainloop
                }
                
            } else {
                
                // value.glucoseLevelRaw != 0.0 or index = self.count - 1
                // in the first case, we need to assign firstnon0Value to the last 0 nil value found
                // in the second case it will not be used anymore but we can assign it anyway
                previousNon0Value = value.glucoseLevelRaw
                
            }
            
        }
        
    }
  
}

extension Array where Element: BgReading {
    
    /// - Filter out readings that are too close to each other
    /// - BgReadings array must be sorted by timeStamp of the BgReading, ascending, ie youngest first
    /// - parameters:
    ///     - minimumTimeBetweenTwoReadingsInMinutes : filter out readings that are to close to each other in time, minimum difference in time between two readings = minimumTimeBetweenTwoReadingsInMinutes
    ///     - lastConnectionStatusChangeTimeStamp : lastConnectionStatusChangeTimeStamp > timeStampLastProcessedBgReading then the first connection will be returned, even if it's less than minimumTimeBetweenTwoReadingsInMinutes away from timeStampLastProcessedBgReading
    ///     - timeStampLastProcessedBgReading : only readings younger than timeStampLastProcessedBgReading will be returned, if nil then this check is not done
    /// - returns
    ///     filtered array, with readings at least minimumTimeBetweenTwoReadingsInMinutes away from each other
    func filter(minimumTimeBetweenTwoReadingsInMinutes: Double, lastConnectionStatusChangeTimeStamp: Date?, timeStampLastProcessedBgReading: Date?) -> [BgReading] {

        var didCheckLastConnectionStatusChangeTimeStamp = false
        
        var timeStampLatestCheckedReading = timeStampLastProcessedBgReading
        
        // create a copy of self, reversed, because the filter algorithm assumes the first is the oldest element, while self is order by youngest first
        var arrayReversed = Array(self.reversed())
        
        // do the required filtering
        arrayReversed =  arrayReversed.filter({
            
            if let lastConnectionStatusChangeTimeStamp = lastConnectionStatusChangeTimeStamp, let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading,  !didCheckLastConnectionStatusChangeTimeStamp {

                // if there was a disconnect or reconnect after the latest processed reading, and $0.timestamp (ie reading being processed) is after lastConnectionStatusChangeTimeStamp then add the reading
                if lastConnectionStatusChangeTimeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > 0.0 && lastConnectionStatusChangeTimeStamp.timeIntervalSince($0.timeStamp) < 0.0 {
                    
                    timeStampLatestCheckedReading = $0.timeStamp

                    didCheckLastConnectionStatusChangeTimeStamp = true

                    return true
                    
                }
                
            }
            
            var returnValue = true
            if let timeStampLatestCheckedReading = timeStampLatestCheckedReading {

                returnValue = $0.timeStamp.timeIntervalSince(timeStampLatestCheckedReading) > minimumTimeBetweenTwoReadingsInMinutes * 60.0

            }

            if returnValue {
                timeStampLatestCheckedReading = $0.timeStamp
            }

            return returnValue
            
        })
        
        return Array(arrayReversed.reversed())

    }

}

extension Array where Element: GlucoseData {
    
    /// returns true if the first howManyToCheck values in the  arrays have equal glucoseLevelRaw
    func hasEqualValues(howManyToCheck: Int, otherArray: [Double]) -> Bool {
        
        // check for the value 0 up to howManyToCheck - 1
        for index in 0..<howManyToCheck {
            
            // if one of the two arrays is shorter than the index, then we can't compare the values, would cause an exception
            if self.count < index + 1 || otherArray.count < index + 1 {
                
                // at least one of the two arrays is too short to compare up to howManyToCheck values
                // if at least one of them is large enough then it means one of the arrays is longer, means not equal
                if self.count >= index + 1 || otherArray.count >= index + 1  {
                    return false
                } else {
                    // two arrays fully processed and we got here means equal values
                    return true
                }
                
            }
            
            // found non matching value
            if self[index].glucoseLevelRaw != otherArray[index] {return false}
            
        }
        
        // we got here, means equal values
        return true
        
    }
    
}

extension Array where Element == Int {
    
    /// returns true if the first howManyToCheck values in the  arrays have equal values
    func hasEqualValues(howManyToCheck: Int, otherArray: [Int]) -> Bool {
        
        // check for the value 0 up to howManyToCheck - 1
        for index in 0..<howManyToCheck {
            
            // if one of the two arrays is shorter than the index, then we can't compare the values, would cause an exception
            if self.count < index + 1 || otherArray.count < index + 1 {
                
                // at least one of the two arrays is too short to compare up to howManyToCheck values
                // if at least one of them is large enough then it means one of the arrays is longer, means not equal
                if self.count >= index + 1 || otherArray.count >= index + 1  {
                    return false
                } else {
                    // two arrays fully processed and we got here means equal values
                    return true
                }
                
            }
            
            // found non matching value
            if self[index] != otherArray[index] {return false}
            
        }
        
        // we got here, means equal values
        return true
        
    }
    
}

