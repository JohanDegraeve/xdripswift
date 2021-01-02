import Foundation

class LibreSmoothing {
    
    // MARK: - public functions
    
    /// - smooths trend array of GlucoseData, ie per minute values using SavitzkyGolayQuaDratic filter
    /// - first per minute SavitzkyGolayQuaDratic, then Kalman filter
    /// - after Kalman filter, back the per 5 minutes : using values of 5 minutes before , 10 minutes before, 5 minutes after and 10 minutes after, ... the number of values taken into account depends on the filterWidth
    public static func smooth(trend: inout [GlucoseData], repeatPerMinuteSmoothingSavitzkyGolay: Int, filterWidthPerMinuteValuesSavitzkyGolay: Int, filterWidthPer5MinuteValuesSavitzkyGolay: Int, repeatPer5MinuteSmoothingSavitzkyGolay:Int) {
        
        // smooth the trend values, filterWidth 5, 2 iterations
        for _ in 1...repeatPerMinuteSmoothingSavitzkyGolay {
            
            trend.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidthPerMinuteValuesSavitzkyGolay)
            
        }
        
        // apply Kalman filter
        LibreSmoothing.smoothWithKalmanFilter(trend: &trend, filterNoise: 2.5)

        // now smooth per 5 minutes
        LibreSmoothing.smoothPer5Minutes(trend: trend, withFilterWidth: filterWidthPer5MinuteValuesSavitzkyGolay, iterations: repeatPer5MinuteSmoothingSavitzkyGolay)
        
    }
    
    /// - smooths history array of GlucoseData, ie per 15 minute values using SavitzkyGolayQuaDratic filter
    public static func smooth(history: inout [GlucoseData], filterWidthPer5MinuteSmoothingSavitzkyGolay: Int) {
        
        history.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidthPer5MinuteSmoothingSavitzkyGolay)
        
    }
    
    // MARK: - private functions

    /// trend must be list of non 0 values, equal time distance from each other (ie every minute)
    private static func smoothWithKalmanFilter(trend: inout [GlucoseData], filterNoise: Double) {

        // there must be at least one element
        guard trend.count > 0 else {return}
        
        // all values must be > 0.0
        guard trend.filter({return $0.glucoseLevelRaw > 0.0}).count > 0 else {return}

        // copy glucoseLevelRaw for each element in trend to array of Double
        let trendAsDoubleArray = trend.map({$0.glucoseLevelRaw})
        
        var filter = KalmanFilter(stateEstimatePrior: trendAsDoubleArray[0], errorCovariancePrior: filterNoise)
        
        // iterate through the items reversed, because the first item is actually the most recent
        for (index, item) in trendAsDoubleArray.enumerated().reversed() {
            
            let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: filterNoise)
            
            let update = prediction.update(measurement: item, observationModel: 1, covarienceOfObservationNoise: filterNoise)
            
            filter = update
            
            let glucose = filter.stateEstimatePrior
            
            guard (glucose > 0.0) else {
                break
            }
            
            trend[index].glucoseLevelRaw = glucose
            
        }
        
    }
    
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
