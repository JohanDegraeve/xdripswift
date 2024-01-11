//
//  RangeBin.swift
//  xdrip
//
//  Created by Todd Dalton on 11/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// This `struct` is used to hold the blood sugar levels in any particular hour..
///
/// In order to draw an Ambulatory Glucose Profile chart, we need to have the BG levels
/// sorted into hours, so there will ultimately be 24 of these 'bins' with all the levels between 00:00 - 00:59 in the first bin,
/// 01:00 - 01-59 in the second, 02:00 - 02:59 in the third and so on,.

struct BGRangeBin {
    
    /// For AGP reports we need the 10th, 25th,50th, 75th and 90th percentiles.
    struct Quartiles {
        /// 10th Percentile
        var Q10: UniversalBGLevel
        /// 25th Percentile
        var Q25: UniversalBGLevel
        /// 50th Percentile - not to be confused with the **average**.
        var Q50: UniversalBGLevel
        /// 75th Percentile
        var Q75: UniversalBGLevel
        /// 90th Percentile
        var Q90: UniversalBGLevel
        
        init() {
            Q10 = UniversalBGLevel()
            Q25 = UniversalBGLevel()
            Q50 = UniversalBGLevel()
            Q75 = UniversalBGLevel()
            Q90 = UniversalBGLevel()
        }
        
        /// The **median** is the same as the second quartile
        var median: UniversalBGLevel { return Q50 }
    }
    
    private (set) var highestLevel: UniversalBGLevel = UniversalBGLevel(mmoll: MMOLL(0))
    
    private (set) var lowestLevel: UniversalBGLevel = UniversalBGLevel(mmoll: MMOLL(999))
    
    private (set) var averageLevel: UniversalBGLevel = UniversalBGLevel(mmoll: MMOLL(6.0))
    
    private (set) var isOnlyInitialised: Bool = true
    
    private(set) var accumulatedTotal: UniversalBGLevel = UniversalBGLevel(value: 0.0)
    
    private(set) var quartiles: Quartiles = Quartiles()
    
    /// This is the hour that this bin refers to.
    ///
    /// The default is zero, so by default this bin will
    /// be for results between 00:00 - 00:59
    var hour: Int = 0
    
    /// This UniversalBGLevel array holds the results in this bin's timeframe
    private (set) var levels:[UniversalBGLevel] = []
    
    /// If the timestamp of a `UniversalBGLevel` is within the `hour` that this
    /// bin is for, then the `count` and high/low/average levels will be adjusted
    /// if applicable.
    ///
    /// Returns a dicardable `Bool` to indicate if the level was "accepted".
    @discardableResult public mutating func addResultWithTimestampCheck(level: UniversalBGLevel) -> Bool {
 
        guard Calendar.current.component(.hour, from: level.timestamp) == hour else { return false }
        
        return addResult(level: level)
    }
    
    /// Adds a value to this bin. The `count` and high/low/average levels will be adjusted
    /// if applicable.
    ///
    /// Returns a dicardable `Bool` to indicate if the level was "accepted".
    @discardableResult public mutating func addResult(level: UniversalBGLevel) -> Bool {
        
        // Check to see if this new level will alter the range bounds
        if level < lowestLevel {
            lowestLevel = UniversalBGLevel(timestamp: level.timestamp, mmoll: level.mmoll)
        }
        
        if level > highestLevel {
            highestLevel = UniversalBGLevel(timestamp: level.timestamp, mmoll: level.mmoll)
        }
        
        levels.append(level)
        
        accumulatedTotal += level
        
        averageLevel = UniversalBGLevel(timestamp: level.timestamp, mmoll: MMOLL(accumulatedTotal.mmoll.value / Double(levels.count)))
        
        isOnlyInitialised = false
        
        return true
    }
    
    /// Calculate the quartiles Q1, 2 & 3
    mutating func calcQs() {
        
        guard !isOnlyInitialised, levels.count > 2 else { return }
        
        levels = levels.sorted { aBG, bBG in
            return aBG < bBG
        }
        
        func quartile(q: Double) -> UniversalBGLevel {
            let qSpot = (q / 100) * Double(levels.count)
            if ceil(qSpot) == floor(qSpot) {
                // whole number
                let med = (levels[Int(qSpot)].levelInUserUnits + levels[min(Int(qSpot) + 1, levels.count - 1)].levelInUserUnits) / 2
                return UniversalBGLevel(timestamp: levels[Int(qSpot)].timestamp, value: med)
            }
            return UniversalBGLevel(anotherReading: levels[Int(qSpot)])
        }
        
        
        // --- Calculate Q10
        quartiles.Q10 = quartile(q: 10)
        // --- Calculate Q25
        quartiles.Q25 = quartile(q: 25)
        // --- Calculate Q50 aka median
        quartiles.Q50 = quartile(q: 50)
        // --- Calculate Q75
        quartiles.Q75 = quartile(q: 75)
        // --- Calculate Q90
        quartiles.Q90 = quartile(q: 90)
    }
}
