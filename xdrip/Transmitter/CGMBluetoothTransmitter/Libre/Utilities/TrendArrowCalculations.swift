//
//  TrendArrowCalculations.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 26/03/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation

//https://github.com/dabear/FloatingGlucose/blob/master/FloatingGlucose/Classes/Utils/GlucoseMath.cs

public enum GlucoseTrend : Int, CaseIterable {
    
    case upUpUp
    
    case upUp
    
    case up
    
    case flat
    
    case down
    
    case downDown
    
    case downDownDown
}

class TrendArrowCalculation {
    static func calculateSlope(current: LibreRawGlucoseData, last: LibreRawGlucoseData) -> Double
    {
        if current.timeStamp == last.timeStamp {
            return 0.0
        }
        
        let _curr = Double(current.timeStamp.timeIntervalSince1970 * 1000)
        let _last = Double(last.timeStamp.timeIntervalSince1970 * 1000)
        
        
        
        return (Double(last.unsmoothedGlucose) - Double(current.unsmoothedGlucose)) / (_last - _curr)
    }
    
    static func calculateSlopeByMinute(current: LibreRawGlucoseData, last: LibreRawGlucoseData) -> Double
    {
        return calculateSlope(current: current, last: last) * 60000;
    }
    
    static func GetGlucoseDirection(current: LibreRawGlucoseData?, last: LibreRawGlucoseData?) -> GlucoseTrend {
        NSLog("GetGlucoseDirection:: current:\(current), last: \(last)")
        guard let current = current, let last = last else {
            return GlucoseTrend.flat
        }
        
        
        let  s = calculateSlopeByMinute(current: current, last: last)
        NSLog("Got trendarrow value of \(s))")
        
        switch s {
        case _ where s <= (-3.5):
            return GlucoseTrend.downDownDown
        case _ where s <= (-2):
            return GlucoseTrend.downDown
        case _ where s <= (-1):
            return GlucoseTrend.down
        case _ where s <= (1):
            return GlucoseTrend.flat
        case _ where s <= (2):
            return GlucoseTrend.up
        case _ where s <= (3.5):
            return GlucoseTrend.upUp
        case _ where s <= (40):
            return GlucoseTrend.flat //flat is the new (tm) "unknown"!
            
        default:
            NSLog("Got unknown trendarrow value of \(s))")
            return GlucoseTrend.flat
        }
        
    }
}
