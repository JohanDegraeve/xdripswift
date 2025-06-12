import Foundation

/// Protocol representing a glucose reading for prediction purposes
public protocol GlucoseReading {
    /// The timestamp when the reading was taken
    var timeStamp: Date { get }
    
    /// The calculated glucose value in mg/dL
    var calculatedValue: Double { get }
}

// MARK: - BgReading Conformance

extension BgReading: GlucoseReading {
    // BgReading already has timeStamp and calculatedValue properties
    // No additional implementation needed
}