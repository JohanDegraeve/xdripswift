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
    /// - BgReadings array must be sorted by timeStamp of the BgReading, ascending, ie most recent reading is at index 0
    /// - parameters:
    ///     - minimumTimeBetweenTwoReadingsInMinutes : filter out readings that are to close to each other in time, minimum difference in time between two readings = minimumTimeBetweenTwoReadingsInMinutes
    ///     - timeStampLastProcessedBgReading : only readings younger than timeStampLastProcessedBgReading will be returned, if nil then this check is not done
    ///     - lastConnectionStatusChangeTimeStamp : if lastConnectionStatusChangeTimeStamp > timeStampLastProcessedBgReading then the most recent reading will be returned, even if it's less than minimumTimeBetweenTwoReadingsInMinutes away from timeStampLastProcessedBgReading
    /// - returns
    ///     filtered array, with readings at least minimumTimeBetweenTwoReadingsInMinutes away from each other
    func filter(minimumTimeBetweenTwoReadingsInMinutes: Double, lastConnectionStatusChangeTimeStamp: Date?, timeStampLastProcessedBgReading: Date?) -> [BgReading] {
        
        // initialise returnValue with empty array
        var returnValue = [BgReading]()
        
        // if most recent reading is either the minimum time away from the last processed reading or if there's been a disconnect after the last processed reading then add the most recent reading
        // but first let's see if there's at least one reading
        if let first = self.first {
            
            if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading {

                if first.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {
                    
                    // most recent reading is more than minimumTimeBetweenTwoReadingsInMinutes later than last processed reading, so let's add it
                    returnValue.append(first)
                    
                } else {
                    
                    // most recent reading is less than minimumTimeBetweenTwoReadingsInMinutes later than last processed reading, but maybe there's been a disconnect/reconnect since the last processed reading
                    if let lastConnectionStatusChangeTimeStamp = lastConnectionStatusChangeTimeStamp {
                        if lastConnectionStatusChangeTimeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > 0 {

                            // there's been a disconnect/reconnect since the last processed reading
                            // add the most recent reading
                            returnValue.append(first)
                            
                        }
                        
                    }
                    
                }

            } else {
                
                // timeStampLastProcessedBgReading is nil, so this is the first reading being processed ever, let's add it
                returnValue.append(first)
                
            }

        }
        
        // now let's see if first was added, and also if there's more readings to add
        if returnValue.count > 0 {
            
            // there's one reading in returnValue, it's the most recent reading in the original array
            
            var timeStampLastAddedReading = returnValue[0].timeStamp
            
            // iterate through the remaining readings
            for reading in self {
                
                // by checking id , we skip the first in self, because that one is already added
                if reading.id != returnValue[0].id {
                    
                    // if the reading is earler than timeStampLastProcessedBgReading then no further processing needed, this reading and also the following readings are older readings, older than timeStampLastProcessedBgReading
                    if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading {

                        if reading.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) < 0 {
                            
                            break
                            
                        }

                    }

                    // add the reading if
                    //      - the reading is more than minimumTimeBetweenTwoReadingsInMinutes earlier than the last added reading
                    //  and
                    //      - the gap between last added reading and timeStampLastProcessedBgReading more than minimumTimeBetweenTwoReadingsInMinutes (otherwise we may be adding a reading in between last processed reading and last added reading even though these two are alrady less than minimumTimeBetweenTwoReadingsInMinutes minutes away from each other
                    if reading.timeStamp.timeIntervalSince(timeStampLastAddedReading) < -minimumTimeBetweenTwoReadingsInMinutes * 60.0 && abs(timeStampLastAddedReading.timeIntervalSince(timeStampLastProcessedBgReading != nil ? timeStampLastProcessedBgReading! : Date(timeIntervalSince1970: 0))) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {
                        
                        returnValue.append(reading)
                        
                        timeStampLastAddedReading = reading.timeStamp
                        
                    }
                    
                }
                
            }
            
        }
        
        return returnValue

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

