import Foundation

/// Protocol defining the interface for all trend line models
public protocol TrendLineModel {
    
    /// Predicts a future glucose value based on historical data
    /// - Parameters:
    ///   - values: Array of historical glucose values in mg/dL
    ///   - timePoints: Array of corresponding timestamps (as TimeInterval since reference date)
    ///   - futureTime: The timestamp for which to make a prediction
    /// - Returns: Predicted glucose value in mg/dL
    func predict(values: [Double], timePoints: [Double], futureTime: Double) -> Double
    
    /// Calculates the error variance of this model against historical data
    /// - Parameters:
    ///   - values: Array of historical glucose values
    ///   - timePoints: Array of corresponding timestamps
    /// - Returns: Error variance (lower is better)
    func calculateErrorVariance(values: [Double], timePoints: [Double]) -> Double
    
    /// The type of this model
    var modelType: PredictionModelType { get }
}

// MARK: - Polynomial Trend Line

/// Polynomial regression model: y = a₀ + a₁x + a₂x² + ... + aₙxⁿ
public class PolynomialTrendLine: TrendLineModel {
    
    public let degree: Int
    public let modelType: PredictionModelType = .polynomial
    
    public init(degree: Int = 2) {
        self.degree = max(1, min(degree, 3)) // Limit degree to 1-3
    }
    
    public func predict(values: [Double], timePoints: [Double], futureTime: Double) -> Double {
        guard values.count == timePoints.count && values.count > degree else {
            return values.last ?? 100.0 // Fallback to last known value
        }
        
        let coefficients = values.polynomialRegression(with: timePoints, degree: degree)
        return Array<Double>.evaluatePolynomial(coefficients: coefficients, at: futureTime)
    }
    
    public func calculateErrorVariance(values: [Double], timePoints: [Double]) -> Double {
        guard values.count == timePoints.count && values.count > degree else {
            return Double.infinity
        }
        
        let coefficients = values.polynomialRegression(with: timePoints, degree: degree)
        let predictions = timePoints.map { timePoint in
            Array<Double>.evaluatePolynomial(coefficients: coefficients, at: timePoint)
        }
        
        return values.errorVariance(predicted: predictions)
    }
}

// MARK: - Logarithmic Trend Line

/// Logarithmic regression model: y = a + b*ln(x)
public class LogarithmicTrendLine: TrendLineModel {
    
    public let modelType: PredictionModelType = .logarithmic
    
    public func predict(values: [Double], timePoints: [Double], futureTime: Double) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return values.last ?? 100.0
        }
        
        // Transform timePoints to log space, handling edge cases
        let minTime = timePoints.min() ?? 0
        let adjustedTimePoints = timePoints.map { max(1.0, $0 - minTime + 1.0) }
        let logTimePoints = adjustedTimePoints.map { log($0) }
        
        let regression = values.linearRegression(with: logTimePoints)
        let adjustedFutureTime = max(1.0, futureTime - minTime + 1.0)
        
        return regression.slope * log(adjustedFutureTime) + regression.intercept
    }
    
    public func calculateErrorVariance(values: [Double], timePoints: [Double]) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return Double.infinity
        }
        
        let minTime = timePoints.min() ?? 0
        let adjustedTimePoints = timePoints.map { max(1.0, $0 - minTime + 1.0) }
        let logTimePoints = adjustedTimePoints.map { log($0) }
        
        let regression = values.linearRegression(with: logTimePoints)
        let predictions = logTimePoints.map { logTime in
            regression.slope * logTime + regression.intercept
        }
        
        return values.errorVariance(predicted: predictions)
    }
}

// MARK: - Exponential Trend Line

/// Exponential regression model: y = a * e^(b*x)
public class ExponentialTrendLine: TrendLineModel {
    
    public let modelType: PredictionModelType = .exponential
    
