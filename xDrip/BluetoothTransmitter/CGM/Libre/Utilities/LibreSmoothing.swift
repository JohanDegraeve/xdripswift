import Foundation

class LibreSmoothing {
    
    // MARK: - public functions
    
    /// - smooths trend array of GlucoseData, ie per minute values using SavitzkyGolayQuaDratic filter
    /// - first per minute SavitzkyGolayQuaDratic
    /// - then per 5 minutes : using values of 5 minutes before , 10 minutes before, 5 minutes after and 10 minutes after, ... the number of values taken into account depends on the filterWidth
    /// - no smoothing will be applied if any of the values is 0
    public static func smooth(trend: inout [GlucoseData], repeatPerMinuteSmoothingSavitzkyGolay: Int, filterWidthPerMinuteValuesSavitzkyGolay: Int, filterWidthPer5MinuteValuesSavitzkyGolay: Int, repeatPer5MinuteSmoothingSavitzkyGolay:Int) {
        
        // do not apply smoothing if any of the values in trend is 0
        for trendValue in trend {
            
            if trendValue.glucoseLevelRaw == 0 {
                
                return
                
            }
            
        }
        
        // smooth the trend values, filterWidth 5, 2 iterations
        for _ in 1...repeatPerMinuteSmoothingSavitzkyGolay {
            
            trend.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidthPerMinuteValuesSavitzkyGolay)
            
        }
        
        // now smooth per 5 minutes
        LibreSmoothing.smoothPer5Minutes(trend: trend, withFilterWidth: filterWidthPer5MinuteValuesSavitzkyGolay, iterations: repeatPer5MinuteSmoothingSavitzkyGolay)
        
    }
    
    /// - smooths history array of GlucoseData, ie per 15 minute values using SavitzkyGolayQuaDratic filter
    public static func smooth(history: inout [GlucoseData], filterWidthPer5MinuteSmoothingSavitzkyGolay: Int) {
        
        history.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidthPer5MinuteSmoothingSavitzkyGolay)
        
    }
    
    // MARK: - private functions

    /// - smooths each value, using values of 5 minutes before , 10 minutes before, 5 minutes after and 10 minutes after, ... the number of values taken into account depends on the filterWidth
    /// - parameters :
    ///     - withFilterWidth : filter width to use
    ///     - repeat : how often to redo the filter
    ///     - trend : glucoseData array to filter, objects in the array will be smoothed (= filtered)
    private static func smoothPer5Minutes(trend: [GlucoseData], withFilterWidth filterWidth: Int, iterations: Int) {
        
        // trend must both have at least 16 values, should always be the case, just to avoid crashes
        guard trend.count >= 16 else {return}
        
        // copy glucose values to array of double
        let smoothedValues = trend.map({$0.glucoseLevelRaw})
        
        // now we have smoothedValues, Double's with values equal to trend's glucoseLevelRaw values
        // we will apply smoothing, each value will be smoothed using the value if 5 minutes before, 10 minutes before, 15 minutes before, 5 minutes after and 10 minutes after and 15 minutes after - because we'll never use two subsequent values, we use them with an interval of 5 minutes and with a filterWidth of 2 .. and more
        for (index, value) in trend.enumerated() {
            
            // initalize toSmooth with value that will be smoothed
            var toSmooth = [smoothedValues[index]]
            
            // while adding values to toSmooth, we need to keep track of the index of the value being smoothed
            var indexOfValueBeingSmoothed = 0
            
            // prepend values 5 and 10 and 15 minutes ago, ... maximum 5 which is the maximum filterwidth
            for count in 1...5 {
                
                let indexToUse = index - 5 * count
                
                if indexToUse >= 0 {
                    toSmooth.insert(smoothedValues[indexToUse], at: 0)
                    indexOfValueBeingSmoothed = count
                }
                
            }
            
            // append values 5 and 10 and 15 minutes later, ... maximum 5 which is the maximum filterwidth
            for count in 1...5 {
                
                let indexToUse = index + 5 * count
                
                if indexToUse < smoothedValues.count - 1 {
                    toSmooth.append(smoothedValues[indexToUse])
                }
                
            }
            
            // smooth
            for _ in 1...iterations {
                
                toSmooth.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidth)
                
            }
            
            // now change the value being smoothed
            value.glucoseLevelRaw = toSmooth[indexOfValueBeingSmoothed]
            
        }
        
    }

}
