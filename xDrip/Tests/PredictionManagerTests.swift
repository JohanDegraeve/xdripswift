import XCTest
import Foundation
@testable import xdrip

/// Unit tests for glucose prediction functionality
final class PredictionManagerTests: XCTestCase {
    
    var predictionManager: PredictionManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        predictionManager = PredictionManager()
    }
    
    override func tearDownWithError() throws {
        predictionManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Mathematical Model Tests
    
    func testPolynomialTrendLineLinear() throws {
        let model = PolynomialTrendLine(degree: 1)
        
        // Test linear trend: y = 2x + 100
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [102.0, 104.0, 106.0, 108.0, 110.0]
        
        let prediction = model.predict(values: values, timePoints: timePoints, futureTime: 6.0)
        
        // Should predict approximately 112.0 (2*6 + 100)
        XCTAssertEqual(prediction, 112.0, accuracy: 1.0, "Linear prediction should be accurate")
    }
    
    func testPolynomialTrendLineQuadratic() throws {
        let model = PolynomialTrendLine(degree: 2)
        
        // Test quadratic trend: y = x² + 100
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [101.0, 104.0, 109.0, 116.0, 125.0]
        
        let prediction = model.predict(values: values, timePoints: timePoints, futureTime: 6.0)
        
        // Should predict approximately 136.0 (6² + 100)
        XCTAssertEqual(prediction, 136.0, accuracy: 2.0, "Quadratic prediction should be accurate")
    }
    
    func testLogarithmicTrendLine() throws {
        let model = LogarithmicTrendLine()
        
        // Test logarithmic trend
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [100.0, 105.0, 108.0, 110.0, 112.0]
        
        let prediction = model.predict(values: values, timePoints: timePoints, futureTime: 6.0)
        
        // Should predict a reasonable glucose value
        XCTAssertGreaterThan(prediction, 50.0, "Prediction should be reasonable")
        XCTAssertLessThan(prediction, 200.0, "Prediction should be reasonable")
    }
    
    func testExponentialTrendLine() throws {
        let model = ExponentialTrendLine()
        
        // Test exponential trend with moderate growth
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [100.0, 102.0, 104.0, 106.0, 108.0]
        
        let prediction = model.predict(values: values, timePoints: timePoints, futureTime: 6.0)
        
        // Should predict a reasonable glucose value
        XCTAssertGreaterThan(prediction, 50.0, "Prediction should be reasonable")
        XCTAssertLessThan(prediction, 300.0, "Prediction should be reasonable")
    }
    
    func testPowerTrendLine() throws {
        let model = PowerTrendLine()
        
        // Test power trend
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [100.0, 105.0, 112.0, 120.0, 130.0]
        
        let prediction = model.predict(values: values, timePoints: timePoints, futureTime: 6.0)
        
        // Should predict a reasonable glucose value
        XCTAssertGreaterThan(prediction, 50.0, "Prediction should be reasonable")
        XCTAssertLessThan(prediction, 300.0, "Prediction should be reasonable")
    }
    
    // MARK: - Error Variance Tests
    
    func testErrorVarianceCalculation() throws {
        let model = PolynomialTrendLine(degree: 1)
        
        // Perfect linear data should have very low error variance
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [102.0, 104.0, 106.0, 108.0, 110.0]
        
        let errorVariance = model.calculateErrorVariance(values: values, timePoints: timePoints)
        
        XCTAssertLessThan(errorVariance, 1.0, "Error variance for perfect linear data should be very low")
    }
    
    func testErrorVarianceWithNoise() throws {
        let model = PolynomialTrendLine(degree: 1)
        
        // Linear data with some noise
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [101.5, 104.2, 105.8, 108.1, 110.3]
        
        let errorVariance = model.calculateErrorVariance(values: values, timePoints: timePoints)
        
        XCTAssertGreaterThan(errorVariance, 0.0, "Error variance should be positive for noisy data")
        XCTAssertLessThan(errorVariance, 5.0, "Error variance should still be reasonable for low noise")
    }
    
    // MARK: - Model Selection Tests
    
    func testModelSelection() throws {
        // Create test data that follows a linear trend
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let values = [100.0, 102.0, 104.0, 106.0, 108.0, 110.0, 112.0, 114.0, 116.0, 118.0]
        
        let allModels = TrendLineModelFactory.createAllModels()
        
        // Find the best model (should be linear for this data)
        var bestModel: TrendLineModel?
        var lowestError = Double.infinity
        
        for model in allModels {
            let error = model.calculateErrorVariance(values: values, timePoints: timePoints)
            if error < lowestError {
                lowestError = error
                bestModel = model
            }
        }
        
        XCTAssertNotNil(bestModel, "Should select a best model")
        
        // For perfect linear data, a linear model should be selected
        if let polynomialModel = bestModel as? PolynomialTrendLine {
            XCTAssertEqual(polynomialModel.degree, 1, "Linear model should be selected for linear data")
        }
    }
    
    // MARK: - Array Extension Tests
    
    func testArrayMean() throws {
        let array = [1.0, 2.0, 3.0, 4.0, 5.0]
        let mean = array.mean()
        
        XCTAssertEqual(mean, 3.0, accuracy: 0.001, "Mean calculation should be correct")
    }
    
    func testArrayStandardDeviation() throws {
        let array = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let stdDev = array.standardDeviation()
        
        // Expected standard deviation is 2.0
        XCTAssertEqual(stdDev, 2.0, accuracy: 0.1, "Standard deviation calculation should be correct")
    }
    
    func testLinearRegression() throws {
        // Test data: y = 2x + 1
        let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
        let values = [3.0, 5.0, 7.0, 9.0, 11.0]
        
        let regression = values.linearRegression(with: timePoints)
        
        XCTAssertEqual(regression.slope, 2.0, accuracy: 0.01, "Slope should be correct")
        XCTAssertEqual(regression.intercept, 1.0, accuracy: 0.01, "Intercept should be correct")
    }
    
    func testPolynomialRegression() throws {
        // Test data: y = x² + 2x + 1 = (x + 1)²
        let timePoints = [0.0, 1.0, 2.0, 3.0, 4.0]
        let values = [1.0, 4.0, 9.0, 16.0, 25.0]
        
        let coefficients = values.polynomialRegression(with: timePoints, degree: 2)
        
        XCTAssertEqual(coefficients.count, 3, "Should return 3 coefficients for degree 2")
        
        // Test evaluation
        let testX = 5.0
        let predicted = Array<Double>.evaluatePolynomial(coefficients: coefficients, at: testX)
        let expected = 36.0 // (5+1)² = 36
        
        XCTAssertEqual(predicted, expected, accuracy: 1.0, "Polynomial evaluation should be accurate")
    }
    
    // MARK: - Prediction Manager Integration Tests
    
    func testPredictionGenerationWithInsufficientData() throws {
        let readings: [BgReading] = [] // Empty array
        
        let predictions = predictionManager.generatePredictions(
            readings: readings,
            timeHorizon: 1800, // 30 minutes
            intervalMinutes: 5
        )
        
        XCTAssertTrue(predictions.isEmpty, "Should return empty predictions for insufficient data")
    }
    
    func testPredictionGenerationWithValidData() throws {
        // Create mock BgReading objects with a clear trend
        let readings = createMockBgReadings(
            startTime: Date().addingTimeInterval(-3600), // 1 hour ago
            count: 12,
            intervalMinutes: 5,
            startValue: 120.0,
            trend: 2.0 // Rising 2 mg/dL per reading
        )
        
        let predictions = predictionManager.generatePredictions(
            readings: readings,
            timeHorizon: 1800, // 30 minutes
            intervalMinutes: 5
        )
        
        XCTAssertFalse(predictions.isEmpty, "Should generate predictions for valid data")
        XCTAssertEqual(predictions.count, 6, "Should generate 6 predictions for 30-minute horizon with 5-minute intervals")
        
        // Check that predictions are in chronological order
        for i in 1..<predictions.count {
            XCTAssertLessThan(predictions[i-1].timestamp, predictions[i].timestamp, "Predictions should be in chronological order")
        }
        
        // Check that predicted values are reasonable
        for prediction in predictions {
            XCTAssertGreaterThan(prediction.value, 50.0, "Predicted values should be reasonable")
            XCTAssertLessThan(prediction.value, 400.0, "Predicted values should be reasonable")
            XCTAssertGreaterThan(prediction.confidence, 0.0, "Confidence should be positive")
            XCTAssertLessThanOrEqual(prediction.confidence, 1.0, "Confidence should not exceed 1.0")
        }
    }
    
    func testLowGlucosePrediction() throws {
        // Create mock readings showing a downward trend toward low glucose
        let readings = createMockBgReadings(
            startTime: Date().addingTimeInterval(-1800), // 30 minutes ago
            count: 6,
            intervalMinutes: 5,
            startValue: 90.0,
            trend: -3.0 // Falling 3 mg/dL per reading
        )
        
        let lowPrediction = predictionManager.predictLowGlucose(
            readings: readings,
            threshold: 70.0,
            maxHoursAhead: 2.0
        )
        
        XCTAssertNotNil(lowPrediction, "Should predict low glucose for downward trend")
        
        if let (timeToLow, severity) = lowPrediction {
            XCTAssertGreaterThan(timeToLow, 0, "Time to low should be positive")
            XCTAssertLessThan(timeToLow, 7200, "Time to low should be within 2 hours")
            
            // Verify severity makes sense based on time to low
            let minutesToLow = timeToLow / 60.0
            switch severity {
            case .immediate:
                XCTAssertLessThanOrEqual(minutesToLow, 15, "Immediate severity should be ≤15 minutes")
            case .urgent:
                XCTAssertLessThanOrEqual(minutesToLow, 30, "Urgent severity should be ≤30 minutes")
            case .warning:
                XCTAssertLessThanOrEqual(minutesToLow, 60, "Warning severity should be ≤60 minutes")
            case .watch:
                XCTAssertGreaterThan(minutesToLow, 60, "Watch severity should be >60 minutes")
            }
        }
    }
    
    func testLowGlucosePredictionWithStableGlucose() throws {
        // Create mock readings showing stable glucose levels
        let readings = createMockBgReadings(
            startTime: Date().addingTimeInterval(-1800), // 30 minutes ago
            count: 6,
            intervalMinutes: 5,
            startValue: 120.0,
            trend: 0.0 // Stable
        )
        
        let lowPrediction = predictionManager.predictLowGlucose(
            readings: readings,
            threshold: 70.0,
            maxHoursAhead: 4.0
        )
        
        XCTAssertNil(lowPrediction, "Should not predict low glucose for stable levels")
    }
    
    // MARK: - Helper Methods
    
    /// Creates mock BgReading objects for testing
    private func createMockBgReadings(
        startTime: Date,
        count: Int,
        intervalMinutes: Int,
        startValue: Double,
        trend: Double
    ) -> [MockBgReading] {
        
        var readings: [MockBgReading] = []
        
        for i in 0..<count {
            let timeStamp = startTime.addingTimeInterval(TimeInterval(i * intervalMinutes * 60))
            let value = startValue + (Double(i) * trend)
            let reading = MockBgReading(timeStamp: timeStamp, calculatedValue: value)
            readings.append(reading)
        }
        
        return readings
    }
}

// MARK: - Mock Classes

/// Mock BgReading class for testing that doesn't require Core Data
class MockBgReading: NSObject, GlucoseReading {
    var timeStamp: Date = Date()
    var calculatedValue: Double = 100.0
    
    init(timeStamp: Date, calculatedValue: Double) {
        super.init()
        self.timeStamp = timeStamp
        self.calculatedValue = calculatedValue
    }
}