    public func predict(values: [Double], timePoints: [Double], futureTime: Double) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return values.last ?? 100.0
        }
        
        // Transform to log space for linear regression: ln(y) = ln(a) + b*x
        let positiveValues = values.map { max(1.0, $0) } // Ensure positive values
        let logValues = positiveValues.map { log($0) }
        
        let regression = logValues.linearRegression(with: timePoints)
        
        // Transform back: y = e^(ln(a) + b*x) = e^ln(a) * e^(b*x) = a * e^(b*x)
        let a = exp(regression.intercept)
        let b = regression.slope
        
        return a * exp(b * futureTime)
    }
    
    public func calculateErrorVariance(values: [Double], timePoints: [Double]) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return Double.infinity
        }
        
        let positiveValues = values.map { max(1.0, $0) }
        let logValues = positiveValues.map { log($0) }
        
        let regression = logValues.linearRegression(with: timePoints)
        let a = exp(regression.intercept)
        let b = regression.slope
        
        let predictions = timePoints.map { timePoint in
            a * exp(b * timePoint)
        }
        
        return values.errorVariance(predicted: predictions)
    }
}

// MARK: - Power Trend Line

/// Power regression model: y = a * x^b
public class PowerTrendLine: TrendLineModel {
    
    public let modelType: PredictionModelType = .power
    
    public func predict(values: [Double], timePoints: [Double], futureTime: Double) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return values.last ?? 100.0
        }
        
        // Transform to log-log space: ln(y) = ln(a) + b*ln(x)
        let positiveValues = values.map { max(1.0, $0) }
        let logValues = positiveValues.map { log($0) }
        
        let minTime = timePoints.min() ?? 0
        let adjustedTimePoints = timePoints.map { max(1.0, $0 - minTime + 1.0) }
        let logTimePoints = adjustedTimePoints.map { log($0) }
        
        let regression = logValues.linearRegression(with: logTimePoints)
        
        // Transform back: y = e^(ln(a) + b*ln(x)) = e^ln(a) * e^(b*ln(x)) = a * x^b
        let a = exp(regression.intercept)
        let b = regression.slope
        
        let adjustedFutureTime = max(1.0, futureTime - minTime + 1.0)
        return a * pow(adjustedFutureTime, b)
    }
    
    public func calculateErrorVariance(values: [Double], timePoints: [Double]) -> Double {
        guard values.count == timePoints.count && values.count > 1 else {
            return Double.infinity
        }
        
        let positiveValues = values.map { max(1.0, $0) }
        let logValues = positiveValues.map { log($0) }
        
        let minTime = timePoints.min() ?? 0
        let adjustedTimePoints = timePoints.map { max(1.0, $0 - minTime + 1.0) }
        let logTimePoints = adjustedTimePoints.map { log($0) }
        
        let regression = logValues.linearRegression(with: logTimePoints)
        let a = exp(regression.intercept)
        let b = regression.slope
        
        let predictions = adjustedTimePoints.map { adjustedTime in
            a * pow(adjustedTime, b)
        }
        
        return values.errorVariance(predicted: predictions)
    }
}

// MARK: - Model Factory

public class TrendLineModelFactory {
    
    /// Creates all available trend line models for testing
    public static func createAllModels() -> [TrendLineModel] {
        return [
            PolynomialTrendLine(degree: 1), // Linear
            PolynomialTrendLine(degree: 2), // Quadratic
            PolynomialTrendLine(degree: 3), // Cubic
            LogarithmicTrendLine(),
            ExponentialTrendLine(),
            PowerTrendLine()
        ]
    }
    
    /// Creates a specific model by type
    public static func createModel(type: PredictionModelType, degree: Int = 2) -> TrendLineModel {
        switch type {
        case .polynomial:
            return PolynomialTrendLine(degree: degree)
        case .logarithmic:
            return LogarithmicTrendLine()
        case .exponential:
            return ExponentialTrendLine()
        case .power:
            return PowerTrendLine()
        }
    }
}