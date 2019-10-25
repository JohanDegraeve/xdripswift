//
//  GlucoseRangeSchedule.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public struct DoubleRange {
    public let minValue: Double
    public let maxValue: Double
    
    public init(minValue: Double, maxValue: Double) {
        self.minValue = minValue
        self.maxValue = maxValue
    }
    
    public var isZero: Bool {
        return abs(minValue) < .ulpOfOne && abs(maxValue) < .ulpOfOne
    }
}


extension DoubleRange: RawRepresentable {
    public typealias RawValue = [Double]
    
    public init?(rawValue: RawValue) {
        guard rawValue.count == 2 else {
            return nil
        }
        
        minValue = rawValue[0]
        maxValue = rawValue[1]
    }
    
    public var rawValue: RawValue {
        return [minValue, maxValue]
    }
}


extension DoubleRange: Equatable {
    public static func ==(lhs: DoubleRange, rhs: DoubleRange) -> Bool {
        return abs(lhs.minValue - rhs.minValue) < .ulpOfOne &&
            abs(lhs.maxValue - rhs.maxValue) < .ulpOfOne
    }
}


/// Defines a daily schedule of glucose ranges
public struct GlucoseRangeSchedule: DailySchedule {
    public typealias RawValue = [String: Any]
    
    /// A time-based value overriding the rangeSchedule
    public struct Override {
        public enum Context: String {
            case workout
            case preMeal
        }
        
        public let context: Context
        public let start: Date
        public let end: Date?
        public let value: DoubleRange
        
        /// Initializes a new override
        ///
        /// - Parameters:
        ///   - context: The context type of the override
        ///   - start: The date at which the override starts
        ///   - end: The date at which the override ends, or nil for an indefinite override
        ///   - value: The value to return when active
        public init(context: Context, start: Date, end: Date?, value: DoubleRange) {
            self.context = context
            self.start = start
            self.end = end
            self.value = value
        }
        
        public var activeDates: DateInterval {
            return DateInterval(start: start, end: end ?? .distantFuture)
        }
        
        public func isActive(at date: Date = Date()) -> Bool {
            return activeDates.contains(date) && !value.isZero
        }
    }
    
    var rangeSchedule: DailyQuantitySchedule<DoubleRange>
    
    /// Default override values per context type
    public var overrideRanges: [Override.Context: DoubleRange]
    
    /// The last-configured override of the range schedule
    public private(set) var override: Override?
    
    /// Enables the predefined override value to be active during a specified system date range
    ///
    /// - Parameters:
    ///   - context: The context type to use for value selection
    ///   - start: The date the override should start
    ///   - end: The date the override should end
    /// - Returns: Whether the override was successfully enabled
    public mutating func setOverride(_ context: Override.Context, from start: Date = Date(), until end: Date) -> Bool {
        guard let value = overrideRanges[context], end > start, !value.isZero else {
            return false
        }
        
        override = Override(context: context, start: start, end: end, value: value)
        return true
    }
    
    /// Removes the specified range override
    ///
    /// - Parameter matching: The context to remove. If nil, all contexts are removed.
    public mutating func clearOverride(matching context: Override.Context? = nil) {
        guard let override = override, context == nil || context! == override.context else {
            return
        }
        
        self.override = nil
    }
    
