import Foundation
import CoreData
import os.log

/// Manages glucose prediction calculations using multiple mathematical models
public class PredictionManager {
    
    // MARK: - Private Properties
    
    private let trace = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryPredictionManager)
    
    /// Available trend line models for prediction
    private let models: [TrendLineModel]
    
    /// Minimum number of readings required for prediction
    private let minimumReadingsRequired = 3
    
    /// Maximum number of readings to use for prediction (performance optimization)
    private let maximumReadingsToUse = 20
    
    // MARK: - Public Properties
    
    /// Shared singleton instance
    public static let shared = PredictionManager()
    
    // MARK: - Initialization
    
    public init() {
        self.models = TrendLineModelFactory.createAllModels()
        os_log("PredictionManager initialized with %{public}d models", log: trace, type: .info, models.count)
    }
    
    // MARK: - Public Methods
    
    /// Generates glucose predictions for a specified time horizon
    /// - Parameters:
    ///   - readings: Array of recent GlucoseReading objects
    ///   - timeHorizon: How far into the future to predict (in seconds)
    ///   - intervalMinutes: Interval between prediction points (default: 5 minutes)
    /// - Returns: Array of PredictionPoint objects
    public func generatePredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int = 5
    ) -> [PredictionPoint] {
        
        guard readings.count >= minimumReadingsRequired else {
            os_log("Insufficient readings for prediction: %{public}d (minimum: %{public}d)", 
                   log: trace, type: .info, readings.count, minimumReadingsRequired)
            return []
        }
        
        // Sort readings by timestamp and take most recent ones
        let sortedReadings = readings.sorted { $0.timeStamp < $1.timeStamp }
        let recentReadings = Array(sortedReadings.suffix(maximumReadingsToUse))
        
        // Extract glucose values and time points
        let values = recentReadings.map { $0.calculatedValue }
        let timePoints = recentReadings.map { $0.timeStamp.timeIntervalSince1970 }
        
        // Select the best model based on error variance
        guard let bestModel = selectBestModel(values: values, timePoints: timePoints) else {
            os_log("No suitable model found for prediction", log: trace, type: .error)
            return []
        }
        
        os_log("Selected model: %{public}@ for prediction", log: trace, type: .info, bestModel.modelType.rawValue)
        
        // Generate predictions at specified intervals
        var predictions: [PredictionPoint] = []
        let startTime = recentReadings.last?.timeStamp ?? Date()
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        let numberOfPredictions = Int(timeHorizon / intervalSeconds)
        
        for i in 1...numberOfPredictions {
            let futureTime = startTime.addingTimeInterval(TimeInterval(i) * intervalSeconds)
            let futureTimeInterval = futureTime.timeIntervalSince1970
            
            let predictedValue = bestModel.predict(
                values: values,
                timePoints: timePoints,
                futureTime: futureTimeInterval
            )
            
            // Ensure predicted value is within reasonable bounds
            let clampedValue = clampGlucoseValue(predictedValue)
            
            let confidence = calculateConfidence(
                model: bestModel,
                values: values,
                timePoints: timePoints,
                minutesAhead: i * intervalMinutes
            )
            
            let predictionPoint = PredictionPoint(
                timestamp: futureTime,
                value: clampedValue,
                confidence: confidence,
                modelType: bestModel.modelType
            )
            
            predictions.append(predictionPoint)
        }
        
        os_log("Generated %{public}d predictions up to %{public}.1f minutes ahead", 
               log: trace, type: .info, predictions.count, timeHorizon / 60.0)
        
        return predictions
    }
    
    /// Predicts when glucose will drop below a specified threshold
    /// - Parameters:
    ///   - readings: Array of recent GlucoseReading objects
    ///   - threshold: Glucose threshold in mg/dL (default: 70.0)
    ///   - maxHoursAhead: Maximum hours to look ahead (default: 4.0)
    /// - Returns: Tuple containing time until low and severity, or nil if no low predicted
    public func predictLowGlucose(
        readings: [GlucoseReading],
        threshold: Double = 70.0,
        maxHoursAhead: Double = 4.0
    ) -> (timeToLow: TimeInterval, severity: LowPredictionSeverity)? {
        
        guard readings.count >= minimumReadingsRequired else { return nil }
        
        let sortedReadings = readings.sorted { $0.timeStamp < $1.timeStamp }
        let recentReadings = Array(sortedReadings.suffix(maximumReadingsToUse))
        
        let values = recentReadings.map { $0.calculatedValue }
        let timePoints = recentReadings.map { $0.timeStamp.timeIntervalSince1970 }
        
        guard let bestModel = selectBestModel(values: values, timePoints: timePoints) else {
            return nil
        }
        
        // Check if current trend is going down
        let currentValue = values.last ?? 100.0
        if currentValue <= threshold {
            return (timeToLow: 0, severity: .immediate)
        }
        
        // Use binary search to find intersection with threshold
        let startTime = recentReadings.last?.timeStamp ?? Date()
        let maxSeconds = maxHoursAhead * 3600
        
        var low: TimeInterval = 0
        var high: TimeInterval = maxSeconds
        let precision: TimeInterval = 60 // 1-minute precision
        
        while high - low > precision {
            let mid = (low + high) / 2
            let futureTime = startTime.timeIntervalSince1970 + mid
            let prediction = bestModel.predict(values: values, timePoints: timePoints, futureTime: futureTime)
            
            if prediction <= threshold {
                high = mid
            } else {
                low = mid
            }
        }
        
        let timeToLow = high
        
        // Only return if low is predicted within the time horizon
        if timeToLow < maxSeconds {
            let severity = calculateLowSeverity(timeToLow: timeToLow, currentValue: currentValue)
            os_log("Low glucose predicted in %{public}.1f minutes (severity: %{public}@)", 
                   log: trace, type: .info, timeToLow / 60.0, severity.rawValue)
            return (timeToLow: timeToLow, severity: severity)
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Selects the best model based on error variance
    private func selectBestModel(values: [Double], timePoints: [Double]) -> TrendLineModel? {
        var bestModel: TrendLineModel?
        var lowestError = Double.infinity
        
        for model in models {
            let error = model.calculateErrorVariance(values: values, timePoints: timePoints)
            
            // Skip models with infinite or extremely high error
            if error.isFinite && error < lowestError {
                lowestError = error
                bestModel = model
            }
        }
        
        return bestModel
    }
    
    /// Calculates confidence based on model error and time horizon
    private func calculateConfidence(
        model: TrendLineModel,
        values: [Double],
        timePoints: [Double],
        minutesAhead: Int
    ) -> Double {
        
        let baseConfidence = 0.9 // Start with high confidence
        let errorVariance = model.calculateErrorVariance(values: values, timePoints: timePoints)
        
        // Reduce confidence based on error variance
        let errorPenalty = min(0.5, errorVariance / 1000.0) // Scale error variance
        
        // Reduce confidence based on time horizon (farther predictions are less confident)
        let timePenalty = Double(minutesAhead) / 120.0 // 50% confidence at 2 hours
        
        let confidence = baseConfidence - errorPenalty - timePenalty
        return max(0.1, min(1.0, confidence)) // Clamp between 0.1 and 1.0
    }
    
    /// Clamps glucose values to reasonable physiological bounds
    private func clampGlucoseValue(_ value: Double) -> Double {
        let minGlucose = 20.0  // mg/dL
        let maxGlucose = 600.0 // mg/dL
        return max(minGlucose, min(maxGlucose, value))
    }
    
    /// Calculates severity of low glucose prediction
    private func calculateLowSeverity(timeToLow: TimeInterval, currentValue: Double) -> LowPredictionSeverity {
        let minutesToLow = timeToLow / 60.0
        
        if minutesToLow <= 15 {
            return .immediate
        } else if minutesToLow <= 30 {
            return .urgent
        } else if minutesToLow <= 60 {
            return .warning
        } else {
            return .watch
        }
    }
}

// MARK: - Low Prediction Severity

/// Severity levels for low glucose predictions
public enum LowPredictionSeverity: String, CaseIterable {
    case immediate = "Immediate"
    case urgent = "Urgent"
    case warning = "Warning"
    case watch = "Watch"
    
    /// Display name for UI
    public var displayName: String {
        return rawValue
    }
    
    /// Color coding for severity
    public var colorName: String {
        switch self {
        case .immediate:
            return "red"
        case .urgent:
            return "orange"
        case .warning:
            return "yellow"
        case .watch:
            return "blue"
        }
    }
}