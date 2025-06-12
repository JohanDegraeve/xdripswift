import Foundation

/// Represents a predicted glucose value at a specific time
public struct PredictionPoint {
    
    /// The timestamp for this prediction
    public let timestamp: Date
    
    /// The predicted glucose value in mg/dL
    public let value: Double
    
    /// Confidence level of this prediction (0.0 to 1.0)
    public let confidence: Double
    
    /// The mathematical model used to generate this prediction
    public let modelType: PredictionModelType
    
    /// How many minutes in the future this prediction is from the last reading
    public var minutesAhead: Int {
        // This would need to be calculated relative to the last actual reading
        // For now, return 0 as placeholder
        return 0
    }
    
    public init(timestamp: Date, value: Double, confidence: Double, modelType: PredictionModelType) {
        self.timestamp = timestamp
        self.value = value
        self.confidence = confidence
        self.modelType = modelType
    }
}

/// Mathematical models available for glucose prediction
public enum PredictionModelType: String, CaseIterable {
    case polynomial = "Polynomial"
    case logarithmic = "Logarithmic"
    case exponential = "Exponential"
    case power = "Power"
    
    /// Display name for UI
    public var displayName: String {
        return rawValue
    }
}

// MARK: - Equatable
extension PredictionPoint: Equatable {
    public static func == (lhs: PredictionPoint, rhs: PredictionPoint) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.value == rhs.value &&
               lhs.confidence == rhs.confidence &&
               lhs.modelType == rhs.modelType
    }
}

// MARK: - Comparable
extension PredictionPoint: Comparable {
    public static func < (lhs: PredictionPoint, rhs: PredictionPoint) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}