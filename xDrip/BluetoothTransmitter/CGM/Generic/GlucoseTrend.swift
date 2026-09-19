import Foundation

/// The phone and Watch use the same slope units (mg/dL per millisecond) and arrow thresholds.
enum GlucoseTrend {
    static func slope(currentValue: Double, currentDate: Date, previousValue: Double, previousDate: Date) -> (Double, Bool) {
        let currentMilliseconds = currentDate.timeIntervalSince1970 * 1000
        let previousMilliseconds = previousDate.timeIntervalSince1970 * 1000
        if currentDate == previousDate || currentMilliseconds - previousMilliseconds > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0, true)
        }
        return ((previousValue - currentValue) / (previousMilliseconds - currentMilliseconds), false)
    }

    static func ordinal(slope: Double, hideSlope: Bool) -> Int {
        guard !hideSlope else { return 0 }
        let slopeByMinute = slope * 60000
        if slopeByMinute <= -3.5 { return 7 }
        if slopeByMinute <= -2 { return 6 }
        if slopeByMinute <= -1 { return 5 }
        if slopeByMinute <= 1 { return 4 }
        if slopeByMinute <= 2 { return 3 }
        if slopeByMinute <= 3.5 { return 2 }
        return 1
    }
}
