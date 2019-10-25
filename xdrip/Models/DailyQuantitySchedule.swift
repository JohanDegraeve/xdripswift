//
//  DailyQuantitySchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct DailyQuantitySchedule<T: RawRepresentable>: DailySchedule {
    public typealias RawValue = [String: Any]
    public let unit: HKUnit
    var valueSchedule: DailyValueSchedule<T>
    
    public init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<T>], timeZone: TimeZone? = nil) {
        guard let valueSchedule = DailyValueSchedule<T>(dailyItems: dailyItems, timeZone: timeZone) else {
            return nil
        }
        
        self.unit = unit
        self.valueSchedule = valueSchedule
    }
    
    public init?(rawValue: RawValue) {
        guard let rawUnit = rawValue["unit"] as? String,
            let valueSchedule = DailyValueSchedule<T>(rawValue: rawValue)
            else
        {
            return nil
        }
        
        self.unit = HKUnit(from: rawUnit)
        self.valueSchedule = valueSchedule
    }
    
    public var items: [RepeatingScheduleValue<T>] {
        return valueSchedule.items
    }
    
    public var timeZone: TimeZone {
        get {
            return valueSchedule.timeZone
        }
        set {
            valueSchedule.timeZone = newValue
        }
    }
    
    public var rawValue: RawValue {
        var rawValue = valueSchedule.rawValue
        
        rawValue["unit"] = unit.unitString
        
        return rawValue
    }
    
    public func between(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<T>] {
        return valueSchedule.between(start: startDate, end: endDate)
    }
    
    public func value(at time: Date) -> T {
        return valueSchedule.value(at: time)
    }
}


extension DailyQuantitySchedule: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(reflecting: rawValue)
    }
}


public typealias SingleQuantitySchedule = DailyQuantitySchedule<Double>


public extension DailyQuantitySchedule where T == Double {
    func quantity(at time: Date) -> HKQuantity {
        return HKQuantity(unit: unit, doubleValue: valueSchedule.value(at: time))
    }
    
    func averageValue() -> Double {
        var total: Double = 0
        
        for (index, item) in valueSchedule.items.enumerated() {
            var endTime = valueSchedule.maxTimeInterval
            
            if index < valueSchedule.items.endIndex - 1 {
                endTime = valueSchedule.items[index + 1].startTime
            }
            
            total += (endTime - item.startTime) * item.value
        }
        
        return total / valueSchedule.repeatInterval
    }
    
    func averageQuantity() -> HKQuantity {
        return HKQuantity(unit: unit, doubleValue: averageValue())
    }
}


extension DailyQuantitySchedule where T: Equatable {
    public static func ==(lhs: DailyQuantitySchedule<T>, rhs: DailyQuantitySchedule<T>) -> Bool {
        return lhs.valueSchedule == rhs.valueSchedule && lhs.unit.unitString == rhs.unit.unitString
    }
}
