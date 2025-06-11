import Foundation
import SwiftCharts
import UIKit
import os.log

// MARK: - Prediction Extensions for GlucoseChartManager

extension GlucoseChartManager {
    
    /// Generates prediction chart points for display on the glucose chart
    /// - Parameters:
    ///   - bgReadings: Array of BgReading objects for prediction input
    ///   - endDate: The end date of the chart (latest time displayed)
    /// - Returns: Array of ChartPoint objects representing glucose predictions
    func generatePredictionChartPoints(bgReadings: [BgReading], endDate: Date) -> [ChartPoint] {
        
        // Check if predictions are enabled in user settings
        guard UserDefaults.standard.predictionEnabled else {
            return []
        }
        
        // Filter out any readings with invalid data
        let validReadings = bgReadings.filter { reading in
            // Ensure the reading has valid data
            return reading.calculatedValue > 0 &&
                   reading.calculatedValue < 1000 && // sanity check for unrealistic values
                   reading.timeStamp.timeIntervalSinceNow < 0 // ensure it's not a future date
        }
        
        guard !validReadings.isEmpty else {
            os_log("No valid readings found for predictions", log: .default, type: .info)
            return []
        }
        
        // Log the readings being used for predictions
        os_log("Generating predictions with %{public}d valid readings", log: .default, type: .info, validReadings.count)
        
        // Get prediction time horizon based on chart width (1/4 of chart width)
        let chartWidthHours = UserDefaults.standard.chartWidthInHours
        let predictionHours = chartWidthHours / 4.0
        let timeHorizon = TimeInterval(predictionHours * 3600)
        
        // Create PredictionManager with coreDataManager for IOB/COB calculations
        let predictionManager = PredictionManager(coreDataManager: coreDataManager)
        
        // Generate predictions using PredictionManager
        // BgReading already conforms to GlucoseReading protocol
        let predictions = predictionManager.generatePredictions(
            readings: validReadings,
            timeHorizon: timeHorizon,
            intervalMinutes: 5
        )
        
        // Convert PredictionPoint objects to ChartPoint objects
        let chartPoints = predictions.map { prediction in
            createPredictionChartPoint(from: prediction, endDate: endDate)
        }
        
        // Log successful prediction generation
        if !chartPoints.isEmpty {
            os_log("Successfully generated %{public}d prediction points", log: .default, type: .info, chartPoints.count)
        }
        
        return chartPoints
    }
    
    /// Generates prediction chart points from reading data (thread-safe version)
    /// - Parameters:
    ///   - readingData: Array of ReadingData structs with timestamp and value
    ///   - endDate: The end date of the chart (latest time displayed)
    /// - Returns: Array of ChartPoint objects representing glucose predictions
    func generatePredictionChartPointsFromData(readingData: [(timestamp: Date, value: Double)], endDate: Date) -> [ChartPoint] {
        
        // Check if predictions are enabled in user settings
        guard UserDefaults.standard.predictionEnabled else {
            return []
        }
        
        // Filter out any readings with invalid data
        let validReadings = readingData.filter { reading in
            // Ensure the reading has valid data
            return reading.value > 0 &&
                   reading.value < 1000 && // sanity check for unrealistic values
                   reading.timestamp.timeIntervalSinceNow < 0 // ensure it's not a future date
        }
        
        guard !validReadings.isEmpty else {
            os_log("No valid readings found for predictions", log: .default, type: .info)
            return []
        }
        
        // Log the readings being used for predictions
        os_log("Generating predictions with %{public}d valid readings", log: .default, type: .info, validReadings.count)
        
        // Get prediction time horizon based on chart width (1/4 of chart width)
        let chartWidthHours = UserDefaults.standard.chartWidthInHours
        let predictionHours = chartWidthHours / 4.0
        let timeHorizon = TimeInterval(predictionHours * 3600)
        
        // Create GlucoseReading objects from the reading data
        let glucoseReadings: [GlucoseReading] = validReadings.map { reading in
            // Create a simple GlucoseReading implementation
            SimpleGlucoseReading(timeStamp: reading.timestamp, calculatedValue: reading.value)
        }
        
        // Create PredictionManager with coreDataManager for IOB/COB calculations
        let predictionManager = PredictionManager(coreDataManager: coreDataManager)
        
        // Generate predictions using PredictionManager
        let predictions = predictionManager.generatePredictions(
            readings: glucoseReadings,
            timeHorizon: timeHorizon,
            intervalMinutes: 5
        )
        
        // Convert PredictionPoint objects to ChartPoint objects
        let chartPoints = predictions.map { prediction in
            createPredictionChartPoint(from: prediction, endDate: endDate)
        }
        
        // Log successful prediction generation
        if !chartPoints.isEmpty {
            os_log("Successfully generated %{public}d prediction points", log: .default, type: .info, chartPoints.count)
        }
        
        return chartPoints
    }
    