    public init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<DoubleRange>], timeZone: TimeZone? = nil, overrideRanges: [Override.Context: DoubleRange], override: Override? = nil) {
        guard let rangeSchedule = DailyQuantitySchedule<DoubleRange>(unit: unit, dailyItems: dailyItems, timeZone: timeZone) else {
            return nil
        }
        
        self.rangeSchedule = rangeSchedule
        self.overrideRanges = overrideRanges
        self.override = override
    }
    
    public init?(rawValue: RawValue) {
        guard let rangeSchedule = DailyQuantitySchedule<DoubleRange>(rawValue: rawValue) else {
            return nil
        }
        
        self.rangeSchedule = rangeSchedule
        
        var overrideRanges: [Override.Context: DoubleRange] = [:]
        
        if let workoutRangeRawValue = rawValue["workoutRange"] as? DoubleRange.RawValue {
            overrideRanges[.workout] = DoubleRange(rawValue: workoutRangeRawValue)
        }
        
        if let overrideRangesRawValue = rawValue["overrideRanges"] as? [String: DoubleRange.RawValue] {
            for (key, value) in overrideRangesRawValue {
                guard let context = Override.Context(rawValue: key),
                    let range = DoubleRange(rawValue: value), !range.isZero
                    else {
                        continue
                }
                
                overrideRanges[context] = range
            }
        }
        
        self.overrideRanges = overrideRanges
        
        if let overrideRawValue = rawValue["override"] as? Override.RawValue {
            self.override = Override(rawValue: overrideRawValue)
        }
    }
    
    public func between(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<DoubleRange>] {
        return rangeSchedule.between(start: startDate, end: endDate)
    }
    
    public func value(at time: Date) -> DoubleRange {
        if let override = override, override.isActive() {
            return override.value
        }
        
        return rangeSchedule.value(at: time)
    }
    
    public var items: [RepeatingScheduleValue<DoubleRange>] {
        return rangeSchedule.items
    }
    
    public var timeZone: TimeZone {
        get {
            return rangeSchedule.timeZone
        }
        set {
            rangeSchedule.timeZone = newValue
        }
    }
    
    public var unit: HKUnit {
        return rangeSchedule.unit
    }
    
    public var rawValue: RawValue {
        var rawValue = rangeSchedule.rawValue
        
        var overrideRangesRawValue: [String: DoubleRange.RawValue] = [:]
        for (key, value) in overrideRanges {
            overrideRangesRawValue[key.rawValue] = value.rawValue
        }
        
        rawValue["overrideRanges"] = overrideRangesRawValue
        rawValue["override"] = override?.rawValue
        
        return rawValue
    }
}


extension GlucoseRangeSchedule.Override: RawRepresentable {
    public typealias RawValue = [String: Any]
    
    public init?(rawValue: RawValue) {
        guard let contextRaw = rawValue["context"] as? Context.RawValue,
            let context = Context(rawValue: contextRaw),
            let valueRaw = rawValue["value"] as? DoubleRange.RawValue,
            let value = DoubleRange(rawValue: valueRaw),
            let start = rawValue["start"] as? Date
            else {
                return nil
        }
        
        self.context = context
        self.start = start
        self.end = rawValue["end"] as? Date
        self.value = value
    }
    
    public var rawValue: RawValue {
        var raw: RawValue = [
            "context": context.rawValue,
            "start": start,
            "value": value.rawValue
        ]
        
        raw["end"] = end
        
        return raw
    }
}


extension GlucoseRangeSchedule.Override: Equatable {
    public static func ==(lhs: GlucoseRangeSchedule.Override, rhs: GlucoseRangeSchedule.Override) -> Bool {
        return lhs.context == rhs.context &&
            lhs.start == rhs.start &&
            lhs.end == rhs.end &&
            lhs.value == rhs.value
    }
}


extension GlucoseRangeSchedule: Equatable {
    public static func ==(lhs: GlucoseRangeSchedule, rhs: GlucoseRangeSchedule) -> Bool {
        return lhs.rangeSchedule == rhs.rangeSchedule &&
            lhs.overrideRanges == rhs.overrideRanges &&
            lhs.override == rhs.override
    }
}

extension GlucoseRangeSchedule {
    func overrideEnabledForContext(_ context: Override.Context) -> Bool? {
        guard let override = override, override.context == context else {
            guard let value = overrideRanges[context], !value.isZero else {
                // Unavailable to set
                return nil
            }
            
            return false
        }
        
        return override.isActive()
    }
    
    var activeOverrideContext: GlucoseRangeSchedule.Override.Context? {
        guard let override = override, override.isActive() else {
            return nil
        }
        
        return override.context
    }
    
    var configuredOverrideContexts: [GlucoseRangeSchedule.Override.Context] {
        var contexts: [GlucoseRangeSchedule.Override.Context] = []
        for (context, range) in overrideRanges where !range.isZero {
            contexts.append(context)
        }
        
        return contexts
    }
    
    func minQuantity(at date: Date) -> HKQuantity {
        return HKQuantity(unit: unit, doubleValue: value(at: date).minValue)
    }
}


extension DoubleRange {
    var averageValue: Double {
        return (maxValue + minValue) / 2
    }
}