    /// Creates a prediction chart layer for display on the glucose chart
    /// - Parameters:
    ///   - predictionChartPoints: Array of prediction chart points
    ///   - xAxisLayer: The chart's x-axis layer
    ///   - yAxisLayer: The chart's y-axis layer
    /// - Returns: ChartPointsLineLayer configured for prediction display
    func createPredictionLineLayer(
        predictionChartPoints: [ChartPoint],
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer
    ) -> ChartPointsLineLayer<ChartPoint>? {
        
        guard !predictionChartPoints.isEmpty else { return nil }
        
        // Configure prediction line appearance
        let predictionLineColor = UserDefaults.standard.predictionLineColor
        let predictionLineWidth = UserDefaults.standard.predictionLineWidth
        
        // Create line model with dotted pattern
        let predictionLineModel = ChartLineModel(
            chartPoints: predictionChartPoints,
            lineColor: predictionLineColor,
            lineWidth: predictionLineWidth,
            animDuration: 0.3,
            animDelay: 0.0,
            dashPattern: [8, 4] // Dotted line pattern: 8px dash, 4px gap
        )
        
        // Create and return the line layer
        return ChartPointsLineLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            lineModels: [predictionLineModel]
        )
    }
    
    /// Creates a confidence band layer for prediction uncertainty visualization
    /// - Parameters:
    ///   - predictionChartPoints: Array of prediction chart points
    ///   - xAxisLayer: The chart's x-axis layer
    ///   - yAxisLayer: The chart's y-axis layer
    /// - Returns: ChartPointsFillsLayer configured for confidence band display
    func createPredictionConfidenceLayer(
        predictionChartPoints: [ChartPoint],
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer
    ) -> ChartPointsFillsLayer? {
        
        guard !predictionChartPoints.isEmpty,
              UserDefaults.standard.showPredictionConfidence else { 
            return nil 
        }
        
        // Create upper and lower confidence bounds
        let confidenceBandPoints = createConfidenceBandPoints(from: predictionChartPoints)
        
        guard !confidenceBandPoints.isEmpty else { return nil }
        
        // Configure confidence band appearance
        let confidenceFillColor = UserDefaults.standard.predictionLineColor.withAlphaComponent(0.2)
        
        // Create fill layer
        let confidenceFill = ChartPointsFill(
            chartPoints: confidenceBandPoints,
            fillColor: confidenceFillColor,
            createContainerPoints: false
        )
        
        return ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: [confidenceFill]
        )
    }
    
    /// Checks for low glucose predictions and returns warning information
    /// - Parameter bgReadings: Array of recent BgReading objects
    /// - Returns: Tuple containing time to low and severity, or nil if no low predicted
    func checkLowGlucosePrediction(bgReadings: [BgReading]) -> (timeToLow: TimeInterval, severity: LowPredictionSeverity)? {
        
        guard UserDefaults.standard.lowGlucosePredictionEnabled else {
            return nil
        }
        
        let threshold = UserDefaults.standard.lowGlucosePredictionThreshold
        
        // Create PredictionManager with coreDataManager for IOB/COB calculations
        let predictionManager = PredictionManager(coreDataManager: coreDataManager)
        
        // BgReading already conforms to GlucoseReading protocol
        return predictionManager.predictLowGlucose(
            readings: bgReadings,
            threshold: threshold,
            maxHoursAhead: 4.0
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a ChartPoint from a PredictionPoint
    private func createPredictionChartPoint(from prediction: PredictionPoint, endDate: Date) -> ChartPoint {
        // Create a simple formatter for the chart - this matches the pattern used elsewhere
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let xValue = ChartAxisValueDate(date: prediction.timestamp, formatter: formatter)
        
        let glucoseValue = UserDefaults.standard.bloodGlucoseUnitIsMgDl 
            ? prediction.value 
            : prediction.value.mgDlToMmol()
        
        let yValue = ChartAxisValueDouble(glucoseValue)
        
        return ChartPoint(x: xValue, y: yValue)
    }
    
    /// Creates confidence band points for uncertainty visualization
    private func createConfidenceBandPoints(from predictionPoints: [ChartPoint]) -> [ChartPoint] {
        var confidenceBandPoints: [ChartPoint] = []
        
        // For simplicity, create a band using ±10% of the predicted value
        // In a more sophisticated implementation, this would use actual confidence intervals
        let confidencePercentage = 0.1
        
        // Create upper bound points
        for point in predictionPoints {
            let upperValue = point.y.scalar * (1.0 + confidencePercentage)
            let upperPoint = ChartPoint(
                x: point.x,
                y: ChartAxisValueDouble(upperValue)
            )
            confidenceBandPoints.append(upperPoint)
        }
        
        // Create lower bound points in reverse order to close the polygon
        for point in predictionPoints.reversed() {
            let lowerValue = point.y.scalar * (1.0 - confidencePercentage)
            let lowerPoint = ChartPoint(
                x: point.x,
                y: ChartAxisValueDouble(lowerValue)
            )
            confidenceBandPoints.append(lowerPoint)
        }
        
        return confidenceBandPoints
    }
}

// MARK: - UserDefaults Extensions for Prediction Settings

extension UserDefaults {
    
    /// Whether glucose prediction is enabled
    var predictionEnabled: Bool {
        get { bool(forKey: "predictionEnabled") }
        set { set(newValue, forKey: "predictionEnabled") }
    }
    
    /// Prediction time horizon in minutes (default: 30)
    var predictionTimeHorizon: Int {
        get { 
            let value = integer(forKey: "predictionTimeHorizon")
            return value > 0 ? value : 30
        }
        set { set(newValue, forKey: "predictionTimeHorizon") }
    }
    
    /// Whether to show prediction confidence bands
    var showPredictionConfidence: Bool {
        get { bool(forKey: "showPredictionConfidence") }
        set { set(newValue, forKey: "showPredictionConfidence") }
    }
    
    /// Prediction line color
    var predictionLineColor: UIColor {
        get {
            if let colorData = data(forKey: "predictionLineColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
                return color
            }
            return UIColor.systemBlue.withAlphaComponent(0.7)
        }
        set {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                set(colorData, forKey: "predictionLineColor")
            }
        }
    }
    
    /// Prediction line width (default: 2.0)
    var predictionLineWidth: CGFloat {
        get {
            let value = double(forKey: "predictionLineWidth")
            return value > 0 ? CGFloat(value) : 2.0
        }
        set { set(Double(newValue), forKey: "predictionLineWidth") }
    }
    
    /// Whether low glucose prediction alerts are enabled
    var lowGlucosePredictionEnabled: Bool {
        get { bool(forKey: "lowGlucosePredictionEnabled") }
        set { set(newValue, forKey: "lowGlucosePredictionEnabled") }
    }
    
    /// Low glucose prediction threshold in mg/dL (default: 70.0)
    var lowGlucosePredictionThreshold: Double {
        get {
            let value = double(forKey: "lowGlucosePredictionThreshold")
            return value > 0 ? value : 70.0
        }
        set { set(newValue, forKey: "lowGlucosePredictionThreshold") }
    }
}

// MARK: - Simple GlucoseReading Implementation for Thread Safety

/// A simple implementation of GlucoseReading protocol that doesn't depend on Core Data
private struct SimpleGlucoseReading: GlucoseReading {
    let timeStamp: Date
    let calculatedValue: Double
}